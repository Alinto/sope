// $Id: EOFault.h 1 2004-08-20 10:38:46Z znek $

#ifndef __EOFault_h__
#define __EOFault_h__

#import <Foundation/NSObject.h>

@class NSArray, NSDictionary, NSString, NSMethodSignature;

@class EOFaultHandler;

@interface EOFault
{
  Class          isa;
  EOFaultHandler *faultResolver;
}

+ (void)makeObjectIntoFault:(id)_object withHandler:(EOFaultHandler *)_handler;
+ (EOFaultHandler *)handlerForFault:(id)_fault;

/* Inquire about a fault */

+ (BOOL)isFault:(id)object;
+ (BOOL)isFault;
- (BOOL)isFault;
+ (void)clearFault:(id)fault;

+ (Class)targetClassForFault:fault;

/* Non-Faulting Instance methods */

- (Class)superclass;
- (Class)class;
+ (Class)class;
- (BOOL)isKindOfClass:(Class)aClass;
- (BOOL)isMemberOfClass:(Class)aClass;
- (BOOL)conformsToProtocol:(Protocol *)aProtocol;
- (BOOL)respondsToSelector:(SEL)aSelector;

+ (id)self;

- (void)dealloc;
- retain;
- (void)release;
- autorelease;
- (NSUInteger)retainCount;
- (NSZone*)zone;

- (BOOL)isProxy;
- (BOOL)isGarbageCollectable;
- (NSString *)description;

- (NSMethodSignature *)methodSignatureForSelector:(SEL)_selector;

@end /* EOFault */

#include <GDLAccess/EOFaultHandler.h>

#endif  /* __EOFault_h__ */
