/* 
   NSString+PGVal.m

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

#import <Foundation/NSString.h>
#include "PostgreSQL72Channel.h"
#include "common.h"

@implementation NSNumber(PostgreSQL72Values)

static BOOL     debugOn       = NO;
static Class    NSNumberClass = Nil;
static NSNumber *yesNum       = nil;
static NSNumber *noNum        = nil;

+ (id)valueFromCString:(const char *)_cstr length:(int)_length
  postgreSQLType:(NSString *)_type
  attribute:(EOAttribute *)_attribute
  adaptorChannel:(PostgreSQL72Channel *)_channel
{
  // TODO: can we avoid the lowercaseString?
  unsigned len;
  unichar  c1;

  if ((len = [_type length]) == 0)
    return nil;

  if (NSNumberClass == Nil) NSNumberClass = [NSNumber class];
  
  c1 = [_type characterAtIndex:0];
  switch (c1) {
  case 'f': case 'F': {
    if (len < 5)
      break;
    if ([[_type lowercaseString] hasPrefix:@"float"])
      return [NSNumberClass numberWithDouble:atof(_cstr)];
    break;
  }
  case 's': case 'S': {
    if (len < 8)
      break;
    if ([[_type lowercaseString] hasPrefix:@"smallint"])
      return [NSNumberClass numberWithShort:atoi(_cstr)];
    break;
  }
  case 'i': case 'I': {
    if (len < 3)
      break;
    if ([[_type lowercaseString] hasPrefix:@"int"])
      return [NSNumberClass numberWithInt:atoi(_cstr)];
  }
  case 'b': case 'B': {
    if (len < 4)
      break;
    if (![[_type lowercaseString] hasPrefix:@"bool"])
      break;
    
    if (yesNum == nil) yesNum = [[NSNumberClass numberWithBool:YES] retain];
    if (noNum  == nil) noNum  = [[NSNumberClass numberWithBool:NO]  retain];
    
    if (_length == 0)
      return noNum;
    
    switch (*_cstr) {
    case 't': case 'T':
    case 'y': case 'Y':
    case '1':
      return yesNum;
    default:
      return noNum;
    }
  }
  }
  return nil;
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
  // TODO: can we avoid the lowercaseString?
  unsigned len;
  unichar  c1;

  if (debugOn)
    NSLog(@"%s(type=%@,attr=%@)", __PRETTY_FUNCTION__, _type, _attribute);
  
  if ((len = [_type length]) == 0) {
    if (debugOn) NSLog(@"  no type, return string");
    return [self stringValue];
  }
  if (len < 4) { /* apparently this is 'INT'? */
    if (debugOn) NSLog(@"  type len < 4 (%@), return string", _type);
#if GNUSTEP_BASE_LIBRARY
    /*
       on gstep-base -stringValue of bool's return YES or NO, which seems to
       be different on Cocoa and liBFoundation.
    */
    {
      static Class BoolClass = Nil;
      
      if (BoolClass == Nil) BoolClass = NSClassFromString(@"NSBoolNumber");
      if ([self isKindOfClass:BoolClass])
	return [self boolValue] ? @"1" : @"0";
    }
#endif
    return [self stringValue];
  }
  
  c1 = [_type characterAtIndex:0];
  if (debugOn) NSLog(@"  typecode '%c' ...", c1);
  switch (c1) {
  case 'b': case 'B':
    if (![[_type lowercaseString] hasPrefix:@"bool"])
      break;
    return [self boolValue] ? @"true" : @"false";
    
  case 'm': case 'M': {
    if (![[_type lowercaseString] hasPrefix:@"money"])
      break;
    return [@"$" stringByAppendingString:[self stringValue]];
  }
  
  case 'c': case 'C':
  case 't': case 'T':
  case 'v': case 'V': {
    static NSMutableString *ms = nil; // reuse mstring, THREAD
    
    _type = [_type lowercaseString];
    if (!([_type hasPrefix:@"char"] ||
	  [_type hasPrefix:@"varchar"] ||
	  [_type hasPrefix:@"text"]))
      break;
    
    // TODO: can we get this faster?!
    if (ms == nil) ms = [[NSMutableString alloc] initWithCapacity:256];
    [ms setString:@"'"];
    [ms appendString:[self stringValue]];
    [ms appendString:@"'"];
    return [[ms copy] autorelease];
  }
  }
  return [self stringValue];
}

@end /* NSNumber(PostgreSQL72Values) */
