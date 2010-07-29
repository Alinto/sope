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

#include "SoObjectResultEntry.h"
#include "common.h"

@implementation SoObjectResultEntry

static BOOL debugOn = NO;
static BOOL useRelativeURLs = NO;

+ (void) initialize
{
  useRelativeURLs = [[NSUserDefaults standardUserDefaults]
		      boolForKey: @"WOUseRelativeURLs"];
}

- (id)initWithURI:(NSString *)_href object:(id)_o values:(NSDictionary *)_d {
  if ((self = [super init])) {
    if (debugOn) {
      // TODO: this happens if we access using Goliath
      if ([_href hasPrefix:@"http:/"] && ![_href hasPrefix:@"http://"]) {
	[self logWithFormat:@"BROKEN URL: %@", _href];
	[self release];
	//abort();
	return nil;
      }
    }
    
    self->href   = [_href copy];
    self->values = [_d retain];
    self->object = [_o retain];
  }
  return self;
}
- (id)init {
  return [self initWithURI:nil object:nil values:nil];
}

- (void)dealloc {
  [self->href   release];
  [self->values release];
  [self->object release];
  [super dealloc];
}

/* keys */

- (NSArray *)attributeKeys {
  return [self->values allKeys];
}

/* dict */

- (NSArray *)allKeys {
  return [self->values allKeys];
}
- (NSEnumerator *)keyEnumerator {
  return [self->values keyEnumerator];
}
- (id)objectForKey:(id)_key {
  return [self->values objectForKey:_key];
}

/* KVC */

- (BOOL)kvcIsPreferredInKeyPath {
  /*
    This is difficult to grasp. It says, that the WOKeyPathAssociation
    should *always* use -valueForKey:, even if the object has an accessors
    method matching the key.
    It's required for all "storage" type objects.
  */
  return YES;
}

- (NSString *)_relativeHREF {
  NSString *newHREF;
  NSRange hostRange;

  if ([self->href hasPrefix: @"/"])
    return self->href;
  else {
    hostRange = [self->href rangeOfString: @"://"];
    if (hostRange.length > 0) {
      newHREF = [self->href substringFromIndex: NSMaxRange (hostRange)];
      hostRange = [newHREF rangeOfString: @"/"];
      if (hostRange.length > 0) {
	newHREF = [newHREF substringFromIndex: hostRange.location];
      }
    } else {
      newHREF = self->href;
    }

    return newHREF;
  }
}

- (id)valueForKey:(NSString *)_key {
  if ([_key isEqualToString:@"{DAV:}href"]) {
    if (useRelativeURLs)
      return [self _relativeHREF];
    else
      return self->href;
  }

  if ([_key isEqualToString:@"{DAV:}status"])
    return nil;
  
  if (!debugOn)
    return [self->values objectForKey:_key];
  
  {
    id v = [self->values objectForKey:_key];
    [self logWithFormat:@"key %@: %@", _key, v];
    return v;
  }
}

/* SoObject */
- (BOOL)isFolderish
{
  return [self->object isFolderish];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self,
        NSStringFromClass((Class)*(void**)self)];
  
  if (self->href)
    [ms appendFormat:@" uri=%@", self->href];

  if (self->object) {
    [ms appendFormat:@" obj=0x%p[%@]", 
	  self->object, NSStringFromClass([self->object class])];
  }
  
  if ([self->values count] > 0) {
    NSEnumerator *e;
    NSString *k;
    
    [ms appendString:@" values"];
    e = [self->values keyEnumerator];
    while ((k = [e nextObject]))
      [ms appendFormat:@":%@=%@", k, [self->values objectForKey:k]];
  }
  
  [ms appendString:@">"];
  return ms;
}

@end /* SoObjectResultEntry */

@implementation SoObjectErrorEntry

- (id)initWithURI:(NSString *)_href object:(id)_o error:(NSException *)_e {
  self->href   = [_href copy];
  self->error  = [_e retain];
  self->object = [_o retain];
  return self;
}

- (void)dealloc {
  [self->object release];
  [self->href   release];
  [self->error  release];
  [super dealloc];
}

/* dict */

- (NSArray *)allKeys {
  return nil;
}
- (NSEnumerator *)keyEnumerator {
  return nil;
}
- (id)objectForKey:(id)_key {
  return nil;
}

/* KVC */

- (BOOL)kvcIsPreferredInKeyPath {
  return YES;
}

- (id)valueForKey:(NSString *)_key {
  if ([_key isEqualToString:@"{DAV:}href"])
    return self->href;
  else if ([_key isEqualToString:@"{DAV:}status"])
    return self->error;
  else
    return nil;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self,
        NSStringFromClass((Class)*(void**)self)];
  
  if (self->href)
    [ms appendFormat:@" uri=%@", self->href];

  if (self->object) {
    [ms appendFormat:@" obj=0x%p[%@]", 
	  self->object, NSStringFromClass([self->object class])];
  }

  if (self->error)
    [ms appendFormat:@" error=%@", self->error];
  
  [ms appendString:@">"];
  return ms;
}

@end /* SoObjectErrorEntry */
