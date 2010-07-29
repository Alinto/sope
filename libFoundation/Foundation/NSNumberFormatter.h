/* 
   NSNumberFormatter.h

   Copyright (C) 1998 MDlink online service center, Helge Hess
   All rights reserved.

   Author: Helge Hess (helge@mdlink.de), Martin Spindler (spindler@mdlink.de)

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
// $Id: NSNumberFormatter.h 827 2005-06-03 14:18:27Z helge $

#ifndef __NSNumberFormatter_h__
#define __NSNumberFormatter_h__

#include <Foundation/NSFormatter.h>
#include <Foundation/NSString.h>

@class NSNumber;

@interface NSNumberFormatter : NSFormatter
{
@protected
    NSString  *negativeFormat;
    NSString  *positiveFormat;
    NSNumber  *minimum;
    NSNumber  *maximum;

    unichar   decimalSeparator;
    unichar   thousandSeparator;
    BOOL      hasThousandSeparator;
}

// setting formats

- (void)setPositiveFormat:(NSString *)_format;
- (NSString *)positiveFormat;

- (void)setNegativeFormat:(NSString *)_format;
- (NSString *)negativeFormat;

- (void)setFormat:(NSString *)_format;
- (NSString *)format;

// attributed string support

#if HAVE_ATTRIBUTED_STRING

- (void)setTextAttributesForPositiveValues:(NSDictionary *)_attrs;
- (NSDictionary *)textAttributesForPositiveValues;

- (void)setTextAttributesForNegativeValues:(NSDictionary *)_attrs;
- (NSDictionary *)textAttributesForNegativeValues;

- (void)setAttributedStringForZero:(NSAttributedString *)_string;
- (NSAttributedString *)attributedStringForZero;

- (void)setAttributedStringForNil:(NSAttributedString *)_string;
- (NSAttributedString *)attributedStringForNil;

- (void)setAttributedStringForNotANumber:(NSAttributedString *)_string;
- (NSAttributedString *)attributedStringForNotANumber;

#endif

// separators

- (void)setThousandSeparator:(NSString *)_string;
- (NSString *)thousandSeparator;

- (void)setDecimalSeparator:(NSString *)_string;
- (NSString *)decimalSeparator;

- (void)setHasThousandSeparators:(BOOL)_flag;
- (BOOL)hasThousandSeparators;

// ranges

#if HAVE_DECIMAL_NUMBER

- (void)setMinimum:(NSDecimalNumber *)_number;
- (NSDecimalNumber *)minimum;

- (void)setMaximum:(NSDecimalNumber *)_number;
- (NSDecimalNumber *)maximum;

- (void)setRoundingBehaviour:(NSDecimalNumberHandler *)_handler;
- (NSDecimalNumberHandler *)roundingBehaviour;

#else

- (void)setMinimum:(NSNumber *)_number;
- (NSNumber *)minimum;

- (void)setMaximum:(NSNumber *)_number;
- (NSNumber *)maximum;

#endif

- (void)setAllowsFloats:(BOOL)_flag;
- (BOOL)allowsFloats;

@end

#endif

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
