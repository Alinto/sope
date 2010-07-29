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

#include "NGVCardName.h"
#include "common.h"

@implementation NGVCardName

+ (int)version {
  return [super version] + 0 /* v0 */;
}
+ (void)initialize {
  NSAssert2([super version] == 0,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)initWithPropertyList:(id)_plist group:(NSString *)_group 
  types:(NSArray *)_types arguments:(NSDictionary *)_a
{
  if ((self = [super initWithGroup:_group types:_types arguments:_a]) != nil) {
    self->family = [[(NSDictionary *)_plist objectForKey:@"family"] copy];
    self->given  = [[(NSDictionary *)_plist objectForKey:@"given"]  copy];
    self->other  = [[(NSDictionary *)_plist objectForKey:@"other"]  copy];
    self->prefix = [[(NSDictionary *)_plist objectForKey:@"prefix"] copy];
    self->suffix = [[(NSDictionary *)_plist objectForKey:@"suffix"] copy];
  }
  return self;
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
  [self->family release];
  [self->given  release];
  [self->other  release];
  [self->prefix release];
  [self->suffix release];
  [super dealloc];
}

/* accessors */

- (NSString *)family {
  return self->family;
}
- (NSString *)given {
  return self->given;
}
- (NSString *)other {
  return self->other;
}
- (NSString *)prefix {
  return self->prefix;
}
- (NSString *)suffix {
  return self->suffix;
}

/* fake being an array */

- (id)objectAtIndex:(unsigned)_idx {
  NSString *s;
  
  switch (_idx) {
  case 0: return (s = [self family]) ? s : (NSString *)[NSNull null];
  case 1: return (s = [self given])  ? s : (NSString *)[NSNull null];
  case 2: return (s = [self other])  ? s : (NSString *)[NSNull null];
  case 3: return (s = [self prefix]) ? s : (NSString *)[NSNull null];
  case 4: return (s = [self suffix]) ? s : (NSString *)[NSNull null];
  }
  
  // TODO: throw exception
  return nil;
}
- (unsigned)count {
  return 5;
}

/* values */

- (NSString *)stringValue {
  return [self vCardString];
}

- (NSString *)xmlString {
  NSMutableString *ms;
  NSString *s;
  
  ms = [[NSMutableString alloc] initWithCapacity:256];
  [self appendXMLTag:@"family" value:[self family] to:ms];
  [self appendXMLTag:@"given"  value:[self given]  to:ms];
  [self appendXMLTag:@"other"  value:[self other]  to:ms];
  [self appendXMLTag:@"prefix" value:[self prefix] to:ms];
  [self appendXMLTag:@"suffix" value:[self suffix] to:ms];
  s = [[ms copy] autorelease];
  [ms release];
  return s;
}

- (NSString *)vCardString {
  NSMutableString *ms;
  NSString *s;
  
  ms = [[NSMutableString alloc] initWithCapacity:256];
  [self appendVCardValue:[self family] to:ms]; [ms appendString:@";"];
  [self appendVCardValue:[self given]  to:ms]; [ms appendString:@";"];
  [self appendVCardValue:[self other]  to:ms]; [ms appendString:@";"];
  [self appendVCardValue:[self prefix] to:ms]; [ms appendString:@";"];
  [self appendVCardValue:[self suffix] to:ms];
  s = [[ms copy] autorelease];
  [ms release];
  return s;
}

- (NSDictionary *)asDictionary {
  static NSString *keys[] = {
    @"family", @"given", @"other", @"prefix", @"suffix", nil
  };
  id values[[self count] + 1];
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

- (id)propertyList {
  return [self asDictionary];
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  [super encodeWithCoder:_coder];
  
  [_coder encodeObject:self->family];
  [_coder encodeObject:self->given];
  [_coder encodeObject:self->other];
  [_coder encodeObject:self->prefix];
  [_coder encodeObject:self->suffix];
}
- (id)initWithCoder:(NSCoder *)_coder {
  if ((self = [super initWithCoder:_coder]) != nil) {
    self->family = [[_coder decodeObject] copy];
    self->given  = [[_coder decodeObject] copy];
    self->other  = [[_coder decodeObject] copy];
    self->prefix = [[_coder decodeObject] copy];
    self->suffix = [[_coder decodeObject] copy];
  }
  return self;
}

/* description */

- (void)appendAttributesToDescription:(NSMutableString *)_ms {
  [super appendAttributesToDescription:_ms];
  [_ms appendFormat:@" vcard=%@", [self vCardString]];
}

@end /* NGVCardName */
