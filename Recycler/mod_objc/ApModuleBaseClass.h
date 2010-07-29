// $Id: ApModuleBaseClass.h,v 1.1 2004/06/08 11:15:58 helge Exp $

#ifndef __ApModuleBaseClass_H__
#define __ApModuleBaseClass_H__

#import <Foundation/NSObject.h>

@class ApacheModule;

@interface ApModuleBaseClass : NSObject

+ (void)setBundleHandler:(ApacheModule *)_handler;
+ (ApacheModule *)bundleHandler;

/* return an initialized Apache module structure ... */
+ (void *)apacheModule;

@end

@interface ApModuleBaseClass(SubclassOverrides)

/* return an Apache module structure with all callback wrappers set ... */
+ (void *)apacheTemplateModule;

/* return the uninitialized Apache module structure */
+ (void *)apacheModuleStructure;

/* the stub to dispatch handlers (placed in the handler_rec structure) */
+ (void *)handleRequestStubFunction;

@end

@interface ApModuleBaseClass(BasicModuleCallbacks)

+ (void)_moduleInit:(void *)s pool:(void *)p;

+ (void *)_perDirConfCreate:(void *)dirspec pool:(void *)p;
+ (void *)_perDirConfMerge:(void *)baseCconf with:(void *)newCconf
  pool:(void *)p;
+ (void *)_perServerConfCreate:(void *)s pool:(void *)p;
+ (void *)_perServerConfMerge:(void *)baseConf with:(void *)newConf
  pool:(void *)p;

+ (int)_translateHandler:(void *)_request;
+ (int)_apCheckUserId:(void *)_request;
+ (int)_authChecker:(void *)_request;
+ (int)_accessChecker:(void *)_request;
+ (int)_typeChecker:(void *)_request;
+ (int)_fixerUpper:(void *)_request;
+ (int)_logger:(void *)_request;
+ (int)_headerParser:(void *)_request;

+ (void)_childInit:(void *)_server pool:(void *)_pool;
+ (void)_childExit:(void *)_server pool:(void *)_pool;

+ (int)_postReadRequest:(void *)_request;

@end

@interface ApModuleBaseClass(HandlerCallback)

+ (int)_handleRequest:(void *)_request;

@end

#endif /* ApModuleBaseClass */
