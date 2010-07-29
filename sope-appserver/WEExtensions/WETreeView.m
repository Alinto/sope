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
  WETreeView
  
  A WETreeView is very similiar to a WETableView (eg it can have arbitary
  columns), but can also show/manage a tree of objects.
  
  TODO: we should support a cookie to store the tree hiearchy for stateless 
        servers like the Zope tree. This probably needs to be implemented in
        takeValues (cookie decoding) and appendToResponse (cookie encoding).
        Zooming (invokeAction) needs to ignore? the component-id in case the
        cookie is set and somehow work based on cookie data.

  TODO: we need to support CSS.
  
  WETreeView associations:
    list & sublist & (item | index | currentPath)
    itemIsLeaf
    showItem
    zoom
    string

    noTable

    // config:
    iconWidth
    plusIcon 
    minusIcon
    leafIcon
    junctionIcon
    cornerIcon
    cornerPlusIcon
    cornerMinusIcon
    leafCornerIcon
    lineIcon

  WETreeHeader associations:
    isTreeElement
    icon
    cornerIcon
    title
    string

  WETreeData associations:
    isTreeElement
    icon
    cornerIcon
    title
    string
  
  Example:

    TestTree.wod:
      --- snip ---
      TestTree: WETreeView {
        list    = rootList;
        item    = item;
        index   = index;
        sublist = item.sublist;
        zoom    = treeState.isExpanded; // take a look at LSWTreeState !!!
        // if you leave out *zoom*, the tree is rendered full expanded
        // and without plus and minus icons

        // if no icons are specified, the tree replaces these icons with
        // ascii characters (that style is supposed to be ugly :-)

        // icon config
        iconWidth       = "13"; // every icon's width should be equal to "13"
        plusIcon        = "plus.gif";
        minusIcon       = "minus.gif";
        leafIcon        = "leaf.gif";
        junctionIcon    = "junction.gif";
        cornerIcon      = "corner.gif";
        cornerPlusIcon  = "corner_plus.gif";
        cornerMinusIcon = "corner_miunus.gif";
        leafCornerIcon  = "leaf_corner.gif";
        lineIcon        = "line.gif";
      }
      TreeDataCell: WETreeData {
        isTreeElement = YES; // this is a tree cell (that means, it has plus
                             // and minus icons and all that stuff)
      }
      DataCell: WETreeData {
        isTreeElement = NO;  // this is NOT a  tree cell, i.e. it does NOT
                             // have any plus or minus icons. (This is just a
                             // ordinary <td></td>!!!)
      }

      TreeHeaderCell: WETreeHeader {
        isTreeElement = YES;
      }
      HeaderCell: WETreeHeader {
        isTreeElement = NO;
      }

      --- snap ---

    TestTree.html:
      --- snip ---
      <#TestTree>
        <!--- tree header --->
          <#TreeHeaderCell>some title</#TreeHeaderCell>
          <#HeaderCell">some title</#HeaderCell>
          <#HeaderCell">some title</#HeaderCell>

        <!-- tree content -->

          <#TreeDataCell">some content</#TreeDataCell>
          <#DataCell">some content</#DataCell>
          <#DataCell">some content</#DataCell>
      </#TestTree>
      --- snap ---

    TestTree.wox
      ---snip---
        <var:treeview list="root" sublist="item.sublist" item="item"
                      currentPath="currentPath" zoom="isZoom"
                      showItem="showItem"
        >
          <var:tree-header const:isTreeElement="YES">treecell</var:tree-header>
          <var:tree-header const:isTreeElement="NO" const:bgcolor="#FFDAAA">
            <b>first name</b>
          </var:tree-header>
        </var:treeview>
      ---snap---
*/

#include <NGObjWeb/WODynamicElement.h>

@interface WETreeView : WODynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  WOAssociation  *list;        // array of objects to iterate through
  WOAssociation  *item;        // current item in the array
  WOAssociation  *sublist;     // sub list of item
  WOAssociation  *itemIsLeaf;  // hh-optimization
  WOAssociation  *index;       // current index
  WOAssociation  *zoom;        // show sub list of item (BOOL)
  WOAssociation  *currentPath; //
  WOAssociation  *showItem;    // show current item

  WOAssociation  *noTable;     // render no TABLE (BOOL)
  
  // config:
  WOAssociation  *plusIcon;
  WOAssociation  *minusIcon;
  WOAssociation  *leafIcon;
  WOAssociation  *junctionIcon;
  WOAssociation  *cornerIcon;
  WOAssociation  *cornerPlusIcon;
  WOAssociation  *cornerMinusIcon;
  WOAssociation  *leafCornerIcon;
  WOAssociation  *lineIcon;
  WOAssociation  *spaceIcon;
  WOAssociation  *iconWidth;
  
  WOElement      *template;
}

@end /* WETreeView */

#include "WETreeContextKeys.h"
#include "WETreeMatrixElement.h"
#include "common.h"
#include <NGObjWeb/WEClientCapabilities.h>

NSString *WETreeView_HEADER_MODE    = @"WETreeView_HEADER_MODE";
NSString *WETreeView_ZOOM_ACTION_ID = @"_";

NSString *WETreeView_TreeElement    = @"WETreeView_TreeElement";
NSString *WETreeView_RenderNoTable  = @"WETreeView_RenderNoTable";

NSString *WETreeView_IconWidth      = @"WETreeView_IconWidth";
NSString *WETreeView_Plus           = @"WETreeView_Plus";
NSString *WETreeView_Minus          = @"WETreeView_Minus";
NSString *WETreeView_Leaf           = @"WETreeView_Leaf";
NSString *WETreeView_Line           = @"WETreeView_Line";
NSString *WETreeView_Junction       = @"WETreeView_Junction";
NSString *WETreeView_Corner         = @"WETreeView_Corner";
NSString *WETreeView_CornerPlus     = @"WETreeView_CornerPlus";
NSString *WETreeView_CornerMinus    = @"WETreeView_CornerMinus";
NSString *WETreeView_CornerLeaf     = @"WETreeView_CornerLeaf";
NSString *WETreeView_Space          = @"WETreeView_Space";

@implementation WETreeView

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->list        = WOExtGetProperty(_config, @"list");
    self->item        = WOExtGetProperty(_config, @"item");
    self->index       = WOExtGetProperty(_config, @"index");
    self->sublist     = WOExtGetProperty(_config, @"sublist");
    self->itemIsLeaf  = WOExtGetProperty(_config, @"itemIsLeaf");
    self->zoom        = WOExtGetProperty(_config, @"zoom");
    self->currentPath = WOExtGetProperty(_config, @"currentPath");
    self->showItem    = WOExtGetProperty(_config, @"showItem");

    self->noTable     = WOExtGetProperty(_config, @"noTable");
    
    // config
    self->plusIcon        = WOExtGetProperty(_config, @"plusIcon");
    self->minusIcon       = WOExtGetProperty(_config, @"minusIcon");
    self->leafIcon        = WOExtGetProperty(_config, @"leafIcon");
    self->junctionIcon    = WOExtGetProperty(_config, @"junctionIcon");
    self->cornerIcon      = WOExtGetProperty(_config, @"cornerIcon");
    self->cornerPlusIcon  = WOExtGetProperty(_config, @"cornerPlusIcon");
    self->cornerMinusIcon = WOExtGetProperty(_config, @"cornerMinusIcon");
    self->leafCornerIcon  = WOExtGetProperty(_config, @"leafCornerIcon");
    self->lineIcon        = WOExtGetProperty(_config, @"lineIcon");
    self->spaceIcon       = WOExtGetProperty(_config, @"spaceIcon");
    self->iconWidth       = WOExtGetProperty(_config, @"iconWidth");
    
    self->template = [_t retain];
  }
  return self;
}

- (void)dealloc {
  [self->itemIsLeaf  release];
  [self->sublist     release];
  [self->list        release];
  [self->item        release];
  [self->index       release];
  [self->zoom        release];
  [self->currentPath release];
  [self->showItem    release];

  [self->noTable     release];

  [self->plusIcon        release];
  [self->minusIcon       release];
  [self->leafIcon        release];
  [self->junctionIcon    release];
  [self->cornerIcon      release];
  [self->cornerPlusIcon  release];
  [self->cornerMinusIcon release];
  [self->leafCornerIcon  release];
  [self->lineIcon        release];
  [self->spaceIcon       release];
  [self->iconWidth       release];

  [self->template release];
  
  [super dealloc];
}

- (void)updateConfigInContext:(WOContext *)_ctx {
  NSString       *tmp;
  WOComponent    *cmp;

  cmp = [_ctx component];

  // TODO: replace the macro with methods?
#define SetConfigInContext(_a_, _key_)                                  \
      if (_a_ && (tmp = [_a_ valueInComponent:cmp]))                    \
        [_ctx setObject:tmp forKey:_key_];                              \

  SetConfigInContext(self->plusIcon,        WETreeView_Plus);
  SetConfigInContext(self->minusIcon,       WETreeView_Minus);
  SetConfigInContext(self->leafIcon,        WETreeView_Leaf);
  SetConfigInContext(self->junctionIcon,    WETreeView_Junction);
  SetConfigInContext(self->cornerIcon,      WETreeView_Corner);
  SetConfigInContext(self->cornerPlusIcon,  WETreeView_CornerPlus);
  SetConfigInContext(self->cornerMinusIcon, WETreeView_CornerMinus);
  SetConfigInContext(self->leafCornerIcon,  WETreeView_CornerLeaf);
  SetConfigInContext(self->lineIcon,        WETreeView_Line);
  SetConfigInContext(self->spaceIcon,       WETreeView_Space);
  SetConfigInContext(self->iconWidth,       WETreeView_IconWidth);
  
#undef SetConfigInContext
}

- (void)removeConfigInContext:(WOContext *)_ctx {
  [_ctx removeObjectForKey:WETreeView_Plus];
  [_ctx removeObjectForKey:WETreeView_Minus];
  [_ctx removeObjectForKey:WETreeView_Leaf];
  [_ctx removeObjectForKey:WETreeView_Junction];
  [_ctx removeObjectForKey:WETreeView_Corner];
  [_ctx removeObjectForKey:WETreeView_CornerPlus];
  [_ctx removeObjectForKey:WETreeView_CornerMinus];
  [_ctx removeObjectForKey:WETreeView_CornerLeaf];
  [_ctx removeObjectForKey:WETreeView_Line];
  [_ctx removeObjectForKey:WETreeView_Space];
  [_ctx removeObjectForKey:WETreeView_IconWidth];
}

- (id)_toggleZoomInContext:(WOContext *)_ctx {
  WOComponent *component = [_ctx component];

  if ([self->zoom isValueSettable]) {
    BOOL isZoom;
    
    isZoom = [self->zoom boolValueInComponent:component];
    [self->zoom setBoolValue:!isZoom inComponent:component];
  }
  return nil;
}

/* OWResponder */

- (NSArray *)_sublistInContext:(WOContext *)_ctx {
  NSArray *a;
  
  if (self->sublist == nil)
    return nil;
  if (self->itemIsLeaf) {
    if ([self->itemIsLeaf boolValueInComponent:[_ctx component]])
      return nil;
  }
  
  if ((a = [self->sublist valueInComponent:[_ctx component]]) == nil)
    return nil;
  
  return [a isNotEmpty] ? a : (NSArray *)nil;
}

/* handle requests */

- (void)_takeValuesFromRequest:(WORequest *)_req
  inContext:(WOContext *)_ctx
  withArray:(NSArray *)array
      depth:(int)_depth
{
  WOComponent *cmp;
  int i, cnt;

#if DEBUG
#if 1
  if (!(_depth <= MAX_TREE_DEPTH-1)) {
    NSLog(@"ERROR[%s]: WETreeView takeValuesFromRequest: max."
          @"recursion depth is %d",
          __PRETTY_FUNCTION__, MAX_TREE_DEPTH-1);
    return;
  }
#else  
  NSAssert1((_depth <= MAX_TREE_DEPTH-1),
            @"WETreeView takeValuesFromRequest: max. recursion depth is %d",
            MAX_TREE_DEPTH-1);
#endif  
#endif
  
  cmp = [_ctx component];
  cnt = [array count];
  
  [_ctx appendZeroElementIDComponent]; // append index
  for (i = 0; i < cnt; i++) {
    NSArray *subArray;
    
    if ([self->index isValueSettable])
      [self->index setUnsignedIntValue:i inComponent:cmp];
    if ([self->item isValueSettable])
      [self->item setValue:[array objectAtIndex:i] inComponent:cmp];

    if (self->showItem && ![self->showItem boolValueInComponent:cmp])
      continue;

    if (self->zoom == nil || [self->zoom boolValueInComponent:cmp])
      subArray = [self _sublistInContext:_ctx];
    else
      subArray = nil;
    
    if (subArray)
      [self _takeValuesFromRequest:_req
                         inContext:_ctx
                         withArray:subArray
                             depth:_depth+1];
    else
      [self->template takeValuesFromRequest:_req inContext:_ctx];
    
    [_ctx incrementLastElementIDComponent];
  }
  [_ctx deleteLastElementIDComponent]; // delete index
}

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  NSArray *array;

  array = [self->list valueInComponent:[_ctx component]];
  [self _takeValuesFromRequest:_req inContext:_ctx withArray:array depth:0];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  id       result  = nil;
  id       idxId   = nil;
  id       object  = nil;
  NSMutableArray *stack = nil;
  NSArray  *array;
  unsigned idCount = 0;

  sComponent = [_ctx component];
  array      = [self->list valueInComponent:sComponent];
  if ([array count] < 1) return nil;
  
  stack = [NSMutableArray arrayWithCapacity:8];
  
  idxId = [_ctx currentElementID]; // top level index
  idCount = 0;
  
  if ([idxId isEqualToString:@"h"]) {
    [_ctx setObject:@"YES" forKey:WETreeView_HEADER_MODE];
    [_ctx appendElementIDComponent:@"h"];
    [_ctx consumeElementID];
    result = [self->template invokeActionForRequest:_rq inContext:_ctx];
    [_ctx deleteLastElementIDComponent];
    [_ctx removeObjectForKey:WETreeView_HEADER_MODE];
    return result;
  }
  
  while ((![idxId isEqualToString:@"end"]) && (idxId != nil) &&
         (array != nil)) {
    unsigned idx = [idxId unsignedIntValue];

    object = [array objectAtIndex:idx];
    [stack addObject:object];
    
    if ([self->index isValueSettable])
      [self->index setUnsignedIntValue:idx inComponent:sComponent];
    if ([self->item isValueSettable])
      [self->item setValue:object inComponent:sComponent];
    if ([self->currentPath isValueSettable])
      [self->currentPath setValue:stack inComponent:sComponent];

    array = [self->sublist valueInComponent:sComponent];
    
    [_ctx appendElementIDComponent:idxId]; idCount++;
    idxId = [_ctx consumeElementID]; // sub level index
  }
  if ([idxId isEqualToString:@"end"]) {
    [_ctx appendElementIDComponent:idxId]; idCount++;
    idxId = [_ctx consumeElementID];
  }
  
  result = ([[_ctx senderID] hasSuffix:WETreeView_ZOOM_ACTION_ID])
    ? [self _toggleZoomInContext:_ctx]
    : [self->template invokeActionForRequest:_rq inContext:_ctx];
  
  /* remove element-ids */
  for (; idCount > 0; idCount--)
    [_ctx deleteLastElementIDComponent];
  
  return result;
}

/* collect rows */

- (void)appendList:(NSArray *)_list
  treeElement:(_WETreeMatrixElement *)_element
  toTableRows:(NSMutableArray *)_matrix
  inContext:(WOContext *)_ctx
{
  /* TODO: split up this method! */
  WOComponent    *comp;
  unsigned       i, cnt;

  comp = [_ctx component];
  cnt  = [_list count];

#if DEBUG
#if 1  
  if (!([_element depth] <= MAX_TREE_DEPTH-1)) {
    NSLog(@"ERROR[%s]: WETreeView takeValuesFromRequest: max."
          @"recursion depth is %d",
          __PRETTY_FUNCTION__, MAX_TREE_DEPTH-1);
    return;
  }
#else  
  NSAssert1(([_element depth] <= MAX_TREE_DEPTH-1),
            @"WETreeView appendToResponse: max. recursion depth is %d",
            MAX_TREE_DEPTH-1);
#endif  
#endif
    
  for (i = 0; i < cnt; i++) {
    id object;

    object = [_list objectAtIndex:i];
    
    [_element setIndex:i];
    [_element setItem:object];
    
    if ([self->index isValueSettable])
      [self->index setUnsignedIntValue:i inComponent:comp];
    if ([self->item isValueSettable])
      [self->item setValue:object inComponent:comp];
    if ([self->currentPath isValueSettable])
      [self->currentPath setValue:[_element currentPath] inComponent:comp];

    if (self->showItem && ![self->showItem boolValueInComponent:comp])
      continue;

    {
      BOOL    isLast;
      BOOL    isLeaf;
      BOOL    isZoom = YES;
      NSArray *sl;

      if (self->itemIsLeaf) {
        isLeaf = [self->itemIsLeaf boolValueInComponent:comp];
        isZoom = (self->zoom)
          ? [self->zoom boolValueInComponent:comp]
          : YES;
        
        sl = (!isLeaf && isZoom)
          ? [self _sublistInContext:_ctx]
          : (NSArray *)nil;
      }
      else {
        sl = [self _sublistInContext:_ctx];
        isLeaf = ![sl isNotEmpty];
      }

      if (self->showItem) {
        if (i == (cnt-1))
          isLast = YES;
        else {
          id       obj;
          unsigned k;

          isLast = YES;
          for (k = (i + 1); k < cnt; k++) {
            obj = [_list objectAtIndex:k];
            
            [_element setIndex:k];
            [_element setItem:obj];
            if ([self->index isValueSettable])
              [self->index setUnsignedIntValue:k inComponent:comp];
            if ([self->item isValueSettable])
              [self->item setValue:obj inComponent:comp];
            if ([self->currentPath isValueSettable])
              [self->currentPath setValue:[_element currentPath]
                   inComponent:comp];
            
            if ([self->showItem boolValueInComponent:comp]) {
              isLast = NO;
              break;
            }
          }
          [_element setIndex:i];
          [_element setItem:object];

          if ([self->index isValueSettable])
            [self->index setUnsignedIntValue:i inComponent:comp];
          if ([self->item isValueSettable])
            [self->item setValue:object inComponent:comp];
          if ([self->currentPath isValueSettable])
            [self->currentPath setValue:[_element currentPath]
                   inComponent:comp];
        }
      }
      else
        isLast = (i == (cnt-1));
        
      if (!isLeaf) { // not a leaf
        _WETreeMatrixElement *newElement;
        
        if (self->zoom == nil) {
          [_element setElement:(isLast)
                    ? WETreeView_Corner
                    : WETreeView_Junction];
        }
        else {
          isZoom = [self->zoom boolValueInComponent:comp];
          if (isZoom) {
            [_element setElement:(isLast)
                 ? ([sl count]) ? WETreeView_CornerMinus : WETreeView_Corner
                 : ([sl count]) ? WETreeView_Minus : WETreeView_Junction];
          }
          else
            [_element setElement:(isLast)
                      ? WETreeView_CornerPlus
                      : WETreeView_Plus];
        }
        [_element setLeaf:(isZoom && [sl count])
                  ? WETreeView_CornerLeaf
                  : WETreeView_Leaf];

        newElement = [[_WETreeMatrixElement alloc] initWithElement:_element];

        [_matrix addObject:newElement];
        [newElement release]; newElement = nil;
        
        if (isZoom) {
          [_element setElement:(isLast)
                      ? WETreeView_Space
                      : WETreeView_Line];
          
          newElement = [[_WETreeMatrixElement alloc] initWithElement:_element];

          [self appendList:sl treeElement:newElement 
                toTableRows:_matrix inContext:_ctx];
          [newElement release]; newElement = nil;
        }
      }
      else {
        _WETreeMatrixElement *newElement;

        [_element setElement: (isLast)
                  ? WETreeView_Corner
                  : WETreeView_Junction];

        newElement = [[_WETreeMatrixElement alloc] initWithElement:_element];

        [newElement setLeaf:WETreeView_Leaf];

        [_matrix addObject:newElement];
        [newElement release]; newElement = nil;
      }
    }
  }
}

- (NSArray *)_calcMatrixInContext:(WOContext *)_ctx depth:(int *)_depth {
  /*
    Note: returns a retained object!

    This is the main entry for the calculation of the rows and the depth
    nesting.
    The rows are stored in _WETreeMatrixElement objects which know about
    their colspan, depth and columns.
  */
  NSMutableArray       *tableRows;
  _WETreeMatrixElement *treeElm;
  NSArray              *top;
  int i, cnt, d, maxDepth = 0;

  top       = [self->list valueInComponent:[_ctx component]];
  tableRows = [[NSMutableArray alloc] initWithCapacity:64];
  
  treeElm = [[_WETreeMatrixElement alloc] init];
  [self appendList:top treeElement:treeElm toTableRows:tableRows
        inContext:_ctx];
  [treeElm release]; treeElm = nil;
  
  cnt = [tableRows count];
  
  /* calc max depth */
  for (i = 0; i < cnt; i++) {
    d = [[tableRows objectAtIndex:i] depth];
    maxDepth = (maxDepth < d) ? d : maxDepth;
  }

  /* update colspan (max-depth minus element-depth) */
  for (i = 0; i < cnt; i++) {
    _WETreeMatrixElement *element;

    element = [tableRows objectAtIndex:i];
    [element setColspan:(maxDepth - [element depth] + 1)];
  }
  *_depth = maxDepth + 2;
  return tableRows;
}

/* generate response, main entry function */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *comp;
  NSArray     *matrix;
  BOOL        doTable;
  int         i, cnt, depth;

  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  [self updateConfigInContext:_ctx];

  comp = [_ctx component];

  /* check for browser */
  if (self->noTable == nil) {
    WEClientCapabilities *ccaps;
    
    ccaps = [[_ctx request] clientCapabilities];
    doTable = [ccaps isFastTableBrowser];
  }
  else
    doTable = ![self->noTable boolValueInComponent:comp];

  if (!doTable)
    [_ctx setObject:@"1" forKey:WETreeView_RenderNoTable];

  if (doTable) {
    [_response appendContentString:
               @"<table border='0' cellspacing='0' cellpadding='0'"];

    [self appendExtraAttributesToResponse:_response inContext:_ctx];
    if (self->otherTagString != nil) {
      [_response appendContentCharacter:' '];
      [_response appendContentString:
                 [self->otherTagString stringValueInComponent:
                      [_ctx component]]];
    }
    [_response appendContentCharacter:'>'];
  }
  
  matrix = [self _calcMatrixInContext:_ctx depth:&depth];

  /* append table title */
  if (doTable)
    [_response appendContentString:@"<tr>"];

  [_ctx setObject:[NSNumber numberWithInt:depth]
        forKey:WETreeView_HEADER_MODE];
  [_ctx appendElementIDComponent:@"h"];
  [self->template appendToResponse:_response inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
  [_ctx removeObjectForKey:WETreeView_HEADER_MODE];
  if (doTable)
    [_response appendContentString:@"</tr>"];
  else if (_ctx->wcFlags.xmlStyleEmptyElements)
    [_response appendContentString:@"<br />"];
  else
    [_response appendContentString:@"<br>"];
  
  /* generate content rows */

  for (i = 0, cnt = [matrix count]; i < cnt; i++) {
    _WETreeMatrixElement *element;

    element = [matrix objectAtIndex:i];

    /* push positioning info into component */
      
    if ([self->index isValueSettable])
      [self->index setUnsignedIntValue:[element index] inComponent:comp];
    
    if ([self->item isValueSettable])
      [self->item setValue:[element item] inComponent:comp];

    if ([self->currentPath isValueSettable])
      [self->currentPath setValue:[element currentPath] inComponent:comp];

    /* set active tree element in context (tree cannot be nested!) */
    
    [_ctx setObject:element forKey:WETreeView_TreeElement];

    /* start table row and update element-ids */
    
    [_ctx appendElementIDComponent:[element elementID]];
    [_ctx appendElementIDComponent:@"end"];
    if (doTable)
      [_response appendContentString:@"<tr>"];
    
    /* generate content */
    
    [self->template appendToResponse:_response inContext:_ctx];

    /* close table row and update element-ids */
    
    if (doTable)
      [_response appendContentString:@"</tr>"];
    else if (_ctx->wcFlags.xmlStyleEmptyElements)
      [_response appendContentString:@"<br />"];
    else
      [_response appendContentString:@"<br>"];
      
    [_ctx deleteLastElementIDComponent]; // delete "end"
      
    [_ctx deleteLastElementIDComponent]; // delete eids
  }
  [_ctx removeObjectForKey:WETreeView_TreeElement];

  if (doTable)
    [_response appendContentString:@"</table>"];
  
  /* cleanup rendering context */

  [self removeConfigInContext:_ctx];
  [_ctx removeObjectForKey:WETreeView_RenderNoTable];
  [matrix release]; matrix = nil;
}

@end /* WETreeView */
