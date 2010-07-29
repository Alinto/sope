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

#ifndef __ODRDynamicXULTag_H__
#define __ODRDynamicXULTag_H__

#import <Foundation/NSObject.h>
#import <NGObjDOM/ODNodeRenderer.h>

@class NSString;
@class WOContext;

@interface ODRDynamicXULTag : ODNodeRenderer

/* whether to process a child, only element-nodes are processed by default */
- (BOOL)addChildNode:(id)_node inContext:(WOContext *)_ctx;

- (void)willAppendChildNode:(id)_child
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_context;
- (void)didAppendChildNode:(id)_child
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_context;

@end

#endif /* __ODRDynamicXULTag_H__ */
