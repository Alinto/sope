/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#include "ODXHTMLNodeRenderFactory.h"
#include "ODRDynamicXHTMLTag.h"
#include <NGObjDOM/ODNamespaces.h>
#include <NGObjDOM/ODNodeRenderer.h>
#include "common.h"

@implementation ODXHTMLNodeRenderFactory

- (ODNodeRenderer *)rendererForNode:(id)_domNode
  inContext:(WOContext *)_ctx
{
  static NSMutableDictionary *tagToRenderer = nil; /* cache, THREAD */
  ODNodeRenderer *renderer;
  NSString *rendererName;

  /* check node-type */
  
  if (!([[_domNode namespaceURI] isEqualToString:XMLNS_XHTML] ||
        [[_domNode namespaceURI] isEqualToString:XMLNS_HTML40]))
    return nil;

  /* lookup renderer in cache */

  if ((renderer = [tagToRenderer objectForKey:[_domNode tagName]]))
    return renderer;
  
  /* lookup renderer by classname */
  
  rendererName = [@"ODR_XHTML_" stringByAppendingString:[_domNode tagName]];

  renderer = [[[NSClassFromString(rendererName) alloc] init] autorelease];

  /* did not find special renderer, use default renderer */
  
  if (renderer == nil) {
    static ODRDynamicXHTMLTag *defRenderer = nil;
    if (defRenderer == nil)
      defRenderer = [[ODRDynamicXHTMLTag alloc] init];
    renderer = defRenderer;
  }

  /* place renderer in cache */

  if (renderer) {
    if (tagToRenderer == nil)
      tagToRenderer = [[NSMutableDictionary alloc] initWithCapacity:64];
    [tagToRenderer setObject:renderer forKey:[_domNode tagName]];
  }
  
  return renderer;
}

@end /* ODXHTMLNodeRenderFactory */
