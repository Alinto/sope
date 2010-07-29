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

#import <NGObjWeb/WODynamicElement.h>

@interface JSImageFlyover : WODynamicElement
{
  WOAssociation *action;
  WOAssociation *javaScriptFunction;
  WOAssociation *pageName;
  WOAssociation *selectedImage;
  WOAssociation *unselectedImage;
  WOAssociation *framework;
  WOAssociation *targetWindow;

  // Skyrix add-ons
  WOAssociation *directActionName;
  WOAssociation *actionClass;
  BOOL          sidInUrl;
  WOAssociation *queryDictionary;
  NSDictionary  *queryParameters;
  
  WOElement     *template;
}

@end

#import <NGObjWeb/NGObjWeb.h>
#include "common.h"

@implementation JSImageFlyover

+ (int)version {
  return [super version] + 0 /* v2 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
	    @"invalid superclass (%@) version %i !",
	    NSStringFromClass([self superclass]), [super version]);
}

- (NSDictionary *)extractQueryParameters: (NSDictionary *)_set {
  NSMutableDictionary *paras = nil;
  NSMutableArray      *paraKeys = nil;
  NSEnumerator        *keys;
  NSString            *key;

  // locate query parameters
  keys = [_set keyEnumerator];
  while ((key = [keys nextObject])) {
    if ([key hasPrefix:@"?"]) {
      WOAssociation *value;

      if ([key isEqualToString:@"?wosid"])
        continue;

      value = [_set objectForKey:key];
          
      if (paraKeys == nil)
        paraKeys = [NSMutableArray arrayWithCapacity:8];
      if (paras == nil)
        paras = [NSMutableDictionary dictionaryWithCapacity:8];
          
      [paraKeys addObject:key];
      [paras setObject:value forKey:[key substringFromIndex:1]];
    }
  }

  // remove query parameters
  if (paraKeys) {
    unsigned cnt, count;
    for (cnt = 0, count = [paraKeys count]; cnt < count; cnt++) {
      [(NSMutableDictionary *)_set removeObjectForKey:
                                     [paraKeys objectAtIndex:cnt]];
    }
  }

  // assign parameters
  return [paras copy];
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_subs
{
  if ((self = [super initWithName:_name associations:_config template:_subs])){
    int           funcCount;
    WOAssociation *sidInUrlAssoc;
    
    self->action             = WOExtGetProperty(_config, @"action");
    self->javaScriptFunction = WOExtGetProperty(_config, @"javaScriptFunction");
    self->pageName           = WOExtGetProperty(_config, @"pageName");
    self->selectedImage      = WOExtGetProperty(_config, @"selectedImage");
    self->unselectedImage    = WOExtGetProperty(_config, @"unselectedImage");
    self->framework          = WOExtGetProperty(_config, @"framework");
    self->targetWindow       = WOExtGetProperty(_config, @"targetWindow");

    self->directActionName   = WOExtGetProperty(_config, @"directActionName");
    self->actionClass        = WOExtGetProperty(_config, @"actionClass");
    self->queryDictionary    = WOExtGetProperty(_config, @"queryDictionary");
    self->queryParameters    = [self extractQueryParameters:_config];
    
    funcCount = 0;
    if (self->action) funcCount++;
    if (self->pageName) funcCount++;
    if (self->javaScriptFunction) funcCount++;
    if (self->directActionName) funcCount++;

    if (funcCount > 1)
      NSLog(@"WARNING: JSImageFlyover: choose only one of "
            @"action | pageName | javaScriptFunction | directActionName");
    if (funcCount < 1)
      NSLog(@"WARNING: JSImageFlyover: no function declared - choose one of"
            @"action | pageName | javaScriptFunction | directActionName");
    if (!self->selectedImage)
      NSLog(@"WARNING: JSImageFlyover: no value for 'selectedImage'");
    if (!self->unselectedImage)
      NSLog(@"WARNING: JSImageFlyover: no value for 'unselectedImage'");

    /* for directActionName */
    sidInUrlAssoc = WOExtGetProperty(_config, @"?wosid");
    self->sidInUrl = (sidInUrlAssoc)
      ? [sidInUrlAssoc boolValueInComponent:nil]
      : YES;
    

    self->template = [_subs retain];
  }
  return self;
}

- (void)dealloc {
  [self->action             release];
  [self->javaScriptFunction release];
  [self->pageName           release];
  [self->selectedImage      release];
  [self->unselectedImage    release];
  [self->framework          release];
  [self->targetWindow       release];
  [self->template           release];

  [self->directActionName release];
  [self->actionClass      release];
  [self->queryDictionary  release];
  [self->queryParameters  release];
  
  [super dealloc];
}

/* handle requests */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  [self->template takeValuesFromRequest:_rq inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  id          result;
  NSString    *name;

  if (self->pageName) {
    name = [self->pageName stringValueInComponent: [_ctx component]];
    result = [[_ctx application] pageWithName:name inContext:_ctx];
  }
  else if (self->action) {
    result = [self->action valueInComponent:[_ctx component]];
  }
  else {
    result = [self->template invokeActionForRequest:_rq inContext:_ctx];
  }
  return result;
}

/* generate response */

- (NSString *)imageByFilename:(NSString *)_name
  inContext:(WOContext *)_ctx
  framework:(NSString *)_framework
{
  WOResourceManager *rm;
  NSString          *tmp;
  NSArray           *languages;

  rm        = [[_ctx application] resourceManager];
  languages = [_ctx resourceLookupLanguages];
  tmp       = [rm urlForResourceNamed:_name
                  inFramework:_framework
                  languages:languages
                  request:[_ctx request]];
  return tmp;
}
    

- (void)appendDirectActionURLToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  WOComponent *comp;
  NSString            *daName;
  NSString            *daClass;
  NSMutableDictionary *qd;
  WOSession           *sn;
  NSDictionary        *tdict;
  NSString *s;
  
  comp    = [_ctx component];
  daName  = [self->directActionName stringValueInComponent:comp];
  daClass = [self->actionClass stringValueInComponent:comp];
      
  if (daClass) {
    if (daName) {
      if (![daClass isEqualToString:@"DirectAction"])
        daName = [NSString stringWithFormat:@"%@/%@", daClass, daName];
    }
    else
      daName = daClass;
  }
      
  qd = [NSMutableDictionary dictionaryWithCapacity:16];

  if (self->queryDictionary) {
    if ((tdict = [self->queryDictionary valueInComponent:comp]))
      [qd addEntriesFromDictionary:tdict];
  }

  if (self->queryParameters) {
    NSEnumerator *keys;
    NSString     *key;

    keys = [self->queryParameters keyEnumerator];
    while ((key = [keys nextObject])) {
      id assoc, value;
      assoc = [self->queryParameters objectForKey:key];
      value = [assoc stringValueInComponent:comp];
      [qd setObject:(value != nil ? value : (id)@"") forKey:key];
    }
  }
      
  if ((self->sidInUrl) && ([_ctx hasSession])) {
    sn = [_ctx session];
    [qd setObject:[sn sessionID] forKey:WORequestValueSessionID];
    if (![sn isDistributionEnabled]) {
      [qd setObject:[[WOApplication application] number]
          forKey:WORequestValueInstance];
    }
  }
      
  s = [_ctx directActionURLForActionNamed:daName queryDictionary:qd];
  [_response appendContentString:s];
}

- (void)appendToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  WOComponent *comp;
  NSString    *tmp;
  NSString    *tunselected, *tselected, *tframework;
  NSString    *elID;
  NSArray     *ta;
  NSString    *s;
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  comp = [_ctx component];
  tunselected = [self->unselectedImage stringValueInComponent:comp];
  tselected   = [self->selectedImage   stringValueInComponent:comp];
  tframework  = (self->framework)
    ? [self->framework stringValueInComponent:comp]
    : [comp frameworkName];

  tunselected = [self imageByFilename: tunselected inContext:_ctx
                      framework: tframework];
  tselected   = [self imageByFilename: tselected inContext:_ctx
                      framework: tframework];
  
  elID = [_ctx elementID];
  /* javascript didn't work with #.#.#.# -> replacing to #x#x#x# */
  ta = [[NSArray alloc] initWithArray:[elID componentsSeparatedByString:@"."]];
  elID = [ta componentsJoinedByString:@"x"];
  [ta release];
  
  /* template */
  [self->template appendToResponse:_response inContext:_ctx];

  /* script */
  [_response appendContentString:@"<script type=\"text/javascript\">\n<!--\n"];

  if (![_ctx valueForKey:@"JSImageFlyoverScriptDone"]) {
    tmp = @"var JSImageFlyoverImages = new Array();\n"
          @"function JSImageFlyover(imgName,imgKind) {\n"
          @"  document.images[imgName].src = "
          @"JSImageFlyoverImages[imgName][imgKind].src;\n"
          @"}\n";
    [_response appendContentString:tmp];
    [_ctx takeValue:[NSNumber numberWithBool:YES]
          forKey:@"JSImageFlyoverScriptDone"];
  }

  tmp = @"JSImageFlyoverImages['%@'] = new Array; \n"
        @"JSImageFlyoverImages['%@'][0] = new Image; "
        @"JSImageFlyoverImages['%@'][0].src = '%@'; \n"
        @"JSImageFlyoverImages['%@'][1] = new Image; "
        @"JSImageFlyoverImages['%@'][1].src = '%@'; \n";
  
  s = [[NSString alloc] initWithFormat:tmp,
                          elID, elID, elID, tunselected,
                          elID, elID, tselected];
  [_response appendContentString:s];
  [s release];
  
  [_response appendContentString:@"\n//-->\n</script>"];
  
  /* link containing onMouseOver, onMouseOut and HREF */
  [_response appendContentString:@"<a onmouseover=\"JSImageFlyover('"];
  [_response appendContentString:elID];
  [_response appendContentString:@"',1)\""];
  [_response appendContentString:@" onmouseout=\"JSImageFlyover('"];
  [_response appendContentString:elID];
  [_response appendContentString:@"',0)\""];
  [_response appendContentString:@" href=\""];
  
  if (self->javaScriptFunction) {
    [_response appendContentString:@"javascript:"];
    [_response appendContentHTMLAttributeValue:
                 [self->javaScriptFunction stringValueInComponent:comp]];
  }
  else if (self->directActionName)
    [self appendDirectActionURLToResponse:_response inContext:_ctx];
  else /* component action */
    [_response appendContentString:[_ctx componentActionURL]];
  
  [_response appendContentString:@"\" "];

  if (self->targetWindow) {
    [_response appendContentString:@" target=\""];
    [_response appendContentHTMLAttributeValue:
                 [self->targetWindow stringValueInComponent: comp]];
    [_response appendContentString:@"\" "];
  }
  [_response appendContentString:@" >"];

  /* the image itself */
  
  [_response appendContentString:@"<img border='0' src=\""];
  [_response appendContentString:tunselected];
  [_response appendContentString:@"\" name=\""];
  [_response appendContentString:elID];
  [_response appendContentString:@"\" "];
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  
  [_response appendContentString:
	       (_ctx->wcFlags.xmlStyleEmptyElements ? @" />" : @">")];

  /* close link */
  [_response appendContentString:@"</a>"];
}

@end /* JSImageFlyover */
