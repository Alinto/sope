/*
  Copyright (C) 2000-2008 SKYRIX Software AG

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

#define BUFSIZE   2048

/* ap_http_method is deprecated in Apache 2.2.x */
#if MODULE_MAGIC_NUMBER_MAJOR >= 20051115
#define ap_http_method ap_http_scheme
#endif

extern int HEAVY_LOG;

#if WITH_LOGGING
static void _logTable(const char *text, apr_table_t *table);
#endif

static ngobjweb_dir_config *_getConfig(request_rec *r) {
  ngobjweb_dir_config *cfg;

  if (r == NULL) {
    fprintf(stderr, "%s: missing request !\n", __PRETTY_FUNCTION__);
    return NULL;
  }
  if (r->per_dir_config == NULL) {
    ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, r->server,
                 "missing directory config in request ...");
    return NULL;
  }
  
  cfg = (ngobjweb_dir_config *)
    ap_get_module_config(r->per_dir_config, &ngobjweb_module);
  
  return cfg;
}

static void _extractAppName(const char *uri, char *appName, int maxLen) {
  char *tmp;
  
  /* extract name of application */
  if ((tmp = index(uri + 1, '/'))) {
    int len;
    len = (tmp - (uri + 1));
    strncpy(appName, (uri + 1), len);
    appName[len] = '\0';
  }
  else {
    strncpy(appName, (uri + 1), maxLen - 1);
    appName[maxLen - 1] = '\0';
  }
  
  /* cut off .woa extension from application name */
  if ((tmp = strstr(appName, ".woa")))
    *tmp = '\0';
  
  /* cut off .sky extension from application name */
  if ((tmp = strstr(appName, ".sky")))
    *tmp = '\0';
}

static void *_readRequestBody(request_rec *r, int *requestContentLength) {
  const char *clen;
  int  contentLength;
  void *ptr;
  int  readBytes, toBeRead;
  void *requestBody;
  
  clen = apr_table_get(r->headers_in, "content-length");
  contentLength = clen ? atoi(clen) : 0;
  *requestContentLength = contentLength;
  
  /* no content to read ... */
  if (contentLength == 0) return NULL;
  
  /* read content */
  
  if (HEAVY_LOG) {
    ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, r->server, 
                 "going to read %i bytes from browser ...", contentLength);
  }
  
  requestBody = apr_palloc(r->pool, contentLength + 2);

  ptr = requestBody;
  for (toBeRead = contentLength; toBeRead > 0;) {
#ifdef AP_VERSION_1
    readBytes = ap_bread(r->connection->client, ptr, toBeRead);
#else
		ap_setup_client_block(r,REQUEST_CHUNKED_DECHUNK);
    readBytes = ap_get_client_block(r, ptr, toBeRead);
#endif
    toBeRead -= readBytes;
    ptr += readBytes;
    if (readBytes == 0) break;
  }
  ptr = NULL;
      
  if (toBeRead > 0) {
    ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, r->server,
                 "couldn't read complete HTTP req body from browser "
                 "(read %i of %i bytes)",
                 (contentLength - toBeRead), contentLength);
    return NULL;
  }
  
  return requestBody;
}

static void
_copyHeadersToRequest(request_rec *r, apr_table_t *headers, int *contentLength)
{
  const apr_array_header_t *array;
  apr_table_entry_t  *entries;
  int          i;
  const char   *value;
  
  if (headers == NULL) return;
  
  value = apr_table_get(headers, "content-type");
  if (value) r->content_type = value;
  value = apr_table_get(headers, "content-encoding");
  if (value) r->content_encoding = value;
  value = apr_table_get(headers, "content-length");
  *contentLength = value ? atoi(value) : 0;
  
  array   = apr_table_elts(headers);
  entries = (apr_table_entry_t *)array->elts;

  for (i = 0; i < array->nelts; i++) {
    apr_table_entry_t *entry = entries + i;

    apr_table_add(r->headers_out, entry->key, entry->val);
  }
  // _logTable("out", r->headers_out);
}

static void _logInstanceAddress(request_rec *r, struct sockaddr *address,
                                size_t addressLen, int domain)
{
  char buf[1024];
  
  if (!HEAVY_LOG) return;
  
  apr_snprintf(buf, sizeof(buf), "  => address len=%li domain=%i<", (long int) addressLen, domain);
  switch (domain) {
    case AF_INET: strcat(buf, "inet"); break;
    case AF_UNIX: strcat(buf, "unix"); break;
    default: strcat(buf, "unknown"); break;
  }
  strcat(buf, ">");
  
  if (domain == AF_UNIX) {
    strcat(buf, " path=\"");
    strcat(buf, ((struct sockaddr_un *)address)->sun_path);
    strcat(buf, "\"");
  }
  else if (domain == AF_INET) {
    char         *ptr = NULL;
    int  port;
    char sport[256];
    
    ptr  = inet_ntoa(((struct sockaddr_in *)address)->sin_addr);
    port = ntohs(((struct sockaddr_in *)address)->sin_port);
    apr_snprintf(sport, sizeof(sport), "host=\"%s\" port=%i", ptr, port);
    strcat(buf, sport);
  }
  
  ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, r->server, buf);
}

static int _connectInstance(request_rec *r,
                            int appFd, struct sockaddr *address,
                            size_t addressLen)
{
  int  result;
  int  tryCount = 0;
  char isConnected = 0;
  
  result = connect(appFd, address, addressLen);
  if (result >= 0) return result;
  
  while (tryCount < 3) {
    char *pdelay = NULL; /* pblock_findval("delay", _paras) */
    int delay    = pdelay ? atoi(pdelay) : 3; // default: 3s

    ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, r->server,
                 "sleeping %is ..", delay);
#ifdef AP_VERSION_1
    apr_sleep(delay); /* should be in seconds for Apache 1? */
#else
    apr_sleep(delay * 1000 * 1000 /* in microseconds now! */);
#endif
    
    ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, r->server,
                 "retry connect ..");
    result = connect(appFd, address, addressLen);
    
    if (result >= 0) {
      isConnected = 1;
      break;
    }
    tryCount++;
  }
  
  if (isConnected == 0) {
    ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, r->server,
                 "connect to application instance failed, tried %i times.",
                 tryCount);
    close(appFd);
    return -1;
  }
  return result;
}

static int _writeInHeaders(NGBufferedDescriptor *toApp, request_rec *r) {
  const apr_array_header_t *array;
  apr_table_entry_t  *entries;
  int          i;
  
  if (r->headers_in == NULL) return 1;

  array   = apr_table_elts(r->headers_in);
  entries = (apr_table_entry_t *)array->elts;

  for (i = 0; i < array->nelts; i++) {
    apr_table_entry_t *entry = &(entries[i]);
        
    if (!NGBufferedDescriptor_writeHttpHeader(toApp,
                                              entry->key, (void*)entry->val)) {
      return 0;
    }
  }
  return 1;
}

int ngobjweb_handler(request_rec *r) {
  struct    sockaddr   *address = NULL;
  size_t               addressLen;
  int                  domain;
  char                 appName[256];
  NGBufferedDescriptor *toApp = NULL;
  int                  appFd;
  int                  result;
  int                  writeError    = 0;
  int                  contentLength = 0;
  int                  statusCode    = 500;
  ngobjweb_dir_config  *cfg;
  const char           *uri;
  unsigned             requestContentLength;
  void                 *requestBody;
  
  uri = r->uri;
  requestContentLength = 0;
  requestBody = NULL;

#ifndef AP_VERSION_1
  if (r->handler == NULL)
    return DECLINED;
  if (strcmp(r->handler, "ngobjweb-adaptor") != 0)
    return DECLINED;
#endif

  if (uri == NULL)   return DECLINED;
  if (uri[0] != '/') return DECLINED;
  if (strstr(uri, "WebServerResources")) return DECLINED;

  /* get directory configuration */
  
  if ((cfg = _getConfig(r))) {
    if (cfg->appPrefix) {
      if (HEAVY_LOG) {
        ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, r->server,
                     "using prefix '%s'\n", cfg->appPrefix);
      }
      uri += strlen(cfg->appPrefix);
    }
  }
  else {
    return 500;
  }

  /* find app name in url */
  _extractAppName(uri, appName, sizeof(appName));
  
  /* before continuing, read request body */
  
  requestBody = _readRequestBody(r, &contentLength);
  requestContentLength = contentLength;
  
  if ((requestBody == NULL) && (contentLength > 0))
    /* read failed, error is logged in function */
    return 500;
  
  /* ask SNS for server address */

  if (cfg->snsPort) {
    address = _sendSNSQuery(r,
                            r->the_request,
                            apr_table_get(r->headers_in, "cookie"),
                            &domain, &addressLen,
                            appName,
                            cfg);
    if (address == NULL) {
      /* did not find an appropriate application server */
      ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, r->server,
                   "did not find SOPE instance using SNS.");
      return DECLINED;
    }
  }
  else if (cfg->appPort) {
    domain = cfg->appPortDomain;
    
    if (cfg->appPortDomain == AF_UNIX) {
      addressLen = sizeof(struct sockaddr_un);
      address = apr_palloc(r->pool, sizeof(struct sockaddr_un)); 
      memset(address, 0, sizeof(struct sockaddr_un)); 
         
      ((struct sockaddr_un *)address)->sun_family = AF_UNIX; 
      strncpy(((struct sockaddr_un *)address)->sun_path, 
              cfg->appPort, 
              sizeof(((struct sockaddr_un *)address)->sun_path) - 1);
    }
    else {
      struct sockaddr_in *snsi;
      char *host, *pos;
      int  port;
      
      if ((pos = index(cfg->appPort, ':'))) {
	host = apr_palloc(r->pool, (pos - cfg->appPort) + 3);
	strncpy(host, cfg->appPort, (pos - cfg->appPort));
	host[pos - cfg->appPort] = '\0';
	
	port = atoi(pos + 1);
      }
      else {
	host = "127.0.0.1";
	port = atoi(cfg->appPort);
      }
      
#if HEAVY_LOG
      ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, r->server,
                   "appPort: '%s' host: %s port %d, cfg 0x%p",
		   cfg->appPort, host, port, cfg);
#endif
      
      addressLen = sizeof(struct sockaddr_in);
      address = apr_palloc(r->pool, sizeof(struct sockaddr_in));
      memset(address, 0, sizeof(struct sockaddr_in)); 
      snsi = (struct sockaddr_in *)address; 
         
      snsi->sin_addr.s_addr = apr_inet_addr(host); 
      
      snsi->sin_family = AF_INET; 
      snsi->sin_port   = htons((short)(port & 0xFFFF)); 
      
      if (snsi->sin_addr.s_addr == -1) { 
	ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, r->server,
		     "could not convert IP address: %s", host); 
      } 
      if (HEAVY_LOG && 0) { 
        ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, r->server,
                     "connect IP address: %s", host); 
      } 
    }
  }
  else {
    ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, r->server,
		 "neither SNS port nor app port are set for request ...");
    return 500;
  }

  if (addressLen > 10000) {
    ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, r->server,
		 "suspect instance port length (%li) ...", 
                 (long int) addressLen);
    return 500;
  }
  
  _logInstanceAddress(r, address, addressLen, domain);
  
  /* setup connection to application server */
  
  if ((appFd = socket(domain, SOCK_STREAM, 0)) < 0) {
    ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, r->server,
                 "could not create socket in domain %i.", domain);
    return DECLINED;
  }

  if ((result = _connectInstance(r, appFd, address, addressLen)) < 0)
    return 500;
  
  toApp = NGBufferedDescriptor_newWithOwnedDescriptorAndSize(appFd, 512);
  if (toApp == NULL) {
    close(appFd);
    ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, r->server,
                 "could not alloc socket buffer for "
                 "application server connection");
    return 500;
  }
  
  /* write request to application server */
  
  if (HEAVY_LOG) {
    ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, r->server, 
                 "transfer reqline");
  }

  {
    char *reqLine;
    unsigned toGo;

    reqLine = r->the_request;
    toGo = reqLine ? strlen(reqLine) : 0;
    
    ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, r->server,
                 "req is %s(len=%i)", reqLine, toGo);

    if (!NGBufferedDescriptor_safeWrite(toApp, reqLine,
                                        reqLine ? strlen(reqLine) : 0)) {
      writeError = 1;
      goto writeErrorHandler;
    }
    if (!NGBufferedDescriptor_safeWrite(toApp, "\r\n", 2)) {
      writeError = 1;
      goto writeErrorHandler;
    }
  }

  /* transfer headers */
  
  if (writeError == 0) {
    if (HEAVY_LOG) {
      ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, r->server, 
                   "transfer hdrs");
    }
    
    /* extended adaptor headers */
    {
      char tmp[256];
      const char *value;
      
      value = r->protocol;
      value = (value != NULL) ? value : "http";
      if (!NGBufferedDescriptor_writeHttpHeader(toApp,
                                                "x-webobjects-server-protocol",
                                                (unsigned char *)value)) {
        writeError = 1;
        goto writeErrorHandler;
      }
      
      if ((value = r->connection->remote_ip) != NULL) {
        if (!NGBufferedDescriptor_writeHttpHeader(toApp,
                                                  "x-webobjects-remote-addr",
                                                  (unsigned char *)value)) {
          writeError = 1;
          goto writeErrorHandler;
        }
      }
      
      value = r->connection->remote_host;
      if (value == NULL) value = r->connection->remote_ip;
      if (value != NULL) {
        if (!NGBufferedDescriptor_writeHttpHeader(toApp,
                                                  "x-webobjects-remote-host",
                                                  (unsigned char *)value)) {
          writeError = 1;
          goto writeErrorHandler;
        }
      }

#ifdef AP_VERSION_1
      if ((value = r->connection->ap_auth_type) != NULL) {
#else
      if ((value = r->ap_auth_type) != NULL) {
#endif
        if (!NGBufferedDescriptor_writeHttpHeader(toApp,
                                                  "x-webobjects-auth-type",
                                                  (unsigned char *)value)) {
          writeError = 1;
          goto writeErrorHandler;
        }
      }
      
#ifdef AP_VERSION_1
      if ((value = r->connection->user) != NULL) {
#else
      if ((value = r->user) != NULL) {
#endif
        if (!NGBufferedDescriptor_writeHttpHeader(toApp,
                                                  "x-webobjects-remote-user",
                                                  (unsigned char *)value)) {
          writeError = 1;
          goto writeErrorHandler;
        }
      }
      
      if (cfg != NULL) {
        if (cfg->appPrefix != NULL) {
          if (!NGBufferedDescriptor_writeHttpHeader(toApp,
                "x-webobjects-adaptor-prefix", 
                (unsigned char *)cfg->appPrefix)) {
            writeError = 1;
            goto writeErrorHandler;
          }
        }
      }

      if (!NGBufferedDescriptor_writeHttpHeader(toApp,
                                                "x-webobjects-server-name",
                                                (unsigned char *)
                                                r->server->server_hostname)) {
        writeError = 1;
        goto writeErrorHandler;
      }
      
      if (r->server->port != 0) {
        apr_snprintf(tmp, sizeof(tmp), "%i", r->server->port);
        if (!NGBufferedDescriptor_writeHttpHeader(toApp,
                                                  "x-webobjects-server-port",
                                                  (unsigned char *)tmp)) {
          writeError = 1;
          goto writeErrorHandler;
        }
      }

      // TODO: this seems to be broken with some Apache's!
      // see: http://www.mail-archive.com/modssl-users@modssl.org/msg16396.html
      if (r->server->port != 0) {
        apr_snprintf(tmp, sizeof(tmp), "%s://%s:%i",
                     ap_http_method(r),
                     r->server->server_hostname,
                     r->server->port);
      }
      else {
        apr_snprintf(tmp, sizeof(tmp), "%s://%s",
                     ap_http_method(r), r->server->server_hostname);
      }
      if (!NGBufferedDescriptor_writeHttpHeader(toApp,
                                                "x-webobjects-server-url",
                                                (unsigned char *)tmp)) {
        writeError = 1;
        goto writeErrorHandler;
      }
      
      /* SSL environment */
      
      if (r->subprocess_env != NULL) {
        apr_table_t *env = r->subprocess_env;
        const char *s;
        
        s = apr_table_get(env, "HTTPS");
        if (s != NULL && strncasecmp(s, "on", 2) == 0) { // SSL is one
          if (!NGBufferedDescriptor_writeHttpHeader(toApp,
                                                  "x-webobjects-https-enabled",
                                                    (unsigned char *)"1")) {
            writeError = 1;
            goto writeErrorHandler;
          }
        }
        
        s = apr_table_get(env, "SSL_CLIENT_CERT");
        if (s != NULL) {
          const apr_array_header_t *array;
          apr_table_entry_t  *entries;
          int          i;
          
          if (!NGBufferedDescriptor_writeHttpHeader(toApp,
                                                   "x-webobjects-clients-cert",
                                                    (unsigned char *)s)) {
            writeError = 1;
            goto writeErrorHandler;
          }
          
          /* deliver all SSL_CLIENT_ env-vars as headers */
          array   = apr_table_elts(env);
          entries = (apr_table_entry_t *)array->elts;
          for (i = 0; i < array->nelts; i++) {
            apr_table_entry_t *entry = &(entries[i]);
            
            if (strncmp(entry->key, "SSL_CLIENT_", 11) != 0)
              continue;
            if (strncmp(entry->key, "SSL_CLIENT_CERT", 15) == 0)
              continue; /* already avail as x-webobjects-clients-cert" */
            
            if (!NGBufferedDescriptor_writeHttpHeader(toApp,
                                                      entry->key,
                                                      (void *)entry->val)) {
              writeError = 1;
              goto writeErrorHandler;
            }
          }
        }

        /* keysize, don't know whether mapping is correct? */
        if ((s = apr_table_get(env, "SSL_CIPHER_ALGKEYSIZE")) != NULL) {
          if (!NGBufferedDescriptor_writeHttpHeader(toApp,
                                        "x-webobjects-https-secret-keysize",
                                                    (unsigned char *)s)) {
            writeError = 1;
            goto writeErrorHandler;
          }
        }
        if ((s = apr_table_get(env, "SSL_CIPHER_USEKEYSIZE")) != NULL) {
          if (!NGBufferedDescriptor_writeHttpHeader(toApp,
                                                  "x-webobjects-https-keysize",
                                                    (unsigned char *)s)) {
            writeError = 1;
            goto writeErrorHandler;
          }
        }
      }
    }
    
    /* http headers */
    if (!_writeInHeaders(toApp, r)) {
      writeError = 1;
      goto writeErrorHandler;
    }
    
    if (!NGBufferedDescriptor_safeWrite(toApp, "\r\n", 2)) {
      writeError = 1;
      goto writeErrorHandler;
    }
    if (!NGBufferedDescriptor_flush(toApp))
      writeError = 1;
  }

 writeErrorHandler:
  if (writeError == 1) {
    if (toApp) {
      NGBufferedDescriptor_free(toApp);
      toApp = NULL;
    }
    
    ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, r->server,
                 "socket write error during transfer of HTTP header section");
    return 500;
  }
  
  /* transfer request body */
  
  if (requestContentLength > 0) {
    if (!NGBufferedDescriptor_safeWrite(toApp,
                                        requestBody,
                                        requestContentLength)) {
      if (toApp) {
	NGBufferedDescriptor_free(toApp);
	toApp = NULL;
      }
      ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, r->server,
                   "couldn't transfer HTTP req body to app server (%i bytes)",
                   contentLength);
      return 500;
    }
    NGBufferedDescriptor_flush(toApp);
  }
  else {
    if (HEAVY_LOG) {
      ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, r->server,
                   "no content in request to transfer");
    }
  }
  
  /* read response line */
  
  if (!NGScanResponseLine(toApp, NULL, &statusCode, NULL)) {
    if (toApp) {
      NGBufferedDescriptor_free(toApp);
      toApp = NULL;
    }
    ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, r->server,
                 "error during reading of response line ..");
    return 500;
  }
  r->status      = statusCode;
  r->status_line = NULL;

  /* process response headers */
  {
    apr_table_t *headers = NULL;
    
    if (HEAVY_LOG)
      ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, r->server, "scan headers");

    if ((headers = NGScanHeaders(r->pool, toApp)) == NULL) {
      ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, r->server,
                   "error during parsing of response headers ..");
    }
    
    _copyHeadersToRequest(r, headers, &contentLength);
#ifdef AP_VERSION_1
    ap_send_http_header(r);
#endif
  }
  
  /* send response content */
  
  if (!r->header_only) {
    if (contentLength > 0) {
      void *buffer = NULL;
      
      if ((buffer = apr_pcalloc(r->pool, contentLength + 1)) == NULL) {
        ap_log_error(__FILE__, __LINE__, APLOG_ERR, 0, r->server,
                     "could not allocate response buffer (size=%i)",
                     contentLength);
      }

      // read whole response
      NGBufferedDescriptor_safeRead(toApp, buffer, contentLength);

      ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, r->server,
                   "send response (size=%i)",
                   contentLength);
      // send response to client
      ap_rwrite(buffer, contentLength, r);
      ap_rflush(r);
    }
    else if (contentLength == 0) {
      // no content length header, read until EOF
      unsigned char buffer[4096];
      int result = 0;
      int writeCount = 0;

      while ((result = NGBufferedDescriptor_read(toApp,
						 buffer,
						 sizeof(buffer))
	      > 0)) {
	ap_rwrite(buffer, result, r);
	ap_rflush(r);
	writeCount += result;
      }

      if (HEAVY_LOG && (writeCount > 0)) {
        ap_log_error(__FILE__, __LINE__, APLOG_INFO, 0, r->server,
                     "write %i bytes (without content-length header)",
                     writeCount);
      }
    }
  }

  // close connection to app
  if (toApp) {
    NGBufferedDescriptor_free(toApp);
    toApp = NULL;
  }

  return OK;
}

#if WITH_LOGGING
#if 0
static void test(void) {
  fprintf(stderr,
          "%s: called:\n"
          "  app:      %s\n"
          "  uri:      %s\n"
          "  pathinfo: %s\n"
          "  method:   %s\n"
          "  protocol: %s\n"
          "  1st:      %s\n"
          "  host:     %s\n"
          "  type:     %s\n"
          "  handler:  %s\n",
          __PRETTY_FUNCTION__,
          appName,
          r->uri,
          r->path_info,
          r->method,
          r->protocol,
          r->the_request,
          apr_table_get(r->headers_in, "content-length"),
          r->content_type,
          r->handler
          );

  _logTable("  out", r->headers_out);
  _logTable("  err", r->err_headers_out);
  _logTable("  env", r->subprocess_env);
  _logTable("  in",  r->headers_in);
}
#endif

static void _logTable(const char *text, apr_table_t *table) {
  const apr_array_header_t *array;
  apr_table_entry_t  *entries;
  int          i;

  if (table == NULL) {
    fprintf(stderr, "%s: log NULL table.\n", text);
    return;
  }

  array   = apr_table_elts(table);
  entries = (apr_table_entry_t *)array->elts;

  if (array->nelts == 0) {
    fprintf(stderr, "%s: empty\n", text);
    return;
  }

  for (i = 0; i < array->nelts; i++) {
    apr_table_entry_t *entry = &(entries[i]);
    
    fprintf(stderr, "%s: %s: %s\n", text, entry->key, entry->val);
  }
}
#endif
