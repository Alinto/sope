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

#include "SxComponent.h"
#include "SxComponentRegistry.h"
#include "SxComponentInvocation.h"
#include "SxComponentMethodSignature.h"
#include "common.h"

@interface SxComponentRegistry(Dealloc)
- (void)_componentWillDealloc:(SxComponent *)_c;
@end

#if APPLE_FOUNDATION_LIBRARY || NeXT_Foundation_LIBRARY
@interface NSObject(Miss)
- (void)subclassResponsibility:(SEL)cmd;
@end
#endif

NSString *SxAsyncResultReadyNotificationName =
  @"SxAsyncResultReadyNotificationName";

@implementation SxComponent

+ (int)version {
  return 1;
}

- (id)initWithName:(NSString *)_name
  namespace:(NSString *)_namespace
  registry:(SxComponentRegistry *)_registry
{
  if ([_name length] == 0) {
    NSLog(@"%s: missing component name ...", __PRETTY_FUNCTION__);
    RELEASE(self);
    return nil;
  }
  if (_registry == nil) {
    NSLog(@"%s: missing registry of component %@ ...", __PRETTY_FUNCTION__,
          _name);
    RELEASE(self);
    return nil;
  }
  
  if ((self = [super init])) {
    self->componentName = [_name copy];
    self->namespace = [_namespace copy];
    self->registry = RETAIN(_registry);
  }
  return self;
}

- (id)initWithName:(NSString *)_name
  registry:(SxComponentRegistry *)_registry
{
  return [self initWithName:_name
               namespace:[[_name componentsSeparatedByString:@"."] lastObject]
               registry:_registry];
}
  
- (id)init {
  return [self initWithName:nil namespace:nil registry:nil];
}

- (void)dealloc {
  [self->registry _componentWillDealloc:self];
  self->registry = nil;
  RELEASE(self->lastException);
  RELEASE(self->componentName);
  RELEASE(self->namespace);
  [super dealloc];
}

/* accessors */

- (SxComponentRegistry *)componentRegistry {
  return self->registry;
}
- (NSString *)componentName {
  return self->componentName;
}

- (NSString *)namespace {
  return self->namespace;
}

/* reflection */

- (Class)invocationClass {
  static Class CompInv = Nil;
  if (CompInv == Nil) CompInv = [SxComponentInvocation class];
  return CompInv;
}

- (SxComponentInvocation *)invocationForMethodNamed:(NSString *)_method
  methodSignature:(SxComponentMethodSignature *)_signature
{
  SxComponentInvocation *invocation = nil;
  
  invocation =
    [[[self invocationClass] alloc]
            initWithComponent:self
            methodName:_method
            signature:_signature];
  return AUTORELEASE(invocation);
}

- (SxComponentInvocation *)invocationForMethodNamed:(NSString *)_method {
  SxComponentMethodSignature *sig;
  NSArray *sigs;

  sig = nil;
  sigs = [self signaturesForMethodNamed:_method];
  if ([sigs count] > 0)
    sig = [sigs objectAtIndex:0];
  
  return [self invocationForMethodNamed:_method
               methodSignature:sig];
}

- (SxComponentInvocation *)invocationForMethodNamed:(NSString *)_method
  arguments:(NSArray *)_args
{
  /*
    naive approach, search for a signature matching the arg count,
    should be overidden by subclass ..
  */
  SxComponentMethodSignature *sig;
  SxComponentInvocation *inv;
  NSArray  *sigs;
  unsigned i, count, argCount;

  argCount = [_args count];
  sigs = [self signaturesForMethodNamed:_method];
  if ((count = [sigs count]) == 0) {
    inv = [self invocationForMethodNamed:_method
                methodSignature:nil];
    [inv setArguments:_args];
    return inv;
  }
  else {
    for (i = 0, sig = nil; i < count; i++) {
      if ([sig numberOfArguments] == argCount)
        break;
    }
  }
  inv = [self invocationForMethodNamed:_method
              methodSignature:sig];
  [inv setArguments:_args];
  return inv;
}

- (NSArray *)signaturesForMethodNamed:(NSString *)_method {
  return nil;
}

/* introspection */

- (NSArray *)listMethods {
  NSArray *names;
  
  names = [[self componentRegistry] listMethods:[self componentName]];
  if (names == nil) return nil;
  
  if ([names isKindOfClass:[NSException class]]) {
    [self setLastException:(id)names];
    return nil;
  }
  
  if (![names isKindOfClass:[NSArray class]]) {
    NSException  *exc;
    NSDictionary *ui;

    if ([names isKindOfClass:[NSException class]])
      exc = (id)names;
    else {
      ui = [NSDictionary dictionaryWithObjectsAndKeys:
                         names, @"resultObject",
                         NSStringFromClass([names class]), @"resultClassName",
                         [self componentName], @"componentName",
                         nil];
      
      exc = [NSException exceptionWithName:@"SxComponentIntrospectionError"
                         reason:@"listMethods failed ..."
                         userInfo:ui];
    }
    [self setLastException:exc];
    names = nil;
  }
  
  return names;
}

- (NSArray *)methodSignature:(NSString *)_methodName {
  NSArray *sig;
  
  sig = [[self componentRegistry]
               methodSignature:[self componentName]
               method:_methodName];
  if (sig == nil) return nil;

  if ([sig isKindOfClass:[NSException class]]) {
    [self setLastException:(id)sig];
    return nil;
  }
  
  if (![sig isKindOfClass:[NSArray class]]) {
    NSException  *exc;
    NSDictionary *ui;
    
    if ([sig isKindOfClass:[NSException class]])
      exc = (id)sig;
    else {
      [self logWithFormat:@"WARNING(%s): got invalid result type !",
              __PRETTY_FUNCTION__];
      
      ui = [NSDictionary dictionaryWithObjectsAndKeys:
                           sig,                            @"resultObject",
                           NSStringFromClass([sig class]), @"resultClassName",
                           [self componentName],           @"componentName",
                           nil];
      
      exc = [NSException exceptionWithName:@"SxComponentIntrospectionError"
                         reason:@"methodSignature failed ..."
                         userInfo:ui];
    }
    [self setLastException:exc];
    sig = nil;
  }
  
  return sig;
}

- (NSString *)methodHelp:(NSString *)_methodName {
  return [[self componentRegistry]
                methodHelp:[self componentName] method:_methodName];
}

/* operations */

- (id)call:(NSString *)_methodName arguments:(NSArray *)_args {
  [self subclassResponsibility:_cmd];
  return nil;
}

- (BOOL)lastCallFailed {
  return [self lastException] != nil ? YES : NO;
}

- (void)setLastException:(NSException *)_exception {
  ASSIGN(self->lastException, _exception);
}
- (NSException *)lastException {
  return self->lastException;
}
- (void)resetLastException {
  ASSIGN(self->lastException, (id)nil);
}

- (id)call:(NSString *)_methodName,... {
  id array, obj, *objects;
  va_list list;
  unsigned int count;
  
  va_start(list, _methodName);
  for (count = 0, obj = va_arg(list, id); obj; obj = va_arg(list,id))
    count++;
  va_end(list);
  
  objects = calloc(count, sizeof(id));
  {
    va_start(list, _methodName);
    for (count = 0, obj = va_arg(list, id); obj; obj = va_arg(list,id))
      objects[count++] = obj;
    va_end(list);
    
    array = [NSArray arrayWithObjects:objects count:count];
  }
  free(objects);
  return [self call:_methodName arguments:array];
}

/* async calls */

- (NSNotificationCenter *)notificationCenter {
  return [NSNotificationCenter defaultCenter];
}

- (id)asyncCall:(NSString *)_methodName,... {
  id array, obj, *objects;
  va_list list;
  unsigned int count;
  
  va_start(list, _methodName);
  for (count = 0, obj = va_arg(list, id); obj; obj = va_arg(list,id))
    count++;
  va_end(list);
  
  objects = calloc(count, sizeof(id));
  {
    va_start(list, _methodName);
    for (count = 0, obj = va_arg(list, id); obj; obj = va_arg(list,id))
      objects[count++] = obj;
    va_end(list);
    
    array = [NSArray arrayWithObjects:objects count:count];
  }
  free(objects);
  return [self asyncCall:_methodName arguments:array];
}

- (id)asyncCall:(NSString *)_methodName arguments:(NSArray *)_args {
  /* default: do everything in a synchronous way ... */
  return [self call:_methodName arguments:_args];
}

/* subcomponents */

- (NSArray *)componentNames {
  NSArray  *array;
  NSString *cp;
  
  cp    = [[self componentName] stringByAppendingString:@"."];
  array = [[self componentRegistry] listComponents:cp];
  
  array = [array mappedArrayUsingSelector:@selector(stringWithoutPrefix:)
                 withObject:[self componentName]];
  
  return array;
}
- (id<NSObject,SxComponent>)componentWithName:(NSString *)_name {
  NSString *qn;
  
  qn = [[[self componentName]
               stringByAppendingString:@"."]
               stringByAppendingString:_name];
  return [[self componentRegistry] getComponent:qn];
}

/* caching */

- (void)flush {
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  [_coder encodeObject:self->componentName];
  [_coder encodeConditionalObject:self->registry];
}
- (id)initWithCoder:(NSCoder *)_coder {
  self->componentName = [[_coder decodeObject] copy];
  
  if ((self->registry = [[_coder decodeObject] retain]) == nil)
    self->registry = [[SxComponentRegistry defaultComponentRegistry] retain];
  
  return self;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]: name=%@",
        self, NSStringFromClass([self class]),
        [self componentName]];
  [ms appendString:@">"];
  
  return ms;
}

@end /* SxComponent */

@implementation NSObject(AsyncCallResult)

- (BOOL)isAsyncResultPending {
  return NO;
}
- (id)asyncResult {
  return self;
}
- (BOOL)asyncCallFailed {
  return NO;
}

@end /* NSObject(AsyncCall) */
