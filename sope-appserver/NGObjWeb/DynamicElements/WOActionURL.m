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

#include <NGObjWeb/WOActionURL.h>
#include "WOElement+private.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOResourceManager.h>
#include "decommon.h"

@interface _WOActionActionURL : WOActionURL
{
  WOAssociation *action;
}
@end

@interface _WOPageActionURL : WOActionURL
{
  WOAssociation *pageName;
}
@end

@interface _WODirectActionActionURL : WOActionURL
{
  WOAssociation *actionClass;
  WOAssociation *directActionName;
  BOOL          sidInUrl;          /* include session-id in wa URL ? */
}
@end

@interface WOActionURL(PrivateMethods)

- (id)_initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t;

- (NSString *)associationDescription;

@end

@implementation WOActionURL

+ (int)version {
  return 1;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

+ (BOOL)containsLinkInAssociations:(NSDictionary *)_assocs {
  if (_assocs == nil) return NO;
  if ([_assocs objectForKey:@"href"])             return YES;
  if ([_assocs objectForKey:@"directActionName"]) return YES;
  if ([_assocs objectForKey:@"pageName"])         return YES;
  if ([_assocs objectForKey:@"action"])           return YES;
  if ([_assocs objectForKey:@"actionClass"])      return YES;
  return NO;
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  Class linkClass = Nil;
  
  if ([_config objectForKey:@"action"])
    linkClass = [_WOActionActionURL class];
  else if ([_config objectForKey:@"pageName"])
    linkClass = [_WOPageActionURL class];
  else
    linkClass = [_WODirectActionActionURL class];

  [self release];
  return
    [[linkClass alloc] initWithName:_name associations:_config template:_t];
}

- (id)_initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->fragmentIdentifier = OWGetProperty(_config, @"fragmentIdentifier");
    self->queryDictionary    = OWGetProperty(_config, @"queryDictionary");
    self->queryParameters    = OWExtractQueryParameters(_config);
    self->template           = [_t retain];
    self->containsForm       = self->queryParameters ? YES : NO;
  }
  return self;
}

- (void)dealloc {
  [self->template           release];
  [self->queryDictionary    release];
  [self->queryParameters    release];
  [self->fragmentIdentifier release];
  [super dealloc];
}

/* accessors */

- (id)template {
  return self->template;
}

/* handling requests */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  /* links can take form values !!!! (for query-parameters) */

  if (self->queryParameters) {
    /* apply values to ?style parameters */
    WOComponent  *sComponent = [_ctx component];
    NSEnumerator *keys;
    NSString     *key;

    keys = [self->queryParameters keyEnumerator];
    while ((key = [keys nextObject])) {
      id assoc, value;

      assoc = [self->queryParameters objectForKey:key];
      value = [_req formValueForKey:key];

      [assoc setValue:value inComponent:sComponent];
    }
  }
  
  [self->template takeValuesFromRequest:_req inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  [[_ctx session] logWithFormat:@"%@[0x%p]: no action/page set !",
                    NSStringFromClass([self class]), self];
  return nil;
}

- (BOOL)_appendHrefToResponse:(WOResponse *)_r inContext:(WOContext *)_ctx {
#if APPLE_FOUNDATION_LIBRARY || NeXT_Foundation_LIBRARY || \
    COCOA_Foundation_LIBRARY
  NSLog(@"subclass responsibility ...");
#else
  [self subclassResponsibility:_cmd];
#endif
  return NO;
}

/* generate response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  NSString *queryString = nil;
  
  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }

  sComponent = [_ctx component];
  
  if ([self _appendHrefToResponse:_response inContext:_ctx]) {
    queryString = [self queryStringForQueryDictionary:
			  [self->queryDictionary valueInComponent:sComponent]
			andQueryParameters:self->queryParameters
			inContext:_ctx];
  }
  
  if (self->fragmentIdentifier != nil) {
    [_response appendContentCharacter:'#'];
    WOResponse_AddString(_response,
         [self->fragmentIdentifier stringValueInComponent:sComponent]);
  }
  if (queryString != nil) {
    [_response appendContentCharacter:'?'];
    WOResponse_AddString(_response, queryString);
  }
    
  /* content */
  [self->template appendToResponse:_response inContext:_ctx];
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = [NSMutableString stringWithCapacity:256];

  if (self->fragmentIdentifier)
    [str appendFormat:@" fragment=%@", self->fragmentIdentifier];

  return str;
}

@end /* WOActionURL */

@implementation _WOActionActionURL

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super _initWithName:_name associations:_config template:_t])) {
    self->action = OWGetProperty(_config, @"action");

    if (self->action == nil) {
      NSLog(@"missing action association for WOActionURL ..");
      RELEASE(self);
      return nil;
    }

#if DEBUG
    if ([_config objectForKey:@"pageName"] ||
        [_config objectForKey:@"href"]     ||
        [_config objectForKey:@"directActionName"] ||
        [_config objectForKey:@"actionClass"]) {
      NSLog(@"WARNING: inconsistent association settings in WOActionURL !"
            @" (assign only one of pageName, href, "
            @"directActionName or action)");
    }
#endif
  }
  return self;
}

- (void)dealloc {
  [self->action release];
  [super dealloc];
}

/* dynamic invocation */

- (id)invokeActionForRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  /* link is active */
  return [self executeAction:self->action inContext:_ctx];
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

  [str appendFormat:@" action=%@", self->action];
  [str appendString:[super associationDescription]];
  return str;
}

@end /* _WOActionActionURL */

@implementation _WOPageActionURL

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super _initWithName:_name associations:_config template:_t])) {
    self->pageName = OWGetProperty(_config, @"pageName");

    if (self->pageName == nil) {
      NSLog(@"missing pageName association for WOActionURL ..");
      RELEASE(self);
      return nil;
    }

#if DEBUG
    if ([_config objectForKey:@"action"] ||
        [_config objectForKey:@"href"]     ||
        [_config objectForKey:@"directActionName"] ||
        [_config objectForKey:@"actionClass"]) {
      NSLog(@"WARNING: inconsistent association settings in WOActionURL !"
            @" (assign only one of pageName, href, "
            @"directActionName or action)");
    }
#endif
  }
  return self;
}

- (void)dealloc {
  [self->pageName release];
  [super dealloc];
}

/* actions */

- (id)invokeActionForRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  WOComponent *page = nil;
  NSString    *name = nil;

  name = [self->pageName stringValueInComponent:[_ctx component]];
  page = [[_ctx application] pageWithName:name inContext:_ctx];

  if (page == nil) {
    [[_ctx session] logWithFormat:
                      @"%@[0x%p]: did not find page with name %@ !",
                      NSStringFromClass([self class]), self, name];
  }
  return page;
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

  [str appendFormat:@" pageName=%@", self->pageName];
  [str appendString:[super associationDescription]];
  return str;
}

@end /* _WOPageActionURL */

@implementation _WODirectActionActionURL

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
    if ([_config objectForKey:@"action"] ||
        [_config objectForKey:@"href"]     ||
        [_config objectForKey:@"pageName"]) {
      NSLog(@"WARNING: inconsistent association settings in WOActionURL !"
            @" (assign only one of pageName, href, "
            @"directActionName or action)");
    }
#endif
  }
  return self;
}

- (void)dealloc {
  [self->actionClass      release];
  [self->directActionName release];
  [super dealloc];
}

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
    while ((key = [keys nextObject]) != nil) {
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

  if (self->actionClass != nil)
    [str appendFormat:@" actionClass=%@", self->actionClass];
  if (self->directActionName != nil)
    [str appendFormat:@" directAction=%@", self->directActionName];
  
  [str appendString:[super associationDescription]];
  return str;
}

@end /* _WODirectActionActionURL */
