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

#ifndef __SoObjects_SoLookupAssociation_H__
#define __SoObjects_SoLookupAssociation_H__

#include <NGObjWeb/WOAssociation.h>

/*
  SoLookupAssociation
  
  This association is experimental, behaviour isn't fixed yet.
  TODO: this should probably traverse relative to the clientObject, not to
        the component?!
        Or we might want to support keypath _and_ lookup path, like:
           "component.context.clientObject:+/abc/toolbar/"
  
  Currently it traverses the path being passed in relative to the component:
    [_component traversePathArray:self->traversalPath 
	        acquire:self->acquire];

  If you prefix the path with a "+" acquisition will be turned on, eg:
    <var:string lookup:value="+toolbar/label" />

  Namespace: http://www.skyrix.com/od/so-lookup
*/

@class NSArray;

@interface SoLookupAssociation : WOAssociation
{
  NSArray *traversalPath;
  BOOL    acquire;
}

/* accessors */

- (NSArray *)traversalPath;
- (BOOL)doesAcquire;

/* value */

- (BOOL)isValueConstant; // returns NO
- (BOOL)isValueSettable; // returns NO

@end

#endif /* __SoObjects_SoLookupAssociation_H__ */
