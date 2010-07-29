/* 
   NSProxy.h

   Copyright (C) 1998 MDlink online service center, Helge Hess
   All rights reserved.

   Author: Helge Hess (helge@mdlink.de)

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#ifndef __NSProxy_h__
#define __NSProxy_h__

#include <Foundation/NSObject.h>
#include <Foundation/NSZone.h>

@class NSInvocation, NSMethodSignature, NSString;

@interface NSProxy < NSObject >
{
    Class isa;
}

+ (id)alloc;
+ (id)allocWithZone:(NSZone *)_zone;
- (void)dealloc;

// getting the class

+ (Class)class;

// handling unimplemented methods

- (void)forwardInvocation:(NSInvocation *)_invocation;
- (NSMethodSignature *)methodSignatureForSelector:(SEL)_selector;

// description

- (NSString *)description;

@end

#endif // __NSProxy_h__

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
