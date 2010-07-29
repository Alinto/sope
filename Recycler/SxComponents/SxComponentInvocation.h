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

#ifndef __SxComponentInvocation_H__
#define __SxComponentInvocation_H__

#import <Foundation/NSObject.h>

@class NSString, NSMutableArray, NSException, NSArray;
@class SxComponent;
@class SxComponentMethodSignature;

/*
  Note: a component method can have *multiple* signatures. Sigh. This
  is because XML-RPC introspection is designed that way.
  An invocation is always associated with either a single or no
  signature (no signature for generic calls).
*/

@interface SxComponentInvocation : NSObject < NSCoding >
{
  SxComponent                *target;
  NSString                   *methodName;
  SxComponentMethodSignature *signature;
  NSMutableArray             *arguments;
  id                         result;
  NSException                *lastException;
  id                         credentials;
}

- (id)initWithComponent:(SxComponent *)_component
  methodName:(NSString *)_method
  signature:(SxComponentMethodSignature *)_signature;

/* arguments */

- (SxComponentMethodSignature *)methodSignature;

- (void)setMethodName:(NSString *)_name;
- (NSString *)methodName;

- (void)setArgument:(id)_argument atIndex:(int)index;
- (id)argumentAtIndex:(int)index;
- (void)setArguments:(NSArray *)_args;
- (NSArray *)arguments;

- (void)setReturnValue:(id)_result;
- (id)returnValue;

- (void)setLastException:(NSException *)_exception;
- (NSException *)lastException;
- (void)resetLastException;

- (BOOL)argumentsRetained;

/* credentials */

- (void)setCredentials:(id)_credentials;
- (id)credentials;

/* Dispatching an Invocation */

- (BOOL)invokeWithTarget:(SxComponent *)_target;
- (BOOL)invoke;
- (BOOL)lastCallFailed; // if this is true, the result is nil !

- (BOOL)asyncInvoke;
- (BOOL)isAsyncResultPending;

/* KVC */

- (void)takeValue:(id)_value forKey:(NSString *)_key;
- (id)valueForKey:(NSString *)_key;

@end

#endif /* __SxComponentInvocation_H__ */
