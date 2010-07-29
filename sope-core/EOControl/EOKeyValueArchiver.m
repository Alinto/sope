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

#include "EOKeyValueArchiver.h"
#include "common.h"

@implementation EOKeyValueArchiver

- (id)init {
  if ((self = [super init])) {
    self->plist = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)dealloc {
  [self->plist release];
  [super dealloc];
}

/* coding */

static BOOL isPListObject(id _obj) {
  if ([_obj isKindOfClass:[NSString class]])
    return YES;
  if ([_obj isKindOfClass:[NSData class]])
    return YES;
  if ([_obj isKindOfClass:[NSArray class]])
    return YES;
  return NO;
}

- (void)encodeObject:(id)_obj forKey:(NSString *)_key {
  NSMutableDictionary *oldPlist;

  if (isPListObject(_obj)) {
    id c;
    c = [_obj copy];
    [self->plist setObject:c forKey:_key];
    [c release];
    return;
  }
  
  oldPlist = self->plist;
  self->plist = [[NSMutableDictionary alloc] init];
  
  if (_obj) {
    /* store class name */
    [self->plist setObject:NSStringFromClass([_obj class]) forKey:@"class"];

    /* let object store itself */
    [_obj encodeWithKeyValueArchiver:self];
  }
  else {
    /* nil ??? */
  }

  [oldPlist setObject:self->plist forKey:_key];
  [self->plist release];
  self->plist = oldPlist;
}

- (void)encodeReferenceToObject:(id)_obj forKey:(NSString *)_key {
  if ([self->delegate respondsToSelector:
           @selector(archiver:referenceToEncodeForObject:)])
    _obj = [self->delegate archiver:self referenceToEncodeForObject:_obj];

  /* if _obj wasn't replaced by the delegate, encode the object in place .. */
  [self encodeObject:_obj forKey:_key];
}

- (void)encodeBool:(BOOL)_flag forKey:(NSString *)_key {
  /* NO values are not archived .. */
  if (_flag) {
    [self->plist setObject:@"YES" forKey:_key];
  }
}
- (void)encodeInt:(int)_value forKey:(NSString *)_key {
  [self->plist setObject:[NSString stringWithFormat:@"%i", _value] forKey:_key];
}

- (NSDictionary *)dictionary {
  return [[self->plist copy] autorelease];
}

/* delegate */

- (void)setDelegate:(id)_delegate {
  self->delegate = _delegate;
}
- (id)delegate {
  return self->delegate;
}

@end /* EOKeyValueArchiver */


@implementation EOKeyValueUnarchiver

- (id)initWithDictionary:(NSDictionary *)_dict {
  self->plist = [_dict copy];
  self->unarchivedObjects = [[NSMutableArray alloc] initWithCapacity:16];
  // should be a hashtable
  self->awakeObjects = [[NSMutableSet alloc] initWithCapacity:16];
  return self;
}
- (id)init {
  [self release];
  return nil;
}

- (void)dealloc {
  [self->awakeObjects      release];
  [self->unarchivedObjects release];
  [self->plist             release];
  [super dealloc];
}

/* class handling */

- (Class)classForName:(NSString *)_name {
  /*
    This method maps class names. It is intended for archives which are
    written by the Java bridge and therefore use fully qualified Java
    package names.
    
    The mapping is hardcoded for now, this could be extended to use a
    dictionary if considered necessary.
  */
  NSString *lastComponent = nil;
  Class   clazz;
  NSRange r;

  if (_name == nil)
    return nil;
  
  if ((clazz = NSClassFromString(_name)) != Nil)
    return clazz;
  
  /* check for Java like . names (eg com.webobjects.directtoweb.Assignment) */
  
  r = [_name rangeOfString:@"." options:NSBackwardsSearch];
  if (r.length > 0) {
    lastComponent = [_name substringFromIndex:(r.location + r.length)];
    
    /* first check whether the last name directly matches a class */
    if ((clazz = NSClassFromString(lastComponent)) != Nil)
      return clazz;
    
    /* then check some hardcoded prefixes */
    
    if ([_name hasPrefix:@"com.webobjects.directtoweb"]) {
      NSString *s;
      
      s = [@"D2W" stringByAppendingString:lastComponent];
      if ((clazz = NSClassFromString(lastComponent)) != Nil)
	return clazz;
    }
    
    NSLog(@"WARNING(%s): could not map Java class in unarchiver: '%@'",
	  __PRETTY_FUNCTION__, _name);
  }
  
  return Nil;
}

/* decoding */

- (id)_decodeCurrentPlist {
  NSString *className;
  Class    clazz;
  id       obj;

  if ([self->plist isKindOfClass:[NSArray class]]) {
      unsigned count;
      
      if ((count = [self->plist count]) == 0)
	obj = [[self->plist copy] autorelease];
      else {
	unsigned i;
	id *objs;
	
	objs = calloc(count + 1, sizeof(id));
	for (i = 0; i < count; i++)
	  objs[i] = [self decodeObjectAtIndex:i];
	
	obj = [NSArray arrayWithObjects:objs count:count];
	if (objs != NULL) free(objs);
      }
      return obj;
  }
  
  if (![self->plist isKindOfClass:[NSDictionary class]])
    return [[self->plist copy] autorelease];
  
  /* handle dictionary */
  
  if ((className = [self->plist objectForKey:@"class"]) == nil)
    return [[self->plist copy] autorelease]; /* treat as plain dictionary */
  
  if ((clazz = [self classForName:className]) == nil) {
    NSLog(@"WARNING(%s): did not find class specified in archive '%@': %@",
	  __PRETTY_FUNCTION__, className, self->plist);
    return nil;
  }
  
  /* create custom object */
  
  obj = [clazz alloc];
  obj = [obj initWithKeyValueUnarchiver:self];
    
  if (obj != nil)
    [self->unarchivedObjects addObject:obj];
  else {
    NSLog(@"WARNING(%s): could not unarchive object %@",
	  __PRETTY_FUNCTION__, self->plist);
  }
  if (self->unarchivedObjects != nil)
    [obj release];
  else
    [obj autorelease];
  
  return obj;
}

- (id)decodeObjectAtIndex:(unsigned)_idx {
  NSDictionary *lastParent;
  id obj;
  
  /* push */
  lastParent   = self->parent;
  self->parent = self->plist;
  self->plist  = [(NSArray *)self->parent objectAtIndex:_idx];
  
  obj = [self _decodeCurrentPlist];

  /* pop */
  self->plist  = self->parent;
  self->parent = lastParent;
  
  return obj != nil ? obj : (id)[NSNull null];
}

- (id)decodeObjectForKey:(NSString *)_key {
  NSDictionary *lastParent;
  id obj;

  /* push */
  lastParent   = self->parent;
  self->parent = self->plist;
  self->plist  = [(NSDictionary *)self->parent objectForKey:_key];

  obj = [self _decodeCurrentPlist];
  
  /* pop */
  self->plist  = self->parent;
  self->parent = lastParent;
  
  return obj;
}
- (id)decodeObjectReferenceForKey:(NSString *)_key {
  id refObj, obj;

  refObj = [self decodeObjectForKey:_key];

  if ([self->delegate respondsToSelector:
           @selector(unarchiver:objectForReference:)]) {
    obj = [self->delegate unarchiver:self objectForReference:refObj];
    
    if (obj != nil) 
      [self->unarchivedObjects addObject:obj];
  }
  else {
    /* if delegate does not dereference, pass back the reference object */
    obj = refObj;
  }
  return obj;
}

- (BOOL)decodeBoolForKey:(NSString *)_key {
  id v;
  
  if ((v = [self->plist objectForKey:_key]) == nil)
    return NO;
  
  if ([v isKindOfClass:[NSString class]]) {
    unsigned l = [v length];
    
    if (l == 4 && [v isEqualToString:@"true"])   return YES;
    if (l == 5 && [v isEqualToString:@"false"])  return NO;
    if (l == 3 && [v isEqualToString:@"YES"])    return YES;
    if (l == 2 && [v isEqualToString:@"NO"])     return NO;
    if (l == 1 && [v characterAtIndex:0] == '1') return YES;
    if (l == 1 && [v characterAtIndex:0] == '0') return NO;
  }
  
  return [v boolValue];
}
- (int)decodeIntForKey:(NSString *)_key {
  return [[self->plist objectForKey:_key] intValue];
}

/* operations */

- (void)ensureObjectAwake:(id)_object {
  if (![self->awakeObjects containsObject:_object]) {
    if ([_object respondsToSelector:@selector(awakeFromKeyValueUnarchiver:)]) {
      [_object awakeFromKeyValueUnarchiver:self];
    }
    [self->awakeObjects addObject:_object];
  }
}
- (void)awakeObjects {
  NSEnumerator *e;
  id obj;

  e = [self->unarchivedObjects objectEnumerator];
  while ((obj = [e nextObject]) != nil)
    [self ensureObjectAwake:obj];
}

- (void)finishInitializationOfObjects {
  NSEnumerator *e;
  id obj;

  e = [self->unarchivedObjects objectEnumerator];
  while ((obj = [e nextObject]) != nil) {
    if ([obj respondsToSelector:
               @selector(finishInitializationWithKeyValueUnarchiver:)])
      [obj finishInitializationWithKeyValueUnarchiver:self];
  }
}

- (id)parent {
  return self->parent;
}

/* delegate */

- (void)setDelegate:(id)_delegate {
  self->delegate = _delegate;
}
- (id)delegate {
  return self->delegate;
}

@end /* EOKeyValueUnarchiver */
