// $Id: mod_gsbundle.m,v 1.1 2004/06/08 11:15:59 helge Exp $

#include "httpd.h"
#include "http_config.h"
#include <dlfcn.h>

/*
  Note:

  an Apache bundle gets *unloaded* during the config process !!!
*/

module MODULE_VAR_EXPORT gsbundle_module;

static void *helperLib = NULL;

static const char *(*GSBundleModuleLoadBundleCommand)
(module *module, cmd_parms *cmd, char *bundlePath) = NULL;

/* Called when the LoadBundle config directive is found */
static const char *loadBundle
(cmd_parms *cmd, void *dummy, char *bundlePath)
{
  if (helperLib == NULL) {
    const char *path;
    const char *dirpath;
    
    dirpath = ap_pstrcat(cmd->pool,
                         getenv("GNUSTEP_SYSTEM_ROOT"), "/Libraries/",
                         getenv("GNUSTEP_HOST_CPU"),    "/",
                         getenv("GNUSTEP_HOST_OS"),     "/",
                         getenv("LIBRARY_COMBO"),       "/",
                         NULL);
    path = ap_pstrcat(cmd->pool, dirpath, "libApHelper_d.so", NULL);
    
    helperLib = dlopen(path, RTLD_NOW | RTLD_GLOBAL);
    if (helperLib == NULL) {
      return ap_pstrcat(cmd->pool,
                        "couldn't load ObjC bundle helper lib:\n  '",
                        path,
                        "' ..." , NULL);
    }
    
    GSBundleModuleLoadBundleCommand =
      dlsym(helperLib, "GSBundleModuleLoadBundleCommand");
  }
  
  if (GSBundleModuleLoadBundleCommand == NULL){
    return ap_pstrcat(cmd->pool,
                      "couldn't find load bundle command in helper lib ...",
                      NULL);
  }
  
  return GSBundleModuleLoadBundleCommand(&gsbundle_module, cmd, bundlePath);
}

/* Config file commands we recognize */
static const command_rec gsbundle_cmds[] =
{
  {
    "LoadBundle",
    loadBundle,
    "my userinfo",
    RSRC_CONF,
    RAW_ARGS,
    "takes bundle-path as arg"
  },
  {NULL}
};

module MODULE_VAR_EXPORT gsbundle_module = {
    STANDARD_MODULE_STUFF,
    NULL,                  /* module initializer                  */
    NULL,                  /* create per-dir    config structures */
    NULL,                  /* merge  per-dir    config structures */
    NULL,                  /* create per-server config structures */
    NULL,                  /* merge  per-server config structures */
    gsbundle_cmds,         /* table of config file commands       */
    NULL,                  /* [#8] MIME-typed-dispatched handlers */
    NULL,                  /* [#1] URI to filename translation    */
    NULL,                  /* [#4] validate user id from request  */
    NULL,                  /* [#5] check if the user is ok _here_ */
    NULL,                  /* [#3] check access by host address   */
    NULL,                  /* [#6] determine MIME type            */
    NULL,                  /* [#7] pre-run fixups                 */
    NULL,                  /* [#9] log a transaction              */
    NULL,                  /* [#2] header parser                  */
    NULL,                  /* child_init                          */
    NULL,                  /* child_exit                          */
    NULL                   /* [#0] post read-request              */
};
