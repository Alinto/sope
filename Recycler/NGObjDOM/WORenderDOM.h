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

#ifndef __NGObjDOM_WORenderDOM_H__
#define __NGObjDOM_WORenderDOM_H__

#include <NGObjWeb/WODynamicElement.h>
#include <NGObjDOM/ODNodeRendererFactory.h>

/*
  This is a NGObjWeb dynamic element for rendering a DOM tree.

  Bindings:

    domDocument [in]
    node        [out]
    factory     [in]
    renderer    [in]

  'Factory' and 'renderer' bindings are invoked with 'node' setup to the
  currently processed DOM-node of 'domDocument'.

  The dynamic element binds itself as the node renderer factory to the ctx,
  and forwards any renderer creation request to either a factory, if
  the factory binding is set, or to a component, if the 'node' binding is set.
*/

@interface WORenderDOM : WODynamicElement < ODNodeRendererFactory >
{
  WOAssociation *domDocument; /* the document object            */
  WOAssociation *factory;     /* the renderer factory           */
  WOAssociation *node;        /* the current node for callbacks */
  WOAssociation *renderer;    /* the renderer to apply on node  */
}

- (id)domInContext:(WOContext *)_ctx; // used in SkyForm

@end

#endif /* __NGObjDOM_WORenderDOM_H__ */
