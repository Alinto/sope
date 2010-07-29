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

#ifndef __NGXmlRpcInvocation_H__
#define __NGXmlRpcInvocation_H__

#import <Foundation/NSObject.h>

@class NSString, NSMutableArray;
@class NGXmlRpcClient;
@class NGXmlRpcMethodSignature;

@interface NGXmlRpcInvocation : NSObject < NSCoding >
{
  NGXmlRpcClient          *target;
  NSString                *methodName;
  NGXmlRpcMethodSignature *signature;
  
  NSMutableArray *arguments;
  id             result;
}

- (id)initWithMethodSignature:(NGXmlRpcMethodSignature *)_sig;

/* arguments */

- (NGXmlRpcMethodSignature *)methodSignature;

- (void)setArgument:(id)_argument atIndex:(int)index;
- (id)argumentAtIndex:(int)index;

- (void)setReturnValue:(id)_result;
- (id)returnValue;

- (void)setMethodName:(NSString *)_mname;
- (NSString *)methodName;

- (void)setTarget:(NGXmlRpcClient *)_target;
- (NGXmlRpcClient *)target;

/* Dispatching an Invocation */

- (void)invoke;
- (void)invokeWithTarget:(NGXmlRpcClient *)_target;

@end

@interface NSObject(XmlRpcValue)

- (id)asXmlRpcValueOfType:(NSString *)_xmlRpcValueType;

@end

#endif /* __NGXmlRpcInvocation_H__ */
