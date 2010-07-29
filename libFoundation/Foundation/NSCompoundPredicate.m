/* 
   NSCompoundPredicate.m

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

#include "NSCompoundPredicate.h"
#include "NSArray.h"
#include "NSCoder.h"
#include "common.h"

@implementation NSCompoundPredicate

+ (NSPredicate *)andPredicateWithSubpredicates:(NSArray *)_subs
{
    return [[[self alloc] initWithType:NSAndPredicateType subpredicates:_subs]
	       autorelease];
}
+ (NSPredicate *)orPredicateWithSubpredicates:(NSArray *)_subs
{
    return [[[self alloc] initWithType:NSOrPredicateType subpredicates:_subs]
	       autorelease];
}
+ (NSPredicate *)notPredicateWithSubpredicates:(NSArray *)_subs
{
    return [[[self alloc] initWithType:NSNotPredicateType subpredicates:_subs] 
	       autorelease];
}

- (id)initWithType:(NSCompoundPredicateType)_type subpredicates:(NSArray *)_s
{
    if ((self = [super init]) != nil) {
    }
    return self;
}
- (id)init
{
    return [self initWithType:NSNotPredicateType subpredicates:nil];
}

- (void)dealloc
{
    [self->subs release];
    [super dealloc];
}

/* accessors */

- (NSCompoundPredicateType)compoundPredicateType
{
    return self->type;
}

- (NSArray *)subpredicates
{
    return self->subs;
}

/* evaluation */

- (BOOL)evaluateWithObject:(id)_object
{
    unsigned i, count;
    
    for (i = 0, count = [self->subs count]; i < count; i++) {
	BOOL ok;
	
	ok = [[self->subs objectAtIndex:i] evaluateWithObject:_object];
	
	/* Note: we treat NOT as a "AND (NOT x)*" */
	if (self->type == NSNotPredicateType)
	    ok = ok ? NO : YES;
	
	if (self->type == NSOrPredicateType) {
	    if (ok) return YES; /* short circuit */
	}
	else { /* AND or AND-NOT */
	    if (!ok) return NO; /* short circuit */
	}
    }
    
    return YES; /* TOD: empty == YES? */
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeValueOfObjCType:@encode(int) at:&(self->type)];
    [aCoder encodeObject:self->subs];
}
- (id)initWithCoder:(NSCoder*)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]) != nil) {
	[aDecoder decodeValueOfObjCType:@encode(int) at:&(self->type)];
	self->subs = [[aDecoder decodeObject] retain];
    }
    return self;
}

@end /* NSCompoundPredicate */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
