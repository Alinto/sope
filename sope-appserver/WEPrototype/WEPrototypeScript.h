/*
  Copyright (C) 2005 Helge Hess

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

#ifndef __WEPrototypeScript_H__
#define __WEPrototypeScript_H__

#import <NGObjWeb/WODynamicElement.h>

/*
  WEPrototypeScript
  
  Generates a link to the direct action which delivers the prototype.js file.
  
  The method is also exposed as a class method so that other methods can
  trigger it. It will generate its content only once (protected by a context
  variable).
*/

@class WOContext, WOResponse;

@interface WEPrototypeScript : WODynamicElement
{
}

+ (BOOL)wasDeliveredInContext:(WOContext *)_ctx;
+ (void)markDeliveredInContext:(WOContext *)_ctx;
+ (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx;

@end

#endif /* __WEPrototypeScript_H__ */
