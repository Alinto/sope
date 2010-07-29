/*
  Copyright (C) 2005 Helge Hess

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

#include "NGVCardAddress.h"
#include "common.h"

@implementation NGVCardAddress

+ (int)version {
  return [super version] + 0 /* v0 */;
}
+ (void)initialize {
  NSAssert2([super version] == 0,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)initWithDictionary:(NSDictionary *)_plist group:(NSString *)_group 
  types:(NSArray *)_types arguments:(NSDictionary *)_a
{
  if ((self = [super initWithGroup:_group types:_types arguments:_a]) != nil) {
    self->pobox    = [[_plist objectForKey:@"pobox"]    copy];
    self->extadd   = [[_plist objectForKey:@"extadd"]   copy];
    self->street   = [[_plist objectForKey:@"street"]   copy];
    self->locality = [[_plist objectForKey:@"locality"] copy];
    self->region   = [[_plist objectForKey:@"region"]   copy];
    self->pcode    = [[_plist objectForKey:@"pcode"]    copy];
    self->country  = [[_plist objectForKey:@"country"]  copy];
  }
  return self;
}
- (id)initWithPropertyList:(id)_plist group:(NSString *)_group 
  types:(NSArray *)_types arguments:(NSDictionary *)_a
{
  return [self initWithDictionary:_plist
	       group:_group types:_types arguments:_a];
}

- (id)initWithGroup:(NSString *)_group types:(NSArray *)_types
  arguments:(NSDictionary *)_a
{
  return [self initWithPropertyList:nil 
	       group:_group types:_types arguments:_a];
}
- (id)init {
  return [self initWithPropertyList:nil group:nil types:nil arguments:nil];
}

- (void)dealloc {
  [self->pobox    release];
  [self->extadd   release];
  [self->street   release];
  [self->locality release];
  [self->region   release];
  [self->pcode    release];
  [self->country  release];
  [super dealloc];
}

/* accessors */

- (NSString *)pobox {
  return self->pobox;
}
- (NSString *)extadd {
  return self->extadd;
}
- (NSString *)street {
  return self->street;
}
- (NSString *)locality {
  return self->locality;
}
- (NSString *)region {
  return self->region;
}
- (NSString *)pcode {
  return self->pcode;
}
- (NSString *)country {
  return self->country;
}

/* fake being an array */

- (id)objectAtIndex:(unsigned)_idx {
  NSString *s;
  
  switch (_idx) {
  case 0: return (s = [self pobox])    ? s : (NSString *)[NSNull null];
  case 1: return (s = [self extadd])   ? s : (NSString *)[NSNull null];
  case 2: return (s = [self street])   ? s : (NSString *)[NSNull null];
  case 3: return (s = [self locality]) ? s : (NSString *)[NSNull null];
  case 4: return (s = [self region])   ? s : (NSString *)[NSNull null];
  case 5: return (s = [self pcode])    ? s : (NSString *)[NSNull null];
  case 6: return (s = [self country])  ? s : (NSString *)[NSNull null];
  }
  
  // TODO: throw exception
  return nil;
}
- (unsigned)count {
  return 7;
}

/* values */

- (NSString *)stringValue {
  return [self vCardString];
}

- (NSString *)xmlString {
  NSMutableString *ms;
  NSString *s;
  
  ms = [[NSMutableString alloc] initWithCapacity:256];
  [self appendXMLTag:@"pobox"    value:[self pobox]    to:ms];
  [self appendXMLTag:@"extadd"   value:[self extadd]   to:ms];
  [self appendXMLTag:@"street"   value:[self street]   to:ms];
  [self appendXMLTag:@"locality" value:[self locality] to:ms];
  [self appendXMLTag:@"region"   value:[self region]   to:ms];
  [self appendXMLTag:@"pcode"    value:[self pcode]    to:ms];
  [self appendXMLTag:@"country"  value:[self country]  to:ms];
  s = [[ms copy] autorelease];
  [ms release];
  return s;
}

- (NSString *)vCardString {
  NSMutableString *ms;
  NSString *s;
  
  ms = [[NSMutableString alloc] initWithCapacity:256];
  [self appendVCardValue:[self pobox]    to:ms]; [ms appendString:@";"];
  [self appendVCardValue:[self extadd]   to:ms]; [ms appendString:@";"];
  [self appendVCardValue:[self street]   to:ms]; [ms appendString:@";"];
  [self appendVCardValue:[self locality] to:ms]; [ms appendString:@";"];
  [self appendVCardValue:[self region]   to:ms]; [ms appendString:@";"];
  [self appendVCardValue:[self pcode]    to:ms]; [ms appendString:@";"];
  [self appendVCardValue:[self country]  to:ms];
  s = [[ms copy] autorelease];
  [ms release];
  return s;
}

- (NSDictionary *)asDictionary {
  static NSString *keys[] = {
    @"pobox", @"extadd", @"street", @"locality", @"region", @"pcode",
    @"country", nil
  };
  id values[8];
  unsigned i;
  
  for (i = 0; i < [self count]; i++)
    values[i] = [self objectAtIndex:i];
  
  return [NSDictionary dictionaryWithObjects:values forKeys:keys 
		       count:[self count]];
}

- (NSArray *)asArray {
  id values[[self count] + 1];
  unsigned i;

  for (i = 0; i < [self count]; i++)
    values[i] = [self objectAtIndex:i];
  
  return [NSArray arrayWithObjects:values count:[self count]];
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  [super encodeWithCoder:_coder];
  
  [_coder encodeObject:self->pobox];
  [_coder encodeObject:self->extadd];
  [_coder encodeObject:self->street];
  [_coder encodeObject:self->locality];
  [_coder encodeObject:self->region];
  [_coder encodeObject:self->pcode];
  [_coder encodeObject:self->country];
}
- (id)initWithCoder:(NSCoder *)_coder {
  if ((self = [super initWithCoder:_coder]) != nil) {
    self->pobox    = [[_coder decodeObject] copy];
    self->extadd   = [[_coder decodeObject] copy];
    self->street   = [[_coder decodeObject] copy];
    self->locality = [[_coder decodeObject] copy];
    self->region   = [[_coder decodeObject] copy];
    self->pcode    = [[_coder decodeObject] copy];
    self->country  = [[_coder decodeObject] copy];
  }
  return self;
}

/* description */

- (void)appendAttributesToDescription:(NSMutableString *)_ms {
  [super appendAttributesToDescription:_ms];
  [_ms appendFormat:@" vcard=%@", [self vCardString]];
}

@end /* NGVCardAddress */
