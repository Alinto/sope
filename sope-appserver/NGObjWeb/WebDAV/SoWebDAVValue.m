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

#include "SoWebDAVValue.h"
#include "common.h"

@implementation SoWebDAVValue

+ (id)valueForObject:(id)_obj attributes:(NSDictionary *)_attrs {
  return [[[self alloc] initWithObject:_obj attributes:_attrs] autorelease];
}
- (id)initWithObject:(id)_obj attributes:(NSDictionary *)_attrs {
  if ((self = [super init])) {
    self->object     = [_obj   retain];
    self->attributes = [_attrs copy];
  }
  return self;
}
- (id)init {
  return [self initWithObject:nil attributes:nil];
}

- (void)dealloc {
  [self->object     release];
  [self->attributes release];
  [super dealloc];
}

- (NSString *)stringForTag:(NSString *)_key rawName:(NSString *)_extName
  inContext:(id)_ctx
  prefixes:(NSDictionary *)_prefixes
{
  NSMutableString *ms;
  NSMutableDictionary *encNS = nil;
  
  ms = [NSMutableString stringWithCapacity:16];
  
  [ms appendString:@"<"];
  [ms appendString:_extName];
  
  /* process attributes */
  if (self->attributes) {
    NSEnumerator *keys;
    NSString *key;
    
    keys = [self->attributes keyEnumerator];
    while ((key = [keys nextObject])) {
      NSString *vs;
      
      vs = [[self->attributes objectForKey:key] stringValue];
      
      if ([key xmlIsFQN]) {
	NSString *ns, *a, *p;
	
	if (encNS == nil)
	  encNS = [NSMutableDictionary dictionaryWithCapacity:16];
	
	a  = [key xmlLocalName];
	ns = [key xmlNamespaceURI];
	
	if ((p = [encNS objectForKey:ns]) == nil) {
	  if ((p = [_prefixes objectForKey:ns]) == nil) {
	    p = [NSString stringWithFormat:@"a%i", [encNS count]];
	    [encNS setObject:p forKey:ns];
	    [ms appendString:@" xmlns:"];
	    [ms appendString:p];
	    [ms appendString:@"=\""];
	    [ms appendString:ns];
	    [ms appendString:@"\""];
	  }
	  else
	    [encNS setObject:p forKey:ns];
	}
	
	[ms appendString:@" "];
	[ms appendString:p];
	[ms appendString:@":"];
	[ms appendString:a];
      }
      else {
	[ms appendString:@" "];
	[ms appendString:key];
      }
      
      [ms appendString:@"=\""];
      [ms appendString:vs];
      [ms appendString:@"\""];
    }
  }
  if (self->object == nil) {
    [ms appendString:@"/>"];
    return ms;
  }
  
  [ms appendString:@">"];
  
  //s = [self stringForValue:value ofProperty:key prefixes:nsToPrefix];
  [ms appendString:[self->object stringValue]];
  
  [ms appendString:@"</"];
  [ms appendString:_extName];
  [ms appendString:@">"];
  return ms;
}

/* description */

- (NSString *)propertyListStringWithLocale:(id)_locale indent:(unsigned)_i {
  return [self->object propertyListStringWithLocale:_locale indent:_i];
}

- (NSString *)stringValue {
  return [self->object stringValue];
}

@end /* SoWebDAVValue */
