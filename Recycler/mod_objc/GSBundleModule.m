// $Id: GSBundleModule.m,v 1.1 2004/06/08 11:15:59 helge Exp $

#include "httpd.h"
#include "http_config.h"
#include "http_log.h"
#include "ap_config.h"

#include "ApacheCmdParms.h"
#include "ApacheServer.h"
#include "ApacheModule.h"
#include "ApacheResourcePool.h"
#import <Foundation/Foundation.h>

/*
  Note:
  
  an Apache module gets *unloaded* during the config process !!!

  This is why we have this helper shared object which is not unloaded :-)
*/

@interface NSObject(ModuleClass)
+ (void)setBundleHandler:(id)_handler;
- (module *)apacheModule;
@end

static void _ensureObjCEnvironment(void) {
#if LIB_FOUNDATION_LIBRARY
  extern char **environ; /* man 5 environ */
  static char *argv[2] = { "apache", NULL };
  [NSProcessInfo initializeWithArguments:argv
                 count:1
                 environment:environ];
#endif
}

@interface ApBundleInfo : NSObject
{
@public
  ApacheResourcePool *configPool;
  NSString     *bundlePath;
  NSString     *bundleName;
  NSBundle     *bundle;
  module       *apacheModule;
  ApacheModule *bundleHandler;
  BOOL         moduleAdded;
  BOOL         bundleLoaded;
}

+ (NSString *)makeBundlePathAbsolute:(NSString *)_relpath;
+ (ApBundleInfo *)bundleInfoForPath:(NSString *)_relpath;

/* accessors */

- (NSBundle *)bundle;
- (NSString *)bundleModuleClassName;
- (Class)bundleModuleClass;

- (BOOL)isBundleLoaded;
- (BOOL)isApacheModuleInitialized;

/* operations */

- (NSString *)setUpWithArgs:(NSString *)_args
  inPool:(ApacheResourcePool *)_pool;
- (void)tearDown;

- (void)configureForServer:(ApacheServer *)_server;

@end

@implementation ApBundleInfo

+ (ApBundleInfo *)bundleInfoForPath:(NSString *)_relpath {
  static NSMutableDictionary *pathToInfo = nil;
  NSString     *p;
  ApBundleInfo *bi;
  
  p = [self makeBundlePathAbsolute:_relpath];
  if ([p length] == 0) return nil;
  
  if (pathToInfo == nil)
    pathToInfo = [[NSMutableDictionary alloc] initWithCapacity:16];

  if ((bi = [pathToInfo objectForKey:p]))
    return bi;
  
  if ((bi = [[self alloc] initWithPath:p])) {
    [pathToInfo setObject:bi forKey:p];
    RELEASE(bi);
  }
  return bi;
}
+ (NSString *)makeBundlePathAbsolute:(NSString *)_relpath {
  NSString *s;
  
  if ([_relpath length] == 0) return nil;
  
  s = [[[NSProcessInfo processInfo]
                       environment]
                       objectForKey:@"GNUSTEP_SYSTEM_ROOT"];
  s = [s stringByAppendingPathComponent:@"Library/Bundles"];
  s = [s stringByAppendingPathComponent:_relpath];
  
  return s;
}

- (id)initWithPath:(NSString *)_path {
  if ([_path length] == 0) {
    RELEASE(self);
    return nil;
  }
  if (![_path isAbsolutePath]) {
    NSLog(@"bundle path '%@' is not absolute ...", _path);
    RELEASE(self);
    return nil;
  }
  
  self->bundlePath = [_path copy];
  self->bundleName =
    [[[_path lastPathComponent] stringByDeletingPathExtension] copy];
  self->bundle     = [[NSBundle bundleWithPath:self->bundlePath] retain];
  
  if (self->bundle == nil) {
    NSLog(@"missing bundle at path %@", self->bundlePath);
    RELEASE(self);
    return nil;
  }
  
  return self;
}

- (void)dealloc {
  NSAutoreleasePool *pool;

  pool = [[NSAutoreleasePool alloc] init];
  RELEASE(self->configPool);
  RELEASE(self->bundleHandler);
  RELEASE(self->bundlePath);
  RELEASE(self->bundleName);
  RELEASE(self->bundle);
  RELEASE(pool);
  [super dealloc];
}

/* accessors */

- (BOOL)isBundleLoaded {
  if (self->bundle == nil) return NO;
  return self->bundleLoaded;
}
- (BOOL)isApacheModuleInitialized {
  if (self->apacheModule == NULL) return NO;
  return self->moduleAdded;
}

- (NSBundle *)bundle {
  return self->bundle;
}

- (NSString *)bundleModuleClassName {
  return [self->bundleName stringByAppendingString:@"Mod_Module_Class"];
}
- (Class)bundleModuleClass {
  /* the class which manages the module structure (helper class) */
  return NSClassFromString([self bundleModuleClassName]);
}

- (Class)bundleHandlerClass {
  /* the class which represents the apache module itself */
  Class c;
  
  if ((c = [self->bundle principalClass]) == Nil)
    return nil;
  if (![c isKindOfClass:[ApacheModule class]])
    return nil;
  
  return c;
}

/* operations */

- (NSString *)setUpWithArgs:(NSString *)_args
  inPool:(ApacheResourcePool *)_pool
{
  NSAutoreleasePool *pool;
  Class modClass;
  
  /* check pre-conditions */

  if (self->bundle == nil) {
    return [NSString stringWithFormat:@"%s: missing bundle info",
                       __PRETTY_FUNCTION__];
  }
  if (self->configPool)
    return @"config pool is already setup";
  if (self->bundleHandler)
    return @"bundle handler is already set up !!!";
  
  pool = [[NSAutoreleasePool alloc] init];

#if 0
  printf("\nSETUP 0x%p (loaded=%s) ...\n", (unsigned int)self,
         self->bundleLoaded ? "yes" : "no");
  fflush(stdout);
#endif
  
  /* Step 0: setup resource pool wrapper */
  
  self->configPool = RETAIN(_pool);
  
  /* Step 1: Load bundle if not done already ... */
  
  if (!self->bundleLoaded) {
    if (![self->bundle load]) {
      return
        [NSString stringWithFormat:@"couldn't load bundle %@", self->bundle];
    }
    self->bundleLoaded = YES;
  }
  
  if ((modClass = [self bundleModuleClass]) == Nil) {
    RELEASE(pool);
    return [NSString stringWithFormat:
                       @"did not find bundle module class (name=%@) ...",
                       [self bundleModuleClassName]];
  }
  
  /* Step 2: Initialize bundle handler object ... */
  
  self->bundleHandler = [[[self bundleHandlerClass] alloc] init];
  if (self->bundleHandler == nil) {
    RELEASE(pool);
    return [NSString stringWithFormat:
                       @"couldn't initialize bundle handler of class '%@'",
                       [self bundleHandlerClass]];
  }
  
  /* Step 3: Remember bundle handler in module-handler class ... */
  
  [modClass setBundleHandler:self->bundleHandler];
  
  /* Step 4: add Apache C module structure */
  
  if ((self->apacheModule = [modClass apacheModule]) == NULL) {
    RELEASE(pool);
    return @"did not find apache module structure of bundle";
  }
  if (self->apacheModule->magic != MODULE_MAGIC_COOKIE) {
    RELEASE(pool);
    return [NSString stringWithFormat:
                       @"API module structure of bundle is broken !"];
  }
  
  /* Step 5: register module with apache ... */
  
  ap_add_loaded_module(self->apacheModule);
  self->moduleAdded = YES;
  
  /* release pool & done */
  
  RELEASE(pool);
  
  return nil;
}

- (void)tearDown {
  NSAutoreleasePool *pool;

  pool = [[NSAutoreleasePool alloc] init];

#if 0
  printf("TEARDOWN 0x%p ...\n", (unsigned int)self);
  fflush(stdout);
#endif

  /* Reverse Step 5: unregister module with apache */
  
  if ((self->apacheModule != NULL) && self->moduleAdded)
    ap_remove_loaded_module(self->apacheModule);
  
  self->moduleAdded = NO;
  
  /* Reverse Step 4: reset apache module structure */
  self->apacheModule = NULL;
  
  /* Reverse Step 3: reset bundle handler in module-handler class ... */
  [[self bundleModuleClass] setBundleHandler:nil];
  
  /* Reverse Step 2: release bundle handler object ... */
  RELEASE(self->bundleHandler);
  self->bundleHandler = nil;
  
  /* DO NOT reverse Step 1 ... */

  /* Reverse Step 0: release config pool proxy */
  RELEASE(self->configPool); self->configPool = nil;
  
  RELEASE(pool);
}

- (void)configureForServer:(ApacheServer *)_server {
  if (self->apacheModule == NULL) {
    NSLog(@"missing bundle module ...");
    return;
  }
  if (self->configPool == NULL) {
    NSLog(@"missing config pool ...");
    return;
  }

#if DEBUG && 0
  printf("CONFIGURE 0x%p ...\n", (unsigned int)self);
  fflush(stdout);
#endif
  
  ap_single_module_configure([self->configPool handle],
                             [_server handle],
                             self->apacheModule);
}

@end /* ApBundleInfo */

static void unloadModule(void *data) {
  ApBundleInfo *binfo;

  if ((binfo = (void *)data)) {
    [binfo tearDown];
  }
}

static int callCount = 0;

/* Called when the LoadBundle config directive is found */
const char *GSBundleModuleLoadBundleCommand
(module *module, cmd_parms *cmd, char *bundlePath)
{
  const char         *result = NULL;
  ApacheCmdParms     *paras;
  NSAutoreleasePool  *opool;
  NSString     *bp, *args;
  ApBundleInfo *bi;
  id tmp;
  
  _ensureObjCEnvironment();
  callCount++;
  
#if HEAVY_GSBUNDLE_DEBUG
  printf("%s: #%i module=0x%p pid=%i "
         "(cmd=0x%p,bp=0x%p) ...\n",
         __PRETTY_FUNCTION__, callCount, (unsigned int)module, getpid(),
         (unsigned int)cmd, (unsigned int)bundlePath);
  fflush(stdout); fflush(stderr);
#endif
  
  opool = [[NSAutoreleasePool alloc] init];
  paras = [[ApacheCmdParms alloc] initWithHandle:cmd];
  
  /* separate bundle path from bundle args */
  
  tmp = [NSString stringWithCString:bundlePath];
#if HEAVY_GSBUNDLE_DEBUG
  printf("%s: %s\n", __PRETTY_FUNCTION__, [[s description] cString]);
  printf("  paras: %s\n",  [[paras description] cString]);
  printf("  server: %s\n", [[[paras server] description] cString]);
  fflush(stdout); fflush(stderr);
#endif
  
  /* separate bundle path and load arguments ... */
  {
    unsigned idx;
    
    if ((idx = [tmp indexOfString:@" "]) == NSNotFound) {
      bp   = tmp;
      args = nil;
    }
    else {
      bp   = [tmp substringToIndex:idx];
      args = [tmp substringFromIndex:(idx + 1)];
    }
  }
  
  /* makeup absolute bundle path */

  if ((bi = [ApBundleInfo bundleInfoForPath:bp]) == nil) {
    result = ap_pstrcat(cmd->pool, "bundle at '", [bp cString], "' could "
                        "not find info !");
    goto done;
  }

  if ((tmp = [bi setUpWithArgs:args inPool:[paras pool]])) {
    result = ap_pstrdup(cmd->pool, [tmp cString]);
    goto done;
  }

  /* register cleanup */
  ap_register_cleanup(cmd->pool, bi, 
                      (void (*)(void*))unloadModule, ap_null_cleanup);
  
  /* run module configuration */
  [bi configureForServer:[paras server]];
  
 done:
  RELEASE(paras);
  RELEASE(opool);
  return result;
}
