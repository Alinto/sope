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

#ifndef __ODRDynamicXHTMLTag_H__
#define __ODRDynamicXHTMLTag_H__

#import <Foundation/NSObject.h>
#include <NGObjDOM/ODNodeRenderer.h>

/*
  This node-renderer is for rendering ELEMENT_NODE nodes which reside in the
  XHTML namespace.
  All non-ELEMENT_NODE / XHTML nodes are ignored and rendering continues at
  their children.
*/

@interface ODRDynamicXHTMLTag : ODNodeRenderer
{
}

/* this generates names for elements (based on 'name' and elementID) */
- (NSString *)_selectNameOfNode:(id)_node inContext:(WOContext *)_ctx;

@end

#endif /* __ODRDynamicXHTMLTag_H__ */
