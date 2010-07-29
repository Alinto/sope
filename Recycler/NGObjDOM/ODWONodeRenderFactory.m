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

#include <NGObjDOM/ODNodeRendererFactory.h>

@interface ODWONodeRenderFactory : NSObject < ODNodeRendererFactory >
@end

#include "ODREmbedComponent.h"
#include <NGObjDOM/ODRWebObject.h>
#include <NGObjDOM/ODREmbedComponent.h>
#include <NGObjDOM/ODNamespaces.h>
#include <NGObjDOM/ODNodeRenderer.h>
#include "common.h"

@implementation ODWONodeRenderFactory

- (ODNodeRenderer *)rendererForNode:(id)_domNode
  inContext:(WOContext *)_ctx
{
  ODNodeRenderer *renderer;
  
  if (![[_domNode namespaceURI] isEqualToString:XMLNS_OD_BIND])
    return nil;
  
  if ([[_domNode tagName] isEqualToString:@"embed"]) {
    static ODREmbedComponent *wor = nil;
    if (wor == nil)
      wor = [[ODREmbedComponent alloc] init];;
    renderer = wor;
  }
  else {
    static ODRWebObject *wor = nil;
    if (wor == nil)
      wor = [[ODRWebObject alloc] init];;
    renderer = wor;
  }
  
  return renderer;
}

@end /* ODWONodeRenderFactory */
