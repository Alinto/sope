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

#ifndef __ODRGenericTag_H__
#define __ODRGenericTag_H__

#import <Foundation/NSObject.h>
#include <NGObjDOM/ODNodeRenderer.h>

/*
  This node-renderer is for rendering ELEMENT_NODE nodes by passing them
  through. All non-ELEMENT_NODE's are ignored and rendering continues at
  their children.
*/

@interface ODRGenericTag : ODNodeRenderer
{
  BOOL ignoreTextNodes;
}

@end

#endif /* __ODRGenericTag_H__ */
