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

#include "NGLdapAttribute.h"
#include "common.h"

@implementation NGLdapAttribute

- (id)initWithAttributeName:(NSString *)_name values:(NSArray *)_values {
  self->name   = [_name   copy];
  self->values = [_values copy];
  return self;
}
- (id)initWithAttributeName:(NSString *)_name {
  return [self initWithAttributeName:_name values:nil];
}

- (void)dealloc {
  [self->name   release];
  [self->values release];
  [super dealloc];
}

/* attribute name operations */

- (NSString *)attributeName {
  return self->name;
}

+ (NSString *)baseNameOfAttributeName:(NSString *)_attrName {
  NSRange r;
  
  r = [_attrName rangeOfString:@";"];
  if (r.length == 0) return _attrName;
  return [_attrName substringToIndex:r.location];
}
- (NSString *)attributeBaseName {
  return [[self class] baseNameOfAttributeName:[self attributeName]];
}

+ (NSArray *)subtypesOfAttributeName:(NSString *)_attrName {
  NSArray *parts;
  
  parts = [_attrName componentsSeparatedByString:@";"];

  return [parts count] > 1
    ? [parts subarrayWithRange:NSMakeRange(1, [parts count] - 1)]
    : (NSArray *)[NSArray array];
}

- (NSArray *)subtypes {
  return [[self class] subtypesOfAttributeName:[self attributeName]];
}

- (BOOL)hasSubtype:(NSString *)_subtype {
  NSString *attrName;
  
  if (_subtype == nil)
    return NO;
  
  attrName = [self attributeName];
  _subtype = [NSString stringWithFormat:@";%@;", _subtype];
  
  return [attrName rangeOfString:_subtype].length > 0 ? YES : NO;
}

- (NSString *)langSubtype {
  NSString *attrName;
  NSRange  r;
  
  attrName = [self attributeName];
  r = [attrName rangeOfString:@";lang-"];
  if (r.length == 0) return nil;
  
  attrName = [attrName substringFromIndex:(r.location + 1)];
  
  r = [attrName rangeOfString:@";"];
  if (r.length > 0) attrName = [attrName substringToIndex:r.location];
  
  return attrName;
}

/* values */

- (unsigned)count {
  return [self->values count];
}

- (void)addValue:(NSData *)_value {
  self->didChange = YES;
  
  if (self->values == nil)
    self->values = [[NSArray alloc] initWithObjects:&_value count:1];
  else {
    NSArray *tmp;

    tmp = self->values;
    self->values = [[tmp arrayByAddingObject:_value] retain];
    [tmp release];
  }
}

- (NSArray *)allValues {
  return self->values;
}
- (NSEnumerator *)valueEnumerator {
  return [self->values objectEnumerator];
}

- (void)addStringValue:(NSString *)_value {
  NSData *d;

  d = [_value dataUsingEncoding:NSUTF8StringEncoding];
  
  [self addValue:d];
}

- (void)catchedDecodeException:(NSException *)_exception {
  fprintf(stderr, "Got exception %s decoding NSUTF8StringEncoding, "
          "use defaultCStringEncoding", [[_exception description] cString]);
}
- (NSString *)stringFromData:(NSData *)_data {
  static NSStringEncoding enc = 0;
  NSString *s;
  
  if (enc == 0) enc = [NSString defaultCStringEncoding];
  
  if (_data == nil) return nil;
  NS_DURING
    s = [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding];
  NS_HANDLER {
    [self catchedDecodeException:localException];
    s = nil;
  }
  NS_ENDHANDLER;
  if (s == nil)
    s = [[NSString alloc] initWithData:_data encoding:enc];

  return s;
}

- (NSString *)stringValueAtIndex:(unsigned)_idx {
  NSData *data;
  
  data = [[self allValues] objectAtIndex:_idx];
  if (![data isNotNull])
    return nil;
  
  return [[self stringFromData:data] autorelease];
}

- (NSArray *)allStringValues {
  unsigned cnt;

  if ((cnt = [self count]) == 0) {
    return [NSArray array];
  }
  else if (cnt == 1) {
    NSString *s;
    NSData   *data;
    NSArray  *a;

    data = [[self allValues] objectAtIndex:0];
    
    if (![data isNotNull])
      return nil;
    
    s = [self stringFromData:data];
    if (s)
      {
        a = [[NSArray alloc] initWithObjects:&s count:1];
        [s release];
        return [a autorelease];
      }
    else
      {
        [self errorWithFormat: @"cound not convert value of %@ to string", [self attributeName]];
        return nil;
      }
  }
  else {
    id       *objs;
    unsigned i;
    NSArray  *vals, *a;
    NSData *data;

    vals = [self allValues];
    
    objs = calloc(cnt, sizeof(id));
    for (i = 0; i < cnt; i++) {

      objs[i] = nil;	
      data = [vals objectAtIndex: i];
      
      if (data)
	objs[i] = [self stringFromData: data];

      if (!objs[i]) {
	NSLog(@"missing data for value at index %i", i);
	objs[i] = [[NSString alloc] initWithString: @""];
      }
    }
    
    a = [[NSArray alloc] initWithObjects:objs count:cnt];

    for (i = 0; i < cnt; i++)
      [objs[i] release];
    
    free(objs); objs = NULL;

    return [a autorelease];
  }
}
- (NSEnumerator *)stringValueEnumerator {
  return [[self allStringValues] objectEnumerator];
}

/* NSObject */
- (BOOL) isEqual: (id)aAttribute
{
  BOOL rc = NO;
  NSArray *otherValues;
  id value, otherValue;
  NSUInteger count, max;

  if (aAttribute == self)
    rc = YES;
  else
    {
      if ([name isEqualToString: [aAttribute attributeName]])
        {
          max = [values count];
          otherValues = [aAttribute allValues];
          if (max == [otherValues count])
            {
              rc = YES;
              for (count = 0; rc && count < max; count++)
                {
                  value = [values objectAtIndex: count];
                  otherValue = [otherValues objectAtIndex: count];
                  if (value != otherValue && ![value isEqual: otherValue])
                    rc = NO;
                }
            }
        }
    }

  return rc;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [[[self class] alloc] initWithAttributeName:self->name
                               values:self->values];
}

/* description */

- (NSString *)stringValue {
  NSMutableString *ms;
  NSString     *s;
  NSEnumerator *e;
  id           value;
  BOOL         isFirst;

  ms = [[NSMutableString alloc] initWithCapacity:100];
  
  e = [self stringValueEnumerator];
  isFirst = YES;
  while ((value = [e nextObject])) {
    if (isFirst) isFirst = NO;
    else [ms appendString:@","];
    [ms appendString:[value description]];
  }
  
  s = [ms copy];
  [ms release];
  return [s autorelease];
}

- (NSString *)description {
  NSMutableString *s;
  
  s = [NSMutableString stringWithCapacity:100];
  [s appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  [s appendFormat:@" name='%@'", [self attributeName]];
  [s appendString:@" values="];
  [s appendString:[self stringValue]];
  [s appendString:@">"];

  return s;
}

@end /* NGLdapAttribute */
