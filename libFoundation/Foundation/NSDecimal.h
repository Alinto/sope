/* 
   NSDecimal.h

   Copyright (C) 2001, MDlink online service center GmbH, Helge Hess
   All rights reserved.

   Author: Helge Hess <helge.hess@mdlink.de>

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

#ifndef __NSDecimal_h__
#define __NSDecimal_h__

#include <Foundation/NSObject.h>

@class NSString, NSDictionary;

/* not fixed yet */

typedef enum {
  NSRoundPlain,
  NSRoundDown,
  NSRoundUp,
  NSRoundBankers
} NSRoundingMode;

typedef enum {
  NSCalculationOK,
  NSCalculationLossOfPrecision,
  NSCalculationOverflow,
  NSCalculationUnderflow,
  NSCalculationDivideByZero,
  NSCalculationNotImplemented
} NSCalculationError;

typedef struct {
  unsigned long long mantissa;
  signed char        exponent;
  BOOL               isNegative;
} NSDecimal;

/* operations */

NSCalculationError NSDecimalAdd
(NSDecimal *result, const NSDecimal *l, const NSDecimal *r, NSRoundingMode rmod);
NSCalculationError NSDecimalSubtract
(NSDecimal *result, const NSDecimal *l, const NSDecimal *r, NSRoundingMode rmod);
NSCalculationError NSDecimalDivide
(NSDecimal *result, const NSDecimal *l, const NSDecimal *r, NSRoundingMode rmod);
NSCalculationError NSDecimalMultiply
(NSDecimal *result, const NSDecimal *l, const NSDecimal *r, NSRoundingMode rmod);

NSCalculationError NSDecimalMultiplyByPowerOf10
(NSDecimal *result, const NSDecimal *n, short p, NSRoundingMode rmod);

NSCalculationError NSDecimalPower
(NSDecimal *result, const NSDecimal *n, unsigned int p, NSRoundingMode rmod);

/* comparisons */

NSComparisonResult NSDecimalCompare(const NSDecimal *l, const NSDecimal *r);
BOOL NSDecimalIsNotANumber(const NSDecimal *decimal);

/* misc */

void NSDecimalRound
(NSDecimal *result, const NSDecimal *n, int scale, NSRoundingMode rmode);

void NSDecimalCompact(NSDecimal *number);
void NSDecimalCopy(NSDecimal *dest, const NSDecimal *src);

NSCalculationError NSDecimalNormalize
(NSDecimal *number1, NSDecimal *number2, NSRoundingMode rmod);

NSString *NSDecimalString(const NSDecimal *decimal, NSDictionary *locale);

#endif /* __NSDecimal_h__ */
