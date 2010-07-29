/* 
   NSPredicate.m

   Copyright (C) 2005, Helge Hess
   All rights reserved.

   Author: Helge Hess <helge.hess@opengroupware.org>

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

#include "NSPredicate.h"

@interface NSTruePredicate : NSPredicate
@end

@interface NSFalsePredicate : NSPredicate
@end

#include "NSAutoreleasePool.h"
#include "common.h"

@implementation NSPredicate

/* evaluation */

- (BOOL)evaluateWithObject:(id)_object
{
    [self subclassResponsibility:_cmd];
    return NO;
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)aCoder
{
}
- (id)initWithCoder:(NSCoder*)aDecoder
{
    return self;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)zone
{
    /* NSPredicate objects are immutable! */
    return [self retain];
}

@end /* NSPredicate */


@implementation NSTruePredicate

/* evaluation */

- (BOOL)evaluateWithObject:(id)_object
{
    return YES;
}

@end /* NSTruePredicate */

@implementation NSFalsePredicate

/* evaluation */

- (BOOL)evaluateWithObject:(id)_object
{
    return NO;
}

@end /* NSFalsePredicate */


@implementation NSArray(NSPredicate)

- (NSArray *)filteredArrayUsingPredicate:(NSPredicate *)_predicate
{
    NSAutoreleasePool *pool;
    NSMutableArray *array = nil;
    NSArray  *result;
    unsigned i, count;

    pool = [[NSAutoreleasePool alloc] init];
    result = nil;
  
    count = [self count];
    array = [NSMutableArray arrayWithCapacity:count];
    for (i = 0, count; i < count; i++) {
	id o;
    
	o = [self objectAtIndex:i];
    
	if ([_predicate evaluateWithObject:o])
	    [array addObject:o];
    }
    result = [array copy];
    [pool release];
    return [result autorelease];
}

@end /* NSArray(NSPredicate) */

@implementation NSMutableArray(NSPredicate)

- (void)filterArrayUsingPredicate:(NSPredicate *)_predicate
{
    // TODO: improve performance, do inline edits
    NSAutoreleasePool *pool;
    NSMutableArray *array = nil;
    NSArray  *result;
    unsigned i, count;

    pool = [[NSAutoreleasePool alloc] init];
    result = nil;
  
    count = [self count];
    array = [NSMutableArray arrayWithCapacity:count];
    for (i = 0, count; i < count; i++) {
	id o;
    
	o = [self objectAtIndex:i];
    
	if ([_predicate evaluateWithObject:o])
	    [array addObject:o];
    }
  
    [self setArray:array];
    [pool release];
}

@end /* NSMutableArray(NSPredicate) */


/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
