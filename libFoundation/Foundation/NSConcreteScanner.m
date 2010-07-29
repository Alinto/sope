/* 
   NSConcreteScanner.m

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

#include <Foundation/common.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSCharacterSet.h>
#include "NSConcreteScanner.h"

@implementation NSConcreteScanner

- (id)initWithString:(NSString*)_string
{
    ASSIGN(self->string, _string);
    return self;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
    RELEASE(self->string);
    RELEASE(self->locale);
    RELEASE(self->skipSet);
    [super dealloc];
}
#endif

- (NSString *)string
{
    return self->string;
}

- (void)setScanLocation:(unsigned int)index
{
    self->scanLocation = index;
}
- (unsigned int)scanLocation
{
    return self->scanLocation;
}

- (void)setCaseSensitive:(BOOL)flag
{
    self->caseSensitive = flag;
}
- (BOOL)caseSensitive
{
    return self->caseSensitive;
}

- (void)setCharactersToBeSkipped:(NSCharacterSet *)_skipSet
{
    ASSIGN(self->skipSet, _skipSet);
}
- (NSCharacterSet *)charactersToBeSkipped
{
    return self->skipSet;
}

- (void)setLocale:(NSDictionary *)_locale
{
    ASSIGN(self->locale, _locale);
}
- (NSDictionary *)locale
{
    return self->locale;
}

@end /* NSConcreteScanner */
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

