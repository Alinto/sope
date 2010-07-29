// $Id: EOFaultHandler.h 1 2004-08-20 10:38:46Z znek $

#ifndef __EOFaultHandler_h__
#define __EOFaultHandler_h__

#import <Foundation/NSObject.h>

@class NSInvocation, NSMethodSignature;
@class EOFault;

@interface EOFaultHandler : NSObject
{
@public
  int     faultReferences;
  void    *extraData;   /* saved ivars overridden by 'faultHandler' ivar */
  Class   targetClass;
  NSZone  *zone;
}

- (Class)targetClass;
- (void *)extraData;
- (void)setTargetClass:(Class)_class extraData:(void *)_extraData;

/* firing */

- (BOOL)shouldPerformInvocation:(NSInvocation *)_invocation;
- (void)faultWillFire:(EOFault *)_fault;
- (void)completeInitializationOfObject:(id)_object;

/* fault reflection */

- (Class)classForFault:(EOFault *)_fault;
- (BOOL)respondsToSelector:(SEL)_selector forFault:(EOFault *)_fault;
- (BOOL)conformsToProtocol:(Protocol *)_protocol forFault:(EOFault *)_fault;
- (BOOL)isKindOfClass:(Class)_class forFault:(EOFault *)_fault;
- (BOOL)isMemberOfClass:(Class)_class forFault:(EOFault *)_fault;

- (NSMethodSignature *)methodSignatureForSelector:(SEL)_selector
  forFault:(EOFault *)_fault;

/* description */

- (NSString *)descriptionForObject:(id)_fault;

@end /* EOFaultHandler */

#endif /* __EOFaultHandler_h__ */
