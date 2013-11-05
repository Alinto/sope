/* 
   NSData+PGVal.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess
   Copyright (C) 2000-2005 SKYRIX Software AG and Helge Hess

   Author: Helge Hess (helge.hess@opengroupware.org)

   This file is part of the PostgreSQL72 Adaptor Library

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

#import <Foundation/NSData.h>
#include "PostgreSQL72Values.h"
#include "PostgreSQL72Channel.h"
#include "common.h"

@implementation NSData(PostgreSQL72Values)

static BOOL   doDebug    = NO;
static NSData *EmptyData = nil;

+ (id)valueFromCString:(const char *)_cstr length:(int)_length
  postgreSQLType:(NSString *)_type
  attribute:(EOAttribute *)_attribute
  adaptorChannel:(PostgreSQL72Channel *)_channel
{
  if (_length == 0) {
    if (EmptyData == nil) EmptyData = [[NSData alloc] init];
    return EmptyData;
  }
  return [[[self alloc] initWithBytes:_cstr length:_length] autorelease];
}

+ (id)valueFromBytes:(const void *)_bytes length:(int)_length
  postgreSQLType:(NSString *)_type
  attribute:(EOAttribute *)_attribute
  adaptorChannel:(PostgreSQL72Channel *)_channel
{
  if (_length == 0) {
    if (EmptyData == nil) EmptyData = [[NSData alloc] init];
    return EmptyData;
  }
  return [[[self alloc] initWithBytes:_bytes length:_length] autorelease];
}

- (NSString *)stringValueForPostgreSQLType:(NSString *)_type
  attribute:(EOAttribute *)_attribute
{
  // TODO: UNICODE
  // TODO: this method looks slow
  // example type: "VARCHAR(4000)"
  static NSStringEncoding enc = 0;
  NSString *str, *t;
  unsigned len;
  unichar  c1;
  
  if ((len = [self length]) == 0)
    return @"";
  
  if (enc == 0) {
    // enc = [NSString defaultCStringEncoding];
    enc = NSUTF8StringEncoding;
    NSLog(@"Note: PostgreSQL adaptor using '%@' encoding for data=>string "
	  @"conversion.",
	  [NSString localizedNameOfStringEncoding:enc]);
  }
  
  str = [[NSString alloc] initWithData:self encoding:enc];

  if (doDebug) {
    NSLog(@"Note: made string (len=%i) for data (len=%i), type %@",
	  [str length], [self length], _type);
  }
  
  if ((len = [_type length]) == 0) {
    NSLog(@"WARNING(%s): missing type for data=>string conversion!",
	  __PRETTY_FUNCTION__);
    return [str autorelease];
  }
  
  c1 = [_type characterAtIndex:0];
  switch (c1) {
  case 'c': case 'C': // char
  case 'v': case 'V': // varchar
  case 'm': case 'M': // money
  case 't': case 'T': // text
    t = [_type lowercaseString];
    if ([t hasPrefix:@"char"]    ||
	[t hasPrefix:@"varchar"] ||
	[t hasPrefix:@"money"]   ||
	[t hasPrefix:@"text"]) {
      if (doDebug) NSLog(@"  converting type: %@", t);
      t = [[str stringValueForPostgreSQLType:_type 
		attribute:_attribute] copy];
      [str release];
      if (doDebug) NSLog(@"  result len %i", [t length]);
      return [t autorelease];
    }
  }
  
  NSLog(@"WARNING(%s): no processing of type '%@' for "
	@"data=>string conversion!",
	__PRETTY_FUNCTION__, _type);
  return [str autorelease];;
}

@end /* NSData(PostgreSQL72Values) */
