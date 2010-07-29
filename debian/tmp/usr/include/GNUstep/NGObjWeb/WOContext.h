/*
  Copyright (C) 2000-2005 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#ifndef __NGObjWeb_WOContext_H__
#define __NGObjWeb_WOContext_H__

#import <Foundation/NSObject.h>
#include <NGObjWeb/WOPageGenerationContext.h>
#include <NGObjWeb/WOElementTrackingContext.h>

/*
  WOContext
  
  The WOContext is the central object for processing a single HTTP
  transaction. It manages request, response, the session, the current
  element id for component actions, the active component etc.
*/

@class NSString, NSMutableDictionary, NSMutableArray, NSMutableSet;
@class NSArray, NSDictionary, NSURL;
@class WOApplication, WOSession, WOComponent, WORequest, WOResponse;
@class WOElementID;

#define NGObjWeb_MAX_COMPONENT_NESTING_DEPTH 50

@interface WOContext : NSObject < WOPageGenerationContext >
{
@protected
  WOApplication       *application;     // non-retained
  NSString            *ctxId;
  WORequest           *request;
  WOResponse          *response;
  NSMutableDictionary *variables;
  WOComponent         *page;
  WOSession           *session;
  NSMutableSet        *awakeComponents; // components that were woken up
  
  /* URLs */
  NSURL               *baseURL;
  NSURL               *appURL;
  
  /* element ids */
  WOElementID *elementID;
  WOElementID *reqElementID;
  NSString    *urlPrefix; /* cached URL prefix */
  
  /* component stack */
  id          componentStack[NGObjWeb_MAX_COMPONENT_NESTING_DEPTH];
  id          contentStack[NGObjWeb_MAX_COMPONENT_NESTING_DEPTH];
  signed char componentStackCount;
  
  /* misc */
  id       activeFormElement;
  NSString *qpJoin;
  
@public /* need fast access to generation flags */
  /* flags */
  struct {
    int savePageRequired:1; /* tracking component actions */
    int inForm:1;
    int xmlStyleEmptyElements:1;
    int allowEmptyAttributes:1;
    int hasNewSession:1;    /* session was created during the run */
    int isRenderingDisabled:1;
    int reserved:26;
  } wcFlags;
  
@protected
  /* SOPE */
  NSString      *fragmentID;

  /* SoObjects */
  id             clientObject;
  NSMutableArray *traversalStack;
  NSString       *soRequestType; // WebDAV, XML-RPC, METHOD
  id             objectDispatcher;
  NSString       *pathInfo;
  id             rootURL;
  id             objectPermissionCache;
  id             activeUser;
  
#if WITH_DEALLOC_OBSERVERS
@private
  id             *deallocObservers;
  unsigned short deallocObserverCount;
  unsigned short deallocObserverCapacity;
#endif
}

+ (id)contextWithRequest:(WORequest *)_request;
- (id)initWithRequest:(WORequest *)_request;
+ (id)context;
- (id)init;

/* URLs */

- (NSURL *)baseURL;
- (NSURL *)applicationURL;
- (NSURL *)serverURL;
- (NSURL *)urlForKey:(NSString *)_key;

- (void)setGenerateXMLStyleEmptyElements:(BOOL)_flag;
- (BOOL)generateXMLStyleEmptyElements;
- (void)setGenerateEmptyAttributes:(BOOL)_flag;
- (BOOL)generateEmptyAttributes;

/* variables */

- (void)setObject:(id)_obj forKey:(NSString *)_key;
- (id)objectForKey:(NSString *)_key;
- (void)removeObjectForKey:(NSString *)_key;
- (void)takeValue:(id)_value forKey:(NSString *)_key;
- (id)valueForKey:(NSString *)_key;

@end

@interface WOContext(ElementIDs) < WOElementTrackingContext >
@end

@interface WOContext(URLs)

- (NSString *)componentActionURL;

- (NSString *)directActionURLForActionNamed:(NSString *)_actionName
  queryDictionary:(NSDictionary *)_queryDict;

- (NSString *)urlWithRequestHandlerKey:(NSString *)_key
  path:(NSString *)_path
  queryString:(NSString *)_query;
- (NSString *)completeURLWithRequestHandlerKey:(NSString *)_key
  path:(NSString *)_path
  queryString:(NSString *)_query
  isSecure:(BOOL)_isSecure
  port:(int)_port;

- (NSString *)senderID; // new in WO4

- (NSString *)queryStringFromDictionary:(NSDictionary *)_queryDict;

- (void)setQueryPathSeparator:(NSString *)_sp;
- (NSString *)queryPathSeparator;

@end

@interface WOContext(PrivateMethods)

- (void)setRequestSenderID:(NSString *)_rqsid;
- (BOOL)savePageRequired;

@end

@interface WOContext(DeprecatedMethodsInWO4)

- (id)application; // use WOApplication:+application

- (void)setDistributionEnabled:(BOOL)_flag; // use methods in
- (BOOL)isDistributionEnabled;              // WOSession instead

- (NSString *)url;              // use componentActionURL methods
- (NSString *)urlSessionPrefix; // use componentActionURL methods

@end

@interface WOContext(SOPEAdditions)

- (BOOL)hasNewSession;

/* languages for resource lookup (non-WO) */

- (NSArray *)resourceLookupLanguages;

/* fragments */

- (void)setFragmentID:(NSString *)_fragmentID;
- (NSString *)fragmentID;

- (void)enableRendering;
- (void)disableRendering;
- (BOOL)isRenderingDisabled;
  
@end

#endif /* __NGObjWeb_WOContext_H__ */
