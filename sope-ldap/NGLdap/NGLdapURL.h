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

#ifndef __NGLdapURL_H__
#define __NGLdapURL_H__

#import <Foundation/NSObject.h> // required by gstep-base
#import <Foundation/NSURL.h>

@class NSString, NSArray, NSHost, NSEnumerator;
@class NGLdapConnection, NGLdapEntry;

// ldap://hostport/dn[?attributes[?scope[?filter]]]

@interface NGLdapURL : NSURL < NSCopying >
{
  NSString *host;
  int      port;
  NSString *base;
  int      scope;
  NSString *filter;
  NSArray  *attributes;
}

+ (id)ldapURLWithString:(NSString *)_url;
- (id)initWithString:(NSString *)_url; // designated initializer

/* accessors */

- (NSString *)hostName;
- (NSHost *)host;

- (int)port;
- (NSString *)baseDN;
- (int)scope;
- (NSString *)searchFilter;
- (NSArray *)attributes;

/* query */

- (NGLdapConnection *)openConnection;
- (NSEnumerator *)fetchEntries;
- (NGLdapEntry *)fetchEntry;

/* url */

- (NSString *)urlString;

@end

#endif /* __NGLdapURL_H__ */
