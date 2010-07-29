/* 
   NSRange.h

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

#ifndef __NSRange_h__
#define __NSRange_h__

#include <Foundation/NSObject.h>

typedef struct _NSRange 
{
    unsigned int location;
    unsigned int length;
} NSRange;

#if (__GNUC__ == 2) && (__GNUC_MINOR__ <= 6) && !defined(__attribute__)
#  define __attribute__(x)
#endif

@class NSString;

LF_EXPORT NSRange	NSUnionRange(NSRange range1, NSRange range2);
LF_EXPORT NSRange	NSIntersectionRange(NSRange range1, NSRange range2);
LF_EXPORT NSString* NSStringFromRange(NSRange range);
LF_EXPORT NSRange  NSSRangeFromString(NSString* string);
LF_EXPORT BOOL 	NSEqualRanges(NSRange range1, NSRange range2);

static inline unsigned NSMaxRange(NSRange) __attribute__((unused));
static inline BOOL NSLocationInRange(unsigned, NSRange)
    __attribute__((unused));

static inline NSRange
NSMakeRange(unsigned int location, unsigned int length)
    __attribute__((unused));


static inline NSRange
NSMakeRange(unsigned int location, unsigned int length)
{
    NSRange range;
    range.location = location;
    range.length   = length;
    return range;
}

static inline unsigned
NSMaxRange(NSRange range) 
{
  return range.location + range.length;
}

static inline BOOL 
NSLocationInRange(unsigned location, NSRange range) 
{
  return (location >= range.location) && (location < NSMaxRange(range));
}

#endif /* __NSRange_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
