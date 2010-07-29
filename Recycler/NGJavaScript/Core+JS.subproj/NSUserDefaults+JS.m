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

/*
  NSUserDefaults JavaScript object

  Properties

    Array searchList
  
  Methods

    bool   synchronize()
           setObjectForKey(obj, key)
    Object objectForKey(key)
           removeObjectForKey(key)
    Array  arrayForKey(key)
    Dict   dictionaryForKey(key)
    Object dataForKey(key)
    Array  stringArrayForKey(key)
    String stringForKey(key)
    bool   boolForKey(key)
    Number floatForKey(key)
    Number integerForKey(key)
*/

@implementation NSUserDefaults(NGJavaScript)

- (id)valueForJSPropertyNamed:(NSString *)_key {
  return [self objectForKey:_key];
}

#if !(NeXT_Foundation_LIBRARY || APPLE_Foundation_LIBRARY)
- (void)_jsprop_searchList:(id)_array {
  [self setSearchList:_array];
}
- (id)_jsprop_searchList {
  return [self searchList];
}
#endif

- (id)_jsfunc_synchronize:(NSArray *)_args {
  return [NSNumber numberWithBool:[self synchronize]];
}

- (id)_jsfunc_setObjectForKey:(NSArray *)_args {
  [self setObject:[_args objectAtIndex:0]
        forKey:[_args objectAtIndex:1]];
  return self;
}
- (id)_jsfunc_objectForKey:(NSArray *)_args {
  return [self objectForKey:[_args objectAtIndex:0]];
}
- (id)_jsfunc_removeObjectForKey:(NSArray *)_args {
  NSEnumerator *e;
  NSString *key;
  
  e = [_args objectEnumerator];
  while ((key = [e nextObject]))
    [self removeObjectForKey:key];
  return self;
}

- (id)_jsfunc_arrayForKey:(NSArray *)_args {
  return [self arrayForKey:[_args objectAtIndex:0]];
}
- (id)_jsfunc_dictionaryForKey:(NSArray *)_args {
  return [self dictionaryForKey:[_args objectAtIndex:0]];
}
- (id)_jsfunc_dataForKey:(NSArray *)_args {
  return [self dataForKey:[_args objectAtIndex:0]];
}
- (id)_jsfunc_stringArrayForKey:(NSArray *)_args {
  return [self stringArrayForKey:[_args objectAtIndex:0]];
}
- (id)_jsfunc_stringForKey:(NSArray *)_args {
  return [self stringForKey:[_args objectAtIndex:0]];
}
- (id)_jsfunc_boolForKey:(NSArray *)_args {
  return [NSNumber numberWithBool:[self boolForKey:[_args objectAtIndex:0]]];
}
- (id)_jsfunc_floatForKey:(NSArray *)_args {
  return [NSNumber numberWithFloat:[self floatForKey:[_args objectAtIndex:0]]];
}
- (id)_jsfunc_integerForKey:(NSArray *)_args {
  return [NSNumber numberWithInt:[self integerForKey:[_args objectAtIndex:0]]];
}

@end /* NSUserDefaults(NGJavaScript) */
