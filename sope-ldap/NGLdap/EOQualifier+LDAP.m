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

#include "EOQualifier+LDAP.h"
#include "common.h"

#if NeXT_RUNTIME
#define sel_eq(sel1, sel2) ((sel1)) == ((sel2))
#endif

@interface EOQualifier(LDAPPrivates)

- (void)addToLDAPFilterString:(NSMutableString *)_s inContext:(id)_ctx;

@end

@implementation EOQualifier(LDAP)

- (id)initWithLDAPFilterString:(NSString *)_filter {
  return nil;
}

- (void)addToLDAPFilterString:(NSMutableString *)_s inContext:(id)_ctx {
  [self doesNotRecognizeSelector:_cmd]; // subclass
}

- (NSString *)ldapFilterString {
  NSMutableString *s;
  NSString *is;

  s = [[NSMutableString alloc] initWithCapacity:100];
  [self addToLDAPFilterString:s inContext:nil];
  is = [s copy];
  [s release];
  return [is autorelease];
}

@end /* EOQualifier(LDAP) */

@implementation EOAndQualifier(LDAP)

- (void)addToLDAPFilterString:(NSMutableString *)_s inContext:(id)_ctx {
  unsigned i, cnt;
  NSArray  *array;

  array = [self qualifiers];
  cnt   = [array count];
  
  [_s appendString:@"(&"];
  
  for (i = 0; i < cnt; i++) {
    EOQualifier *sq;

    sq = [array objectAtIndex:i];
    [sq addToLDAPFilterString:_s inContext:_ctx];
  }
  
  [_s appendString:@")"];
}

@end /* EOAndQualifier(LDAP) */

@implementation EOOrQualifier(LDAP)

- (void)addToLDAPFilterString:(NSMutableString *)_s inContext:(id)_ctx {
  unsigned i, cnt;
  NSArray  *array;

  array = [self qualifiers];
  cnt   = [array count];
  
  [_s appendString:@"(|"];
  
  for (i = 0; i < cnt; i++) {
    EOQualifier *sq;

    sq = [array objectAtIndex:i];
    [sq addToLDAPFilterString:_s inContext:_ctx];
  }
  
  [_s appendString:@")"];
}

@end /* EOOrQualifier(LDAP) */

@implementation EONotQualifier(LDAP)

- (void)addToLDAPFilterString:(NSMutableString *)_s inContext:(id)_ctx {
  [_s appendString:@"(!"];
  [[self qualifier] addToLDAPFilterString:_s inContext:_ctx];
  [_s appendString:@")"];
}

@end /* EONotQualifier(LDAP) */

@implementation EOKeyValueQualifier(LDAP)

- (void)addToLDAPFilterString:(NSMutableString *)_s inContext:(id)_ctx {
  // TODO: patterns are treated like regular strings or the reverse?
  SEL sel;

  sel = [self selector];

  if (sel_eq(sel,  EOQualifierOperatorNotEqual))
    [_s appendString:@"(!"];
  
  [_s appendString:@"("];
  [_s appendString:[self key]];

  if (sel_eq(sel,  EOQualifierOperatorEqual))
    [_s appendString:@"="];
  else if (sel_eq(sel,  EOQualifierOperatorNotEqual))
    [_s appendString:@"="];
  else if (sel_eq(sel,  EOQualifierOperatorLessThan))
    [_s appendString:@"<"];
  else if (sel_eq(sel,  EOQualifierOperatorGreaterThan))
    [_s appendString:@">"];
  else if (sel_eq(sel,  EOQualifierOperatorLessThanOrEqualTo))
    [_s appendString:@"<="];
  else if (sel_eq(sel,  EOQualifierOperatorGreaterThanOrEqualTo))
    [_s appendString:@">="];
  else if (sel_eq(sel,  EOQualifierOperatorContains))
    [_s appendString:@"=*"];
  else if (sel_eq(sel,  EOQualifierOperatorLike))
    [_s appendString:@"="];
  else if (sel_eq(sel,  EOQualifierOperatorCaseInsensitiveLike))
    [_s appendString:@"="];
  else {
    NSLog(@"UNKNOWN operator: %@", NSStringFromSelector([self selector]));
    [_s appendString:@"="];
  }

  [_s appendString:[[self value] description]];
  [_s appendString:@")"];
  
  if (sel_eq(sel,  EOQualifierOperatorNotEqual))
    [_s appendString:@")"];
}

@end /* EOKeyValueQualifier(LDAP) */

@implementation EOKeyComparisonQualifier(LDAP)

- (void)addToLDAPFilterString:(NSMutableString *)_s inContext:(id)_ctx {
  /* ldap supports no comparison operations on keys */
  SEL sel;

  sel = [self selector];

  if (sel_eq(sel,  EOQualifierOperatorNotEqual))
    [_s appendString:@"(!"];
  
  [_s appendString:@"("];
  [_s appendString:[self leftKey]];

  if (sel_eq(sel,  EOQualifierOperatorEqual))
    [_s appendString:@"="];
  else if (sel_eq(sel,  EOQualifierOperatorNotEqual))
    [_s appendString:@"="];
  else if (sel_eq(sel,  EOQualifierOperatorLessThan))
    [_s appendString:@"<"];
  else if (sel_eq(sel,  EOQualifierOperatorGreaterThan))
    [_s appendString:@">"];
  else if (sel_eq(sel,  EOQualifierOperatorLessThanOrEqualTo))
    [_s appendString:@"<="];
  else if (sel_eq(sel,  EOQualifierOperatorGreaterThanOrEqualTo))
    [_s appendString:@">="];
  else if (sel_eq(sel,  EOQualifierOperatorContains))
    [_s appendString:@"=*"];
  else if (sel_eq(sel,  EOQualifierOperatorLike))
    [_s appendString:@"="];
  else if (sel_eq(sel,  EOQualifierOperatorCaseInsensitiveLike))
    [_s appendString:@"="];
  else {
    NSLog(@"UNKNOWN operator: %@", NSStringFromSelector([self selector]));
    [_s appendString:@"="];
  }

  [_s appendString:[self rightKey]];
  [_s appendString:@")"];
  
  if (sel_eq(sel,  EOQualifierOperatorNotEqual))
    [_s appendString:@")"];
}

@end /* EOKeyComparisonQualifier(LDAP) */
