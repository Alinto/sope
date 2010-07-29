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

#ifndef __SxComponent_H__
#define __SxComponent_H__

#import <Foundation/NSObject.h>

/*
  This is the abstract superclass representing a component
  as registered in the SxComponentRegistry.
  
  Feature: Components sometimes support asynchronous invocation
  of methods. You can choose from two options to wait for a result:
  
  a) polling (easy ;-):
    id r = [component asyncCall:@"system.tar", @"/", nil];
    while ([r isAsyncResultPending])
      sleep(1); // check once per second for result .. 
    if ([r asyncCallFailed]) [[r asyncResult] raise];
    r = [r asyncResult]; // turn into "real" result
  
  b) notification (more difficult ...):
    id r = [component asyncCall:@"system.tar", @"/", nil];
    if ([r isAsyncResultPending]) {
      // component only posts, if result couldn't be resolved immediatly !!!
      [[component notificationCenter]
                  addObserver:self selector:@selector(asyncResult:)
                  notificationName:SxAsyncResultReadyNotificationName
                  object:r];
    }
    else
      [self setResult:r]; // should check for errors
    
    - (void)asyncResult:(NSNotification *)_n {
      id r = [_n object];
      if ([r asyncCallFailed]) [[r asyncResult] raise];
      [self setResult:[r asyncResult]]; // turn into "real" result
    }
*/

@class NSNotificationCenter, NSString, NSArray, NSException;
@class SxComponentRegistry;
@class SxComponentInvocation, SxComponentMethodSignature;

extern NSString *SxAsyncResultReadyNotificationName;

@protocol SxComponent

/* accessors */

- (SxComponentRegistry *)componentRegistry;
- (NSString *)componentName;
- (NSString *)namespace;

/* reflection */

- (NSArray *)signaturesForMethodNamed:(NSString *)_method;

- (SxComponentInvocation *)invocationForMethodNamed:(NSString *)_method
  methodSignature:(SxComponentMethodSignature *)_signature;
- (SxComponentInvocation *)invocationForMethodNamed:(NSString *)_method;
- (SxComponentInvocation *)invocationForMethodNamed:(NSString *)_method
  arguments:(NSArray *)_args;

/* introspection */

- (NSArray *)listMethods;
- (NSArray *)methodSignature:(NSString *)_methodName;
- (NSString *)methodHelp:(NSString *)_methodName;

/* operations */

- (id)call:(NSString *)_methodName,...;
- (id)call:(NSString *)_methodName arguments:(NSArray *)_args;
- (NSException *)lastException;

/* async calls */

- (NSNotificationCenter *)notificationCenter;
- (id)asyncCall:(NSString *)_methodName,...;
- (id)asyncCall:(NSString *)_methodName arguments:(NSArray *)_args;

/* subcomponents */

- (NSArray *)componentNames;
- (id<NSObject,SxComponent>)componentWithName:(NSString *)_name;

@end

@interface SxComponent : NSObject < SxComponent, NSCoding >
{
@protected
  SxComponentRegistry *registry;
  NSString            *componentName;
  NSString            *namespace;
@private
  NSException         *lastException;
}

- (id)initWithName:(NSString *)_name
  namespace:(NSString *)_namespace
  registry:(SxComponentRegistry *)_registry;

- (id)initWithName:(NSString *)_name
  registry:(SxComponentRegistry *)_registry;

- (void)flush;

- (void)setLastException:(NSException *)_exception;
- (void)resetLastException;
- (BOOL)lastCallFailed;

@end

/*
  Managing results of asynchronous invocations. The methods are
  overridden by special proxy objects created by components. All
  "usual" objects return:
  - isAsyncResultPending => NO
  - asyncResult          => self
  - asyncCallFailed      => NO
*/

@interface NSObject(AsyncCallResult)

- (BOOL)isAsyncResultPending;
- (id)asyncResult;
- (BOOL)asyncCallFailed;

@end

#endif /* __SxComponent_H__ */
