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

#include "ODXULNodeRenderFactory.h"
#include <NGObjDOM/ODNamespaces.h>
#include <NGObjDOM/ODNodeRenderer.h>
#include "common.h"

@implementation ODXULNodeRenderFactory

- (ODNodeRenderer *)rendererForNode:(id)_domNode
  inContext:(WOContext *)_ctx
{
  static NSMutableDictionary *tagToRenderer = nil; /* cache, THREAD */
  ODNodeRenderer *renderer;
  NSString *rendererName;

  if ((renderer = [tagToRenderer objectForKey:[_domNode tagName]]))
    return renderer;
  
  if (![[_domNode namespaceURI] isEqualToString:XMLNS_XUL])
    return nil;
  
  rendererName = [@"ODR_XUL_" stringByAppendingString:[_domNode tagName]];
  
  if ((renderer = [[NSClassFromString(rendererName) alloc] init])) {
    if (tagToRenderer == nil)
      tagToRenderer = [[NSMutableDictionary alloc] initWithCapacity:64];
    [tagToRenderer setObject:renderer forKey:[_domNode tagName]];
    AUTORELEASE(renderer);
  }
  
  return renderer;
}

@end /* ODXULNodeRenderFactory */
