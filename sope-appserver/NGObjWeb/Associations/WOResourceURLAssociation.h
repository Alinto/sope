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

#ifndef __NGObjWeb_WOResourceURLAssociation_H__
#define __NGObjWeb_WOResourceURLAssociation_H__

#include <NGObjWeb/WOAssociation.h>

/*
  WOResourceURLAssociation
  
  Lookup an association value as a resource URL. Eg for a binding:
    <img rsrc:src="image.gif" />
  
  "image.gif" will be looked up using WOResourceManager and the URL for the
  image will be returned.
  
  Note: you cannot trigger that association in a .wo wrapper template.
*/

@class NSString;

@interface WOResourceURLAssociation : WOAssociation < NSCopying >
{
@private
  NSString *resourceName;
  NSString *frameworkName;
}

/* accessors */

- (NSString *)resourceName;

/* value */

- (BOOL)isValueConstant;
- (BOOL)isValueSettable;

@end

#endif /* __NGObjWeb_WOResourceURLAssociation_H__ */
