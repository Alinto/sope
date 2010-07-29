/* 
   NSSortDescriptor.m

   Copyright (C) 2003 SKYRIX Software AG, Helge Hess.
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

#include <Foundation/NSSortDescriptor.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSNull.h>
#include <Foundation/NSException.h>
#include <Foundation/NSKeyValueCoding.h>
#include <common.h>

@implementation NSSortDescriptor

- (id)initWithKey:(NSString *)_key ascending:(BOOL)_asc selector:(SEL)_sortsel
{
    if ((self = [super init])) {
        self->key                 = [_key copy];
        self->selector            = _sortsel ? _sortsel : @selector(compare:);
        self->sdFlags.isAscending = _asc ? 1 : 0;
    }
    return self;
}
- (id)initWithKey:(NSString *)_key ascending:(BOOL)_asc
{
    return [self initWithKey:_key ascending:_asc selector:@selector(compare:)];
}
- (id)init 
{
    return [self initWithKey:nil ascending:YES selector:NULL];
}

/* accessors */

- (NSString *)key 
{
    return self->key;
}
- (SEL)selector
{
    return self->selector;
}
- (BOOL)ascending
{
    return self->sdFlags.isAscending ? YES : NO;
}

/* operations */

- (id)reversedSortDescriptor 
{
    return [self initWithKey:[self key] 
                 ascending:([self ascending] ? NO : YES)
                 selector:[self selector]];
}

- (NSComparisonResult)compareObject:(id)_obj1 toObject:(id)_obj2 
{
    // TODO: check out edge cases (eg nil!)
    NSComparisonResult (*sortfunc)(id, SEL, id);
    BOOL               doReverse;
    NSComparisonResult result;
    id v1, v2;
    
    if (_obj1 == _obj2) return NSOrderedSame;
    
    v1 = [_obj1 valueForKey:self->key];
    v2 = [_obj2 valueForKey:self->key];
    if (v1 == v2) return NSOrderedSame;
    
    doReverse = ![self ascending];
    if (v1 == nil) { /* if the left side is nil, swap for comparison */
        v1 = v2;
        v2 = nil;
        doReverse = !doReverse;
    }
    
    if ((sortfunc = (void*)[v1 methodForSelector:self->selector]) == NULL)
        return NSOrderedAscending;
    
    result = sortfunc(v1, self->selector, v2);
    if (!doReverse) return result;
    
    /* reverse */
    if (result < 0)
        return NSOrderedDescending;
    if (result > 0)
        return NSOrderedAscending;
    return NSOrderedSame;
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder
{
    BOOL iasc = self->sdFlags.isAscending;
    [_coder encodeObject:self->key];
    [_coder encodeValueOfObjCType:@encode(SEL)  at:&(self->selector)];
    [_coder encodeValueOfObjCType:@encode(BOOL) at:&iasc];
}
- (id)initWithCoder:(NSCoder *)_decoder
{
    NSString *ikey = nil;
    SEL      isel  = NULL;
    BOOL     iasc  = YES;
    
    ikey = [_decoder decodeObject];
    [_decoder decodeValueOfObjCType:@encode(SEL)  at:&isel];
    [_decoder decodeValueOfObjCType:@encode(BOOL) at:&iasc];
    return [self initWithKey:ikey ascending:iasc selector:isel];
}

/* NSCopying */

- (id)copyWithZone:(NSZone*)zone
{
    if (NSShouldRetainWithZone(self, zone))
	return [self retain];
    
    return [[NSSortDescriptor allocWithZone:zone]
               initWithKey:[self key] 
               ascending:[self ascending] 
               selector:[self selector]];
}

@end /* NSSortDescriptor */

@implementation NSArray(NSSortDescriptorSort)

- (NSArray *)sortedArrayUsingDescriptors:(NSArray *)_descs
{
    NSMutableArray *m      = nil;
    NSArray        *result = nil;
  
    if ([_descs count] == 0)
        return [[self copy] autorelease];
  
    m = [self mutableCopy];
    [m sortUsingDescriptors:_descs];
    result = [m copy];
    [m release]; m = nil;
    return [result autorelease];
}

@end /* NSArray(NSSortDescriptorSort) */

@implementation NSMutableArray(NSSortDescriptorSort)

#define MAX_DESC_COUNT 10
typedef struct {
    NSSortDescriptor *sortdescs[MAX_DESC_COUNT]; /* max depth 10 */
    short            count;
} NSSortDescriptorContext;

static NSNull *null = nil;

static int sortDescComparator(id o1, id o2, NSSortDescriptorContext *context) 
{
    short i;

    for (i = 0; i < context->count; i++) {
        int result;
        
        result = [context->sortdescs[i] compareObject:o1 toObject:o2];
        if (result != NSOrderedSame)
            return result;
    }
    return NSOrderedSame;
}

- (void)sortUsingDescriptors:(NSArray *)_descs 
{
    NSEnumerator            *e    = nil;
    NSSortDescriptor        *desc = nil;
    NSSortDescriptorContext ctx;
    int                     i;
  
    NSAssert1([_descs count] < MAX_DESC_COUNT, 
              @"max sort descriptor count is %i!", MAX_DESC_COUNT);
  
    e = [_descs objectEnumerator];
    for (i = 0; (desc = [e nextObject]) && (i < MAX_DESC_COUNT); i++)
        ctx.sortdescs[i] = desc;
  
    ctx.count = i;
  
    if (null == nil) null = [NSNull null];
    [self sortUsingFunction:(void *)sortDescComparator context:&ctx];
}

@end /* NSMutableArray(NSSortDescriptorSort) */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
