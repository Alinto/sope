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

#ifndef __NGObjWeb_Adaptors_apache_H__
#define __NGObjWeb_Adaptors_apache_H__

/* System includes */

#include <strings.h>
#include <netdb.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <sys/un.h>
#include <arpa/inet.h>
#include <unistd.h>

/* Apache includes */

#include <httpd.h>
#include <http_core.h>
#include <http_config.h>
#include <http_log.h>
#include <http_protocol.h>

#if MODULE_MAGIC_NUMBER_MAJOR >= 20010224
/* apache ap version 2 */
#include "apr.h"
#include "apr_buckets.h"
#include "apr_strings.h"
#include "apr_portable.h"
#include "apr_optional.h"
#include "apr_lib.h"
#include "ap_config.h"
#include "ap_listen.h"
#else
/* for compatibility */
#define AP_VERSION_1

#define apr_array_header_t array_header
#define apr_inet_addr      inet_addr
#define apr_isalnum        isalnum
#define apr_isspace        isspace
#define apr_palloc         ap_palloc
#define apr_pcalloc        ap_pcalloc
#define apr_pool_t         pool
#define apr_table_elts     ap_table_elts
#define apr_table_entry_t  table_entry
#define apr_table_get      ap_table_get
#define apr_table_make     ap_make_table
#define apr_table_set      ap_table_set
#define apr_table_t        table
#define apr_sleep          sleep
#define apr_snprintf       snprintf

#define ap_log_error(file, line, level, status, vars...) \
	ap_log_error(file, line, level, ## vars)
#endif

#include "NGBufferedDescriptor.h"

module ngobjweb_module;

typedef struct {
  char *snsPort;  /* the port of the SNS daemon                */
  int  snsPortDomain;
  
  char *appPort; /* a single pass-through port of an instance */
  int  appPortDomain;
  
  char *appPrefix;
  int  useHTTP;
} ngobjweb_dir_config;

#define MAX_PORTNAME_SIZE   140
#define MAX_SNS_PATH_SIZE   MAX_PORTNAME_SIZE
#define MAX_APP_PREFIX_SIZE 256

/* SNS */

extern void *
_sendSNSQuery(request_rec *_rq, const char *_line, const char *_cookie,
              int *_domain, size_t *_len,
              const char *_appName,
              ngobjweb_dir_config *_cfg);

/* HTTP */

extern unsigned char
NGScanResponseLine(NGBufferedDescriptor *_in,
                   unsigned char *_version, int *_status, 
                   unsigned char *_text);
extern apr_table_t *NGScanHeaders(apr_pool_t *_pool, NGBufferedDescriptor *_in);

/* handlers */

extern int ngobjweb_handler(request_rec *r);

/* commands */

extern const char *ngobjweb_set_sns_port(cmd_parms *cmd,
                                         ngobjweb_dir_config *cfg,
                                         char *arg);
extern const char *ngobjweb_set_app_port(cmd_parms *cmd,
                                         ngobjweb_dir_config *cfg,
                                         char *arg);
extern const char *ngobjweb_set_app_prefix(cmd_parms *cmd,
                                           ngobjweb_dir_config *cfg,
                                           char *arg);
extern const char *ngobjweb_set_use_http(cmd_parms *cmd,
                                         ngobjweb_dir_config *cfg);

/* configuration */

extern void *ngobjweb_create_dir_config(apr_pool_t *p, char *dummy);
extern void *ngobjweb_merge_dir_configs(apr_pool_t *p, void *basev, void *addv);

#endif /* __NGObjWeb_Adaptors_apache_H__ */
