/*
  Copyright (C) 2000-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess

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

#include "NGLdapURL.h"
#include "NGLdapConnection.h"
#include "NGLdapEntry.h"
#include "EOQualifier+LDAP.h"
#include <NGExtensions/NSString+misc.h>
#include "common.h"
#include <string.h>

@implementation NGLdapURL

+ (id)ldapURLWithString:(NSString *)_url {
  if (!ldap_is_ldap_url((char *)[_url UTF8String]))
    return nil;

  return [[[self alloc] initWithString:_url] autorelease];
}

- (id)initWithString:(NSString *)_url {
  LDAPURLDesc *urld = NULL;
  unsigned attrCount, i;
  int err;

  self->scope = -1;

  if ((err = ldap_url_parse((char *)[_url UTF8String], &urld)) != 0) {
    [self release];
    return nil;
  }
  if (urld == NULL) {
    [self release];
    return nil;
  }
    
  self->host   = [[NSString alloc] initWithCString:urld->lud_host];
  self->port   = urld->lud_port;
  self->base   = [[NSString alloc] initWithCString:urld->lud_dn];
  self->scope  = urld->lud_scope;
  self->filter = [[NSString alloc] initWithCString:urld->lud_filter];
  
  if (urld != NULL && urld->lud_attrs != NULL) {
    register char *tmp, **a;
    a = urld->lud_attrs;
    for (i = 0; (tmp = a[i]); i++)
      ;
    attrCount = i;
  }
  else
    attrCount = 0;
    
  if (attrCount > 0) {
    id *attrs;

    attrs = calloc(attrCount+1, sizeof(id));
    
    for (i = 0; i < attrCount; i++)
      attrs[i] = [[NSString alloc] initWithCString:urld->lud_attrs[i]];
      
    self->attributes = [[NSArray alloc] initWithObjects:attrs count:attrCount];

    for (i = 0; i < attrCount; i++)
      [attrs[i] release];
    if (attrs) free(attrs);
  }
  
  if (urld) ldap_free_urldesc(urld);
  
  return self;
}

- (id)init {
  return [self initWithString:nil];
}

- (void)dealloc {
  [self->host       release];
  [self->base       release];
  [self->filter     release];
  [self->attributes release];
  [super dealloc];
}

/* accessors */

- (NSString *)hostName {
  return self->host;
}
- (NSHost *)host {
  return [NSHost hostWithName:[self hostName]];
}

- (int)port {
  return self->port;
}
- (NSString *)baseDN {
  return self->base;
}
- (int)scope {
  return self->scope;
}

- (NSString *)searchFilter {
  return self->filter;
}
- (EOQualifier *)searchFilterQualifier {
  EOQualifier *q;
  
  if (self->filter == nil)
    return nil;

  q = nil;
  q = [[EOQualifier alloc] initWithLDAPFilterString:self->filter];

  return [q autorelease];
}

- (NSArray *)attributes {
  return self->attributes;
}

/* perform fetches */

- (NGLdapConnection *)openConnection {
  NGLdapConnection *con;

  con = [[NGLdapConnection alloc] initWithHostName:[self hostName]
                                  port:[self port] ? [self port] : 389];
  return [con autorelease];
}

- (NSEnumerator *)fetchEntries {
  NGLdapConnection *con;

  if ((con = [self openConnection]) == nil)
    return nil;
  
  switch (self->scope) {
    case LDAP_SCOPE_ONELEVEL:
      return [con flatSearchAtBaseDN:[self baseDN]
                  qualifier:[self searchFilterQualifier]
                  attributes:[self attributes]];
      
    case LDAP_SCOPE_SUBTREE:
      return [con deepSearchAtBaseDN:[self baseDN]
                  qualifier:[self searchFilterQualifier]
                  attributes:[self attributes]];
      
    case LDAP_SCOPE_BASE:
      return [con baseSearchAtBaseDN:[self baseDN]
                  qualifier:[self searchFilterQualifier]
                  attributes:[self attributes]];
  }

  return nil;
}
- (NGLdapEntry *)fetchEntry {
  return [[self fetchEntries] nextObject];
}

/* url */

- (NSString *)urlString {
  NSMutableString *s;
  NSString *r;
  
  s = [[NSMutableString alloc] initWithCapacity:200];

  [s appendString:@"ldap://"];
  [s appendString:self->host != nil ? self->host : (NSString *)@"localhost"];
  if (self->port > 0) [s appendFormat:@":%i", self->port];

  [s appendString:@"/"];
  [s appendString:[self->base stringByEscapingURL]];
  
  if ((self->attributes != nil) || (self->scope!=-1) || (self->filter != nil)){
    NSString *is;
    [s appendString:@"?"];
    is = [self->attributes componentsJoinedByString:@","];
    [s appendString:[is stringByEscapingURL]];
  }
  if ((self->scope != -1) || (self->filter != nil)) {
    [s appendString:@"?"];
    switch (self->scope) {
      case LDAP_SCOPE_ONELEVEL:
        [s appendString:@"one"];
        break;
      case LDAP_SCOPE_SUBTREE:
        [s appendString:@"sub"];
        break;
      case LDAP_SCOPE_BASE:
      default:
        [s appendString:@"base"];
        break;
    }
  }
  if ([self->filter isNotEmpty]) {
    [s appendString:@"?"];
    [s appendString:[self->filter stringByEscapingURL]];
  }

  r = [[s copy] autorelease];
  [s release]; s = nil;
  return r;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [[[self class] allocWithZone:_zone] initWithString:[self urlString]];
}

/* description */

- (NSString *)description {
  return [self urlString];
}

@end /* NGLdapURL */
