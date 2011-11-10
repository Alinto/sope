/* 
   NSString+PGVal.m

   Copyright (C) 1999      MDlink online service center GmbH and Helge Hess
   Copyright (C) 2000-2006 SKYRIX Software AG and Helge Hess

   Author: Helge Hess (helge.hess@opengroupware.org)

   This file is part of the PostgreSQL Adaptor Library

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#include "PostgreSQL72Channel.h"
#include "common.h"

@implementation NSString(PostgreSQL72Values)

static Class NSStringClass = Nil;
static Class EOExprClass   = Nil;
static id    (*ctor)(id, SEL, const char *) = NULL;

+ (id)valueFromCString:(const char *)_cstr length:(int)_length
  postgreSQLType:(NSString *)_type
  attribute:(EOAttribute *)_attribute
  adaptorChannel:(PostgreSQL72Channel *)_channel
{
  // TODO: would be better if this would return a retained object to avoid
  //       the dreaded autorelease pool
  if (_cstr  == NULL) return nil;
  if (*_cstr == '\0') return @"";
  
  if (NSStringClass == Nil) NSStringClass = [NSString class];

  if (ctor == NULL) {
    ctor = (void *)
      [NSStringClass methodForSelector:@selector(stringWithUTF8String:)];
  }
  
  // TODO: cache IMP of selector
  return ctor != NULL
    ? ctor(NSStringClass, @selector(stringWithUTF8String:), _cstr)
    : [NSStringClass stringWithUTF8String:_cstr];
}

+ (id)valueFromBytes:(const void *)_bytes length:(int)_length
  postgreSQLType:(NSString *)_type
  attribute:(EOAttribute *)_attribute
  adaptorChannel:(PostgreSQL72Channel *)_channel
{
#if COCOA_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
  NSLog(@"%s: not implemented!", __PRETTY_FUNCTION__);
  return nil;
#else
  return [self notImplemented:_cmd];
#endif
}

- (NSString *)stringValueForPostgreSQLType:(NSString *)_type
  attribute:(EOAttribute *)_attribute
{
  // TODO: all this looks slow ...
  unsigned len;
  unichar  c1;
  
  if ((len = [_type length]) == 0)
    return self;
  
  c1 = [_type characterAtIndex:0];
  switch (c1) {
  case 'c': case 'C':
  case 'v': case 'V':
  case 't': case 'T': {
    NSString           *s;
    EOQuotedExpression *expr;
    
    if (len < 4)
      return self;
    
    _type = [_type lowercaseString]; // looks slow
  
    if (!([_type hasPrefix:@"char"] ||
	[_type hasPrefix:@"varchar"] ||
	[_type hasPrefix:@"text"]))
      break;
    
    /* TODO: creates too many autoreleased strings :-( */
    
    if (EOExprClass == Nil) EOExprClass = [EOQuotedExpression class];
    expr = [[EOExprClass alloc] initWithExpression:self quote:@"'" escape:@"''"];
    s = [[expr expressionValueForContext:nil] retain];
    [expr release];
    return [s autorelease];
  }
  case 'm': case 'M': {
    if (len < 5) {
      if ([[_type lowercaseString] hasPrefix:@"money"])
	return [@"$" stringByAppendingString:self];
    }
    break;
  }
  }
  return self;
}

@end /* NSString(PostgreSQL72Values) */
