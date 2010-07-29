/* 
   DefaultScannerHandler.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@apache.org>
           Helge Hess <helge.hess@opengroupware.org>

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
#include "FormatScanner.h"
#include "DefaultScannerHandler.h"

@implementation DefaultScannerHandler

- (id)init {
    int i;
    IMP unknownSpecifierIMP
	    = [self methodForSelector:@selector(unknownSpecifier:scanner:)];

    for(i = 0; i < 256; i++)
	specHandler[i] = unknownSpecifierIMP;
    return self;
}

- (NSString *)unknownSpecifier:(void *)arg scanner:scanner
{
    char str[] = { [scanner characterSpecifier], 0 };
    return [NSString stringWithCString:str];
}

- (NSString *)stringForArgument:(void *)arg scanner:scanner
{
    return (*specHandler[(int)[scanner characterSpecifier]])
		(self, _cmd, arg, scanner);
}

@end /* DefaultScannerHandler */

@implementation DefaultEnumScannerHandler

- (id)init
{
    int i;
    IMP unknownSpecifierIMP;

    unknownSpecifierIMP =
        [self methodForSelector:@selector(unknownSpecifier:scanner:)];
    
    for(i = 0; i < 256; i++)
	self->specHandler[i] = unknownSpecifierIMP;
    return self;
}

- (NSString *)unknownSpecifier:(void *)arg scanner:scanner
{
    char str[] = { [scanner characterSpecifier], 0 };
    return [NSString stringWithCString:str];
}

- (NSString *)stringForArgument:(void *)arg scanner:scanner
{
    return (*specHandler[(int)[scanner characterSpecifier]])
		(self, _cmd, arg, scanner);
}

@end /* DefaultEnumScannerHandler */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
