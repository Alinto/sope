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

#include "SxComponentInvocation.h"
#include "SxComponentMethodSignature.h"
#include "SxComponent.h"
#include <NGExtensions/NSString+Ext.h>
#include "common.h"

@implementation SxComponentInvocation

static NSNull *null = nil;

+ (int)version {
  return 1;
}

- (void)_ensureArgs {
  unsigned i, count;

  if (self->arguments) return;
  if (self->signature == nil) return;
  if (null == nil) null = [[NSNull null] retain];

  count = [self->signature numberOfArguments];
  
  self->arguments = [[NSMutableArray alloc] initWithCapacity:count];
  for (i = 0; i < count; i++)
    [self->arguments addObject:null];
}

- (id)initWithMethodSignature:(id)_sig {
  if (_sig == nil) {
    [self release];
    return nil;
  }

  self->signature = [_sig retain];
  [self _ensureArgs];
  
  return self;
}
- (id)init {
  return [self initWithMethodSignature:nil];
}
- (id)initWithComponent:(SxComponent *)_component
  methodName:(NSString *)_method
  signature:(SxComponentMethodSignature *)_signature
{
  if ((self = [self initWithMethodSignature:_signature])) {
    self->methodName = [_method    copy];
    self->target     = [_component retain];
  }
  return self;
}

- (void)dealloc {
  [self->credentials   release];
  [self->lastException release];
  [self->arguments     release];
  [self->result        release];
  [self->target        release];
  [self->methodName    release];
  [self->signature     release];
  [super dealloc];
}

/* arguments */

- (SxComponentMethodSignature *)methodSignature {
  return self->signature;
}

- (void)setArgument:(id)_argument atIndex:(int)_idx {
  if (_argument == nil) _argument = null;
  [self->arguments replaceObjectAtIndex:_idx withObject:_argument];
}
- (id)argumentAtIndex:(int)_idx {
  id res;
  
  res = [self->arguments objectAtIndex:_idx];
  if (res == null) res = nil;
  return res;
}
- (void)setArguments:(NSArray *)_args {
  NSAssert2(([self->signature numberOfArguments] == [_args count]),
            @"arg count mismatch (%i expected, got %i)",
            [self->signature numberOfArguments],
            [_args count]);
  
  [self->arguments removeAllObjects];
  [self->arguments addObjectsFromArray:_args];
}
- (NSArray *)arguments {
  return [[self->arguments copy] autorelease];
}

- (BOOL)argumentsRetained {
  return YES;
}

- (void)setTarget:(SxComponent *)_target {
  ASSIGN(self->target, _target);
}
- (SxComponent *)target {
  return self->target;
}

- (void)setMethodName:(NSString *)_name {
  ASSIGNCOPY(self->methodName, _name);
}
- (NSString *)methodName {
  return self->methodName;
}

- (void)setReturnValue:(id)_result {
  ASSIGN(self->result, _result);
}
- (id)returnValue {
  return self->result;
}

- (void)setLastException:(NSException *)_exception {
  ASSIGN(self->lastException, _exception);
}

- (NSException *)lastException {
  return self->lastException;
}
- (BOOL)lastCallFailed {
  return self->lastException != nil ? YES : NO;
}
- (void)resetLastException {
  ASSIGN(self->lastException, (id)nil);
}

/* credentials */

- (void)setCredentials:(id)_credentials {
  ASSIGN(self->credentials, _credentials);
}
- (id)credentials {
  return self->credentials;
}

/* Dispatching an Invocation */

- (NSArray *)argumentsForCall {
  return self->arguments;
}

- (id)_call:(NSString *)_methodName
  onTarget:(SxComponent *)_target
  arguments:(NSArray *)_params
{
  return [_target call:_methodName arguments:_params];
}
- (BOOL)_asyncCall:(NSString *)_methodName
  onTarget:(SxComponent *)_target
  arguments:(NSArray *)_params
{
  return [_target asyncCall:_methodName arguments:_params] ? YES : NO;
}

- (BOOL)invokeWithTarget:(SxComponent *)_target {
  NSAutoreleasePool *pool;
  BOOL ok;
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    NSArray *args;
    id res;

    /* reset state */
    [self->lastException release]; self->lastException = nil;
    [self->result        release]; self->result = nil;
    
    /* get arguments */
    args = [self argumentsForCall];
    
    /* invoke remote method */
    res = [self _call:[self methodName] onTarget:_target arguments:args];
    
    /* check for errors */
    
    if (self->lastException) {
      ok = NO;
      [self setReturnValue:nil];
    }
    else {
      /* store return value */
      [self setReturnValue:res];
      ok = YES;
    }
  }
  [pool release];

  return ok;
}
- (BOOL)invoke {
  return [self invokeWithTarget:[self target]];
}

/* asynchronous */

- (void)asyncResultReady:(NSNotification *)_notification {
  id proxy;
  
  if (self->result != [_notification object]) {
    NSLog(@"%s: WARNING, got an invalid aync result notification: %@",
          __PRETTY_FUNCTION__, _notification);
    return;
  }

  proxy = [self->result retain];
  [self->result release]; self->result = nil;
  
  if ([proxy asyncCallFailed]) {
    self->lastException = [[proxy asyncResult] retain];
    [self setReturnValue:nil];
  }
  else
    [self setReturnValue:[proxy asyncResult]];
  
  [proxy release]; proxy = nil;
  
  [[self->target notificationCenter]
                 postNotificationName:SxAsyncResultReadyNotificationName
                 object:self];
}

- (BOOL)asyncInvoke {
  NSAutoreleasePool *pool;
  BOOL ok;
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    NSArray *args;
    id res;

    /* reset state */
    [self->lastException release]; self->lastException = nil;
    [self->result        release]; self->result = nil;
    
    /* get arguments */
    args = [self argumentsForCall];
    
    /* invoke remote method */
    
    res = [self->target asyncCall:[self methodName] arguments:args];
    
    if (![res isAsyncResultPending]) {
      /* result is ready :-) */
      
      /* check for errors */
      if ([self->target lastCallFailed]) {
        self->lastException = [res retain];
        [self setReturnValue:nil];
        ok = NO;
      }
      else {
        /* store return value */
        [self setReturnValue:res];
        ok = YES;
      }
    }
    else {
      /* result isn't ready yet, register for notification */
      ok = YES;
      self->result = [res retain];
      
      [[self->target notificationCenter]
                     addObserver:self selector:@selector(asyncResultReady:)
                     name:SxAsyncResultReadyNotificationName
                     object:self->result];
    }
  }
  [pool release];
  
  return ok;
}

- (BOOL)isAsyncResultPending {
  return [self->result isAsyncResultPending];
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  [_coder encodeObject:self->target];
  [_coder encodeObject:self->methodName];
  [_coder encodeObject:self->signature];
  [_coder encodeObject:self->arguments];
  [_coder encodeObject:self->result];
  [_coder encodeObject:self->lastException];
}
- (id)initWithCoder:(NSCoder *)_coder {
  if (null == nil) null = [[NSNull null] retain];
  
  self->target        = [[_coder decodeObject] retain];
  self->methodName    = [[_coder decodeObject] copy];
  self->signature     = [[_coder decodeObject] retain];
  self->arguments     = [[_coder decodeObject] retain];
  self->result        = [[_coder decodeObject] retain];
  self->lastException = [[_coder decodeObject] retain];
  
  if (self->signature == nil) {
    NSLog(@"%s: missing signature (required during decoding)",
          __PRETTY_FUNCTION__);
    [self release];
    return nil;
  }
  [self _ensureArgs];
  
  return self;
}

/* KVC */

/* access the arguments with key "arg<element position>"
   e.g. 'arg0' for the first element
*/

- (int)_indexForKey:(NSString *)_key {
  NSString *prefix;

  prefix = @"arg";
  
  if(![_key hasPrefix:prefix])
    return -1;
  
  return [[_key substringFromIndex:[prefix length]] intValue];
}

- (void)takeValue:(id)_value forKey:(NSString *)_key {
  int index;

  if ((index = [self _indexForKey:_key]) != -1)
    [self setArgument:_value atIndex:index];
}

- (id)valueForKey:(NSString *)_key {
  int index;

  if ((index = [self _indexForKey:_key]) != -1)
    return [self argumentAtIndex:index];

  return nil;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [ms appendFormat:@" %@", self->methodName];
  if (self->arguments)
    [ms appendFormat:@" #args=%i", [self->arguments count]];
  else
    [ms appendString:@" no-args"];
  if (self->lastException)
    [ms appendString:@" exception-is-set"];
  if (self->result)
    [ms appendString:@" result-is-set"];
  if (self->signature == nil)
    [ms appendString:@" no-signature"];
  else {
    [ms appendFormat:@" signature=%@",
          [[self->signature xmlRpcTypes]
                            componentsJoinedByString:@","]];
    if ([self->signature isOneway])
      [ms appendString:@" oneway"];
  }
  [ms appendString:@">"];
  return ms;
}

@end /* SxComponentInvocation */
