/* 
   GarbageCollector.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>

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

#ifndef __GarbageCollector_h__
#define __GarbageCollector_h__

#include <Foundation/NSObject.h>

@interface GarbageCollector : NSObject

/* Determining the garbage collector environment */

+ (BOOL)usesBoehmGC;
+ (void)collectGarbages;

@end


@interface GarbageCollector (ReferenceCountingGC)

+ (void)addObject:(id)anObject;
+ (void)objectWillBeDeallocated:(id)anObject;

+ (BOOL)isGarbageCollecting;

@end


#if LIB_FOUNDATION_BOEHM_GC

@interface GarbageCollector (BoehmGCSupport)

+ (void)registerForFinalizationObserver:(id)observer
  selector:(SEL)selector
  object:(id)object;
+ (void)unregisterObserver:(id)observer
  forObjectFinalization:(id)object;

+ (void)allowGarbageCollection;
+ (void)denyGarbageCollection;

@end

#endif /* LIB_FOUNDATION_BOEHM_GC */


#endif /* __GarbageCollector_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
