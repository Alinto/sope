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

#ifndef __SoObjects_SoTemplateRenderer_H__
#define __SoObjects_SoTemplateRenderer_H__

#import <Foundation/NSObject.h>

/*
  SoTemplateRenderer
  
  This renderer is intended to render webpages or content by using a
  "template". A template is usually an OFSWebMethod or WOComponent
  exported by a product.
  
  Templates are located by several aspects.
  TODO: describe
  - lookup based on hierarchy
  - lookup based on query-key
  - lookup based on folder-type
  - default template (Main)
*/

@class NSException;
@class WOContext;

@interface SoTemplateRenderer : NSObject
{
}

+ (id)sharedRenderer;

- (NSException *)renderObject:(id)_object inContext:(WOContext *)_ctx;
- (BOOL)canRenderObject:(id)_object inContext:(WOContext *)_ctx;

@end

#endif /* __SoObjects_SoTemplateRenderer_H__ */
