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

@interface WOIFrame : WOHTMLDynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  /* new in WO4 */
  WOAssociation *queryDictionary;
  NSDictionary  *queryParameters;  /* associations beginning with ? */
  WOElement     *template;
}

@end

@interface _WOPageIFrame : WOIFrame
{
  WOAssociation *pageName;
}
@end

@interface _WOHrefIFrame : WOIFrame
{
  WOAssociation *src;
}
@end

@interface _WOValueIFrame : WOIFrame
{
  WOAssociation *value;
  WOAssociation *filename;
}
@end

@interface _WODirectActionIFrame : WOIFrame
{
  WOAssociation *actionClass;
  WOAssociation *directActionName;
  BOOL          sidInUrl;          /* include session-id in wa URL ? */
}
@end

@interface WOIFrame(PrivateMethods)

- (id)_initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t;

- (NSString *)associationDescription;

@end

#if NeXT_Foundation_LIBRARY || APPLE_FOUNDATION_LIBRARY
@interface NSObject(Miss)
- (void)subclassResponsibility:(SEL)cmd;
@end
#endif

@implementation WOIFrame

+ (int)version {
  return 1;
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  Class frameClass = Nil;
  
  if ([_config objectForKey:@"value"])
    frameClass = [_WOValueIFrame class];
  else if ([_config objectForKey:@"pageName"])
    frameClass = [_WOPageIFrame class];
  else if ([_config objectForKey:@"src"])
    frameClass = [_WOHrefIFrame class];
  else
    frameClass = [_WODirectActionIFrame class];

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

    self->template = [_tmpl retain];
  }
  return self;
}

- (void)dealloc {
  [self->template        release];
  [self->queryDictionary release];
  [self->queryParameters release];
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

  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }

  sComponent  = [_ctx component];
  queryString = nil;

  WOResponse_AddCString(_response, "<iframe src=\"");

  if ([self _appendHrefToResponse:_response inContext:_ctx]) {
    queryString = [self queryStringForQueryDictionary:
                          [self->queryDictionary valueInComponent:sComponent]
                        andQueryParameters:self->queryParameters
                        inContext:_ctx];
  }

  if (queryString) {
    WOResponse_AddChar(_response, '?');
    WOResponse_AddString(_response, queryString);
  }
  WOResponse_AddChar(_response, '"');
  
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  
  if (self->otherTagString) {
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response,
                         [self->otherTagString stringValueInComponent:
                                                 [_ctx component]]);
  }
  WOResponse_AddChar(_response, '>');

  [self->template appendToResponse:_response inContext:_ctx];
  
  WOResponse_AddCString(_response, "</iframe>");

}

// description

- (NSString *)associationDescription {
  return @"";
}

@end /* WOIFrame */

@implementation _WOPageIFrame

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super _initWithName:_name associations:_config template:_t])) {
    self->pageName = OWGetProperty(_config, @"pageName");

    if (self->pageName == nil) {
      NSLog(@"missing pageName association for WOIFrame ..");
      [self release];
      return nil;
    }

#if DEBUG
    if ([_config objectForKey:@"value"] ||
        [_config objectForKey:@"src"]     ||
        [_config objectForKey:@"directActionName"] ||
        [_config objectForKey:@"actionClass"]) {
      NSLog(@"WARNING: inconsistent association settings in WOIFrame !"
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

@end /* _WOPageIFrame */

@implementation _WOHrefIFrame

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super _initWithName:_name associations:_config template:_t])) {
    self->src = OWGetProperty(_config, @"src");

    if (self->src == nil) {
      NSLog(@"missing src association for WOIFrame ..");
      [self release];
      return nil;
    }

#if DEBUG
    if ([_config objectForKey:@"value"] ||
        [_config objectForKey:@"pageName"]     ||
        [_config objectForKey:@"directActionName"] ||
        [_config objectForKey:@"actionClass"]) {
      NSLog(@"WARNING: inconsistent association settings in WOIFrame !"
            @" (assign only one of pageName, src, directActionName or value)");
    }
#endif
  }
  return self;
}

- (void)dealloc {
  [self->src release];
  [super dealloc];
}

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

@end /* _WOHrefIFrame */

@implementation _WODirectActionIFrame

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
      NSLog(@"WARNING: inconsistent association settings in WOIFrame !"
            @" (assign only one of value, src, directActionName or pageName)");
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

  if (self->queryParameters != nil) {
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

@end /* _WODirectActionIFrame */

@implementation _WOValueIFrame

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super _initWithName:_name associations:_config template:_t])) {
    self->value    = OWGetProperty(_config, @"value");
    self->filename = OWGetProperty(_config, @"filename");

    if (self->value == nil) {
      NSLog(@"missing value association for WOIFrame ..");
      [self release];
      return nil;
    }

#if DEBUG
    if ([_config objectForKey:@"pageName"] ||
        [_config objectForKey:@"href"]     ||
        [_config objectForKey:@"directActionName"] ||
        [_config objectForKey:@"actionClass"]) {
      NSLog(@"WARNING: inconsistent association settings in WOIFrame !"
            @" (assign only one of pageName, href, directActionName or value)");
    }
#endif
  }
  return self;
}

- (void)dealloc {
  [self->filename release];
  [self->value    release];
  [super dealloc];
}

/* dynamic invocation */

- (id)invokeActionForRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  return [self->value valueInComponent:[_ctx component]];
}

- (BOOL)_appendHrefToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *uri, *fn;
  
  uri = [_ctx componentActionURL];
  fn  = [self->filename stringValueInComponent:[_ctx component]];

  if ([fn length] > 0) {
    uri = [uri stringByAppendingString:@"/"];
    uri = [uri stringByAppendingString:fn];
  }
  
  WOResponse_AddString(_response, uri);
  return YES;
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = [NSMutableString stringWithCapacity:256];

  [str appendFormat:@" value=%@", self->value];
  [str appendString:[super associationDescription]];
  return str;
}

@end /* _WOValueIFrame */
