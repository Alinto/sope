/* 
   NSCoderExceptions.m

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
#include <Foundation/NSDictionary.h>
#include <Foundation/NSValue.h>
#include <extensions/exceptions/NSCoderExceptions.h>


@implementation NSCoderException
@end /* NSCoderExceptions */


@implementation InvalidSignatureForCoderException
- init
{
    self = [self initWithName:NSInvalidArgumentException
	    reason:@"Invalid signature for unarchiver's data: "
		    @"data written by an unknown archiver type"
	    userInfo:nil];
    return self;
}
@end /* InvalidSignatureForCoder */


@implementation DifferentKindOfCodersException
- initForClassName:(NSString*)class1 andClassName:(NSString*)class2
{
    self = [self initWithName:NSInvalidArgumentException
	    reason:@"Invalid coder signature"
	    userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
					class1, @"first class",
					class2, @"second class", nil]];
    return self;
}
@end /* DifferentKindOfCodersException */


@implementation CoderHasAlreadyWrittenRootObjectException
- init
{
    self = [self initWithName:NSInvalidArgumentException
	    reason:@"Coder has already written root object"
	    userInfo:nil];
    return self;
}
@end /* CoderHasAlreadyWrittenRootObjectException */


@implementation RootObjectHasNotBeenWrittenException
- init
{
    self = [self initWithName:NSInvalidArgumentException
	    reason:@"Root object has not been written before"
	    userInfo:nil];
    return self;
}
@end /* RootObjectHasNotBeenWrittenException */

@implementation UnexpectedTypeException
+ allocForExpected:(NSString*)_expected andGot:(NSString*)_got
{
    UnexpectedTypeException* exception = [self alloc];
    exception->expected = _expected;
    exception->got = _got;

    exception = [exception initWithName:NSInvalidArgumentException
	    reason:@"Different type was written in archive"
	    userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
				    exception->expected, @"expected to read",
				    exception->got, @"got from archive", nil]];

    return exception;
}

+ allocForExpectedSize:(int)_expected andGotSize:(int)_got
{
    UnexpectedTypeException* exception = [self alloc];
    exception->expected = [[NSNumber numberWithInt:_expected] stringValue];
    exception->got = [[NSNumber numberWithInt:_got] stringValue];

    exception = [exception initWithName:NSInvalidArgumentException
	    reason:@"Different number of elements was written in archive"
	    userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
				exception->expected, @"expected to read",
				exception->got, @"got from archive", nil]];

    return exception;
}
@end /* UnexpectedTypeException */


@implementation ReadUnknownTagException
- initForTag:(char)_tag
{
    tag = _tag;
    self = [self initWithName:NSInvalidArgumentException
	    reason:@"Invalid tag read from archive"
	    userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
			[[NSNumber numberWithChar:tag] stringValue], @"tag",
			nil]];
    return self;
}
@end /* ReadUnknownTagException */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

