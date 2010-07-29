/* 
   PrintfFormatScanner.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@apache.org>

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

#import <Foundation/NSString.h>
#include "PrintfFormatScanner.h"
#include "DefaultScannerHandler.h"

@implementation PrintfFormatScanner

- (NSString *)stringWithFormat:(NSString *)format arguments:(va_list)args {
    va_list va;

#ifdef __va_copy
    __va_copy(va, args);
#else
    va = args;
#endif

    self->result = [NSMutableString stringWithCapacity:[format cStringLength]];
    [self parseFormatString:format context:&va];
    return [[self->result copy] autorelease];
}

- (BOOL)handleOrdinaryString:(NSString *)string {
    [self->result appendString:string];
    return YES;
}

- (BOOL)handleFormatSpecifierWithContext:(void *)context {
    [self->result appendString:[handler stringForArgument:context scanner:self]];
    return YES;
}

@end /* PrintfFormatScanner */
