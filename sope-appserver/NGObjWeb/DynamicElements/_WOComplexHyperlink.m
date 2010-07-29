/*
  Copyright (C) 2000-2008 SKYRIX Software AG
  Copyright (C) 2008      Helge Hess

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

#include "WOHyperlink.h"

/*
  Class Hierachy
    [WOHTMLDynamicElement]
      [WOHyperlink]
        _WOComplexHyperlink
          _WOHrefHyperlink
          _WOActionHyperlink
          _WOPageHyperlink
          _WODirectActionHyperlink
*/

@interface _WOComplexHyperlink : WOHyperlink
{
  /* superclass of most hyperlink classes */
@protected
  WOAssociation *fragmentIdentifier;
  WOAssociation *string;
  WOAssociation *target;
  WOAssociation *disabled;
  WOAssociation *isAbsolute;
  WOElement     *template;
  
  /* new in WO4: */
  WOAssociation *queryDictionary;
  NSDictionary  *queryParameters;  /* associations beginning with ? */

  /* non WO, image stuff */
  WOAssociation *filename;         /* path relative to WebServerResources */
  WOAssociation *framework;
  WOAssociation *src;              /* absolute URL */
  WOAssociation *disabledFilename; /* icon for 'disabled' state */
}

- (NSString *)associationDescription;

@end

@interface _WOHrefHyperlink : _WOComplexHyperlink
{
  WOAssociation *href;
}
@end

@interface _WOActionHyperlink : _WOComplexHyperlink
{
  WOAssociation *action;
}
@end

@interface _WOPageHyperlink : _WOComplexHyperlink
{
  WOAssociation *pageName;
}
@end

@interface _WODirectActionHyperlink : _WOComplexHyperlink
{
  WOAssociation *actionClass;
  WOAssociation *directActionName;
  BOOL          sidInUrl;          /* include session-id in wa URL ? */
}
@end

#include "WOElement+private.h"
#include "WOHyperlinkInfo.h"
#include "WOCompoundElement.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOResourceManager.h>
#include <NGExtensions/NSString+Ext.h>
#include "decommon.h"

static Class NSURLClass = Nil;

@implementation _WOComplexHyperlink

+ (int)version {
  return [super version] /* v4 */;
}
+ (void)initialize {
  NSAssert2([super version] == 4,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  if (NSURLClass == Nil)
    NSURLClass = [NSURL class];
}

- (id)initWithName:(NSString *)_name
  hyperlinkInfo:(WOHyperlinkInfo *)_info
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name hyperlinkInfo:_info template:_t])) {
    self->template = [_t retain];
    
    self->fragmentIdentifier = _info->fragmentIdentifier;
    self->string             = _info->string;
    self->target             = _info->target;
    self->disabled           = _info->disabled;
    self->queryDictionary    = _info->queryDictionary;
    self->queryParameters    = _info->queryParameters;
    
    /* image */
    self->filename         = _info->filename;
    self->framework        = _info->framework;
    self->src              = _info->src;
    self->disabledFilename = _info->disabledFilename;
    
    self->containsForm = self->queryParameters ? YES : NO;
  }
  return self;
}

- (void)dealloc {
  [self->template           release];
  [self->queryDictionary    release];
  [self->queryParameters    release];
  [self->disabledFilename   release];
  [self->filename           release];
  [self->framework          release];
  [self->src                release];
  [self->fragmentIdentifier release];
  [self->string             release];
  [self->target             release];
  [self->disabled           release];
  [super dealloc];
}

/* accessors */

- (id)template {
  return self->template;
}

/* handle requests */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  /* links can take form values !!!! (for query-parameters) */
  
  if (self->queryParameters != nil) {
    /* apply values to ?style parameters */
    WOComponent  *sComponent = [_ctx component];
    NSEnumerator *keys;
    NSString     *key;
    
    keys = [self->queryParameters keyEnumerator];
    while ((key = [keys nextObject]) != nil) {
      id assoc, value;
      
      assoc = [self->queryParameters objectForKey:key];
      
      if ([assoc isValueSettable]) {
        value = [_rq formValueForKey:key];
        [assoc setValue:value inComponent:sComponent];
      }
    }
  }
  
  [self->template takeValuesFromRequest:_rq inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  if (self->disabled != nil) {
    if ([self->disabled boolValueInComponent:[_ctx component]])
      return nil;
  }
  
  if (![[_ctx elementID] isEqualToString:[_ctx senderID]])
    /* link is not the active element */
    return [self->template invokeActionForRequest:_rq inContext:_ctx];
  
  /* link is active */
  [[_ctx session] logWithFormat:@"%@[0x%p]: no action/page set !",
                  NSStringFromClass([self class]), self];
  return nil;
}

- (BOOL)_appendHrefToResponse:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  [self subclassResponsibility:_cmd];
  return NO;
}

- (void)_addImageToResponse:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  WOComponent *sComponent = [_ctx component];
  NSString *uUri;
  NSString *uFi  = nil;
  NSArray *languages;
  
  uUri = [[self->src valueInContext:_ctx] stringValue];
      
  if ([self->disabled boolValueInComponent:sComponent]) {
    uFi =  [self->disabledFilename stringValueInComponent:sComponent];
    if (uFi == nil)
      uFi = [self->filename stringValueInComponent:sComponent];
  }
  else
    uFi = [self->filename stringValueInComponent:sComponent];
  
  if (!((uFi != nil) || (uUri != nil))) 
    return;

  languages = [_ctx resourceLookupLanguages];
        
  WOResponse_AddCString(_resp, "<img src=\"");
  
  if (uFi) {
    WOResourceManager *rm;
          
    if ((rm = [[_ctx component] resourceManager]) == nil)
      rm = [[_ctx application] resourceManager];
          
    uFi = [rm urlForResourceNamed:uFi
	      inFramework:
		[self->framework stringValueInComponent:sComponent]
	      languages:languages
	      request:[_ctx request]];
    if (uFi == nil) {
      NSLog(@"%@: did not find resource %@", sComponent,
	    [self->filename stringValueInComponent:sComponent]);
      uFi = uUri;
    }
    [_resp appendContentHTMLAttributeValue:uFi];
  }
  else {
    [_resp appendContentHTMLAttributeValue:uUri];
  }
  WOResponse_AddChar(_resp, '"');
  
  [self appendExtraAttributesToResponse:_resp inContext:_ctx];
  
  WOResponse_AddEmptyCloseParens(_resp, _ctx);
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *sComponent = [_ctx component];
  NSString    *content;
  BOOL        doNotDisplay;

  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  content      = [self->string valueInContext:_ctx];
  doNotDisplay = [self->disabled boolValueInComponent:sComponent];

  if (!doNotDisplay) {
    NSString *targetView;
    NSString *queryString = nil;

    targetView = [self->target stringValueInComponent:sComponent];
    
    WOResponse_AddCString(_response, "<a href=\"");
      
    if ([self _appendHrefToResponse:_response inContext:_ctx]) {
      queryString = [self queryStringForQueryDictionary:
          [self->queryDictionary valueInComponent:sComponent]
          andQueryParameters:self->queryParameters
          inContext:_ctx];
    }

    if (self->fragmentIdentifier) {
        [_response appendContentCharacter:'#'];
        WOResponse_AddString(_response,
           [self->fragmentIdentifier stringValueInComponent:sComponent]);
    }
    if (queryString) {
      [_response appendContentCharacter:'?'];
      WOResponse_AddString(_response, queryString);
    }
    [_response appendContentCharacter:'"'];
      
    if (targetView) {
      WOResponse_AddCString(_response, " target=\"");
      WOResponse_AddString(_response, targetView);
      [_response appendContentCharacter:'"'];
    }
      
    [self appendExtraAttributesToResponse:_response inContext:_ctx];
      
    if (self->otherTagString) {
      WOResponse_AddChar(_response, ' ');
      WOResponse_AddString(_response,
                           [self->otherTagString stringValueInComponent:
                             [_ctx component]]);
    }
    [_response appendContentCharacter:'>'];
  }

  /* content */
  [self->template appendToResponse:_response inContext:_ctx];
  if (content) [_response appendContentHTMLString:content];
  
  /* image content */
  if ((self->src != nil) || (self->filename != nil))
    [self _addImageToResponse:_response inContext:_ctx];
  
  if (!doNotDisplay) {
    /* closing tag */
    WOResponse_AddCString(_response, "</a>");
  }
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = [NSMutableString stringWithCapacity:256];

  if (self->fragmentIdentifier)
    [str appendFormat:@" fragment=%@", self->fragmentIdentifier];
  if (self->string)   [str appendFormat:@" string=%@",   self->string];
  if (self->target)   [str appendFormat:@" target=%@",   self->target];
  if (self->disabled) [str appendFormat:@" disabled=%@", self->disabled];

  /* image .. */
  if (self->filename)  [str appendFormat:@" filename=%@",  self->filename];
  if (self->framework) [str appendFormat:@" framework=%@", self->framework];
  if (self->src)       [str appendFormat:@" src=%@",       self->src];

  return str;
}

@end /* _WOComplexHyperlink */


@implementation _WOHrefHyperlink

static BOOL debugStaticLinks = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  debugStaticLinks = [ud boolForKey:@"WODebugStaticLinkProcessing"];
}

- (id)initWithName:(NSString *)_name
  hyperlinkInfo:(WOHyperlinkInfo *)_info
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name hyperlinkInfo:_info template:_t])) {
    self->href = _info->href;
    self->isAbsolute = _info->isAbsolute;
  }
  return self;
}

- (void)dealloc {
  [self->href release];
  [super dealloc];
}

/* URI generation */

- (BOOL)shouldRewriteURLString:(NSString *)_s inContext:(WOContext *)_ctx {
  // TODO: we need a binding to disable rewriting!
  NSRange r;

  if ([[self->isAbsolute valueInContext:_ctx] boolValue] == YES)
    return NO;

  r.length = [_s length];

  /* do not rewrite pure fragment URLs */
  if (r.length > 0 && [_s characterAtIndex:0] == '#')
    return NO;
  
  /* rewrite all URLs w/o a protocol */
  r = [_s rangeOfString:@":"];
  if (r.length == 0) 
    return YES;
  
  /* only rewrite HTTP URLs */
  return [_s hasPrefix:@"http"];
}

- (BOOL)_appendHrefToResponse:(WOResponse *)_r inContext:(WOContext *)_ctx {
  NSString *s;
  id    hrefValue;
  NSURL *url, *base;
  
  base      = [_ctx baseURL];
  hrefValue = [self->href valueInContext:_ctx];
  url       = nil;
  
  if (hrefValue == nil)
    return NO;
  
  if ((*(Class *)hrefValue == NSURLClass) ||
      [hrefValue isKindOfClass:NSURLClass]) {
    s = [hrefValue stringValueRelativeToURL:base];
  }
  else {
    /* given HREF is a string */
    s = [hrefValue stringValue];
    
    /* we do not want to rewrite stuff like mailto: or javascript: URLs */
    if ([self shouldRewriteURLString:s inContext:_ctx]) {
      if ([s isAbsoluteURL]) {
        // TODO: why are we doing this? we could just pass through the string?
        //    => probably to generate relative links
        url = [NSURLClass URLWithString:s];
      }
      else if (base != nil) {
        /* avoid creating a new URL for ".", just return the base */
        url = [s isEqualToString:@"."]
          ? base
          : (NSURL *)[NSURLClass URLWithString:s relativeToURL:base];
      }
      else {
        [self warnWithFormat:@"missing base URL in context ..."];
        WOResponse_AddString(_r, s);
        return YES;
      }
      
      if (url == nil) {
        [self logWithFormat:
                @"could not construct URL from 'href' string '%@' (base=%@)",
                s, base];
        return NO;
      }
      
      s = [url stringValueRelativeToURL:base];
    }
  }
  
  /* generate URL */
  
  if (debugStaticLinks) {
    [self logWithFormat:@"static links based on 'href': '%@'", hrefValue];
    [self logWithFormat:@"  base     %@", base];
    [self logWithFormat:@"  base-abs %@", [base absoluteString]];
    [self logWithFormat:@"  url      %@", url];
    if (url != nil)
      [self logWithFormat:@"  url-abs  %@", [url absoluteString]];
    else
      [self logWithFormat:@"  href     %@", hrefValue];
    [self logWithFormat:@"  string   %@", s];
  }
  
  WOResponse_AddString(_r, s);
  return YES;
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = [NSMutableString stringWithCapacity:256];

  [str appendFormat:@" href=%@", self->href];
  [str appendString:[super associationDescription]];
  
  return str;
}

@end /* _WOHrefHyperlink */


@implementation _WOActionHyperlink

- (id)initWithName:(NSString *)_name
  hyperlinkInfo:(WOHyperlinkInfo *)_info
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name hyperlinkInfo:_info template:_t])) {
    self->action = _info->action;
  }
  return self;
}

- (void)dealloc {
  [self->action release];
  [super dealloc];
}

/* dynamic invocation */

- (id)invokeActionForRequest:(WORequest *)_rq
  inContext:(WOContext *)_ctx
{
  if (self->disabled) {
    if ([self->disabled boolValueInComponent:[_ctx component]])
      return nil;
  }

  if (![[_ctx elementID] isEqualToString:[_ctx senderID]])
    /* link is not the active element */
    return [self->template invokeActionForRequest:_rq inContext:_ctx];
  
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

@end /* _WOActionHyperlink */


@implementation _WOPageHyperlink

- (id)initWithName:(NSString *)_name
  hyperlinkInfo:(WOHyperlinkInfo *)_info
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name hyperlinkInfo:_info template:_t])) {
    self->pageName = _info->pageName;
  }
  return self;
}

- (void)dealloc {
  [self->pageName release];
  [super dealloc];
}

/* handle request */

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  WOComponent *page;
  NSString    *name;

  if (self->disabled) {
    if ([self->disabled boolValueInComponent:[_ctx component]])
      return nil;
  }
  
  if (![[_ctx elementID] isEqualToString:[_ctx senderID]])
    /* link is not the active element */
    return [self->template invokeActionForRequest:_rq inContext:_ctx];
  
  /* link is the active element */
  
  name = [self->pageName stringValueInComponent:[_ctx component]];
  page = [[_ctx application] pageWithName:name inContext:_ctx];

  if (page == nil) {
    [[_ctx session] logWithFormat:
                      @"%@[0x%p]: did not find page with name %@ !",
                      NSStringFromClass([self class]), self, name];
  }
  return page;
}

/* generate response */

- (BOOL)_appendHrefToResponse:(WOResponse *)_r inContext:(WOContext *)_ctx {
  /*
    Profiling:
      87% -componentActionURL
      13% NSString dataUsingEncoding(appendContentString!)
    TODO(prof): use addcstring
  */
  WOResponse_AddString(_r, [_ctx componentActionURL]);
  return YES;
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = [NSMutableString stringWithCapacity:256];

  [str appendFormat:@" pageName=%@", self->pageName];
  [str appendString:[super associationDescription]];
  return str;
}

@end /* _WOPageHyperlink */


@implementation _WODirectActionHyperlink

- (id)initWithName:(NSString *)_name
  hyperlinkInfo:(WOHyperlinkInfo *)_info
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name hyperlinkInfo:_info template:_t])) {
    self->actionClass      = _info->actionClass;
    self->directActionName = _info->directActionName;
    self->sidInUrl         = _info->sidInUrl;

    self->containsForm = NO; /* direct actions are never form stuff ... */
  }
  return self;
}

- (void)dealloc {
  [self->actionClass      release];
  [self->directActionName release];
  [super dealloc];
}

/* handle requests */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  /* DA links can *never* take form values !!!! */
  [self->template takeValuesFromRequest:_req inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  /* DA links can *never* invoke an action !!!! */
  return [self->template invokeActionForRequest:_rq inContext:_ctx];
}

/* generate response */

- (BOOL)_appendHrefToResponse:(WOResponse *)_r
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
      WOSession *sn;
      
      sn = [_ctx session];
      [qd setObject:[sn sessionID] forKey:WORequestValueSessionID];
      
      if (![sn isDistributionEnabled]) {
        [qd setObject:[[WOApplication application] number]
            forKey:WORequestValueInstance];
      }
    }
  }

  WOResponse_AddString(_r,
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

@end /* _WODirectActionHyperlink */
