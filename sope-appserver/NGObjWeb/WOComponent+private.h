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

#ifndef __NGObjWeb_WOComponent_private_H__
#define __NGObjWeb_WOComponent_private_H__

#import <NGObjWeb/WOComponent.h>

@class NSString;
@class WOElement, WOTemplate, WOSession, WOApplication, WOContext;

@interface WOComponent(PrivateMethods)

- (void)setApplication:(WOApplication *)_application;

/* URL generation */

- (NSString *)componentActionURLForContext:(WOContext *)_ctx;

/* activity */

- (void)_awakeWithContext:(WOContext *)_ctx;
- (void)_sleepWithContext:(WOContext *)_ctx;
- (void)_setContext:(WOContext *)_ctx;

/* used by WOApplication: */
- (WOElement *)_woComponentTemplate;

/* used by WOComponentReference: */
- (void)setName:(NSString *)_name;
- (void)setBindings:(NSDictionary *)_bindings;
- (void)setSubComponents:(NSDictionary *)_dictionary;
- (void)setParent:(WOComponent *)_parent;
- (WOComponent *)childComponentWithName:(NSString *)_name;

extern void WOComponent_syncFromParent(WOComponent *child, WOComponent *parent);
extern void WOComponent_syncToParent(WOComponent *child, WOComponent *parent);

@end /* WOComponent(PrivateMethods) */

#endif /* __NGObjWeb_WOComponent_private_H__ */
