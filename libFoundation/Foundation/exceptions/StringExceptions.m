/* 
   StringExceptions.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

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
#include <Foundation/exceptions/StringExceptions.h>

@implementation StringException
@end

NSString* NSStringBoundsError = @"Index out of range in string";

@implementation StringBoundsErrorException
- init
{
    return [self initWithName:NSStringBoundsError reason:nil userInfo:nil];
}
@end
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

