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

#include "NGLdapEntry.h"
#include "NGLdapAttribute.h"
#include "NSString+DN.h"
#import <EOControl/EOControl.h>
#include "common.h"

@implementation NGLdapEntry

- (id)initWithDN:(NSString *)_dn attributes:(NSArray *)_attrs {
  _dn = [_dn lowercaseString];
  self->dn         = [[[_dn dnComponents] componentsJoinedByString:@","] copy];
  self->attributes = _attrs;
  [self->attributes retain];

  return self;
}
- (id)init {
  [self release];
  return nil;
}

- (void)dealloc {
  [self->attributes release];
  [self->dn         release];
  [super dealloc];
}

/* distinguished name */

- (NSString *)dn {
  return self->dn;
}
- (NSString *)rdn {
  return [self->dn lastDNComponent];
}

/* class */

- (NSArray *)objectClasses {
  NGLdapAttribute *a;

  a = [self attributeWithName:@"objectclass"];
  
  return [[a allStringValues] sortedArrayUsingSelector:@selector(compare:)];
}

/* attributes */

- (unsigned)count {
  return [self->attributes count];
}

- (NSArray *)attributeNames {
  NSMutableArray  *ma;
  NSArray         *a;
  NSEnumerator    *e;
  NGLdapAttribute *attr;

  ma = [[NSMutableArray alloc] initWithCapacity:[self->attributes count]];

  e = [self->attributes objectEnumerator];
  while ((attr = [e nextObject]))
    [ma addObject:[attr attributeName]];
  
  a = [ma copy];
  [ma release];
  return [a autorelease];
}
- (NSDictionary *)attributes {
  NSMutableDictionary *md;
  NSDictionary    *d;
  NSEnumerator    *e;
  NGLdapAttribute *a;
  
  md = [[NSMutableDictionary alloc] initWithCapacity:[self->attributes count]];

  e = [self->attributes objectEnumerator];
  while ((a = [e nextObject]))
    [md setObject:a forKey:[a attributeName]];
  
  d = [md copy];
  [md release];
  return [d autorelease];
}

- (NGLdapAttribute *)attributeWithName:(NSString *)_name {
  NSEnumerator    *e;
  NGLdapAttribute *a;
  NSString        *upperName;

  if (_name == nil)
    return nil;

  upperName = [_name uppercaseString];
  e = [self->attributes objectEnumerator];

  while ((a = [e nextObject])) {
    if ([[[a attributeName] uppercaseString] isEqualToString:upperName])
      return a;
  }
  return nil;
}

- (NGLdapAttribute *)attributeWithName:(NSString *)_name
  language:(NSString *)_language
{
  NSEnumerator    *e;
  NGLdapAttribute *a;
  NGLdapAttribute *awl, *al;

  if (_language == nil)
    return [self attributeWithName:_name];

  awl = al = nil;
  e = [self->attributes objectEnumerator];
  while ((a = [e nextObject])) {
    if ([[a attributeBaseName] isEqualToString:_name]) {
      NSString *lang;
      
      if (al == nil) al = a;

      if ((lang = [a langSubtype])) {
        if ([lang isEqualToString:_language])
          return a;
      }
      else {
        awl = a;
      }
    }
  }
  if (awl) return awl;
  if (al)  return al;
  return nil;
}

/* LDIF */

- (NSString *)ldif {
  NSMutableString *ms;
  NSEnumerator    *names;
  NSString        *cname;
  
  ms = [NSMutableString stringWithCapacity:256];

  /* add DN to LDIF */
  [ms appendString:@"DN: "];
  [ms appendString:[self dn]];
  [ms appendString:@"\n"];
  
  /* add attributes */
  names = [[self attributeNames] objectEnumerator];
  while ((cname = [names nextObject])) {
    NGLdapAttribute *attr;
    
    if ((attr = [self attributeWithName:cname])) {
      NSEnumerator *values;
      NSString *value;

      values = [attr stringValueEnumerator];
      while ((value = [values nextObject])) {
        [ms appendString:cname];
        [ms appendString:@": "];
        [ms appendString:value];
        [ms appendString:@"\n"];
      }
    }
  }
  
  return ms;
}

/* key-value coding */

- (id)valueForKey:(NSString *)_key {
  return [self attributeWithName:_key];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [[[self class] alloc] initWithDN:self->dn attributes:self->attributes];
}

/* description */

- (NSString *)description {
  NSMutableString *s;
  
  s = [NSMutableString stringWithCapacity:100];
  [s appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  [s appendFormat:@" dn='%@'", [self dn]];
  
  [s appendString:@" attrs="];
  [s appendString:[[self attributes] description]];

  [s appendString:@">"];

  return s;
}

@end /* NGLdapEntry */
