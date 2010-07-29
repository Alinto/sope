/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#ifndef __SoObjects_SoPageInvocation_H__
#define __SoObjects_SoPageInvocation_H__

#if COMPILING_NGOBJWEB
#  include <SoObjects/SoActionInvocation.h>
#else
#  include <NGObjWeb/SoActionInvocation.h>
#endif

/*
  An invocation object for WOComponent based SoClass methods.
  
  If the invocation is bound, the component is instantiated and initialized,
  if it is called, the "actionName" is called and the result is returned or
  if no "actionName" is set, the component itself is returned.
*/

@class NSString, NSDictionary;
@class WOComponent;
@class SoProduct;

@interface SoPageInvocation : SoActionInvocation
{
  SoProduct *product; /* non-retained ! */
}

- (id)initWithPageName:(NSString *)_pageName;
- (id)initWithPageName:(NSString *)_pageName actionName:(NSString *)_action;
- (id)initWithPageName:(NSString *)_pageName actionName:(NSString *)_action
  product:(SoProduct *)_product;

/* accessors */

- (NSString *)pageName;

@end

#endif /* __SoObjects_SoPageInvocation_H__ */
