/* 
   NSCoderExceptions.h

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

#ifndef __NSCoderExceptions_h__
#define __NSCoderExceptions_h__

#include <extensions/exceptions/FoundationException.h>

@class NSString;

@interface NSCoderException : FoundationException
@end

@interface InvalidSignatureForCoderException : NSCoderException
@end

@interface DifferentKindOfCodersException : NSCoderException
- initForClassName:(NSString*)class1 andClassName:(NSString*)class2;
@end

@interface CoderHasAlreadyWrittenRootObjectException : NSCoderException
@end

@interface RootObjectHasNotBeenWrittenException : NSCoderException
@end

@interface UnexpectedTypeException : NSCoderException
{
    NSString* expected;
    NSString* got;
}
+ allocForExpected:(NSString*)expected andGot:(NSString*)got;
+ allocForExpectedSize:(int)expected andGotSize:(int)got;
@end

@interface ReadUnknownTagException : NSCoderException
{
    char tag;
}
- initForTag:(char)tag;
@end

#endif /* __NSCoderExceptions_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
