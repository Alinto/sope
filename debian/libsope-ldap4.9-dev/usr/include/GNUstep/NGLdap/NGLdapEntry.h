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

#ifndef __NGLdapEntry_H__
#define __NGLdapEntry_H__

#import <Foundation/NSObject.h>

@class NSString, NSDictionary, NSArray;
@class NGLdapAttribute;

@interface NGLdapEntry : NSObject < NSCopying >
{
  NSString *dn;
  NSArray  *attributes;
}

- (id)initWithDN:(NSString *)_dn attributes:(NSArray *)_attrs;

/* distinguished name */

- (NSString *)dn;
- (NSString *)rdn; /* relative dn */

/* class */

- (NSArray *)objectClasses;

/* attributes */

- (NGLdapAttribute *)attributeWithName:(NSString *)_name;
- (NGLdapAttribute *)attributeWithName:(NSString *)_name
  language:(NSString *)_language;

- (NSArray *)attributeNames;
- (NSDictionary *)attributes;
- (unsigned)count;

/* LDIF */

- (NSString *)ldif;

@end

#endif /* __NGLdapEntry_H__ */
