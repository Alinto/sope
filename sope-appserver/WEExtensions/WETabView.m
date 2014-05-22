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

#include "WETabView.h"
#include <NGObjWeb/WEClientCapabilities.h>
#include "common.h"

#if DEBUG
// #  define DEBUG_TAKEVALUES 1
#  define DEBUG_JS 1
#endif

/* context keys */
NSString *WETabView_HEAD      = @"WETabView_head";
NSString *WETabView_BODY      = @"WETabView_body";
NSString *WETabView_KEYS      = @"WETabView_keys";
NSString *WETabView_SCRIPT    = @"WETabView_script";
NSString *WETabView_ACTIVEKEY = @"WETabView_activekey";
NSString *WETabView_COLLECT   = @"~tv~";

@implementation WETabView

static NSNumber *YesNumber;

+ (void)initialize {
  if (YesNumber == nil)
    YesNumber = [[NSNumber numberWithBool:YES] retain];
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->selection          = WOExtGetProperty(_config, @"selection");
    
    self->bgColor            = WOExtGetProperty(_config, @"bgColor");
    self->nonSelectedBgColor = WOExtGetProperty(_config,@"nonSelectedBgColor");
    self->leftCornerIcon     = WOExtGetProperty(_config, @"leftCornerIcon");
    self->rightCornerIcon    = WOExtGetProperty(_config, @"rightCornerIcon");

    self->tabIcon            = WOExtGetProperty(_config, @"tabIcon");
    self->leftTabIcon        = WOExtGetProperty(_config, @"leftTabIcon");
    self->selectedTabIcon    = WOExtGetProperty(_config, @"selectedTabIcon");

    self->asBackground       = WOExtGetProperty(_config, @"asBackground");
    self->width              = WOExtGetProperty(_config, @"width");
    self->height             = WOExtGetProperty(_config, @"height");
    self->activeBgColor      = WOExtGetProperty(_config, @"activeBgColor");
    self->inactiveBgColor    = WOExtGetProperty(_config, @"inactiveBgColor");

    self->fontColor          = WOExtGetProperty(_config, @"fontColor");
    self->fontSize           = WOExtGetProperty(_config, @"fontSize");
    self->fontFace           = WOExtGetProperty(_config, @"fontFace");
    
    self->disabledTabKeys = WOExtGetProperty(_config, @"disabledTabKeys");

    self->template = [_t retain];
  }
  return self;
}

- (void)dealloc {
  [self->disabledTabKeys    release];
  [self->selection          release];
  [self->bgColor            release];
  [self->nonSelectedBgColor release];
  [self->leftCornerIcon  release];
  [self->rightCornerIcon release];
  [self->leftTabIcon     release];
  [self->selectedTabIcon release];
  [self->tabIcon         release];
  [self->width           release];
  [self->height          release];
  [self->activeBgColor   release];
  [self->inactiveBgColor release];
  [self->fontColor       release];
  [self->fontSize        release];
  [self->fontFace        release];
  [self->template        release];
  [super dealloc];
}

/* nesting */

- (id)saveNestedStateInContext:(WOContext *)_ctx {
  return nil;
}
- (void)restoreNestedState:(id)_state inContext:(WOContext *)_ctx {
  if (_state == nil) return;
}

- (NSArray *)filterKeys:(NSArray *)_keys inContext:(WOContext *)_ctx {
  NSMutableArray *ma;
  NSArray  *rkeys;
  unsigned i, count;
  
  if (self->disabledTabKeys == nil || _keys == nil)
    return _keys;
  
  rkeys = [self->disabledTabKeys valueInComponent:[_ctx component]];
  if (rkeys == nil || (count = [rkeys count]) == 0)
    return _keys;
  
  ma = [[_keys mutableCopy] autorelease];
  for (i = 0; i < count; i++) {
    unsigned j, jc;
    
    // TODO: not particulary efficient, but should be OK ... */
    for (j = 0, jc = [ma count]; j < jc; j++) {
      WETabItemInfo *info;
      
      info = [ma objectAtIndex:j];
      if (![info->key isEqualToString:[rkeys objectAtIndex:i]])
	continue;
      
      [ma removeObjectAtIndex:j];
    }
  }
  
  return ma;
}

- (NSArray *)collectKeysInContext:(WOContext *)_ctx {
  NSArray *keys;
  
  /* collect mode, collects all keys */
  [_ctx setObject:WETabView_COLLECT forKey:WETabView_HEAD];
  [self->template appendToResponse:nil inContext:_ctx];
  [_ctx removeObjectForKey:WETabView_HEAD];
  
  keys = [_ctx objectForKey:WETabView_KEYS];

  /* filter keys */
  keys = [self filterKeys:keys inContext:_ctx];
  
  return keys;
}

/* responder */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  id       nestedState;
  NSString *activeTabKey;
  
  activeTabKey = [self->selection stringValueInComponent:[_ctx component]];
  
  nestedState = [self saveNestedStateInContext:_ctx];
  [_ctx appendElementIDComponent:@"b"];
  [_ctx appendElementIDComponent:activeTabKey];
  
  [_ctx setObject:activeTabKey forKey:WETabView_BODY];
  
#if DEBUG_TAKEVALUES
  [[_ctx component] debugWithFormat:@"WETabView: body takes values, eid='%@'",
                    [_ctx elementID]];
#endif
  
  [self->template takeValuesFromRequest:_req inContext:_ctx];
  
  [_ctx removeObjectForKey:WETabView_BODY];
  [_ctx deleteLastElementIDComponent]; // activeKey
  [_ctx deleteLastElementIDComponent]; /* 'b' */
  [self restoreNestedState:nestedState inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  NSString *key;
  id       result;
  id       nestedState;
  
  if ((key = [_ctx currentElementID]) == nil)
    return nil;
  
  result      = nil;
  nestedState = [self saveNestedStateInContext:_ctx];
    
  if ([key isEqualToString:@"h"]) {
    /* header action */
    //NSString *urlKey;
    
    [_ctx consumeElementID];
    [_ctx appendElementIDComponent:@"h"];
#if 0
    if ((urlKey = [_ctx currentElementID]) == nil) {
      [[_ctx application]
             debugWithFormat:@"missing active head tab key !"];
    }
    else {
      //NSLog(@"clicked: %@", urlKey);
      [_ctx consumeElementID];
      [_ctx appendElementIDComponent:urlKey];
    }
#endif
    
    [_ctx setObject:self->selection forKey:WETabView_HEAD];
    result = [self->template invokeActionForRequest:_req inContext:_ctx];
    [_ctx removeObjectForKey:WETabView_HEAD];

#if 0
    if (urlKey)
      [_ctx deleteLastElementIDComponent]; // active key
#endif
    [_ctx deleteLastElementIDComponent]; // 'h'
  }
  else if ([key isEqualToString:@"b"]) {
    /* body action */
    NSString *activeTabKey, *urlKey;
    
    [_ctx consumeElementID];
    [_ctx appendElementIDComponent:@"b"];
      
    if ((urlKey = [_ctx currentElementID]) == nil) {
      [[_ctx application]
             debugWithFormat:@"missing active body tab key !"];
    }
    else {
      //NSLog(@"clicked: %@", urlKey);
      [_ctx consumeElementID];
      [_ctx appendElementIDComponent:urlKey];
    }
    
    activeTabKey = [self->selection stringValueInComponent:[_ctx component]];
    [_ctx setObject:activeTabKey forKey:WETabView_BODY];
    
    result = [self->template invokeActionForRequest:_req inContext:_ctx];
      
    [_ctx removeObjectForKey:WETabView_BODY];

    if (urlKey)
      [_ctx deleteLastElementIDComponent]; // active key
    [_ctx deleteLastElementIDComponent]; // 'b'
  }
  else {
    [[_ctx application]
           debugWithFormat:@"unknown tab container key '%@'", key];
  }
    
  [self restoreNestedState:nestedState inContext:_ctx];
  return result;
}

- (NSString *)_tabViewCountInContext:(WOContext *)_ctx {
  int count;
  count = [[_ctx valueForKey:@"WETabViewScriptDone"] intValue];
  return [NSString stringWithFormat:@"%d",count];
}

- (NSString *)scriptHref:(WETabItemInfo *)_info
  inContext:(WOContext *)_ctx
  isLeft:(BOOL)_isLeft
  keys:(NSArray *)_keys
{
  NSMutableString *result = [NSMutableString string];
  WETabItemInfo *tmp;
  NSString       *activeKey;
  int            i, cnt;
  NSString       *elID;
  NSString       *tstring;
  
  activeKey = [self->selection stringValueInComponent:[_ctx component]];
  [result appendString:@"JavaScript:showTab("];
  [result appendString:_info->key];
  [result appendString:@"Tab);"];
  
  [result appendString:@"swapCorners("];
  tstring = (!_isLeft)
    ? @"tabCorner%@,tabCornerLeft%@);"
    : @"tabCornerLeft%@,tabCorner%@);";
  elID = [self _tabViewCountInContext:_ctx];
  [result appendString:[NSString stringWithFormat:tstring,elID,elID]];
  
  for (i=0, cnt = [_keys count]; i < cnt; i++) {
    tmp = [_keys objectAtIndex:i];

    if ((tmp->isScript || [tmp->key isEqualToString:activeKey])
        && ![tmp->key isEqualToString:_info->key]) {
      [result appendString:@"hideTab("];
      [result appendString:tmp->key];
      [result appendString:@"Tab);"];
    }
  }
  return result;
}

- (void)appendLink:(WETabItemInfo *)_info
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  isActive:(BOOL)_isActive isLeft:(BOOL)_isLeft
  doScript:(BOOL)_doScript keys:(NSArray *)_keys
{
  BOOL        doBgIcon;
  BOOL        doImages;
  NSString    *headUri    = nil;
  NSString    *imgUri     = nil;
  NSString    *label      = nil;
  NSString    *bgcolor    = nil;
  NSString    *w          = nil;
  NSString    *h          = nil;
  NSString    *scriptHref = nil;
  WOComponent *comp;

  doImages = ![[[_ctx request] clientCapabilities] isTextModeBrowser];

  comp = [_ctx component];
  headUri = _info->uri;

  if (_info->asBackground == 0)
    doBgIcon = [self->asBackground boolValueInComponent:comp];
  else
    doBgIcon = (_info->asBackground == 1) ? YES : NO;
  
  if ((label = _info->label) == nil)
    label = _info->key;
  
  if (doImages) {
    /* lookup image */
    NSString *imgName = nil;
    
    if (_isActive) {
      imgName = _info->selIcon;  // selectedTabIcon
      if (imgName == nil)
        imgName = [self->selectedTabIcon stringValueInComponent:comp];
    }
    else if (_isLeft) {
      imgName = _info->leftIcon; // leftTabIcon
      if (imgName == nil)
        imgName = [self->leftTabIcon stringValueInComponent:comp];
    }
    else {
      imgName = _info->tabIcon;  // tabIcon
      if (imgName == nil)
        imgName = [self->tabIcon stringValueInComponent:comp];
    }

    if (imgName == nil) {
      imgName = _info->icon;
    }

    imgUri = WEUriOfResource(imgName, _ctx);
    
    if (![imgUri isNotEmpty])
      doImages = NO;
  }

  if (_isActive) {
    bgcolor = (_info->activeBg)
      ? _info->activeBg
      : [self->activeBgColor stringValueInComponent:comp];
  }
  else {
    bgcolor = (_info->inactiveBg)
      ? _info->inactiveBg
      : [self->inactiveBgColor stringValueInComponent:comp];
  }
  
  w  = (_info->width)
    ? _info->width
    : [self->width stringValueInComponent:comp];
  h  = (_info->height)
    ? _info->height
    : [self->height stringValueInComponent:comp];
  
  [_response appendContentString:@"<td align='center' valign='middle'"];
  
  if (w != nil) {
    [_response appendContentString:@" width='"];
    [_response appendContentHTMLAttributeValue:w];
    [_response appendContentCharacter:'\''];
  }
  if (h != nil) {
    [_response appendContentString:@" height='"];
    [_response appendContentHTMLAttributeValue:h];
    [_response appendContentCharacter:'\''];
  }
  if (bgcolor != nil) {
    [_response appendContentString:@" bgcolor='"];
    [_response appendContentHTMLAttributeValue:bgcolor];
    [_response appendContentCharacter:'\''];
  }
  if (doBgIcon && doImages) {
    WEClientCapabilities *ccaps;
  
    ccaps = [[_ctx request] clientCapabilities];
    
    [_response appendContentString:@" background='"];
    [_response appendContentHTMLAttributeValue:imgUri];
    [_response appendContentCharacter:'\''];

    // click on td background
    if ([ccaps isInternetExplorer] && [ccaps isJavaScriptBrowser]) {
      [_response appendContentString:@" onclick=\"window.location.href='"];
       [_response appendContentHTMLAttributeValue:headUri];
      [_response appendContentString:@"'\""];
    }
  }
  
  [_response appendContentCharacter:'>'];
  
  if (!doImages) [_response appendContentString:@"["];
  
  [_response appendContentString:@"<a style=\"text-decoration:none;\" href=\""];

  if (_doScript && doImages && (_info->isScript || _isActive)) {
    scriptHref =
      [self scriptHref:_info inContext:_ctx isLeft:_isLeft keys:_keys];
    [_response appendContentHTMLAttributeValue:scriptHref];
  }
  else {
    [_response appendContentHTMLAttributeValue:headUri];
  }
  
  [_response appendContentString:@"\" "];
  [_response appendContentString:
               [NSString stringWithFormat:@"name='%@TabLink'", _info->key]];
  [_response appendContentString:@">"];
  
  if (!doImages && _isActive)
    [_response appendContentString:@"<b>"];
  
  if (doImages && !doBgIcon) {
    [_response appendContentString:@"<img border='0' src='"];
    [_response appendContentString:imgUri];
    [_response appendContentString:@"' name='"];
    [_response appendContentString:_info->key];
    [_response appendContentString:@"TabImg' alt='"];
    [_response appendContentHTMLAttributeValue:label];
    [_response appendContentString:@"' title='"];
    [_response appendContentHTMLAttributeValue:label];
    [_response appendContentString:@"'"];
    if (_ctx->wcFlags.xmlStyleEmptyElements)
      [_response appendContentString:@" />"];
    else
      [_response appendContentString:@">"];
  }
  else {
    NSString *fc     = [self->fontColor stringValueInComponent:comp];
    NSString *fs     = [self->fontSize  stringValueInComponent:comp];
    NSString *ff     = [self->fontFace  stringValueInComponent:comp];
    BOOL     hasFont;
    
    hasFont = (fc || fs || ff) ? YES : NO;
    
    if (![label isNotEmpty])
      label = _info->key;
    [_response appendContentString:@"<nobr>"];
    if (hasFont) WEAppendFont(_response, fc, ff, fs);           // <font>
    
    if (_isActive) [_response appendContentString:@"<b>"];
    [_response appendContentHTMLString:label];
    if (_isActive) [_response appendContentString:@"</b>"];
    
    if (hasFont) [_response appendContentString:@"</font>"];    // </font>
    [_response appendContentString:@"</nobr>"];
  }
  
  if (!doImages && _isActive)
    [_response appendContentString:@"</b>"];
  
  [_response appendContentString:@"</a>"];
  if (!doImages) [_response appendContentString:@"]"];


  [_response appendContentString:@"</td>"];
  
  if (_doScript && doImages && (_info->isScript || _isActive)) {
    NSString *k; // key 
    NSString *s; // selected   tab icon
    NSString *u; // unselected tab icon
    //NSString *out;

    k = _info->key;
    s = _info->selIcon; // selectedTabIcon
    u = (_isLeft) ? _info->leftIcon : _info->tabIcon;
    
    s = WEUriOfResource(s, _ctx);
    u = WEUriOfResource(u, _ctx);

    s = (![s isNotEmpty]) ? imgUri : s;
    u = (![u isNotEmpty]) ? imgUri : u;
    
#if 0
    out = [NSString alloc];
    out = [out initWithFormat:
                    @"<script language=\"JavaScript\">\n"
                    @"<!--\n"
                    @"var %@Tab = new Array();\n"
                    @"%@Tab[\"link\"] = %@TabLink;\n"
                    @"%@Tab[\"href1\"] = \"%@\";\n"
                    @"%@Tab[\"href2\"] = \"%@\";\n"
                    @"%@Tab[\"Img\"] = window.document.%@TabImg;\n"
                    @"%@Tab[\"Ar\"]  = new Array();\n"
                    @"%@Tab[\"Ar\"][0] = new Image();\n"
                    @"%@Tab[\"Ar\"][0].src = \"%@\";\n"
                    @"%@Tab[\"Ar\"][1] = new Image();\n"
                    @"%@Tab[\"Ar\"][1].src = \"%@\";\n"
                    @"//-->\n</script>",
                    k, k, k, k, scriptHref, k, headUri,
                    k, k, k, k,
                    k, u, k, k, s
                    ];
 
    [_response appendContentString:out];
    RELEASE(out);
#else
#  define _appendStr_(_str_) [_response appendContentString:_str_]
    _appendStr_(@"<script language=\"JavaScript\">\n<!--\nvar ");
    _appendStr_(k); _appendStr_(@"Tab = new Array();\n");

    _appendStr_(k); _appendStr_(@"Tab[\"link\"] = ");
    _appendStr_(k); _appendStr_(@"TabLink;\n");   // linkName
      
    _appendStr_(k); _appendStr_(@"Tab[\"href1\"] = \"");
    _appendStr_(scriptHref); _appendStr_(@"\";\n"); // scriptHref

    _appendStr_(k); _appendStr_(@"Tab[\"href2\"] = \"");
    _appendStr_(_info->uri); _appendStr_(@"\";\n"); // actionHref
      
    _appendStr_(k); _appendStr_(@"Tab[\"Img\"] = window.document.");
    _appendStr_(k); _appendStr_(@"TabImg;\n");
    _appendStr_(k); _appendStr_(@"Tab[\"Ar\"]  = new Array();\n");
    _appendStr_(k); _appendStr_(@"Tab[\"Ar\"][0] = new Image();\n");
    _appendStr_(k); _appendStr_(@"Tab[\"Ar\"][0].src = \"");
    _appendStr_(u); _appendStr_(@"\";\n");  // unselected img
    _appendStr_(k); _appendStr_(@"Tab[\"Ar\"][1] = new Image();\n");
    _appendStr_(k); _appendStr_(@"Tab[\"Ar\"][1].src = \"");
    _appendStr_(s); _appendStr_(@"\";\n");  // selected img
    _appendStr_(@"//-->\n</script>");
#undef _appendStr_
#endif
  }
}

- (void)appendSubmitButton:(WETabItemInfo *)_info
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  isActive:(BOOL)_isActive isLeft:(BOOL)_left
  doScript:(BOOL)_doScript   keys:(NSArray *)_keys
{
  [self appendLink:_info
        toResponse:_response
        inContext:_ctx
        isActive:_isActive isLeft:_left
        doScript:_doScript   keys:_keys];
}

- (void)_appendTabViewJSScriptToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  [_response appendContentString:
               @"<script language=\"JavaScript\">\n<!--\n\n"
               @"function showTab(obj) {\n"
#if DEBUG_JS
               @"  if (obj==null) { alert('missing tab obj ..'); return; }\n"
               @"  if (obj['Div']==null) {"
               @"    alert('missing div key in ' + obj); return; }\n"
               @"  if (obj['Div'].style==null) {"
               @"    alert('missing style key in div ' + obj['Div']);return; }\n"
#endif
               @"  obj['Div'].style.display = \"\";\n"
               @"  obj['Img'].src = obj[\"Ar\"][1].src;\n"
               @"  obj['link'].href = obj[\"href2\"];\n"
               @"}\n"
               @"function hideTab(obj) {\n"
#if DEBUG_JS
               @"  if (obj==null) { alert('missing tab obj ..'); return; }\n"
               @"  if (obj['Div']==null) {"
               @"    alert('missing div key in ' + obj); return; }\n"
               @"  if (obj['Div'].style==null) {"
               @"    alert('missing style key in div ' + obj['Div']);return; }\n"
#endif
               @" obj['Div'].style.display = \"none\";\n"
               @" obj['Img'].src = obj[\"Ar\"][0].src;\n"
               @" obj['link'].href = obj[\"href1\"];\n"
               @"}\n"
               @"function swapCorners(obj1,obj2) {\n"
               @"   if (obj1==null) { alert('missing corner 1'); return; }\n"
               @"   if (obj2==null) { alert('missing corner 2'); return; }\n"
               @"   obj1.style.display = \"none\";\n"
               @"   obj2.style.display = \"\";\n"
               @"}\n"
               @"//-->\n</script>"];
}

- (void)_appendHeaderRowToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  keys:(NSArray *)keys activeKey:(NSString *)activeKey
  doScript:(BOOL)doScript
{
  unsigned i, count;
  BOOL doForm;
  
  doForm = NO;  /* generate form controls ? */
  
  [_response appendContentString:@"<tr><td colspan='2'>"];
  [_response appendContentString:
               @"<table border='0' cellpadding='0' cellspacing='0'><tr>"];
  
  for (i = 0, count = [keys count]; i < count; i++) {
    WETabItemInfo *info;
    NSString       *key;
    BOOL           isActive;
    
    info     = [keys objectAtIndex:i];
    key      = info->key;
    isActive = [key isEqualToString:activeKey];
    
    [_ctx appendElementIDComponent:key];
    
    if (doForm) {
      /* tab is inside of a FORM, so produce submit buttons */
      [self appendSubmitButton:info
            toResponse:_response
            inContext:_ctx
            isActive:isActive
            isLeft:(i == 0) ? YES : NO
            doScript:doScript
            keys:keys];
    }
    else {
      /* tab is not in a FORM, generate hyperlinks for tab */
      [self appendLink:info
            toResponse:_response
            inContext:_ctx
            isActive:isActive
            isLeft:(i == 0) ? YES : NO
            doScript:doScript
            keys:keys];
    }
    
    [_ctx deleteLastElementIDComponent];
  }
  //  [_response appendContentString:@"<td></td>"];
  [_response appendContentString:@"</tr></table>"];
  [_response appendContentString:@"</td></tr>"];
}

- (void)_appendHeaderFootRowToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  bgcolor:(NSString *)bgcolor
  doScript:(BOOL)doScript
  isLeftActive:(BOOL)isLeftActive
{
  [_response appendContentString:@"  <tr"];
  if (bgcolor) {
    [_response appendContentString:@" bgcolor=\""];
    [_response appendContentHTMLAttributeValue:bgcolor];
    [_response appendContentString:@"\""];
  }
  [_response appendContentString:@">"];
    
  /* left corner */
  [_response appendContentString:@"    <td align=\"left\" width=\"10\">"];
  
  if (doScript) {
    [_response appendContentString:@"<div id=\"tabCorner"];
    [_response appendContentString:[self _tabViewCountInContext:_ctx]];
    [_response appendContentString:@"\" "];
    [_response appendContentString:@"style=\"display: "];
    [_response appendContentString:(isLeftActive) ? @"" : @"none"];
    [_response appendContentString:@";\">"];
    [_response appendContentString:@"&nbsp;"];
    [_response appendContentString:@"</div>"];
  }
  else if (isLeftActive)
    [_response appendContentString:@"&nbsp;"];
  
  if (doScript) {
    [_response appendContentString:@"<div id=\"tabCornerLeft"];
    [_response appendContentString:[self _tabViewCountInContext:_ctx]];
    [_response appendContentString:@"\" "];
    [_response appendContentString:@"style=\"display: "];
    [_response appendContentString:(!isLeftActive) ? @"visible" : @"none"];
    [_response appendContentString:@";\">"];
  }
  
  if (!isLeftActive || doScript) {
    NSString *uri;
    
    uri = [self->leftCornerIcon stringValueInComponent:[_ctx component]];
    if ((uri = WEUriOfResource(uri, _ctx))) {
      [_response appendContentString:@"<img border=\"0\" alt=\"\" src=\""];
      [_response appendContentString:uri];
      [_response appendContentString:@"\" />"];
    }
    else
      [_response appendContentString:@"&nbsp;"];
  }
  if (doScript)
    [_response appendContentString:@"</div>"];

  [_response appendContentString:@"</td>"];

  /* right corner */
  [_response appendContentString:@"    <td align=\"right\">"];
  {
    NSString *uri;
      
    uri = [self->rightCornerIcon stringValueInComponent:[_ctx component]];
    if ((uri = WEUriOfResource(uri, _ctx))) {
      [_response appendContentString:@"<img border=\"0\" alt=\"\" src=\""];
      [_response appendContentString:uri];
      if (_ctx->wcFlags.xmlStyleEmptyElements)
	[_response appendContentString:@"\" />"];
      else
	[_response appendContentString:@"\">"];
    }
    else
      [_response appendContentString:@"&nbsp;"];
  }
  [_response appendContentString:@"</td>"];
    
  [_response appendContentString:@"  </tr>"];
}

- (void)_appendBodyRowToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  bgcolor:(NSString *)bgcolor
  activeKey:(NSString *)activeKey
{
  WEClientCapabilities *ccaps;
  BOOL indentContent;
  
  ccaps = [[_ctx request] clientCapabilities];
  
  /* put additional padding table into content ??? */
  indentContent = [ccaps isFastTableBrowser] && ![ccaps isTextModeBrowser];
  
  [_response appendContentString:@"<tr><td colspan='2'"];
  
  if (bgcolor) {
    [_response appendContentString:@" bgcolor=\""];
    [_response appendContentHTMLAttributeValue:bgcolor];
    [_response appendContentString:@"\""];
  }
  [_response appendContentString:@">"];
    
  if (indentContent) { // TODO: we can now replace that with CSS padding?
    /* start padding table */
    [_response appendContentString:
               @"<table border='0' width='100%'"
               @" cellpadding='10' cellspacing='0'>"];
    [_response appendContentString:@"<tr><td>"];
  }
    
  [_ctx appendElementIDComponent:@"b"];
  [_ctx appendElementIDComponent:activeKey];
  
  /* generate currently active body */
  {
    [_ctx setObject:activeKey forKey:WETabView_BODY];
    [self->template appendToResponse:_response inContext:_ctx];
    [_ctx removeObjectForKey:WETabView_BODY];
  }
  
  [_ctx deleteLastElementIDComponent]; // activeKey
  [_ctx deleteLastElementIDComponent]; // 'b'
    
  if (indentContent)
    /* close padding table */
    [_response appendContentString:@"</td></tr></table>"];
    
  [_response appendContentString:@"</td></tr>"];
}

- (BOOL)isLeftActiveInKeys:(NSArray *)keys activeKey:(NSString *)activeKey{
  unsigned i, count;
  BOOL isLeftActive;
  
  isLeftActive = NO;
  
  for (i = 0, count = [keys count]; i < count; i++) {
    WETabItemInfo *info;
    
    info = [keys objectAtIndex:i];
    
    if ((i == 0) && [info->key isEqualToString:activeKey])
      isLeftActive = YES;
  }
  
  return isLeftActive;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  /*
    generates a table with three rows:
    - a row with the tabs
    - a row for round edges
    - a row for the content
  */
  WOComponent  *cmp;
  NSString     *bgcolor;
  BOOL         isLeftActive;
  BOOL         doScript;
  id           nestedState;
  NSString     *activeKey;
  NSArray      *keys;
  int          tabViewCount; /* used for image id's and writing script once */
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  doScript      = NO;  /* perform tab-clicks on browser (use javascript) */
  tabViewCount  = [[_ctx objectForKey:@"WETabViewScriptDone"] intValue];
  cmp           = [_ctx component];
  
  /* check for browser */
  {
    WEClientCapabilities *ccaps;
    //BOOL isJavaScriptBrowser;
    
    ccaps    = [[_ctx request] clientCapabilities];
    doScript = [ccaps isInternetExplorer] && [ccaps isJavaScriptBrowser]; 
    if ([_ctx hasSession]) {
      WOSession *sn;
      
      sn = [cmp session];
      doScript = (doScript &&
		  [[sn valueForKey:@"isJavaScriptEnabled"] boolValue]);
    }
  }

  /* disable javascript */
  doScript = NO;
  
  /* save state */
  
  nestedState = [self saveNestedStateInContext:_ctx];
  
  /* configure */
  
  activeKey = [self->selection stringValueInComponent:cmp];
  
  bgcolor = [self->bgColor stringValueInComponent:cmp];
  bgcolor = [bgcolor stringValue];
  
  [_ctx appendElementIDComponent:@"h"];
  
  /* collect & process keys (= available tabs) */
  
  keys = [self collectKeysInContext:_ctx];
  
  if (![[keys valueForKey:@"key"] containsObject:activeKey])
    /* selection is not available in keys */
    activeKey = nil;
  
  if ((activeKey == nil) && ([keys count] > 0)) {
    /* no or invalid selection, use first key */
    activeKey = [[keys objectAtIndex:0] key];
    if ([self->selection isValueSettable])
      [self->selection setValue:activeKey inComponent:[_ctx component]];
  }

  if (doScript) {
    doScript = [[keys valueForKey:@"isScript"] containsObject:YesNumber];
    [_ctx setObject:[NSNumber numberWithBool:doScript]
          forKey:WETabView_SCRIPT];
  }

  /* start appending */
  
  if ((doScript) && (tabViewCount == 0))
    [self _appendTabViewJSScriptToResponse:_response inContext:_ctx];
  
  /* count up for unique tabCorner/tabCornerLeft images */
  [_ctx takeValue:[NSNumber numberWithInt:(tabViewCount + 1)]
        forKey:@"WETabViewScriptDone"];

  // TODO: add CSS class for table
  [_response appendContentString:
               @"<table border='0' width='100%'"
               @" cellpadding='0' cellspacing='0'>"];
  
  /* find out whether left is active */
  
  isLeftActive = [self isLeftActiveInKeys:keys activeKey:activeKey];
  
  /* generate header row */
  
  [self _appendHeaderRowToResponse:_response inContext:_ctx
        keys:keys activeKey:activeKey
        doScript:doScript];
  
  [_ctx deleteLastElementIDComponent]; // 'h' for head
  [_ctx removeObjectForKey:WETabView_HEAD];
  
  /* header foot row */
  
  [self _appendHeaderFootRowToResponse:_response inContext:_ctx
        bgcolor:bgcolor
        doScript:doScript
        isLeftActive:isLeftActive];
  
  /* body row */
  
  [self _appendBodyRowToResponse:_response inContext:_ctx
        bgcolor:bgcolor
        activeKey:activeKey];
  
  /* close table */
  
  [_response appendContentString:@"</table>"];
  [_ctx removeObjectForKey:WETabView_ACTIVEKEY];
  [_ctx removeObjectForKey:WETabView_KEYS];
  [self restoreNestedState:nestedState inContext:_ctx];
}

@end /* WETabView */
