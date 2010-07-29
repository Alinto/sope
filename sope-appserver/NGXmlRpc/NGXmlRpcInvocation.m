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

#include "NGXmlRpcInvocation.h"
#include "NGXmlRpcMethodSignature.h"
#include "NGXmlRpcClient.h"
#include "common.h"

@implementation NGXmlRpcInvocation

static NSNull *null = nil;

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

- (id)initWithMethodSignature:(NGXmlRpcMethodSignature *)_sig {
  if (_sig == nil) {
    RELEASE(self);
    return nil;
  }
  
  self->signature = RETAIN(_sig);
  [self _ensureArgs];
  
  return self;
}
- (id)init {
  return [self initWithMethodSignature:nil];
}

- (void)dealloc {
  RELEASE(self->arguments);
  RELEASE(self->result);
  RELEASE(self->target);
  RELEASE(self->methodName);
  RELEASE(self->signature);
  [super dealloc];
}

/* arguments */

- (NGXmlRpcMethodSignature *)methodSignature {
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

- (void)setTarget:(NGXmlRpcClient *)_target {
  ASSIGN(self->target, _target);
}
- (NGXmlRpcClient *)target {
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

/* Dispatching an Invocation */

- (void)invoke {
  [self invokeWithTarget:[self target]];
}

- (void)invokeWithTarget:(NGXmlRpcClient *)_target {
  NSAutoreleasePool *pool;
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    NSArray *args;
    id res;
    unsigned count;
    NGXmlRpcMethodSignature *sig;

    sig = [self methodSignature];
    
    /* collect arguments, coerce types ... */
    if ((count = [self->arguments count]) == 0)
      args = self->arguments;
    else if (sig) {
      unsigned i;
      id *aa;
      
      aa = calloc(count + 2 /* be defensive, yeah! */, sizeof(id));
      for (i = 0; i < count; i++) {
        NSString *xrtype;
        id value;
        
        xrtype = [sig argumentTypeAtIndex:i];
        
        value = [self->arguments objectAtIndex:i];
        value = [value asXmlRpcValueOfType:xrtype];
        aa[i] = value != nil ? value : (id)null;
      }
      args = [NSArray arrayWithObjects:aa count:count];
      if (aa != NULL) free(aa);
    }
    else
      args = self->arguments;
    
    /* invoke remote method */
    res = [_target invokeMethodNamed:[self methodName] parameters:args];
    
    /* store return value */
    [self setReturnValue:res];
  }
  RELEASE(pool);
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  [_coder encodeObject:self->target];
  [_coder encodeObject:self->methodName];
  [_coder encodeObject:self->signature];
  [_coder encodeObject:self->arguments];
  [_coder encodeObject:self->result];
}
- (id)initWithCoder:(NSCoder *)_coder {
  if (null == nil) null = [[NSNull null] retain];
  
  self->target     = [[_coder decodeObject] retain];
  self->methodName = [[_coder decodeObject] copy];
  self->signature  = [[_coder decodeObject] retain];
  self->arguments  = [[_coder decodeObject] retain];
  self->result     = [[_coder decodeObject] retain];
  
  if (self->signature == nil) {
    NSLog(@"%s: missing signature (required during decoding)",
          __PRETTY_FUNCTION__);
    RELEASE(self);
    return nil;
  }
  [self _ensureArgs];
  
  return self;
}

@end /* NGXmlRpcInvocation */

@implementation NSObject(XmlRpcValue)

- (NSArray *)asXmlRpcArray {
  if ([self respondsToSelector:@selector(objectEnumerator)]) {
    return [[[NSArray alloc]
                      initWithObjectsFromEnumerator:
                        [(id)self objectEnumerator]]
                      autorelease];
  }
  return nil;
}

- (NSDictionary *)asXmlRpcStruct {
  return [self valuesForKeys:[[self classDescription] attributeKeys]];
}

- (NSString *)asXmlRpcString {
  return [self stringValue];
}
- (int)asXmlRpcInt {
  return [self intValue];
}
- (int)asXmlRpcDouble {
  return [self doubleValue];
}

- (NSData *)asXmlRpcBase64 {
  return [[self stringValue] dataUsingEncoding:NSUTF8StringEncoding];
}
- (NSDate *)asXmlRpcDateTime {
  return [[[NSDate alloc] initWithString:[self stringValue]] autorelease];
}

- (id)asXmlRpcValueOfType:(NSString *)_xmlRpcValueType {
  unsigned len;
  
  if ((len = [_xmlRpcValueType length]) == 0)
    return self;

  if ([_xmlRpcValueType isEqualToString:@"string"])
    return [self asXmlRpcString];
  if ([_xmlRpcValueType isEqualToString:@"int"])
    return [NSNumber numberWithInt:[self asXmlRpcInt]];
  if ([_xmlRpcValueType isEqualToString:@"i4"])
    return [NSNumber numberWithInt:[self asXmlRpcInt]];
  if ([_xmlRpcValueType isEqualToString:@"double"])
    return [NSNumber numberWithDouble:[self asXmlRpcDouble]];
  if ([_xmlRpcValueType isEqualToString:@"float"])
    return [NSNumber numberWithDouble:[self asXmlRpcDouble]];
  if ([_xmlRpcValueType isEqualToString:@"array"])
    return [self asXmlRpcArray];
  if ([_xmlRpcValueType isEqualToString:@"struct"])
    return [self asXmlRpcStruct];
  if ([_xmlRpcValueType isEqualToString:@"datetime"])
    return [self asXmlRpcDateTime];
  if ([_xmlRpcValueType isEqualToString:@"base64"])
    return [self asXmlRpcBase64];
  
  return self;
}

@end /* NSObject(XmlRpcValue) */

@implementation NSArray(XmlRpcValue)

- (NSArray *)asXmlRpcArray {
  return self;
}

- (id)asXmlRpcValueOfType:(NSString *)_xmlRpcValueType {
  return self;
}

@end /* NSArray(XmlRpcValue) */

@implementation NSDictionary(XmlRpcValue)

- (NSArray *)asXmlRpcArray {
  return [self allValues];
}

- (NSDictionary *)asXmlRpcStruct {
  return self;
}

@end /* NSDictionary(XmlRpcValue) */

@implementation NSDate(XmlRpcValue)

- (NSDate *)asXmlRpcDateTime {
  return self;
}

@end /* NSDate(XmlRpcValue) */

@implementation NSData(XmlRpcValue)

- (NSData *)asXmlRpcBase64 {
  return self;
}

@end /* NSCalendarDate(XmlRpcValue) */
