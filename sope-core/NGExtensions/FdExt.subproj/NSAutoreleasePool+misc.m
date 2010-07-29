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

#import "common.h"
#import "NSAutoreleasePool+misc.h"

#if defined(LIB_FOUNDATION_LIBRARY)

BOOL __autoreleaseEnableRetainRemove = NO;

#if !LIB_FOUNDATION_BOEHM_GC

@implementation NSAutoreleasePool(misc)

// retain/remove check

+ (void)enableRetainRemove:(BOOL)enable {
    __autoreleaseEnableRetainRemove = enable;
}

+ (NSAutoreleasePool *)findReleasingPoolForObject:(id)_obj {
    NSAutoreleasePool *pool = nil;
    
    for (pool = [self defaultPool]; pool; pool = pool->parentPool) {
        NSAutoreleasePoolChunk *ch;
        int i;

        for (ch = pool->firstChunk; ch; ch = ch->next) {
            for (i = 0; i < ch->used; i++) {
                if (ch->objects[i] == _obj)
                    return pool;
            }
        }
        //if ([pool doesReleaseObject:_obj])
        //    return pool;
    }
    return nil;
}

+ (BOOL)retainAutoreleasedObject:(id)_obj {
    register NSAutoreleasePool *pool = nil;
    
    for (pool = [self defaultPool]; pool; pool = pool->parentPool) {
        register NSAutoreleasePoolChunk *ch;
        register int i;

        for (ch = pool->firstChunk; ch; ch = ch->next) {
            for (i = 0; i < ch->used; i++) {
                if (ch->objects[i] == _obj) {
                    ch->objects[i] = nil;
                    return YES;
                }
            }
        }
        //if ([pool doesReleaseObject:_obj])
        //    return pool;
    }
    return NO;
}

- (BOOL)retainAutoreleasedObject:(id)_obj {
    NSAutoreleasePoolChunk *ch;
    int i;

    for (ch = firstChunk; ch; ch = ch->next) {
	for (i = 0; i < ch->used; i++) {
	    if (ch->objects[i] == _obj) {
                ch->objects[i] = nil;
                return YES;
            }
        }
    }
    return NO;
}

@end

@implementation NSObject(RC)

- (oneway void)release
{
#if BUILD_libFoundation_DLL && defined(__WIN32__)
    extern __declspec(dllimport) BOOL __autoreleaseEnableCheck;
#else
    extern BOOL __autoreleaseEnableCheck;
#endif

    // check if retainCount is Ok
    if (__autoreleaseEnableCheck) {
	unsigned int toCome = 
	  [NSAutoreleasePool autoreleaseCountForObject:self];
	if (toCome + 1 > [self retainCount]) {
	    NSLog(@"Release[0x%p<%@>] release check for object %@ "
                  @"has %d references "
	    	  @"and %d pending calls to release in autorelease pools\n", 
		  self, NSStringFromClass([self class]),
                  self,
                  [self retainCount], toCome);
            NSLog(@"  description='%@'", [self description]);
            abort(); // core dump for debugging
	    return;
	}
    }
    if (NSExtraRefCount(self) == 1)
	[self dealloc];
    else
	NSDecrementExtraRefCountWasZero(self);
}

- (id)retain
{
    extern BOOL __autoreleaseEnableRetainRemove;

    if (__autoreleaseEnableRetainRemove) {
        if ([NSAutoreleasePool retainAutoreleasedObject:self]) {
            NSLog(@"retained autoreleased object ..");
            return self;
        }
    }
    
    NSIncrementExtraRefCount(self);
    return self;
}

@end

#endif // !LIB_FOUNDATION_BOEHM_GC

#endif // defined(LIB_FOUNDATION_LIBRARY)

void __link_NSAutoreleasePool_misc(void) {
  __link_NSAutoreleasePool_misc();
}
