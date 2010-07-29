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

#ifndef __ODNodeRenderer_H__
#define __ODNodeRenderer_H__

#import <Foundation/NSObject.h>

@class WOContext, WORequest, WOResponse;

@interface ODNodeRenderer : NSObject

/* renderer lookup (uses the ODNodeRendererFactory stored in the WOContext) */

- (ODNodeRenderer *)rendererForNode:(id)_domNode
  inContext:(WOContext *)_ctx;

/* request phases */

- (void)takeValuesForNode:(id)_domNode
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_context;

- (id)invokeActionForNode:(id)_domNode
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_context;

- (void)appendNode:(id)_domNode
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_context;

/* request phases for child nodes */

- (void)takeValuesForChildNodes:(id)_nodeList
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_context;
- (id)invokeActionForChildNodes:(id)_nodeList
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_context;
- (void)appendChildNodes:(id)_nodeList
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_context;

/* requires HTML form */

- (BOOL)requiresFormForNode:(id)_domNode inContext:(WOContext *)_ctx;
- (BOOL)requiresFormForChildNodes:(id)_nodeList inContext:(WOContext *)_ctx;

/* selecting children */

- (BOOL)includeChildNode:(id)_childNode
  ofNode:(id)_domNode
  inContext:(WOContext *)_ctx;

/* generating node ids unique in DOM tree */

- (NSString *)uniqueIDForNode:(id)_node inContext:(WOContext *)_ctx;

@end

#include <NGObjDOM/ODNodeRenderer+attributes.h>

#endif /* __ODNodeRenderer_H__ */
