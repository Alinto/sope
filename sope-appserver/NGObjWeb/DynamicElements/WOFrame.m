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

#include "WOElement+private.h"
#include <NGObjWeb/WOHTMLDynamicElement.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOResourceManager.h>
#include <NGObjWeb/WODynamicElement.h>
#include "decommon.h"

#define FRAME_TYPE_None  0
#define FRAME_TYPE_Page  1
#define FRAME_TYPE_Href  2
#define FRAME_TYPE_Value 3
#define FRAME_TYPE_DA    4

@interface WOFrame : WOHTMLDynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  /* new in WO4 */
  WOAssociation *queryDictionary;
  NSDictionary  *queryParameters;  /* associations beginning with ? */
}

@end

@interface _WOPageFrame : WOFrame
{
  WOAssociation *pageName;
}
@end

@interface _WOHrefFrame : WOFrame
{
  WOAssociation *src;
}
@end

@interface _WOValueFrame : WOFrame
{
  WOAssociation *value;
}
@end

@interface _WODirectActionFrame : WOFrame
{
  WOAssociation *actionClass;
  WOAssociation *directActionName;
  BOOL          sidInUrl;          /* include session-id in wa URL ? */
}
@end

@interface WOFrame(PrivateMethods)

- (id)_initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t;

- (NSString *)associationDescription;

@end

#if COCOA_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
@interface NSObject(Miss)
- (void)subclassResponsibility:(SEL)_cmd;
@end
#endif

@implementation WOFrame

+ (int)version {
  return 1;
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  Class frameClass = Nil;
  
  if ([_config objectForKey:@"value"])
    frameClass = [_WOValueFrame class];
  else if ([_config objectForKey:@"pageName"])
    frameClass = [_WOPageFrame class];
  else if ([_config objectForKey:@"src"])
    frameClass = [_WOHrefFrame class];
  else
    frameClass = [_WODirectActionFrame class];

  [self release];
  return [[frameClass alloc]
                      initWithName:_name associations:_config template:_t];
}

- (id)_initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_tmpl
{
  if ((self = [super initWithName:_name associations:_config template:_tmpl])) {
    self->queryDictionary = OWGetProperty(_config, @"queryDictionary");
    self->queryParameters = OWExtractQueryParameters(_config);
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->queryDictionary);
  RELEASE(self->queryParameters);
  [super dealloc];
}

// ******************** responder ********************

#define StrVal(__x__) [self->__x__ stringValueInComponent:sComponent]

- (BOOL)_appendHrefToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  [self subclassResponsibility:_cmd];
  return NO;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  NSString    *queryString;

  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent])
    return;

  sComponent  = [_ctx component];
  queryString = nil;

  WOResponse_AddCString(_response, "<frame src=\"");
    
  if ([self _appendHrefToResponse:_response inContext:_ctx]) {
    queryString = [self queryStringForQueryDictionary:
                        [self->queryDictionary valueInComponent:sComponent]
                        andQueryParameters:self->queryParameters
                        inContext:_ctx];
  }

  if (queryString) {
    [_response appendContentCharacter:'?'];
    WOResponse_AddString(_response, queryString);
  }
  WOResponse_AddChar(_response, '"');
  
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
    
  if (self->otherTagString) {
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response,
                         [self->otherTagString stringValueInComponent:
                              sComponent]);
  }
  WOResponse_AddEmptyCloseParens(_response, _ctx);
}

// description

- (NSString *)associationDescription {
  return @"";
}

@end /* WOFrame */

@implementation _WOPageFrame

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super _initWithName:_name associations:_config template:_t])) {
    self->pageName = OWGetProperty(_config, @"pageName");

    if (self->pageName == nil) {
      NSLog(@"missing pageName association for WOFrame ..");
      RELEASE(self);
      return nil;
    }

#if DEBUG
    if ([_config objectForKey:@"value"] ||
        [_config objectForKey:@"src"]     ||
        [_config objectForKey:@"directActionName"] ||
        [_config objectForKey:@"actionClass"]) {
      NSLog(@"WARNING: inconsistent association settings in WOFrame !"
            @" (assign only one of pageName, href, "
            @"directActionName or action)");
    }
#endif
  }
  return self;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  RELEASE(self->pageName);
  [super dealloc];
}
#endif

/* value generation */

- (id)invokeActionForRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  NSString    *name;
  WOComponent *page;

  name = [self->pageName stringValueInComponent:[_ctx component]];
  page = [[WOApplication application] pageWithName:name inContext:_ctx];

  [[_ctx component] debugWithFormat:@"deliver page %@", [page name]];

  return page;
}

/* href generation */

- (BOOL)_appendHrefToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  WOResponse_AddString(_response, [_ctx componentActionURL]);
  return YES;
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = [NSMutableString stringWithCapacity:256];

  [str appendFormat:@" pageName=%@", self->pageName];
  [str appendString:[super associationDescription]];
  return str;
}

@end /* _WOPageFrame */

@implementation _WOHrefFrame

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super _initWithName:_name associations:_config template:_t])) {
    self->src = OWGetProperty(_config, @"src");

    if (self->src == nil) {
      NSLog(@"missing src association for WOFrame ..");
      RELEASE(self);
      return nil;
    }

#if DEBUG
    if ([_config objectForKey:@"value"] ||
        [_config objectForKey:@"pageName"]     ||
        [_config objectForKey:@"directActionName"] ||
        [_config objectForKey:@"actionClass"]) {
      NSLog(@"WARNING: inconsistent association settings in WOFrame !"
            @" (assign only one of pageName, src, directActionName or value)");
    }
#endif
  }
  return self;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  RELEASE(self->src);
  [super dealloc];
}
#endif

/* URI generation */

- (BOOL)_appendHrefToResponse:(WOResponse *)_r inContext:(WOContext *)_ctx {
  WOResponse_AddString(_r, [self->src stringValueInComponent:[_ctx component]]);
  return YES;
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = [NSMutableString stringWithCapacity:256];

  [str appendFormat:@" src=%@", self->src];
  [str appendString:[super associationDescription]];

  return str;
}

@end /* _WOHrefFrame */

@implementation _WODirectActionFrame

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super _initWithName:_name associations:_config template:_t])) {
    WOAssociation *sidInUrlAssoc;

    sidInUrlAssoc          = OWGetProperty(_config, @"?wosid");
    self->actionClass      = OWGetProperty(_config, @"actionClass");
    self->directActionName = OWGetProperty(_config, @"directActionName");

    self->sidInUrl = (sidInUrlAssoc)
      ? [sidInUrlAssoc boolValueInComponent:nil]
      : YES;
    
#if DEBUG
    if ([_config objectForKey:@"value"] ||
        [_config objectForKey:@"src"]     ||
        [_config objectForKey:@"pageName"]) {
      NSLog(@"WARNING: inconsistent association settings in WOFrame !"
            @" (assign only one of value, src, directActionName or pageName)");
    }
#endif
  }
  return self;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  RELEASE(self->actionClass);
  RELEASE(self->directActionName);
  [super dealloc];
}
#endif

/* href */

- (BOOL)_appendHrefToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  WOComponent         *sComponent;
  NSString            *daClass;
  NSString            *daName;
  NSMutableDictionary *qd;
  NSDictionary        *tmp;

  sComponent = [_ctx component];
  daClass = [self->actionClass stringValueInComponent:sComponent];
  daName  = [self->directActionName stringValueInComponent:sComponent];

  if (daClass) {
    if (daName) {
      if (![daClass isEqualToString:@"DirectAction"])
        daName = [NSString stringWithFormat:@"%@/%@", daClass, daName];
    }
    else
      daName = daClass;
  }

  qd = [NSMutableDictionary dictionaryWithCapacity:16];

      /* add query dictionary */
      
  if (self->queryDictionary) {
    if ((tmp = [self->queryDictionary valueInComponent:sComponent]))
      [qd addEntriesFromDictionary:tmp];
  }
      
  /* add ?style parameters */

  if (self->queryParameters) {
    NSEnumerator *keys;
    NSString     *key;

    keys = [self->queryParameters keyEnumerator];
    while ((key = [keys nextObject])) {
      id assoc, value;

      assoc = [self->queryParameters objectForKey:key];
      value = [assoc stringValueInComponent:sComponent];
          
      [qd setObject:(value != nil ? value : (id)@"") forKey:key];
    }
  }
      
  /* add session ID */

  if (self->sidInUrl) {
    if ([_ctx hasSession]) {
      WOSession *sn = [_ctx session];
          
      [qd setObject:[sn sessionID] forKey:WORequestValueSessionID];
          
      if (![sn isDistributionEnabled]) {
        [qd setObject:[[WOApplication application] number]
            forKey:WORequestValueInstance];
      }
    }
  }

  WOResponse_AddString(_response,
                       [_ctx directActionURLForActionNamed:daName
                             queryDictionary:qd]);
  return NO;
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = [NSMutableString stringWithCapacity:256];

  if (self->actionClass)
    [str appendFormat:@" actionClass=%@", self->actionClass];
  if (self->directActionName)
    [str appendFormat:@" directAction=%@", self->directActionName];
  
  [str appendString:[super associationDescription]];
  return str;
}

@end /* _WODirectActionFrame */

@implementation _WOValueFrame

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super _initWithName:_name associations:_config template:_t])) {
    self->value = OWGetProperty(_config, @"value");

    if (self->value == nil) {
      NSLog(@"missing value association for WOFrame ..");
      RELEASE(self);
      return nil;
    }

#if DEBUG
    if ([_config objectForKey:@"pageName"] ||
        [_config objectForKey:@"href"]     ||
        [_config objectForKey:@"directActionName"] ||
        [_config objectForKey:@"actionClass"]) {
      NSLog(@"WARNING: inconsistent association settings in WOFrame !"
            @" (assign only one of pageName, href, directActionName or value)");
    }
#endif
  }
  return self;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  RELEASE(self->value);
  [super dealloc];
}
#endif

/* dynamic invocation */

- (id)invokeActionForRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  return [self->value valueInComponent:[_ctx component]];
}

- (BOOL)_appendHrefToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  WOResponse_AddString(_response, [_ctx componentActionURL]);
  return YES;
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = [NSMutableString stringWithCapacity:256];

  [str appendFormat:@" value=%@", self->value];
  [str appendString:[super associationDescription]];
  return str;
}

@end /* _WOValueFrame */
