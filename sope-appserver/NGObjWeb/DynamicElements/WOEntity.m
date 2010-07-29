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
#include <NGObjWeb/WOResourceManager.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOxElemBuilder.h>
#include <DOM/DOMProtocols.h>
#include "decommon.h"

@interface WOEntity : WOHTMLDynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  WOAssociation *name;
}

@end /* WOEntity */

@implementation WOEntity

- (id)initWithElement:(id<DOMElement>)_element
  templateBuilder:(WOxElemBuilder *)_builder
{
  NSString            *tname;
  NSMutableDictionary *assocs;
  id<NSObject,DOMNamedNodeMap> attrs;
  unsigned count;
  
  tname = [_element tagName];
  
  /* construct associations */
  
  assocs = nil;
  attrs = [_element attributes];
  if ((count = [attrs length]) > 0)
    assocs = [_builder associationsForAttributes:attrs];

  if ([tname isEqualToString:@"nbsp"]) {
    WOAssociation *a;

    a = [_builder associationForValue:@"nbsp"];
    if (assocs)
      [assocs setObject:a forKey:@"name"];
    else
      assocs = [NSMutableDictionary dictionaryWithObject:a forKey:@"name"];
  }
  
  /* construct child elements */
  
  if ([_element hasChildNodes]) {
    [_builder logWithFormat:@"WARNING: element %@ has child-nodes (ignored)",
                _element];
  }
  
  /* construct self ... */
  self = [self initWithName:tname
               associations:assocs 
               contentElements:nil];
  [(id)self setExtraAttributes:assocs];
  return self;
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_tmpl
{
  if ((self = [super initWithName:_name associations:_config template:_tmpl])) {
    if ((self->name = OWGetProperty(_config, @"name")) == nil) {
      NSLog(@"%s: missing 'name' binding for entity element %@ (assocs=%@)...",
            __PRETTY_FUNCTION__, _name, _config);
      RELEASE(self);
      return nil;
    }
  }
  return self;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  RELEASE(self->name);
  [super dealloc];
}
#endif

// ******************** responder ********************

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *s;
  
  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent])
    return;

  s = [self->name stringValueInComponent:[_ctx component]];
  if ([s length] == 0)
    return;

  WOResponse_AddChar(_response, '&');
  WOResponse_AddString(_response, s);
  WOResponse_AddChar(_response, ';');
}

/* description */

- (NSString *)associationDescription {
  return [NSString stringWithFormat:@" name=%@",  self->name];
}

@end /* WOEntity */
