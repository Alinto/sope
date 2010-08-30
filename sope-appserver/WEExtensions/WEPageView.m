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

#include <NGObjWeb/WODynamicElement.h>
#include <NGObjWeb/WOContext.h>

/*
  WEPageView
  
  TODO: describe what it does
*/

@interface WEPageView : WODynamicElement
{
  WOAssociation *selection;

  /* config: */
  WOAssociation *titleColor;
  WOAssociation *contentColor;

  WOAssociation *fontColor;
  WOAssociation *fontFace;
  WOAssociation *fontSize;
  
  WOAssociation *firstIcon;
  WOAssociation *firstBlind;    // firstBlindIcon
  WOAssociation *previousIcon;
  WOAssociation *previousBlind; // previousBlindIcon
  WOAssociation *nextIcon;
  WOAssociation *nextBlind;     // nextBlindIcon
  WOAssociation *lastIcon;
  WOAssociation *lastBlind;     // lastBlindIcon

  WOAssociation *firstLabel;
  WOAssociation *previousLabel;
  WOAssociation *nextLabel;
  WOAssociation *lastLabel;
  
  id            template;
}

@end

@interface WEPageItem : WODynamicElement
{
  WOAssociation *key;
  WOAssociation *title;
  WOAssociation *action;
  
  id            template;
}

@end

@interface WEPageItemInfo : NSObject
{
@public
  NSString *title;
  NSString *key;
  NSString *uri;
}
@end

#include <NGObjWeb/WEClientCapabilities.h>
#include "common.h"

// #define DEBUG_TAKEVALUES 1

/* context keys */
static NSString *WEPageView_HEAD      = @"WEPageView_head";
static NSString *WEPageView_BODY      = @"WEPageView_body";
static NSString *WEPageView_KEYS      = @"WEPageView_keys";
static NSString *WEPageView_ACTIVEKEY = @"WEPageView_activekey";
static NSString *WEPageView_COLLECT   = @"~tv~";

// navigation icons
static NSString *WEPageView_first          = @"WEPageView_first";
static NSString *WEPageView_first_blind    = @"WEPageView_first_blind";
static NSString *WEPageView_previous       = @"WEPageView_previous";
static NSString *WEPageView_previous_blind = @"WEPageView_previous_blind";
static NSString *WEPageView_next           = @"WEPageView_next";
static NSString *WEPageView_next_blind     = @"WEPageView_next_blind";
static NSString *WEPageView_last           = @"WEPageView_last";
static NSString *WEPageView_last_blind     = @"WEPageView_last_blind";

// labels
static NSString *WEPageView_firstLabel     = @"WEPageView_firstLabel";
static NSString *WEPageView_previousLabel  = @"WEPageView_previousLabel";
static NSString *WEPageView_nextLabel      = @"WEPageView_nextLabel";
static NSString *WEPageView_lastLabel      = @"WEPageView_lastLabel";

static NSString *WEPageView_               = @"WEPageView_";

@implementation WEPageView

static NSNumber *YesNumber = nil;

+ (void)initialize {
  if (YesNumber == nil) YesNumber = [[NSNumber numberWithBool:YES] retain];
}

+ (int)version {
  return [super version] + 0;
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_subs
{
  if ((self = [super initWithName:_name associations:_config template:_subs])) {
    self->selection      = WOExtGetProperty(_config, @"selection");

    self->contentColor   = WOExtGetProperty(_config, @"contentColor");
    self->titleColor     = WOExtGetProperty(_config, @"titleColor");
    
    self->firstIcon      = WOExtGetProperty(_config, @"firstIcon");
    self->firstBlind     = WOExtGetProperty(_config, @"firstBlindIcon");
    self->previousIcon   = WOExtGetProperty(_config, @"previousIcon");
    self->previousBlind  = WOExtGetProperty(_config, @"previousBlindIcon");
    self->nextIcon       = WOExtGetProperty(_config, @"nextIcon");
    self->nextBlind      = WOExtGetProperty(_config, @"nextBlindIcon");
    self->lastIcon       = WOExtGetProperty(_config, @"lastIcon");
    self->lastBlind      = WOExtGetProperty(_config, @"lastBlindIcon");

    self->firstLabel     = WOExtGetProperty(_config, @"firstLabel");
    self->previousLabel  = WOExtGetProperty(_config, @"previousLabel");
    self->nextLabel      = WOExtGetProperty(_config, @"nextLabel");
    self->lastLabel      = WOExtGetProperty(_config, @"lastLabel");

    self->fontColor      = WOExtGetProperty(_config, @"fontColor");
    self->fontFace       = WOExtGetProperty(_config, @"fontFace");
    self->fontSize       = WOExtGetProperty(_config, @"fontSize");

#define SetAssociationValue(_a_, _value_) \
    if (_a_ == nil) \
      _a_ = [[WOAssociation associationWithValue:_value_] retain];
    
    SetAssociationValue(self->firstLabel,    @"<<");
    SetAssociationValue(self->previousLabel, @"<");
    SetAssociationValue(self->nextLabel,     @">");
    SetAssociationValue(self->lastLabel,     @">>");
           
#undef SetAssociationValue
    
    self->template = [_subs retain];
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->selection);
  
  RELEASE(self->contentColor);
  RELEASE(self->titleColor);

  RELEASE(self->firstIcon);
  RELEASE(self->firstBlind);
  RELEASE(self->previousIcon);
  RELEASE(self->previousBlind);
  RELEASE(self->nextIcon);
  RELEASE(self->nextBlind);
  RELEASE(self->lastIcon);
  RELEASE(self->lastBlind);

  RELEASE(self->firstLabel);
  RELEASE(self->previousLabel);
  RELEASE(self->nextLabel);
  RELEASE(self->lastLabel);

  RELEASE(self->fontColor);
  RELEASE(self->fontFace);
  RELEASE(self->fontSize);
  
  RELEASE(self->template);
  [super dealloc];
}


- (void)updateConfigInContext:(WOContext *)_ctx {
  WOComponent *cmp;
  NSString    *tmp;

  cmp = [_ctx component];

#define SetConfigInContext(_a_, _key_)                                  \
      if (_a_ && (tmp = [_a_ valueInComponent:cmp]))                    \
        [_ctx setObject:tmp forKey:_key_];                              \
    
  SetConfigInContext(self->firstIcon,     WEPageView_first);
  SetConfigInContext(self->firstBlind,    WEPageView_first_blind);
  SetConfigInContext(self->previousIcon,  WEPageView_previous);
  SetConfigInContext(self->previousBlind, WEPageView_previous_blind);
  SetConfigInContext(self->nextIcon,      WEPageView_next);
  SetConfigInContext(self->nextBlind,     WEPageView_next_blind);
  SetConfigInContext(self->lastIcon,      WEPageView_last);
  SetConfigInContext(self->lastBlind,     WEPageView_last_blind);

  SetConfigInContext(self->firstLabel,    WEPageView_firstLabel);
  SetConfigInContext(self->previousLabel, WEPageView_previousLabel);
  SetConfigInContext(self->nextLabel,     WEPageView_nextLabel);
  SetConfigInContext(self->lastLabel,     WEPageView_lastLabel);

#undef SetConfigInContext
}

- (void)removeConfigInContext:(WOContext *)_ctx {
  [_ctx removeObjectForKey:WEPageView_first];
  [_ctx removeObjectForKey:WEPageView_first_blind];
  [_ctx removeObjectForKey:WEPageView_previous];
  [_ctx removeObjectForKey:WEPageView_previous_blind];
  [_ctx removeObjectForKey:WEPageView_next];
  [_ctx removeObjectForKey:WEPageView_next_blind];
  [_ctx removeObjectForKey:WEPageView_last];
  [_ctx removeObjectForKey:WEPageView_last_blind];

  [_ctx removeObjectForKey:WEPageView_firstLabel];
  [_ctx removeObjectForKey:WEPageView_previousLabel];
  [_ctx removeObjectForKey:WEPageView_nextLabel];
  [_ctx removeObjectForKey:WEPageView_lastLabel];
}

static inline NSString *WEPageLabelForKey(NSString *_key, WOContext *_ctx) {
  NSString *key;

  key = [NSString stringWithFormat:@"WEPageView_%@Label", _key];
  return [_ctx objectForKey:key];
}

/* nesting */

- (id)saveNestedStateInContext:(WOContext *)_ctx {
  return nil;
}
- (void)restoreNestedState:(id)_state inContext:(WOContext *)_ctx {
  if (_state == nil) return;
}

- (NSArray *)collectKeysInContext:(WOContext *)_ctx {
  /* collect mode, collects all keys */
  [_ctx setObject:WEPageView_COLLECT forKey:WEPageView_HEAD];

  [self->template appendToResponse:nil inContext:_ctx];
  
  [_ctx removeObjectForKey:WEPageView_HEAD];
  return [_ctx objectForKey:WEPageView_KEYS];
}

/* responder */

- (void)takeValuesFromRequest:(WORequest *)_request inContext:(WOContext *)_ctx {
  id nestedState;
  
  nestedState = [self saveNestedStateInContext:_ctx];

  [_ctx appendElementIDComponent:@"h"];
  [self->template takeValuesFromRequest:_request inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
  
  [_ctx appendElementIDComponent:@"b"];
  [_ctx setObject:self->selection forKey:WEPageView_BODY];

#if DEBUG_TAKEVALUES
  [[_ctx component] debugWithFormat:@"WEPageView: body takes values, eid='%@'",
                    [_ctx elementID]];
#endif
  
  [self->template takeValuesFromRequest:_request inContext:_ctx];
  
  [_ctx removeObjectForKey:WEPageView_BODY];
  [_ctx deleteLastElementIDComponent]; /* 'b' */
  [self restoreNestedState:nestedState inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_request inContext:(WOContext *)_ctx {
  NSString *key;
  id result;

  result = nil;
  if ((key = [_ctx currentElementID])) {
    id nestedState;
    
    nestedState = [self saveNestedStateInContext:_ctx];
    
    if ([key isEqualToString:@"h"]) {
      /* header action */
      
      [_ctx consumeElementID];
      [_ctx appendElementIDComponent:key];
      
      [_ctx setObject:self->selection forKey:WEPageView_HEAD];
      result = [self->template invokeActionForRequest:_request inContext:_ctx];
      [_ctx removeObjectForKey:WEPageView_HEAD];
      
      [_ctx deleteLastElementIDComponent];
    }
    else if ([key isEqualToString:@"b"]) {
      /* body action */
      
      [_ctx consumeElementID];
      [_ctx appendElementIDComponent:key];

      [_ctx setObject:self->selection forKey:WEPageView_BODY];
      
      result = [self->template invokeActionForRequest:_request inContext:_ctx];
      
      [_ctx removeObjectForKey:WEPageView_BODY];
      
      [_ctx deleteLastElementIDComponent];
    }
    else {
      [[_ctx application]
             debugWithFormat:@"unknown page container key '%@'", key];
    }
    
    [self restoreNestedState:nestedState inContext:_ctx];
  }
  return result;
}



- (void)_appendNav:(NSString *)_nav isBlind:(BOOL)_isBlind
  toResponse:(WOResponse *)_response inContext:(WOContext *)_ctx
  info:(WEPageItemInfo *)_info
{
  NSString *img;
  NSString *label;
  BOOL     doForm;
  
  doForm = [_ctx isInForm];
  img = [WEPageView_ stringByAppendingString:_nav];
  img = [img stringByAppendingString:(_isBlind) ? @"_blind" : @""];
  img = [_ctx objectForKey:img];
  img = WEUriOfResource(img,_ctx);
  
  label  = WEPageLabelForKey(_nav, _ctx);

  // append as submit button
  if (doForm && !_isBlind && img && _info) {
    NSString *uri;

    uri = [[_info->uri componentsSeparatedByString:@"/"] lastObject];
    
    [_ctx appendElementIDComponent:_nav];
    [_response appendContentString:@"<input type=\"image\" border=\"0\""];
    [_response appendContentString:@" name=\""];
    [_response appendContentString:uri];
    [_response appendContentString:@"\" src=\""];
    [_response appendContentString:img];
    [_response appendContentString:@"\" alt=\""];
    [_response appendContentString:label];
    if (_ctx->wcFlags.xmlStyleEmptyElements)
      [_response appendContentString:@"\" />"];
    else
      [_response appendContentString:@"\">"];
    [_ctx deleteLastElementIDComponent];
    return;
  }

  /* open anker */
  if (!_isBlind && _info) {
    [_ctx appendElementIDComponent:_nav];
    [_response appendContentString:@"<a href=\""];
    [_response appendContentString:_info->uri];
    [_response appendContentString:@"\">"];
  }
  if (!img) {
    [_response appendContentCharacter:'['];
    [_response appendContentString:label];
    [_response appendContentCharacter:']'];
  }
  else {
    [_response appendContentString:@"<img border=\"0\" src=\""];
    [_response appendContentString:img];
    [_response appendContentString:@"\" alt=\""];
    [_response appendContentString:label];
    if (_ctx->wcFlags.xmlStyleEmptyElements)
      [_response appendContentString:@"\" />"];
    else
      [_response appendContentString:@"\">"];
  }
  /* close anker */
  if (!_isBlind && _info) {
    [_response appendContentString:@"</a>"];
    [_ctx deleteLastElementIDComponent];
  }
}

- (void)appendNavToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  isLeft:(BOOL)_isLeft
  activeKey:(WEPageItemInfo *)_activeKey
  keys:(NSArray *)_keys
{
  WEPageItemInfo *info;
  int idx, cnt;

  idx = [_keys indexOfObject:_activeKey];
  cnt = [_keys count];

  if (idx > cnt) {
    NSLog(@"Warning! WEPageView: idx is out of range!");
    return;
  }

  if (_isLeft) {
    info = (cnt > 0) ? [_keys objectAtIndex:0] : nil;
    [self _appendNav:@"first"     isBlind:(idx < 1) ? YES : NO
          toResponse:_response  inContext:_ctx info:info];

    info = (cnt > 0 && idx > 0) ? [_keys objectAtIndex:idx-1] : nil;
    [self _appendNav:@"previous"   isBlind:(idx < 1) ? YES : NO
          toResponse:_response  inContext:_ctx info:info];
  }
  else {
    info = (cnt > idx+1) ? [_keys objectAtIndex:idx+1] : nil;
    [self _appendNav:@"next"     isBlind:(cnt <= idx+1) ? YES : NO
          toResponse:_response inContext:_ctx info:info];

    info = (cnt > 0) ? [_keys objectAtIndex:cnt-1] : nil;
    [self _appendNav:@"last"     isBlind:(cnt <= idx+1) ? YES : NO
          toResponse:_response inContext:_ctx info:info];
  }
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent    *cmp;
  BOOL           indentContent;
  BOOL           doForm;
  NSString       *bgcolor;
  id             nestedState;
  NSString       *activeKey;
  WEPageItemInfo *activeInfo = nil;
  NSArray        *keys;
  unsigned       i, count;
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  [self updateConfigInContext:_ctx];
  
  doForm        = NO;  /* generate form controls ? */
  indentContent = YES; /* put additional padding table into content */
  cmp           = [_ctx component];
  
  /* check for browser */

  {
    WEClientCapabilities *ccaps;

    ccaps = [[_ctx request] clientCapabilities];
    if ([ccaps isFastTableBrowser] && ![ccaps isTextModeBrowser])
      indentContent = YES;
  }
  
  /* save state */
  
  nestedState = [self saveNestedStateInContext:_ctx];
    
  /* collect & process keys (= available tabs) */

  [_ctx appendElementIDComponent:@"h"];

  activeKey = [self->selection stringValueInComponent:cmp];
  keys      = [self collectKeysInContext:_ctx];
  
  if (![[keys valueForKey:@"key"] containsObject:activeKey])
    /* selection is not available in keys */
    activeKey = nil;
  
  if ((activeKey == nil) && ([keys count] > 0)) {
    /* no or invalid selection, use first key */
    activeKey = [[keys objectAtIndex:0] key];
    if ([self->selection isValueSettable])
      [self->selection setValue:activeKey inComponent:[_ctx component]];
  }
  
  for (i = 0, count = [keys count]; i < count; i++) {
    WEPageItemInfo *info;

    info     = [keys objectAtIndex:i];

    if ([info->key isEqualToString:activeKey]) {
      activeInfo = info;
      break;
    }
  }

  /* start appending */

  [_response appendContentString:
               @"<table border=\"0\" width=\"100%\""
               @" cellpadding=\"0\" cellspacing=\"0\">"];

  /* generate header row */

  bgcolor = [self->titleColor stringValueInComponent:cmp];

  [_response appendContentString:@"<tr>"];

  /* left navigation */
  WEAppendTD(_response, @"left", nil, bgcolor);
  [self appendNavToResponse:_response
        inContext:_ctx
        isLeft:YES
        activeKey:activeInfo
        keys:keys];
  [_response appendContentString:@"</td>"];


  /* title */
  WEAppendTD(_response, @"center", nil, bgcolor);
  {
    unsigned char buf[256];
    NSString *tC, *tF, *tS; // text font attrtibutes
    BOOL     hasFont;
    
    cmp = [_ctx component];
  
    // TODO: use CSS
    tC  = [self->fontColor stringValueInComponent:cmp];
    tF  = [self->fontFace  stringValueInComponent:cmp];
    tS  = [self->fontSize  stringValueInComponent:cmp];

    hasFont = (tC || tF || tS) ? YES : NO;

    if (hasFont)
      WEAppendFont(_response, tC, tF, tS);
  
    for (i = 0, count = [keys count]; i < count; i++) {
      WEPageItemInfo *info;

      info = [keys objectAtIndex:i];

      // TODO: use CSS
      if ([info->key isEqualToString:activeKey]) {
        [_response appendContentString:@"<b>"];
        [_response appendContentString:info->title];
        [_response appendContentString:@"</b>"];
        break;
      }
    }
    // TODO: use CSS
    sprintf((char *)buf, " <small>(%d/%d)</small>", (i + 1), count);
    [_response appendContentCString:buf];
    
    if (hasFont)
      [_response appendContentString:@"</font>"];
  }
  [_response appendContentString:@"</td>"];

  /* right navigation */

  WEAppendTD(_response, @"right", nil, bgcolor);
  [self appendNavToResponse:_response
        inContext:_ctx
        isLeft:NO
        activeKey:activeInfo
        keys:keys];
  [_response appendContentString:@"</td>"];
  
  [_response appendContentString:@"</tr>"];
  [_ctx deleteLastElementIDComponent]; // delete "h"
  [_ctx removeObjectForKey:WEPageView_HEAD];
  
  /* body row */

  bgcolor = [self->contentColor stringValueInComponent:cmp];
  
  {
    [_response appendContentString:@"<tr><td colspan=\"3\""];
    if (bgcolor) {
      [_response appendContentString:@" bgcolor=\""];
      [_response appendContentHTMLAttributeValue:bgcolor];
      [_response appendContentString:@"\""];
    }
    [_response appendContentString:@">"];
    
    if (indentContent) {
      /* start padding table */
      [_response appendContentString:
                   @"<table border=\"0\" width=\"100%\""
                   @" cellpadding=\"10\" cellspacing=\"0\">"];
      [_response appendContentString:@"<tr><td>"];
    }
    
    [_ctx appendElementIDComponent:@"b"];

    /* generate currently active page */
    
    {
      [_ctx setObject:activeKey forKey:WEPageView_BODY];
      [self->template appendToResponse:_response inContext:_ctx];
      [_ctx removeObjectForKey:WEPageView_BODY];
    }
    
    [_ctx deleteLastElementIDComponent];
    
    if (indentContent)
      /* close padding table */
      [_response appendContentString:@"</td></tr></table>"];
    
    [_response appendContentString:@"</td></tr>"];
  }  
  [_response appendContentString:@"</table>"];
  
  [_ctx removeObjectForKey:WEPageView_ACTIVEKEY];
  [_ctx removeObjectForKey:WEPageView_KEYS];
  [self restoreNestedState:nestedState inContext:_ctx];

  [self removeConfigInContext:_ctx];
}

@end /* WEPageView */

@implementation WEPageItem

+ (int)version {
  return [super version] + 0;
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_subs
{
  if ((self = [super initWithName:_name associations:_config template:_subs])) {
    self->key      = WOExtGetProperty(_config, @"key");
    self->title    = WOExtGetProperty(_config, @"title");
    self->action   = WOExtGetProperty(_config, @"action");

    self->template = RETAIN(_subs);
  }
  return self;
}

- (void)dealloc {
  [self->action   release];
  [self->title    release];
  [self->key      release];
  [self->template release];
  [super dealloc];
}

/* responder */

- (void)takeValuesFromRequest:(WORequest *)_request inContext:(WOContext *)_ctx {
  WOAssociation *tmp;
  
  if ((tmp = [_ctx objectForKey:WEPageView_BODY])) {
    NSString *activeTabKey;
    NSString *myTabKey;
    
    activeTabKey = [tmp stringValueInComponent:[_ctx component]];
    myTabKey     = [self->key stringValueInComponent:[_ctx component]];

    if ([activeTabKey isEqualToString:myTabKey]) {
      [_ctx appendElementIDComponent:activeTabKey];

#if DEBUG_TAKEVALUES
      [[_ctx component] debugWithFormat:
                          @"WEPageItem: body takes values, eid='%@'",
                          [_ctx elementID]];
#endif
      
      [self->template takeValuesFromRequest:_request inContext:_ctx];
      [_ctx deleteLastElementIDComponent];
    }
#if DEBUG_TAKEVALUES
    else {
      [[_ctx component] debugWithFormat:
                          @"WEPageItem: body takes no values, eid='%@'",
                          [_ctx elementID]];
    }
#endif
  }
  else {
    NSString *k;
    NSString *eid;

    k = [self->key stringValueInComponent:[_ctx component]];
    
    eid = [[_ctx elementID] stringByAppendingString:@"."];
    eid = [eid stringByAppendingString:k];
    
    if (k && [_request formValueForKey:[eid stringByAppendingString:@".x"]]) {
      [_ctx addActiveFormElement:self];
      [_ctx setRequestSenderID:eid];
    }
  }
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  NSString      *tabkey;
  id            result;
  WOAssociation *tmp;

  tabkey = [_ctx currentElementID];
  [_ctx consumeElementID];
  [_ctx appendElementIDComponent:tabkey];
  
  if ((tmp = [_ctx objectForKey:WEPageView_HEAD])) {
    /* click on tab icon */
    if ([tmp isValueSettable])
      [tmp setValue:tabkey inComponent:[_ctx component]];
    
    result = [self->action valueInComponent:[_ctx component]];
  }
  else if ((tmp = [_ctx objectForKey:WEPageView_BODY])) {
    /* clicked somewhere in the body */
    if ([tmp isValueSettable])
      [tmp setValue:tabkey inComponent:[_ctx component]];
    
    result = [self->template invokeActionForRequest:_rq inContext:_ctx];
  }
  else {
    [[_ctx component] debugWithFormat:@"WEPageItem: invalid invoke state"];
    result = [self->template invokeActionForRequest:_rq inContext:_ctx];
  }
  
  [_ctx deleteLastElementIDComponent];
  return result;
}

- (void)appendHead:(NSString *)tmp 
  toResponse:(WOResponse *)_response inContext:(WOContext *)_ctx 
{
  NSMutableArray *keys;
  WEPageItemInfo *info;
  WOComponent    *cmp;
  NSString *k;
  
  if (![tmp isEqual:WEPageView_COLLECT])
    return;
  
  /* collect keys */

  cmp  = [_ctx component];
  keys = [_ctx objectForKey:WEPageView_KEYS];
  if (keys == nil) {
    keys = [NSMutableArray arrayWithCapacity:8];
    [_ctx setObject:keys forKey:WEPageView_KEYS];
  }
  
  if ((k = [self->key stringValueInComponent:[_ctx component]]) == nil) {
    /* auto-assign a key */
    char kb[16];
#if GS_64BIT_OLD
    sprintf(kb, "%d", [keys count]);
#else
    sprintf(kb, "%ld", [keys count]);
#endif
    k = [NSString stringWithCString:kb];
  }
  [_ctx appendElementIDComponent:k];
      
  info = [[WEPageItemInfo alloc] init];
  info->key      = [k copy];
  info->title    = [[self->title stringValueInComponent:cmp] copy];
  info->uri      = [[_ctx componentActionURL] copy];
      
  [keys addObject:info];
  [info release];
  
  [_ctx deleteLastElementIDComponent];
}

- (void)appendBody:(NSString *)tmp 
  toResponse:(WOResponse *)_response inContext:(WOContext *)_ctx 
{
  NSString *k;
  
  k = [self->key stringValueInComponent:[_ctx component]];
  if (![tmp isEqualToString:k])
    return;
  
  /* content is active or used as layer*/
  [_ctx appendElementIDComponent:k];
#if DEBUG
  [self debugWithFormat:@"PAGE: %@", k];
#endif
  [self->template appendToResponse:_response inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *tmp;
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  if ((tmp = [_ctx objectForKey:WEPageView_HEAD]))
    [self appendHead:tmp toResponse:_response inContext:_ctx];
  else if ((tmp = [_ctx objectForKey:WEPageView_BODY]))
    [self appendBody:tmp toResponse:_response inContext:_ctx];
  else
    [_response appendContentString:@"[invalid pageview state]"];
}

@end /* WEPageItem */

@implementation WEPageItemInfo

- (void)dealloc {
  [self->uri   release];
  [self->title release];
  [self->key   release];
  [super dealloc];
}

- (NSString *)key {
  return self->key;
}
- (NSString *)title {
  return self->title;
}
- (NSString *)uri {
  return self->uri;
}

@end /* WEPageItemInfo */
