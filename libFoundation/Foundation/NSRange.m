/* 
   NSRange.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
	   Mircea Oancea <mircea@jupiter.elcom.pub.ro>

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

#include <Foundation/common.h>
#include <Foundation/NSString.h>

/* Query a Range */
BOOL	
NSEqualRanges(NSRange range1, NSRange range2)
{
    return ((range1.location == range2.location)
    		&& (range1.length == range2.length));
}

/* Compute a Range from Two Other Ranges */
NSRange 
NSUnionRange(NSRange aRange, NSRange bRange)
{
    NSRange range;
    
    range.location = MIN(aRange.location, bRange.location);
    range.length   = MAX(NSMaxRange(aRange), NSMaxRange(bRange)) 
    		- range.location;
    return range;
}

NSRange 
NSIntersectionRange (NSRange aRange, NSRange bRange)
{
    NSRange range;
    
    if (NSMaxRange(aRange) < bRange.location
    		|| NSMaxRange(bRange) < aRange.location)
	return NSMakeRange(0, 0);
	
    range.location = MAX(aRange.location, bRange.location);
    range.length   = MIN(NSMaxRange(aRange), NSMaxRange(bRange)) 
    		- range.location;
    return range;
}

NSString*
NSStringFromRange(NSRange range)
{
    return [NSString stringWithFormat:@"{location = %d; length = %d}",
    		range.location, range.length];
}

NSRange
NSSRangeFromString(NSString* string)
{
    return NSMakeRange(0,0);
}
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

