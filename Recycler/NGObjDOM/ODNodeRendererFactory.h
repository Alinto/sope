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

#ifndef __NGObjDOM_ODNodeRendererFactory_H__
#define __NGObjDOM_ODNodeRendererFactory_H__

#import <Foundation/NSObject.h>

@class WOContext;
@class ODNodeRenderer;

@protocol ODNodeRendererFactory

- (ODNodeRenderer *)rendererForNode:(id)_domNode
  inContext:(WOContext *)_ctx;

@end

@interface ODNodeRendererFactory : NSObject < ODNodeRendererFactory >

/* those are called by -rendererForNode:inContext: depending on the node-type */

- (ODNodeRenderer *)rendererForTextNode:(id)_domNode 
  inContext:(WOContext *)_ctx;
- (ODNodeRenderer *)rendererForElementNode:(id)_domNode 
  inContext:(WOContext *)_ctx;

/* 'master' factory */

- (ODNodeRenderer *)rendererForNode:(id)_domNode
  inContext:(WOContext *)_ctx;

@end

#endif /* __NGObjDOM_ODNodeRendererFactory_H__ */
