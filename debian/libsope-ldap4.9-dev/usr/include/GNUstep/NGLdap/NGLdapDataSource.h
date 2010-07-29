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

#ifndef __NGLdapDataSource_H__
#define __NGLdapDataSource_H__

#import <EOControl/EODataSource.h>

@class EOFetchSpecification;
@class NGLdapConnection;

/*
  supported keys:
    
    any LDAP attribute name
    
  supported fetch hints:

    NSFetchKeys  - array of NSString's denoting the keys to fetch
    NSFetchScope - [NSFetchScopeBase|NSFetchScopeOneLevel|NSFetchScopeSubTree]
*/

@interface NGLdapDataSource : EODataSource
{
  NGLdapConnection     *ldap;
  EOFetchSpecification *fspec;
  NSString             *searchBase;
}

- (id)initWithLdapConnection:(NGLdapConnection *)_con searchBase:(NSString *)_dn;

/* accessors */

- (void)setFetchSpecification:(EOFetchSpecification *)_fspec;
- (EOFetchSpecification *)fetchSpecification;

/* operations */

- (NSArray *)fetchObjects;

- (NSString *)searchBase;

@end /* NGLdapDataSource */

#endif /* __NGLdapDataSource_H__ */
