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

#include <NGObjWeb/WOxElemBuilder.h>
#include "common.h"

@implementation WOxTagClassElemBuilder

- (Class)classForElement:(id<DOMElement>)_element {
  return Nil;
}

- (WOElement *)buildNextElement:(id<DOMElement>)_elem templateBuilder:(id)_b {
  if (self->nextBuilder != nil)
    return [self->nextBuilder buildElement:_elem templateBuilder:_b];
  
  [self logWithFormat:
	  @"did not find dynamic element class for DOM element %@", _elem];
  return nil;
}

- (WOElement *)buildElement:(id<DOMElement>)_element templateBuilder:(id)_b {
  Class clazz;
  
  if ((clazz = [self classForElement:_element]) == Nil)
    return [self buildNextElement:_element templateBuilder:_b];
  
  return [[clazz alloc] initWithElement:_element templateBuilder:_b];
}

@end /* WOxTagClassElemBuilder */
