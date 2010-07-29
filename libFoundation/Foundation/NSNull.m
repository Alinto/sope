/* 
   NSNull.m

   Copyright (C) 2000, MDlink online service center GmbH, Helge Hess
   All rights reserved.

   Author: Helge Hess <helge.hess@mdlink.de>

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

#include <Foundation/NSNull.h>
#include <Foundation/NSUtilities.h>
#include <common.h>

@implementation NSNull

// MT, THREAD
static NSNull *sharedNSNull = nil;

+ (void)initialize
{
    if (sharedNSNull == nil) {
	sharedNSNull = (NSNull *)
	    NSAllocateObject(self, 0, NSDefaultMallocZone());
    }
}

+ (NSNull *)null
{
    return sharedNSNull;
}

+ (id)allocWithZone:(NSZone *)_zone
{
    return sharedNSNull;
}
+ (id)alloc
{
    return sharedNSNull;
}

- (void)dealloc
{
    NSLog(@"WARNING: tried to deallocate NSNull !");
    
    /* this is to please gcc 4.1 which otherwise issues a warning (and we
       don't know the -W option to disable it, let me know if you do ;-)*/
    if (0) [super dealloc];
}

/* NSCoding */

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self == sharedNSNull)
	return sharedNSNull;

    RELEASE(self);
    return sharedNSNull;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
}

/* NSCopying */

- (id)copy
{
    return RETAIN(self);
}
- (id)copyWithZone:(NSZone *)zone
{
    return RETAIN(self);
}

- (id)retain
{
    return self;
}
- (void)release
{
}
- (id)autorelease
{
    return self;
}

/* comparison */

- (NSComparisonResult)compare:(id)_otherObject
{
    return (_otherObject == self)
	? NSOrderedSame
	: NSOrderedDescending;
}

- (BOOL)boolValue
{
    return NO;
}

- (NSString *)description
{
    return @"<null>";
}
- (NSString *)stringValue
{
    return @"";
}

- (NSString *)stringRepresentation
{
  /* encode as empty string in property lists ! */
#if DEBUG
    NSLog(@"WARNING(%s): encoded NSNull in property list !",
	  __PRETTY_FUNCTION__);
#endif
    return @"\"\"";
}

@end /* NSNull */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
