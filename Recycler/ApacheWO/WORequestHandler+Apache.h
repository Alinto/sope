// $Id: WORequestHandler+Apache.h,v 1.1 2004/06/08 11:06:00 helge Exp $

#ifndef __WORequestHandler_ApacheExt_H__
#define __WORequestHandler_ApacheExt_H__

#include <NGObjWeb/WORequestHandler.h>

@class NSDictionary;

@interface WORequestHandler(ApacheExt)

+ (WORequestHandler *)requestHandlerForConfig:(NSDictionary *)_plist;
- (id)initWithConfig:(NSDictionary *)_cfg;

@end

#endif /* __WORequestHandler_ApacheExt_H__ */
