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

static command_rec ngobjweb_cmds[] = {
  {
    "SetSNSPort",
    ngobjweb_set_sns_port,
    NULL,
    OR_FILEINFO,
    TAKE1,
    "the path of the Unix domain address to use (eg /tmp/.snsd)"
  },
  {
    "SetAppPort",
    ngobjweb_set_app_port,
    NULL,
    OR_FILEINFO,
    TAKE1,
    "the path of the Unix domain address to use (eg /tmp/.snsd)"
  },
  {
    "SetAppPrefix",
    ngobjweb_set_app_prefix,
    NULL,
    OR_FILEINFO,
    TAKE1,
    "any prefix that is before the app name (eg /MyDir with /MyDir/MyApp.woa)"
  },
  {
    "SNSUseHTTP",
    ngobjweb_set_use_http,
    NULL,
    OR_FILEINFO,
    0,
    "use HTTP protocol to query snsd (on,off) ?"
  },
  { NULL }
};

#ifdef AP_VERSION_1
static handler_rec ngobjweb_handlers[] = {
  { "ngobjweb-adaptor", ngobjweb_handler },
  { NULL }
};

static void ngobjweb_init(server_rec *_server, pool *_pool) {
}

module ngobjweb_module = {
  STANDARD_MODULE_STUFF,
  ngobjweb_init,              /* initializer */
  ngobjweb_create_dir_config, /* dir config creater */
  ngobjweb_merge_dir_configs, /* dir merger --- default is to override */
  NULL,                       /* server config */
  NULL,                       /* merge server config */
  ngobjweb_cmds,              /* command table */
  ngobjweb_handlers,          /* handlers */
  NULL,                       /* filename translation */ 
  NULL,                       /* check_user_id */
  NULL,                       /* check auth */
  NULL,                       /* check access */
  NULL,                       /* type_checker */
  NULL,                       /* fixups */
  NULL,                       /* logger */
  NULL                        /* header parser */
};
#else
static void ngobjweb_register_hooks(apr_pool_t *p) {
  ap_hook_handler(ngobjweb_handler, NULL, NULL, APR_HOOK_LAST);
}

module AP_MODULE_DECLARE_DATA ngobjweb_module = {
  STANDARD20_MODULE_STUFF,
  ngobjweb_create_dir_config,  /* create per-directory config structures */
  ngobjweb_merge_dir_configs,  /* merge per-directory config structures  */
  NULL,                        /* create per-server config structures    */
  NULL,                        /* merge per-server config structures     */
  ngobjweb_cmds,               /* command handlers */
  ngobjweb_register_hooks      /* register hooks */
};
#endif

