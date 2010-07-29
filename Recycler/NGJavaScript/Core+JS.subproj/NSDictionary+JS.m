/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#include "NGJavaScriptContext.h"
#import <Foundation/Foundation.h>
#import <EOControl/EONull.h>
#include "../common.h"

@implementation NSDictionary(NGJavaScript)

- (id)valueForJSPropertyNamed:(NSString *)_key {
  return [self objectForKey:_key];
}

- (id)_jsfunc_allKeys:(NSArray *)_args {
  return [self allKeys];
}
- (id)_jsfunc_allKeysForObject:(NSArray *)_args {
  return [self allKeysForObject:[_args objectAtIndex:0]];
}
- (id)_jsfunc_allValues:(NSArray *)_args {
  return [self allValues];
}

- (id)_jsfunc_objectForKey:(NSArray *)_args {
  return [self objectForKey:[_args objectAtIndex:0]];
}
- (id)_jsfunc_objectsForKeys:(NSArray *)_args {
  unsigned count;
  id notFound;
  
  notFound = ((count = [_args count]) > 1)
    ? [_args objectAtIndex:1]
    : [EONull null];

  return [self objectsForKeys:[_args objectAtIndex:0] notFoundMarker:notFound];
}

/* IO */

- (id)_jsfunc_writeToFile:(NSArray *)_args {
  BOOL atomically;
  
  atomically =  ([_args count] > 1)
    ? [[_args objectAtIndex:1] boolValue]
    : YES;
  
   atomically = [self writeToFile:[[_args objectAtIndex:0] stringValue]
                      atomically:atomically];
   return [NSNumber numberWithBool:atomically];
}

@end /* NSDictionary(NGJavaScript) */

@implementation NSMutableDictionary(NGJavaScript)

- (BOOL)takeValue:(id)_value forJSPropertyNamed:(NSString *)_key {
  if ((_value == nil) || (_key == nil))
      return NO;
  
  [self setObject:_value forKey:_key];
  return YES;
}

/* adding objects */

- (id)_jsfunc_addEntriesFromDictionary:(NSArray *)_args {
  NSEnumerator *e;
  NSDictionary *d;

  e = [_args objectEnumerator];
  while ((d = [e nextObject]))
    [self addEntriesFromDictionary:d];
  return self;
}
- (id)_jsfunc_setObjectForKey:(NSArray *)_args {
  [self setObject:[_args objectAtIndex:0] forKey:[_args objectAtIndex:1]];
  return self;
}
- (id)_jsfunc_setDictionary:(NSArray *)_args {
  [self setDictionary:[_args objectAtIndex:0]];
  return self;
}

/* removing objects */

- (id)_jsfunc_removeAllObjects:(NSArray *)_args {
  [self removeAllObjects];
  return self;
}
- (id)_jsfunc_removeObjectForKey:(NSArray *)_args {
  NSEnumerator *e;
  NSString *d;

  e = [_args objectEnumerator];
  while ((d = [e nextObject]))
    [self removeObjectForKey:d];
  return self;
}
- (id)_jsfunc_removeObjectsForKeys:(NSArray *)_args {
  NSEnumerator *e;
  NSArray *d;

  e = [_args objectEnumerator];
  while ((d = [e nextObject]))
    [self removeObjectsForKeys:d];
  return self;
}

@end /* NSMutableDictionary(NGJavaScript) */
