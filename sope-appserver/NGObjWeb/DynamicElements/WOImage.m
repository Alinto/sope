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

#include "WOImage.h"

@interface _WOTemporaryImage : NSObject
@end

@interface _WODynamicImage : WOImage /* new in WO4 */
{
  WOAssociation *data;
  WOAssociation *mimeType;
  WOAssociation *key;
}
@end

@interface _WOElementImage : WOImage
{
  WOAssociation *value;     // image data (eg from a database)
}
@end

@interface _WOExternalImage : WOImage
{
  WOAssociation *src;       // absolute URL
}
@end

@interface WOImage(PrivateMethods)

- (NSString *)associationDescription;

@end

#include "WOElement+private.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOResourceManager.h>
#include "decommon.h"

#if NeXT_Foundation_LIBRARY || APPLE_FOUNDATION_LIBRARY
@interface NSObject(Miss)
- (void)subclassResponsibility:(SEL)cmd;
@end
#endif

@implementation WOImage

+ (id)allocWithZone:(NSZone *)zone {
  static Class WOImageClass = Nil;
  static _WOTemporaryImage *temporaryImage = nil;
  
  if (WOImageClass == Nil)
    WOImageClass = [WOImage class];
  if (temporaryImage == nil)
    temporaryImage = [_WOTemporaryImage allocWithZone:zone];
  
  return (self == WOImageClass)
    ? (id)temporaryImage
    : (id)NSAllocateObject(self, 0, zone);
}

/* request handling */

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  NSLog(@"no value configured for WOImage %@", self);
  return nil;
}

- (void)_appendSrcToResponse:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  [self subclassResponsibility:_cmd];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent])
    return;

  WOResponse_AddCString(_response, "<img src=\"");
  
#if DEBUG && USE_EXCEPTION_HANDLER
  NS_DURING {
    [self _appendSrcToResponse:_response inContext:_ctx];
  }
  NS_HANDLER {
    fprintf(stderr, "exception in %s: %s\n",
            [[self description] cString],
            [[localException description] cString]);
    [localException raise];
  }
  NS_ENDHANDLER;
#else
  [self _appendSrcToResponse:_response inContext:_ctx];
#endif
  
  WOResponse_AddChar(_response, '"');
  
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
    
  if (self->otherTagString) {
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response,
                         [self->otherTagString stringValueInComponent:
                              [_ctx component]]);
  }
  
  WOResponse_AddEmptyCloseParens(_response, _ctx);
}

@end /* WOImage */

@implementation _WODynamicImage

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->data     = OWGetProperty(_config, @"data");
    self->mimeType = OWGetProperty(_config, @"mimeType");
    self->key      = OWGetProperty(_config, @"key");
    
#if DEBUG
    if ([_config objectForKey:@"value"]     ||
        [_config objectForKey:@"filename"]  ||
        [_config objectForKey:@"framework"] ||
        [_config objectForKey:@"src"]) {
      NSLog(@"WARNING: inconsistent association settings in WOImage !"
            @" (assign only one of value, src, data or filename)");
    }
#endif
  }
  return self;
}

- (void)dealloc {
  [self->key      release];
  [self->data     release];
  [self->mimeType release];
  [super dealloc];
}

/* dynamic delivery */

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  WOComponent *sComponent = [_ctx component];
  NSData     *adata;
  NSString   *atype;
  WOResponse *response;

  adata = [self->data     valueInComponent:sComponent];
  atype = [self->mimeType stringValueInComponent:sComponent];

  response = [_ctx response];
    
  [response setContent:adata];
  [response setHeader:
	      (atype != nil ? atype : (NSString *)@"application/octet-stream")
            forKey:@"content-type"];
    
  return response;
}

/* HTML generation */

- (void)_appendSrcToResponse:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  WOResourceManager *rm;
  WOComponent *sComponent;
  NSString *kk, *url;

  sComponent = [_ctx component];
  
  if ((kk = [self->key stringValueInComponent:sComponent]) == nil) {
    WOResponse_AddString(_resp, [_ctx componentActionURL]);
    return;
  }

  if ((rm = [[_ctx component] resourceManager]) == nil)
    rm = [[_ctx application] resourceManager];
    
  [rm setData:[self->data valueInComponent:sComponent] forKey:kk
      mimeType:[self->mimeType stringValueInComponent:sComponent]
      session:[_ctx hasSession] ? [_ctx session] : nil];
    
  url = [_ctx urlWithRequestHandlerKey:
                [WOApplication resourceRequestHandlerKey]
              path:[@"/" stringByAppendingString:kk]
              queryString:nil];
    
  WOResponse_AddString(_resp, url);
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = [NSMutableString stringWithCapacity:64];
  if (self->data)      [str appendFormat:@" data=%@",      self->data];
  if (self->mimeType)  [str appendFormat:@" mimeType=%@",  self->mimeType];
  if (self->key)       [str appendFormat:@" key=%@",       self->key];
  [str appendString:[super associationDescription]];
  return str;
}

@end /* _WODynamicImage */

@implementation _WOElementImage

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->value = OWGetProperty(_config, @"value");

#if DEBUG
    if ([_config objectForKey:@"data"]      ||
        [_config objectForKey:@"mimeType"]  ||
        [_config objectForKey:@"key"]       ||
        [_config objectForKey:@"filename"]  ||
        [_config objectForKey:@"framework"] ||
        [_config objectForKey:@"src"]) {
      NSLog(@"WARNING: inconsistent association settings in WOImage !"
            @" (assign only one of value, src, data or filename)");
    }
#endif
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->value);
  [super dealloc];
}

/* dynamic delivery */

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  WOElement *element;
  
  if ((element = [self->value valueInComponent:[_ctx component]]) == nil) {
    NSLog(@"WARNING: missing element value for WOImage %@", self);
    return nil;
  }

  [element appendToResponse:[_ctx response] inContext:_ctx];
  return [_ctx response];
}

/* HTML generation */

- (void)_appendSrcToResponse:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  WOResponse_AddString(_resp, [_ctx componentActionURL]);
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = [NSMutableString stringWithCapacity:64];

  [str appendFormat:@" value=%@", self->value];
  [str appendString:[super associationDescription]];
  return str;
}

@end /* _WOElementImage */

@implementation _WOExternalImage

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->src = OWGetProperty(_config, @"src");

#if DEBUG
    if ([_config objectForKey:@"data"]      ||
        [_config objectForKey:@"mimeType"]  ||
        [_config objectForKey:@"key"]       ||
        [_config objectForKey:@"filename"]  ||
        [_config objectForKey:@"framework"] ||
        [_config objectForKey:@"value"]) {
      NSLog(@"WARNING: inconsistent association settings in WOImage !"
            @" (assign only one of value, src, data or filename)");
    }
#endif
  }
  return self;
}

- (void)dealloc {
  [self->src release];
  [super dealloc];
}

/* HTML generation */

- (void)_appendSrcToResponse:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  NSString *s;
  
  s = [self->src stringValueInComponent:[_ctx component]];
  if (s != nil) [_resp appendContentHTMLAttributeValue:s];
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;
  
  str = [NSMutableString stringWithCapacity:64];
  [str appendFormat:@" src=%@", self->src];
  [str appendString:[super associationDescription]];
  return str;
}

@end /* _WOExternalImage */

@implementation _WOTemporaryImage

- (id)initWithName:(NSString *)_n
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  // TODO: cache class objects?
  Class imageClass = Nil;
  WOAssociation *a;
  
  if ((a = [_config objectForKey:@"filename"])) {
    if ([a isValueConstant] && [_config objectForKey:@"framework"] == nil)
      imageClass = NSClassFromString(@"_WOConstResourceImage");
    else
      imageClass = NSClassFromString(@"_WOResourceImage");
  }
  else if ([_config objectForKey:@"src"])
    imageClass = [_WOExternalImage class];
  else if ([_config objectForKey:@"value"])
    imageClass = [_WOElementImage class];
  else if ([_config objectForKey:@"data"])
    imageClass = [_WODynamicImage class];
  else {
    NSLog(@"WARNING: missing data source association for WOImage !");
  }
  
  return [[imageClass alloc] initWithName:_n associations:_config template:_t];
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_associations
  contentElements:(NSArray *)_contents
{
  WOAssociation *a;
  Class imageClass = Nil;
  
  if ((a = [_associations objectForKey:@"filename"])) {
    if ([a isValueConstant] && [_associations objectForKey:@"framework"]==nil)
      imageClass = NSClassFromString(@"_WOConstResourceImage");
    else
      imageClass = NSClassFromString(@"_WOResourceImage");
  }
  else if ([_associations objectForKey:@"src"])
    imageClass = [_WOExternalImage class];
  else if ([_associations objectForKey:@"value"])
    imageClass = [_WOElementImage class];
  else if ([_associations objectForKey:@"data"])
    imageClass = [_WODynamicImage class];
  else {
    NSLog(@"WARNING: missing data source association for WOImage !");
  }
  
  return [[imageClass alloc] initWithName:_name
                             associations:_associations
                             contentElements:_contents];
}

- (void)dealloc {
  [self errorWithFormat:@"called dealloc on %@", self];
#if DEBUG
  abort();
#endif
  return;
  
  // same issue with gcc 4.1 on Linux ..., make Tiger GCC happy
  if (0) [super dealloc];
}

@end /* _WOTemporaryImage */
