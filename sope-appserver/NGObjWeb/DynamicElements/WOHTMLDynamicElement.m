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

#include <NGObjWeb/WOHTMLDynamicElement.h>
#include "WOElement+private.h"
#include "decommon.h"

@implementation WOHTMLDynamicElement

static BOOL debugActionExecute = NO;

+ (int)version {
  return [super version] + 0 /* v2 */;
}

+ (void)initialize {
  NSUserDefaults *ud;
    
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  
  ud = [NSUserDefaults standardUserDefaults];
  debugActionExecute = [ud boolForKey:@"WODebugActions"];
}

/* active element */

- (id)executeAction:(WOAssociation *)_action inContext:(WOContext *)_ctx {
  // TODO: I think this is deprectated?
  id  object;
  SEL act;
  
  if (_action == nil) {
    if (debugActionExecute) {
      [self logWithFormat:@"%@(%@): got no action to execute ..",
              NSStringFromClass([self class]), _ctx];
    }
    return nil;
  }
  
  if ((object = [_ctx component]) == nil) {
    if (debugActionExecute) {
      [self logWithFormat:@"%@(%@): got no object to execute action: %@",
              NSStringFromClass([self class]), _ctx, _action];
    }
    return nil;
  }
  
  if (![_action isValueConstant]) {
    /* action specified like this: action = doIt; */
    id result;
    
    result = [_action valueInComponent:object];
    if (debugActionExecute) {
      [self logWithFormat:@"%@(%@): executed dynamic action, got: %@",
              NSStringFromClass([self class]), _ctx, result];
    }
    
    if ([result respondsToSelector:@selector(ensureAwakeInContext:)]) {
      if (debugActionExecute) {
        [self logWithFormat:@"%@(%@): ensure result is awake in ctx",
                NSStringFromClass([self class]), _ctx];
      }
      [result ensureAwakeInContext:_ctx];
    }
    return result;
  }
    
  /* action specified like this: action = "doIt"; */

  [[_ctx component]
         debugWithFormat:@"WARNING: %@ used with 'string' action !", self];

  act = NSSelectorFromString([_action stringValueInComponent:object]);
  if ([object respondsToSelector:act])
    return [object performSelector:act];
  
  [[_ctx component] logWithFormat:
                      @"%@[0x%p]: %@ does not respond to action @%@",
                      NSStringFromClass([self class]), self,
                      object,
                      NSStringFromSelector(act)];
  return nil;
}

@end /* WOHTMLDynamicElement */

NSDictionary *OWExtractQueryParameters(NSDictionary *_set) {
  NSMutableDictionary *paras = nil;
  NSMutableArray      *paraKeys = nil;
  NSEnumerator        *keys;
  NSString            *key;

  /* locate query parameters */
  keys = [_set keyEnumerator];
  while ((key = [keys nextObject])) {
    if ([key hasPrefix:@"?"]) {
      WOAssociation *value;

      if ([key isEqualToString:@"?wosid"])
        continue;

      value = [_set objectForKey:key];
          
      if (paraKeys == nil) {
        paraKeys = [NSMutableArray arrayWithCapacity:8];
        paras    = [NSMutableDictionary dictionaryWithCapacity:8];
      }

      [paraKeys addObject:key];
      [paras setObject:value forKey:[key substringFromIndex:1]];
    }
  }

  // remove query parameters
  if (paraKeys) {
    unsigned cnt, count;
    for (cnt = 0, count = [paraKeys count]; cnt < count; cnt++) {
      [(NSMutableDictionary *)_set removeObjectForKey:
                                     [paraKeys objectAtIndex:cnt]];
    }
  }

  // assign parameters
  return [paras copy];
}
