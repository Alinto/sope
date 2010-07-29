/*
  Copyright (C) 2000-2005 SKYRIX Software AG
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

#ifndef __NGObjWeb_WOContext_private_H__
#define __NGObjWeb_WOContext_private_H__

#include <NGObjWeb/WOContext.h>

@class WOComponent, WOSession, WOResponse, WOElement, WODynamicElement;

extern void WOContext_enterComponent
(WOContext *_ctx, WOComponent *_component, WOElement *element);
extern void WOContext_leaveComponent(WOContext *_ctx, WOComponent *_component);

@interface WOContext(NGObjWebInternal)

- (void)_addAwakeComponent:(WOComponent *)_component;

- (void)enterComponent:(WOComponent *)_component content:(WOElement *)_content;
- (void)leaveComponent:(WOComponent *)_component;
- (void)sleepComponents;
- (WOComponent *)parentComponent;
- (WODynamicElement *)componentContent;

- (void)setSession:(WOSession *)_session;
- (void)setNewSession:(WOSession *)_session;
- (void)setPage:(WOComponent *)_page;
- (void)setResponse:(WOResponse *)_response;

@end

@interface WOContext(FormSupport)

- (void)addActiveFormElement:(WOElement *)_formElement;
- (WOElement *)activeFormElement;

@end

#if !LIB_FOUNDATION_BOEHM_GC

@interface WOContext(DeallocNotifications)
/* dealloc observers are *not* retained !!! */
- (void)_objectWillDealloc:(id)_object;
- (void)addDeallocObserver:(id)_observer;
- (void)removeDeallocObserver:(id)_observer;
@end

#endif

#endif /* __NGObjWeb_WOContext_private_H__ */
