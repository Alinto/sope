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

/*
  WETreeDate

  Take a look at WETreeView for more information.

  WETreeData associations:
    isTreeElement
    icon
    cornerIcon
    title
    string
    treeLink (do not generate a -componentActionURL but use the specified link)

  Example:
      TreeDataCell: WETreeData {
        isTreeElement = YES; // this is a tree cell (that means, it has plus
                             // and minus icons and all that stuff)
      }
      DataCell: WETreeData {
        isTreeElement = NO;  // this is NOT a  tree cell, i.e. it does NOT
                             // have any plus or minus icons. (This is just a
                             // ordinary <td></td>!!!)
      }
*/

#include <NGObjWeb/WODynamicElement.h>

@interface WETreeData : WODynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  WOAssociation *isTreeElement;
  WOAssociation *title;
  WOAssociation *string;
  WOAssociation *icon;
  WOAssociation *cornerIcon;
  WOAssociation *treeLink;
  
  BOOL          doTable;    // THREAD (used during generation)
  WOElement     *template;
}

@end

#include "WETreeContextKeys.h"
#include "WETreeMatrixElement.h"
#include "common.h"

@implementation WETreeData

static Class StrClass = Nil;

+ (void)initialize {
  StrClass = [NSString class];
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_root
{
  if ((self = [super initWithName:_name associations:_config template:_root])){
    self->isTreeElement = WOExtGetProperty(_config, @"isTreeElement");
    self->icon          = WOExtGetProperty(_config, @"icon");
    self->cornerIcon    = WOExtGetProperty(_config, @"cornerIcon");
    self->title         = WOExtGetProperty(_config, @"title");
    self->string        = WOExtGetProperty(_config, @"string");
    self->treeLink      = WOExtGetProperty(_config, @"treeLink");

    self->template = [_root retain];
  }
  return self;
}

- (void)dealloc {
  [self->isTreeElement release];
  [self->treeLink      release];
  [self->icon          release];
  [self->cornerIcon    release];
  [self->title         release];
  [self->string        release];
  [self->template      release];
  [super dealloc];
}

/* HTML generation */

- (void)_appendIcon:(NSString *)_icon alt:(NSString *)_alt
  toResponse:(WOResponse *)_response inContext:(WOContext *)_ctx
{
  NSString *iconWidth;
  
  iconWidth = [_ctx objectForKey:WETreeView_IconWidth];
  
  [_response appendContentString:@"<img border=\"0\" src=\""];
  [_response appendContentHTMLAttributeValue:_icon];
  [_response appendContentString:@"\""];
  
  if ([iconWidth isNotEmpty]) {
    [_response appendContentString:@" width=\""];
    [_response appendContentString:iconWidth];
    [_response appendContentString:@"\""];
  }
  if ([_alt isNotEmpty]) {
    [_response appendContentString:@" alt=\""];
    [_response appendContentHTMLAttributeValue:_alt];
    [_response appendContentString:@"\""];
  }
  
  if (_ctx->wcFlags.xmlStyleEmptyElements)
    [_response appendContentString:@" />"];
  else
    [_response appendContentString:@">"];
}

- (void)_appendLink:(NSString *)_icon resp:(WOResponse *)_response
  ctx:(WOContext *)_ctx
{
  BOOL doForm;
  
  // doForm = [_ctx isInForm];
  doForm = NO;
  
  if (doForm) {
    // TODO: we might want to support an assoc to provide the name
    [_response appendContentString:@"<input type=\"image\" border=\"0\""];
    [_response appendContentString:@" align=\"top\" name=\""];
    [_response appendContentString:[_ctx elementID]];
    [_response appendContentString:@"\" src=\""];
    [_response appendContentString:_icon];
    if (_ctx->wcFlags.xmlStyleEmptyElements)
      [_response appendContentString:@"\" />"];
    else
      [_response appendContentString:@"\">"];
  }
  else {
    NSString *link;
    
    [_ctx appendElementIDComponent:WETreeView_ZOOM_ACTION_ID];

    link = (self->treeLink != nil)
      ? [self->treeLink stringValueInComponent:[_ctx component]]
      : [_ctx componentActionURL];
    
    if ([link isNotEmpty]) {
      [_response appendContentString:@"<a href=\""];
      [_response appendContentString:link];
      [_response appendContentString:@"\">"];
    }
    [self _appendIcon:_icon alt:@"z" toResponse:_response inContext:_ctx];
    if ([link isNotEmpty])
      [_response appendContentString:@"</a>"];
    
    [_ctx deleteLastElementIDComponent];
  }
}

- (void)_appendTreeElement:(NSString *)_key
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  /* this appends plus and minus images and links to expand/collapse */
  // TODO: explain more
  BOOL     doLink;
  NSString *img;
  NSString *link;
  
  // TODO: we need to patch this for stateless operation
  
  link   = nil;
  doLink = (_key == WETreeView_Plus   || _key == WETreeView_CornerPlus ||
            _key == WETreeView_Minus  || _key == WETreeView_CornerMinus);
  if (doLink) {
    if (self->treeLink) {
      link = [self->treeLink stringValueInComponent:[_ctx component]];
      if (![link isNotEmpty])
	doLink = NO;
    }
  }
  
  img = [_ctx objectForKey:_key];
  img = WEUriOfResource(img, _ctx);
  
  if (_key == WETreeView_Leaf) {
    NSString *tmp = [self->icon stringValueInComponent:[_ctx component]];
    
    tmp = WEUriOfResource(tmp, _ctx);
    img = (tmp) ? tmp : img;    
  }
  else if (_key == WETreeView_CornerLeaf) {
    NSString *tmp = [self->cornerIcon stringValueInComponent:[_ctx component]];
    tmp = WEUriOfResource(tmp, _ctx);
    img = (tmp) ? tmp : img;
  }
  
  if (img == nil) {
    if (doLink) {
      [_ctx appendElementIDComponent:WETreeView_ZOOM_ACTION_ID];
      [_response appendContentString:@"<a href=\""];
      [_response appendContentString:(link ? link :[_ctx componentActionURL])];
      [_response appendContentString:@"\">"];

      if (_key == WETreeView_Plus || _key == WETreeView_CornerPlus)
        [_response appendContentString:@"<tt>[+]</tt>"];
      else if (_key == WETreeView_Minus || _key == WETreeView_CornerMinus)
        [_response appendContentString:@"<tt>[-]</tt>"];
      
      [_response appendContentString:@"</a>"];
      [_ctx deleteLastElementIDComponent]; /* WETreeView_ZOOM_ACTION_ID */
    }
    else if (_key == WETreeView_Leaf)
      [_response appendContentString:@"<tt>--&nbsp;</tt>"];
    else if (_key == WETreeView_CornerLeaf)
      [_response appendContentString:@"<tt>-|&nbsp;</tt>"];
    else if (_key == WETreeView_Line)
      [_response appendContentString:@"<tt>&nbsp;|&nbsp;</tt>"];
    else if (_key == WETreeView_CornerLeaf)
      [_response appendContentString:@"<tt>&nbsp;--</tt>"];
    else if (_key == WETreeView_Junction || _key == WETreeView_Corner)
      [_response appendContentString:@"<tt>&nbsp;|-</tt>"];
    else if (_key == WETreeView_Space)
      [_response appendContentString:@"<tt>&nbsp;&nbsp;&nbsp;</tt>"];
  }
  else {
    if (doLink)
      [self _appendLink:img resp:_response ctx:_ctx];
    else
      [self _appendIcon:img alt:@"z" toResponse:_response inContext:_ctx];
  }
}

- (void)appendHeader:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *cmp;
  NSString    *tmp;
  BOOL        isTree;
  
  cmp    = [_ctx component];
  tmp    = [self->title stringValueInComponent:cmp];
  isTree = [self->isTreeElement boolValueInComponent:cmp];;
  
  if (tmp == nil)
    return;
  
  if (self->doTable) {
    [_response appendContentString:@"<td"];
    [self appendExtraAttributesToResponse:_response inContext:_ctx];
    if (self->otherTagString) {
      [_response appendContentCharacter:' '];
      [_response appendContentString:
                   [self->otherTagString stringValueInComponent:
                        [_ctx component]]];
    }
    if (isTree) {
      [_response appendContentString:@" colspan=\""];
      [_response appendContentString:
                   [[_ctx objectForKey:WETreeView_HEADER_MODE] stringValue]];
      [_response appendContentString:@"\"><nobr>"];
    }
    else
      [_response appendContentString:@"><nobr>"];
  }
  
  [_response appendContentString:@"<b>"];
  [_response appendContentHTMLString:tmp];
  [_response appendContentString:@"</b>"];
  
  if (doTable)
    [_response appendContentString:@"</nobr></td>"];
}

- (void)appendPaddingCellsOfTreeElement:(id)treeElement
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  /*
    This renders all the tree-view related lines and plus/minus signs,
    padding etc.
  */
  unsigned int i;
  
  for (i = 0; i < [treeElement depth]+1; i++) {
    NSString *iconWidth;
    NSString *treeElm;

    iconWidth = [_ctx objectForKey:WETreeView_IconWidth];
      
    treeElm = (i < [treeElement depth])
      ? [treeElement elementAtIndex:i]
      : [treeElement leaf];

    if (self->doTable) {
      [_response appendContentString:@"<td"];
      [self appendExtraAttributesToResponse:_response inContext:_ctx];
      [_response appendContentString:@" valign=\"middle\" align=\"center\""];
        
      if (iconWidth) {
        NSString *s;
        s = [[StrClass alloc] initWithFormat:@" width=\"%@\"", iconWidth];
        [_response appendContentString:s];
        [s release];
      }
        
      if (treeElm == WETreeView_Plus     || treeElm == WETreeView_Minus ||
          treeElm == WETreeView_Junction || treeElm == WETreeView_Line) {
        NSString *img;
          
        img = [_ctx objectForKey:WETreeView_Line];
        img = WEUriOfResource(img, _ctx);
        if (img) {
          [_response appendContentString:@" background=\""];
          [_response appendContentString:img];
          [_response appendContentCharacter:'"'];
        }
      }
      [_response appendContentString:@"><nobr>"];
    }
    
    /* this appends plus and minus images and links to expand/collapse */
    [self _appendTreeElement:treeElm toResponse:_response inContext:_ctx];
    
    if (self->doTable)
      [_response appendContentString:@"</nobr></td>"];
  }
}

- (void)appendData:(WOResponse *)_response inContext:(WOContext *)_ctx {
  /* TODO: split up this method */
  _WETreeMatrixElement *treeElement;
  WOComponent *cmp       = nil;
  BOOL        isTree     = NO;
  NSString    *content   = nil;
  
  cmp         = [_ctx component];
  isTree      = [self->isTreeElement boolValueInComponent:cmp];
  content     = [self->string stringValueInComponent:cmp];
  treeElement = [_ctx objectForKey:WETreeView_TreeElement];

  if (isTree) {
    /* this is a first cell in a row, it renders the tree controls */
    [self appendPaddingCellsOfTreeElement:treeElement
          toResponse:_response inContext:_ctx];

    if (self->doTable) {
      [_response appendContentString:@"<td"];
      [self appendExtraAttributesToResponse:_response inContext:_ctx];
      [_response appendContentString:@" width='97%'"];
      [_response appendContentString:@" valign='middle' align='left'"];
      [_response appendContentString:@" colspan=\""];
      [_response appendContentString:[treeElement colspanAsString]];
      [_response appendContentString:@"\">"];
    }
    
    /* add cell content */
    [self->template appendToResponse:_response inContext:_ctx];
    if (content)
      [_response appendContentHTMLString:content];
    
    if (self->doTable)
      [_response appendContentString:@"</td>"];
  }
  else { // ! isTree
    /* this is a follow-up cell in a row, it renders just the content */
    if (self->doTable) {
      [_response appendContentString:@"<td"];
      [self appendExtraAttributesToResponse:_response inContext:_ctx];
      if (self->otherTagString) {
        [_response appendContentCharacter:' '];
        [_response appendContentString:
                   [self->otherTagString stringValueInComponent:
                        [_ctx component]]];
      }
      [_response appendContentCharacter:'>'];
    }
    
    /* add cell content */
    [self->template appendToResponse:_response inContext:_ctx];
    if (content != nil) [_response appendContentHTMLString:content];

    if (self->doTable)
      [_response appendContentString:@"</td>"];
  }
}

/* handle requests */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  [self->template takeValuesFromRequest:_rq inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  return [self->template invokeActionForRequest:_rq inContext:_ctx];
}

/* generate response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  self->doTable = ([_ctx objectForKey:WETreeView_RenderNoTable] == nil)?YES:NO;
  
  if ([_ctx objectForKey:WETreeView_HEADER_MODE])
    [self appendHeader:_response inContext:_ctx];
  else
    [self appendData:_response inContext:_ctx];
}

@end /* WETreeData */
