/* 
   NSInvocationExceptions.m

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

#include <Foundation/NSString.h>
#include <Foundation/exceptions/NSInvocationExceptions.h>

@implementation NSInvocationException
@end /* NSInvocationException */


@implementation NullTargetException
- init
{
    [self initWithName:NSInvalidArgumentException
	    reason:@"Target for NSInvocation must not be the nil object"
	    userInfo:nil];
    return self;
}
@end /* NullTargetException */


@implementation NullSelectorException
- init
{
    [self initWithName:NSInvalidArgumentException
	    reason:@"Selector for NSInvocation must not be the NULL selector"
	    userInfo:nil];
    return self;
}
@end /* NullSelectorException */


@implementation InvalidMethodSignatureException
- init
{
    [self initWithName:NSInvalidArgumentException
	reason:@"NSMethodSignature must not be nil to perform the operation"
	userInfo:nil];
    return self;
}
@end /* InvalidMethodSignatureException */


@implementation FrameIsNotSetupException
- init
{
    [self initWithName:NSInvalidArgumentException
	reason:@"Frame must be previously set up before invoking the method"
	userInfo:nil];
    return self;
}
@end /* FrameIsNotSetupException */


@implementation CouldntGetTypeForSelector
- initForSelector:(SEL)selector
{
    reason = [NSString stringWithFormat:@"Couldn't get type for selector %s",
				    [NSStringFromSelector(selector) cString]];
    [self initWithName:NSInvalidArgumentException
		    reason:reason userInfo:nil];
    return self;
}
@end /* CouldntGetTypeForSelector */


@implementation TypesDontMatchException
- initWithTypes:(const char*)t1 :(const char*)t2
{
	reason = [NSString stringWithFormat:@"Types of selector and method "
			    @"signature don't match: '%s' and '%s'", t1, t2];
	[self initWithName:NSInvalidArgumentException
			reason:reason userInfo:nil];
	return self;
}
@end
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

