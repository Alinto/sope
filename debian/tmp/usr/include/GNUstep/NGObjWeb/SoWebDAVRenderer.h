/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#ifndef __SoObjects_SoWebDAVRenderer_H__
#define __SoObjects_SoWebDAVRenderer_H__

#import <Foundation/NSObject.h>

/*
  SoWebDAVRenderer
  
  An object which can render DAV responses of all kinds.
*/

@class NSException;
@class WOContext;

@interface SoWebDAVRenderer : NSObject
{
}

+ (id)sharedRenderer;

/* master renderer */

- (NSException *)renderObject:(id)_object inContext:(WOContext *)_ctx;
- (BOOL)canRenderObject:(id)_object inContext:(WOContext *)_ctx;

/* render individual response types, auto-selected by renderObject:inContext: */

- (BOOL)renderSearchResult:(id)_object    inContext:(WOContext *)_ctx;
- (BOOL)renderLockToken:(id)_object       inContext:(WOContext *)_ctx;
- (BOOL)renderOptions:(id)_object         inContext:(WOContext *)_ctx;
- (BOOL)renderSubscription:(id)_object    inContext:(WOContext *)_ctx;
- (BOOL)renderPropPatchResult:(id)_object inContext:(WOContext *)_ctx;
- (BOOL)renderDeleteResult:(id)_object    inContext:(WOContext *)_ctx;
- (BOOL)renderUploadResult:(id)_object    inContext:(WOContext *)_ctx;
- (BOOL)renderPollResult:(id)_object      inContext:(WOContext *)_ctx;
- (BOOL)renderMkColResult:(id)_object     inContext:(WOContext *)_ctx;

@end

#endif /* __SoObjects_SoWebDAVRenderer_H__ */
