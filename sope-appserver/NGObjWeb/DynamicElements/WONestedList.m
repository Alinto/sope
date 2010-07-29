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

#include <NGObjWeb/WOHTMLDynamicElement.h>
#include "WOElement+private.h"
#include "decommon.h"

@interface WONestedList : WOHTMLDynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  WOAssociation *list;
  WOAssociation *item;
  WOAssociation *value;
  WOAssociation *sublist;
  WOAssociation *action;
  WOAssociation *selection;
  WOAssociation *index;
  WOAssociation *level;
  WOAssociation *isOrdered;
  WOAssociation *prefix;
  WOAssociation *suffix;
}

@end /* WONestedList */

@implementation WONestedList

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_root
{
  if ((self = [super initWithName:_name associations:_config template:_root])) {
    self->action          = OWGetProperty(_config, @"action");
    self->list            = OWGetProperty(_config, @"list");
    self->item            = OWGetProperty(_config, @"item");
    self->index           = OWGetProperty(_config, @"index");
    self->selection       = OWGetProperty(_config, @"selection");
    self->prefix          = OWGetProperty(_config, @"prefix");
    self->suffix          = OWGetProperty(_config, @"suffix");
    self->sublist         = OWGetProperty(_config, @"sublist");
    self->value           = OWGetProperty(_config, @"value");
    self->isOrdered       = OWGetProperty(_config, @"isOrdered");
    self->level           = OWGetProperty(_config, @"level");
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->level);
  RELEASE(self->isOrdered);
  RELEASE(self->value);
  RELEASE(self->sublist);
  RELEASE(self->list);
  RELEASE(self->item);
  RELEASE(self->index);
  RELEASE(self->selection);
  RELEASE(self->prefix);
  RELEASE(self->suffix);
  RELEASE(self->action);
  [super dealloc];
}

/* processing requests */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  // not a container ..
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  WOComponent *sComponent = [_ctx component];
  id       idxId   = nil;
  id       object  = nil;
  unsigned nesting = 0;
  NSArray  *array;

  array  = [self->list valueInComponent:sComponent];
  if ([array count] < 1) return nil;
  
  idxId = [_ctx currentElementID]; // top level index
  while ((idxId != nil) && (array != nil)) {
    unsigned idx = [idxId unsignedIntValue];
    
    object = [array objectAtIndex:idx];

    if ([self->level isValueSettable])
      [self->level setUnsignedIntValue:nesting inComponent:sComponent];
    if ([self->index isValueSettable])
      [self->index setUnsignedIntValue:idx inComponent:sComponent];
    if ([self->item isValueSettable])
      [self->item setValue:object inComponent:sComponent];

    array = [self->sublist valueInComponent:sComponent];
    idxId = [_ctx consumeElementID]; // sub level index
    nesting++;
  }

  if ([self->selection isValueSettable])
    [self->selection setValue:object inComponent:sComponent];

  return [self executeAction:self->action inContext:_ctx];
}

/* generating response */

- (void)appendList:(NSArray *)_list atLevel:(unsigned int)_level
  toResponse:(WOResponse *)_response inContext:(WOContext *)_ctx
{
  WOComponent *sComponent = [_ctx component];
  unsigned    count       = [_list count];
  unsigned    cnt;

  if (count > 0) {
    BOOL ordered;
    
    if ([self->level isValueSettable])
      [self->level setUnsignedIntValue:_level inComponent:sComponent];

    ordered = [self->isOrdered boolValueInComponent:sComponent];
    
    WOResponse_AddString(_response, ordered ? @"<ol>" : @"<ul>");

    [_ctx appendZeroElementIDComponent];
    for (cnt = 0; cnt < count; cnt++) {
      id object = [_list objectAtIndex:cnt];

      if ([self->index isValueSettable])
        [self->index setUnsignedIntValue:cnt inComponent:sComponent];

      if ([self->item isValueSettable])
        [self->item setValue:object inComponent:sComponent];

      // add item
      WOResponse_AddCString(_response, "<li>");
      {
        NSArray *sl = [self->sublist valueInComponent:sComponent];
        
        if (self->prefix) {
          NSString *ps;

          ps = [self->prefix stringValueInComponent:sComponent];
          WOResponse_AddString(_response, ps);
        }
        
        if (self->value) {
          if (self->action) {
            WOResponse_AddCString(_response, "<a href=\"");
            WOResponse_AddString(_response, [_ctx componentActionURL]);
            [_response appendContentCharacter:'"'];
            [self appendExtraAttributesToResponse:_response inContext:_ctx];
            [_response appendContentCharacter:'>'];
          }

          WOResponse_AddHtmlString(_response,
            [self->value stringValueInComponent:sComponent]);
          if (self->action)
            WOResponse_AddCString(_response, "</a>");
        }

        if (self->suffix) {
          NSString *ss;

          ss = [self->suffix stringValueInComponent:sComponent];
          WOResponse_AddString(_response, ss);
        }

        if ([sl count] > 0) { // not a leaf
          [self appendList:sl
                atLevel:(_level + 1)
                toResponse:_response
                inContext:_ctx];
          if ([self->level isValueSettable])
            [self->level setUnsignedIntValue:_level inComponent:sComponent];
        }
      }
      WOResponse_AddCString(_response, "</li>\n");
      
      [_ctx incrementLastElementIDComponent];
    }
    [_ctx deleteLastElementIDComponent]; // list index

    WOResponse_AddString(_response, ordered ? @"</ol>" : @"</ul>");

    if ([self->level isValueSettable])
      [self->level setUnsignedIntValue:_level inComponent:sComponent];
  }
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSArray *top;
  
  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent])
    return;

  top = [self->list valueInComponent:[_ctx component]];
  if ([top count] > 0) {
    [self appendList:top
          atLevel:0
          toResponse:_response
          inContext:_ctx];
  }
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;

  str = [NSMutableString stringWithCapacity:64];
  if (self->action)    [str appendFormat:@" action=%@",    self->action];
  if (self->list)      [str appendFormat:@" list=%@",      self->list];
  if (self->sublist)   [str appendFormat:@" sublist=%@",   self->sublist];
  if (self->item)      [str appendFormat:@" item=%@",      self->item];
  if (self->index)     [str appendFormat:@" index=%@",     self->index];
  if (self->prefix)    [str appendFormat:@" prefix=%@",    self->prefix];
  if (self->suffix)    [str appendFormat:@" suffix=%@",    self->suffix];
  if (self->selection) [str appendFormat:@" selection=%@", self->selection];
  if (self->value)     [str appendFormat:@" value=%@",     self->value];
  if (self->isOrdered) [str appendFormat:@" isOrdered=%@", self->isOrdered];
  if (self->level)     [str appendFormat:@" level=%@",     self->level];
  return str;
}

@end /* WONestedList */
