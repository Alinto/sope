// $Id: ApModuleBaseClass.m,v 1.1 2004/06/08 11:15:58 helge Exp $

#include "ApModuleBaseClass.h"
#include <httpd.h>
#include "http_config.h"
#import <Foundation/NSBundle.h>
#import <Foundation/NSString.h>
#import <Foundation/NSAutoreleasePool.h>
#include "ApacheServer.h"
#include "ApacheResourcePool.h"
#include "ApacheModule.h"
#include "ApacheRequest.h"

@interface ApModuleBaseClass(Privates)

+ (handler_rec *)apacheHandlerTable;
+ (command_rec *)apacheCommandTable;

@end

@implementation ApModuleBaseClass

+ (void)setBundleHandler:(ApacheModule *)_handler {
  [self subclassResponsibility:_cmd];
}
+ (ApacheModule *)bundleHandler {
  return [self subclassResponsibility:_cmd];
}

+ (void *)apacheModule {
  ApacheModule *bundleHandler = [self bundleHandler];
  module *mod, *tmpl;
  
  if (bundleHandler == nil) {
    NSLog(@"%s: missing bundle handler !!!", __PRETTY_FUNCTION__);
    return NULL;
  }
  
  mod  = [self apacheModuleStructure];
  tmpl = [self apacheTemplateModule];
  
  mod->cmds     = [self apacheCommandTable];
  mod->handlers = [self apacheHandlerTable];
  
  /* fill module based on handler reflection ... */
  
  mod->init =
    [bundleHandler respondsToSelector:
                     @selector(initializeModuleForServer:inPool:)]
    ? tmpl->init : NULL;

  mod->create_dir_config =
    [bundleHandler respondsToSelector:
         @selector(createPerDirectoryConfigInPool:)]
    ? tmpl->create_dir_config : NULL;

  mod->merge_dir_config =
    [bundleHandler respondsToSelector:
         @selector(mergePerDirectoryBaseConfig:withNewConfig:inPool:)]
    ? tmpl->merge_dir_config : NULL;

  mod->create_server_config =
    [bundleHandler respondsToSelector:
                     @selector(createPerServerConfig:inPool:)]
    ? tmpl->create_server_config : NULL;

  mod->merge_server_config =
    [bundleHandler respondsToSelector:
         @selector(mergePerServerBaseConfig:withNewConfig:inPool:)]
    ? tmpl->merge_server_config : NULL;
  
  mod->translate_handler =
    [bundleHandler respondsToSelector:@selector(handleTranslationForRequest:)]
    ? tmpl->translate_handler : NULL;
  mod->ap_check_user_id =
    [bundleHandler respondsToSelector:@selector(checkUserIdFromRequest:)]
    ? tmpl->ap_check_user_id : NULL;
  mod->auth_checker =
    [bundleHandler respondsToSelector:@selector(checkAuthForRequest:)]
    ? tmpl->auth_checker : NULL;
  mod->access_checker =
    [bundleHandler respondsToSelector:@selector(checkAccessForRequest:)]
    ? tmpl->access_checker : NULL;
  mod->type_checker =
    [bundleHandler respondsToSelector:@selector(checkTypeForRequest:)]
    ? tmpl->type_checker : NULL;
  mod->logger =
    [bundleHandler respondsToSelector:@selector(logRequest:)]
    ? tmpl->logger : NULL;
    
  mod->fixer_upper =
    [bundleHandler respondsToSelector:@selector(fixupRequest:)]
    ? tmpl->fixer_upper : NULL;
  
  mod->header_parser =
    [bundleHandler respondsToSelector:@selector(parseHeadersOfRequest:)]
    ? tmpl->header_parser : NULL;

  mod->post_read_request =
    [bundleHandler respondsToSelector:@selector(postProcessRequest:)]
    ? tmpl->post_read_request : NULL;

  mod->child_init =
    [bundleHandler respondsToSelector:
      @selector(initializeChildProcessWithServer:inPool:)]
    ? tmpl->child_init : NULL;
  mod->child_exit =
    [bundleHandler respondsToSelector:
      @selector(exitChildProcessWithServer:inPool:)]
    ? tmpl->child_exit : NULL;
  
  return mod;
}

@end /* ApModuleBaseClass */

@implementation ApModuleBaseClass(SubclassOverrides)

+ (void *)apacheTemplateModule {
  return [self subclassResponsibility:_cmd];
}
+ (void *)apacheModuleStructure {
  return [self subclassResponsibility:_cmd];
}
+ (void *)handleRequestStubFunction {
  return [self subclassResponsibility:_cmd];
}

@end /* ApModuleBaseClass(SubclassOverrides) */
