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

#include <NGXmlRpc/NGXmlRpcRequestHandler.h>
#include <NGXmlRpc/NGXmlRpcAction.h>
#include <NGXmlRpc/NGXmlRpc.h>
#include <NGXmlRpc/XmlRpcMethodCall+WO.h>
#include <NGXmlRpc/XmlRpcMethodResponse+WO.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOStatisticsStore.h>
#include "common.h"

static BOOL  perflog = NO;
static Class NSDateClass = Nil;

//#define USE_POOLS 1

@interface NSObject(RPC2)
- (id<WOActionResults>)RPC2Action;
@end

@implementation NGXmlRpcRequestHandler

+ (int)version {
  return [super version] + 0 /* 2 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);

  NSDateClass = [NSDate class];
  perflog = [[NSUserDefaults standardUserDefaults]
                             boolForKey:
                               @"WOProfileXmlRpcActionRequestHandler"];
}

/*
  The request handler part of a direct action URI looks like this:

    [actionClass/]actionName[?key=value&key=value&...]
*/

- (WOResponse *)_runObject:(NGXmlRpcAction *)_object
  request:(WORequest *)_req 
{
  WOResponse       *result;
  XmlRpcMethodCall *call;
  
  if (_object == nil) return nil;
  
  if (![[_req method] isEqualToString:@"POST"]) {
    /* only POST is allowed ! */
    return nil;
  }
    
  call = [(XmlRpcMethodCall *)[XmlRpcMethodCall alloc] initWithRequest:_req];
  call = [call autorelease];
    
  if (call == nil) {
    NSData *content;
      
    content = [_req content];
    
    [self logWithFormat:@"couldn't decode XMLRPC content:\n"];
    [self logWithFormat:@"  content-len: %d", [content length]];
    [self logWithFormat:@"  encoding:    %d", [_req contentEncoding]];
    result = nil;
  }
  else {
    [_object awake];
    result = [[_object performMethodCall:call] generateResponse];
    [_object sleep];
  }
  
  if (result == nil)
    return nil;
  
  if (![result isKindOfClass:[WOResponse class]]) {
    /* morph an object result into a XML-RPC response .. */
    XmlRpcMethodResponse *r;
    
    r = [[XmlRpcMethodResponse alloc] initWithResult:result];
    result = [[[r generateResponse] retain] autorelease];
    [r release];
  }
  
  return result;
}

- (WOResponse *)handleRequest:(WORequest *)_request {
  NSTimeInterval    startHandling = 0.0;
#if USE_POOLS
  NSAutoreleasePool *pool = nil;
#endif
  WOApplication *app;
  NSString      *handlerPath = nil;
  NSString      *actionClassName;
  WOResponse    *response   = nil;
  WOContext     *context    = nil;
  NSThread      *thread;
  NSMutableDictionary *threadDict;
  Class         actionClass = Nil;
  
  if (![[_request method] isEqualToString:@"POST"]) {
    [self logWithFormat:@"only POST requests are valid XML-RPC requests ..."];
    return nil;
  }
  
  if (perflog)
    startHandling = [[NSDateClass date] timeIntervalSince1970];
  
  thread = [NSThread currentThread];
  NSAssert(thread, @"missing current thread ...");
  threadDict = [thread threadDictionary];
  NSAssert(threadDict, @"missing current thread's dictionary ...");
  
  if (_request == nil) return nil;
  
  *(&app)             = nil;
  *(&actionClassName) = nil;
  
  app = [WOApplication application];
  
  handlerPath = [_request uri];
  actionClass = [NGXmlRpcAction actionClassForURI:handlerPath];
  
  if (actionClass == Nil) {
    [self logWithFormat:@"found no action class for URI: %@", handlerPath];
    actionClass = [app defaultActionClassForRequest:_request];
  }
  
#if DEBUG_XMLRPC_ACTION
  NSLog(@"[XML-RPC request handler] class=%@ ..",
        actionClassName);
#endif
  
#if USE_POOLS
  *(&pool) = [[NSAutoreleasePool alloc] init];
#endif
  {
    /* setup context */
    context = [WOContext contextWithRequest:_request];
    NSAssert(context, @"no context assigned ..");
    NSAssert(threadDict, @"missing current thread's dictionary ...");
    [threadDict setObject:context forKey:@"WOContext"];
    
    NS_DURING {
      [app awake];
      {
        NGXmlRpcAction      *actionObject = nil;
        id<WOActionResults> result = nil;

        *(&result) = nil;
        
        NS_DURING {
#if USE_POOLS
          NSAutoreleasePool *pool2 = [NSAutoreleasePool new];
#endif

          {
            /* create direct action object */
            actionObject = [actionClass alloc];
            actionObject = [actionObject initWithContext:context];
            actionObject = [actionObject autorelease];
            
            if (actionObject == nil) {
              [app logWithFormat:
                   @"ERROR: could not create direct action object of class %@",
                   actionClassName];
              actionObject = nil;
            }
            else {
              result = [self _runObject:actionObject request:_request];
              result = [(id)result retain];
              
              if (result == nil) {
                [self logWithFormat:
                      @"WARNING: got empty result from action .."];
                response = [WOResponse alloc];
                response = [response initWithRequest:_request];
                [response setStatus:500];
              }
              else {
                /* generate response */
                response = [[result generateResponse] retain];
              }
              
              [(id)result release]; result = nil;
            }
          }

#if USE_POOLS
          RELEASE(pool2); pool2 = nil;
#endif
          response = [response autorelease];
        }
        NS_HANDLER {
          response = [app handleException:localException inContext:context];
        }
        NS_ENDHANDLER;
        
        response = [response retain];
      }
      [app sleep];
    }  
    NS_HANDLER {
      response = [app handleException:localException inContext:context];
      response = [response retain];
    }
    NS_ENDHANDLER;
    
    NSAssert(threadDict, @"missing current thread's dictionary ...");
    [threadDict removeObjectForKey:@"WOContext"];
  }
#if USE_POOLS
  [pool release]; pool = nil;
#endif

  if (perflog) {
    NSTimeInterval rt;
    rt = [[NSDateClass date] timeIntervalSince1970] - startHandling;
    NSLog(@"[da-handler]: handleRequest took %4.3fs.",
          rt < 0.0 ? -1.0 : rt);
  }
  
  return AUTORELEASE(response);
}

@end /* NGXmlRpcRequestHandler */
