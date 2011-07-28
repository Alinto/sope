/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#include "SoObjCClass.h"
#include "SoSelectorInvocation.h"
#include <NGExtensions/NSString+Ext.h>
#include "common.h"

@implementation SoObjCClass

- (id)initWithSoSuperClass:(SoClass *)_soClass class:(Class)_clazz {
  NSAssert(_clazz, @"missing ObjC class parameter !");
  if ((self = [super initWithSoSuperClass:_soClass])) {
    self->clazz = _clazz;
  }
  return self;
}
- (id)initWithSoSuperClass:(SoClass *)_soClass {
  return [self initWithSoSuperClass:_soClass class:nil];
}

- (NSEnumerator *) _methodsFromClass: (Class) c {
  NSMutableArray *a;
  int i;

  a = [NSMutableArray array];

#if (defined(__GNU_LIBOBJC__) && (__GNU_LIBOBJC__ == 20100911)) || defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
  Method *p, *m;
  int count;
   
  p = m = class_copyMethodList(c, &count);

  for (i = 0; i < count; i++) {
    [a addObject: NSStringFromSelector(method_getName(*m))];
    m++;
  }

  free(p);
#else
  struct objc_method_list *methods; 
  Method_t method; 
  for (methods = c->methods; methods != NULL; methods = methods->method_next) {
    for (i = 0; i < methods->method_count; i++) {
	  method = &(methods->method_list[i]);
      [a addObject: NSStringFromSelector(method->method_name)];
	}
  }

#endif

  return [a objectEnumerator];
}

- (void)rescanClass {
  NSMutableDictionary *prefixMap;
  NSEnumerator *e;
  NSString *methodName;
  
  prefixMap = [[NSMutableDictionary alloc] initWithCapacity:32];
  
  [self debugWithFormat:@"scanning ObjC class %@ for SoObject methods ...",
	  NSStringFromClass(self->clazz)];
  e = [self _methodsFromClass: self->clazz];
  while ((methodName = [e nextObject])) {
    SoSelectorInvocation *invocation;
    NSString *methodPrefix;
    NSRange  r;
    unsigned len;
    
    if ((len = [methodName length]) < 6)
      continue;
    
    r = [methodName rangeOfString:@"Action"];
    if (r.length == 0) continue;
    
    /* eg: doItAction:abc: => doItAction */
    methodPrefix = [methodName substringToIndex:(r.location + r.length)];
    
    if (len > (r.location + r.length)) {
      /* something is beyond the xxxAction, *must* be followed by a colon */
      if ([methodName characterAtIndex:(r.location + r.length)] != ':')
	continue;
    }
    
    [self debugWithFormat:@"  found an action: %@", methodName];
    
    if ((invocation = [prefixMap objectForKey:methodPrefix]) == nil) {
      invocation = [[SoSelectorInvocation alloc] init];
      [prefixMap setObject:invocation forKey:methodPrefix];
      [invocation release];
    }
    [invocation addSelectorNamed:methodName];
  }
  
  e = [prefixMap keyEnumerator];
  while ((methodName = [e nextObject])) {
    SoSelectorInvocation *inv;
    NSString *slotName;
    
    slotName = [methodName hasSuffix:@"Action"]
      ? [methodName substringToIndex:([methodName length] - 6)]
      : methodName;
    inv = [prefixMap objectForKey:methodName];
    [self setValue:inv forSlot:slotName];
  }
}

/* factory */

- (id)instantiateObject {
  return [[[self->clazz alloc] init] autorelease];
}

- (NSClassDescription *)soClassDescription {
  return [NSClassDescription classDescriptionForClass:self->clazz];
}

- (NSString *)className {
  return NSStringFromClass(self->clazz);
}
- (Class)objcClass {
  return self->clazz;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self,
        NSStringFromClass((Class)*(void**)self)];
  
  if (self->soSuperClass)
    [ms appendFormat:@" super=0x%p", self->soSuperClass];
  else
    [ms appendString:@" root"];

  if (self->clazz)
    [ms appendFormat:@" objc=%@", NSStringFromClass(self->clazz)];
  else
    [ms appendString:@" <no-objc-class>"];
  
  if ([self->slots count] > 0) {
    [ms appendFormat:@" slots=%@", 
	  [[self->slots allKeys] componentsJoinedByString:@","]];
  }
  
  [ms appendString:@">"];
  return ms;
}

/* logging */

- (NSString *)loggingPrefix {
  return [NSString stringWithFormat:@"[so-objc-class:%@]", 
		     NSStringFromClass(self->clazz)];
}
- (BOOL)isDebuggingEnabled {
  static int debugOn = -1;
  if (debugOn == -1) {
    debugOn = [[NSUserDefaults standardUserDefaults]
		boolForKey:@"SoObjCClassDebugEnabled"] ? 1 : 0;
  }
  return debugOn ? YES : NO;
}

@end /* SoObjCClass */
