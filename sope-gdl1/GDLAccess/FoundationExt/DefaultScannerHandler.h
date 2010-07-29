/* 
   DefaultScannerHandler.h

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

#ifndef __DefaultScannerHandler_h__
#define __DefaultScannerHandler_h__

#include <Foundation/NSObject.h>

@class NSString;
@class FormatScanner;

@interface DefaultScannerHandler : NSObject
{
    IMP specHandler[256];
}

- (NSString *)stringForArgument:(void *)arg scanner:(id)aFormatScanner;
- (NSString *)unknownSpecifier:(void *)arg scanner:(id)scanner;

@end

@class NSEnumerator;

@interface DefaultEnumScannerHandler : NSObject
{
    IMP specHandler[256];
}

- (NSString *)stringForArgument:(void *)arg scanner:(id)aFormatScanner;
- (NSString *)unknownSpecifier:(void *)arg scanner:(id)scanner;

@end

#endif /* __DefaultScannerHandler_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
