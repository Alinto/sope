/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "common.h"
#include "NGBufferedDescriptor.h"

extern int HEAVY_LOG;

//#define HTTP_DETAIL_LOG 1

#define SNS_HTTP_METHOD "POST"
#define SNS_LOOKUP_URL  "/snsd2/wa/lookupSession"
#define SNS_REQLINE     "reqline"
#define SNS_APPNAME     "appname"
#define SNS_COOKIES     "cookies"

static inline int _isPlistBreakChar(unsigned char c)
{
    if (!apr_isalnum(c)) return 1;
    
    switch (c) {
        case '_': case '@': case '#': case '$':
        case '.': case '=': case ';': case ',':
        case '{': case '}': case '(': case ')':
        case '<': case '>': case '/': case '\\':
        case '"':
            return 1;
            
        default:
            return 0;
    }
}

static void _getSNSAddressForRequest(request_rec *_rq, struct sockaddr **_sns,
                                     ngobjweb_dir_config *_cfg)
{
  //extern struct sockaddr *sns;
  struct sockaddr *result = NULL; //sns;
  const char *socket;
  
  *_sns = NULL;
  if (_rq == NULL) {
    fprintf(stderr, "%s: missing request ...\n", __PRETTY_FUNCTION__);
    return;
  }
  if (_cfg == NULL) {
    ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, _rq->server,
                 "SNS: missing directory config for request ..");
    return;
  }
  
    if ((socket = _cfg->snsPort)) {
      long int port;
      char     *end, *pos;
      
      if (_cfg->snsPortDomain == AF_UNIX) {
        result = apr_palloc(_rq->pool, sizeof(struct sockaddr_un));
        memset(result, 0, sizeof(struct sockaddr_un));
        
        ((struct sockaddr_un *)result)->sun_family = AF_UNIX;
        strncpy(((struct sockaddr_un *)result)->sun_path,
                socket,
                sizeof(((struct sockaddr_un *)result)->sun_path) - 1);
      }
      else if (_cfg->snsPortDomain == AF_INET) {
        /* the string contained a number - the port of an IP address */
        struct sockaddr_in *snsi;
        unsigned char *host;

        /* try to convert port to number */
        if ((pos = index(socket, ':'))) {
          /* contains a ':' */
          port = strtol((pos + 1), &end, 10);
          
          host = apr_palloc(_rq->pool, (pos - socket) + 3);
          strncpy((char *)host, socket, (pos - socket));
          host[pos - socket] = '\0';
        }
        else {
          host = (unsigned char *)"127.0.0.1";
          port = strtol(socket, &end, 10);
        }
        
        result = apr_palloc(_rq->pool, sizeof(struct sockaddr_in));
        memset(result, 0, sizeof(struct sockaddr_in));
        snsi = (struct sockaddr_in *)result;
        
        snsi->sin_addr.s_addr = apr_inet_addr((char *)host);
        
        snsi->sin_family = AF_INET;
        snsi->sin_port   = htons((short)(port & 0xFFFF));
        
        if (snsi->sin_addr.s_addr == -1) {
          ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, _rq->server,
                       "SNS: couldn't convert snsd IP address: %s", host);
        }
        if (HEAVY_LOG && 0) {
          ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, _rq->server,
                       "SNS: connect IP address: %s", host);
        }
      }
      else {
        ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, _rq->server,
                     "SNS: unknown socket domain %i for SNS server "
                     "(address=%s) !!!",
                     _cfg->snsPortDomain, _cfg->snsPort);
      }
    }
  
  *_sns = result;
}

static void _logSNSConnect(request_rec *_rq, struct sockaddr *sns) {
  if (sns == NULL) {
    ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, _rq->server,
                 "found no SNS socket address ...");
    return;
  }
  if (sns->sa_family == AF_INET) {
    struct sockaddr_in *snsi = (struct sockaddr_in *)sns;
      
    if (HEAVY_LOG) {
      ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, _rq->server,
                   "SNS: connecting INET socket (family=%d, ip=%s:%i) ...",
                   sns->sa_family,
                   inet_ntoa(snsi->sin_addr),
                   ntohs(snsi->sin_port));
    }
  }
  else if (sns->sa_family == AF_UNIX) {
    if (HEAVY_LOG) {
      ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, _rq->server,
                   "SNS: connect UNIX socket (family=%d) ...",
                   sns->sa_family);
    }
  }
  else {
    ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, _rq->server,
                 "SNS: unknown socket address family: %d.",
                 sns->sa_family);
  }
}

void *_sendSNSQuery(request_rec *_rq, const char *_line,
                    const char *_cookie,
                    int *_domain, size_t *_len,
                    const char *_appName,
                    ngobjweb_dir_config *_cfg)
{
  /*
    Sends a query for the instance socket address to the session
    name server.
  */
  NGBufferedDescriptor *toSNS = NULL;
  int    fd;
  struct sockaddr *sns;
  int    failed = 0;
  
  _getSNSAddressForRequest(_rq, &sns, _cfg);
  if (sns == NULL) {
    return NULL;
  }
  
  *_domain = 0;
  *_len    = 0;
  
  if (_line   == NULL) _line   = "";
  if (_cookie == NULL) _cookie = "";
  
  /* setup connection */
  {
    _logSNSConnect(_rq, sns);
    
    fd = socket(sns->sa_family, SOCK_STREAM, 0);
    if (fd < 0) {
      ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, _rq->server,
                   "SNS: could not setup socket to SNS: %s.",
                   strerror(errno));
      return NULL;
    }
    
    if (connect(fd, sns,
                (sns->sa_family == AF_INET)
                ? sizeof(struct sockaddr_in)
                : sizeof(struct sockaddr_un)) != 0) {
      if (HEAVY_LOG) {
        ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, _rq->server,
                     "could not connect sns daemon %s: %s.",
                     sns->sa_family == AF_UNIX
                     ? ((struct sockaddr_un *)sns)->sun_path
                     : "via ip",
                     strerror(errno));
      }
      close(fd);
      return NULL;
    }
    
    toSNS = NGBufferedDescriptor_newWithOwnedDescriptorAndSize(fd, 1024);
    if (toSNS == NULL) {
      ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, _rq->server,
                "could not allocate buffered descriptor.");
      close(fd);
      return NULL;
    }
  }
  
  /* send request */
  {
    char c   = 50; // SNSLookupSession
    int  len = strlen(_line);
    
    if (HEAVY_LOG) {
      ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, _rq->server,
                   "SNS: line %s cookie '%s'", _line, _cookie);
    }
    
    /* send message code */
    if (!NGBufferedDescriptor_safeWrite(toSNS, &c, 1)) {
      failed = 1;
      goto finish;
    }
    
    /* send request line + space + appname */
    len = strlen(_line) + 1 + strlen(_appName);
    if (!NGBufferedDescriptor_safeWrite(toSNS, &len, sizeof(len))) {
      failed = 2;
      goto finish;
    }
    
    if ((len = strlen(_line)) > 0) {
      if (!NGBufferedDescriptor_safeWrite(toSNS, _line, len)) {
        failed = 3;
        goto finish;
      }
    }
    if (!NGBufferedDescriptor_safeWrite(toSNS, " ", 1)) {
      failed = 4;
      goto finish;
    }
    if ((len = strlen(_appName)) > 0) {
      if (!NGBufferedDescriptor_safeWrite(toSNS, _appName, len)) {
        failed = 5;
        goto finish;
      }
    }
    
    // send cookie
    len = strlen(_cookie);
    if (len > 2000) {
      ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, _rq->server,
                   "WARNING: cookie length > 2000 bytes (%i bytes): %s",
                   len, _cookie);
    }
    if (!NGBufferedDescriptor_safeWrite(toSNS, &len, sizeof(len))) {
      failed = 6;
      goto finish;
    }
    if (len > 0) {
      if (!NGBufferedDescriptor_safeWrite(toSNS, _cookie, len)) {
        failed = 7;
        goto finish;
      }
    }

    if (!NGBufferedDescriptor_flush(toSNS)) {
      failed = 8;
      goto finish;
    }
    
    if (HEAVY_LOG) {
      ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, _rq->server,
                   "SNS: reading response ..");
    }
    
    // recv response
    {
      char *buffer;
      int  domain;
      int  size;

      buffer = apr_palloc(_rq->pool, 1000);
      memset(buffer, 0, 1000);
      
      if (!NGBufferedDescriptor_safeRead(toSNS, &domain, sizeof(domain))) {
        failed = 9;
        goto finish;
      }
      if (HEAVY_LOG) {
        ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, _rq->server,
                     "SNS:   domain: %i ..", domain);
      }
      
      if (!NGBufferedDescriptor_safeRead(toSNS, &size, sizeof(size))) {
        failed = 10;
        goto finish;
      }
      if (HEAVY_LOG) {
        ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, _rq->server,
                     "SNS:   size: %i ..", size);
      }
      
      if (size > 1024) {
        ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, _rq->server,
                     "SNS: size of returned address is too big (%i bytes) !",
                     size);
        goto finish;
      }
      
      if (!NGBufferedDescriptor_safeRead(toSNS, buffer, size)) {
        failed = 11;
        goto finish;
      }
      
      if (HEAVY_LOG) {
        ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, _rq->server,
                     "SNS: got address in domain %i, size is %i bytes !",
                     domain, size);
      }

      *_domain = domain;
      *_len    = size;
      
      if (toSNS) {
        NGBufferedDescriptor_free(toSNS);
        toSNS = NULL;
      }
      return buffer;
    }
  finish:
    if (failed) {
      ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, _rq->server,
                   "SNS: lookup request failed (code=%i) !", failed);
    }
    if (toSNS) {
      NGBufferedDescriptor_free(toSNS);
      toSNS = NULL;
    }
  }
  return NULL;
}
