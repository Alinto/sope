/* 
   NSDecimal.m

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

#include <Foundation/NSDecimal.h>
#include <Foundation/NSString.h>
#include <common.h>
#include <math.h>

/* operations */

NSCalculationError NSDecimalAdd
(NSDecimal *res, const NSDecimal *_l, const NSDecimal *_r, NSRoundingMode rmod)
{
  /* WARNING: no overflow checks ... */
  NSCalculationError e;
  NSDecimal l, r;
  
  NSDecimalCopy(&l, _l);
  NSDecimalCopy(&r, _r);
  
  if ((e = NSDecimalNormalize(&l, &r, rmod)) != NSCalculationOK)
    return e;
  
  res->exponent = l.exponent;
  
  if (l.isNegative == r.isNegative) {
    /* both are positive or both are negative */
    res->mantissa   = l.mantissa + r.mantissa;
    res->isNegative = l.isNegative;
  }
  else {
    /* one is negative, subtraction */
    
    if (l.isNegative) {
      /* switch positions ... */
      NSDecimal swap;
      
      NSDecimalCopy(&swap, &l);
      NSDecimalCopy(&l, &r);
      NSDecimalCopy(&r, &swap);
    }
    
    /* now l is positive and r is negative */
    if (l.mantissa == r.mantissa) {
      /* x - x = 0 */
      res->mantissa   = 0;
      res->exponent   = l.exponent;
      res->isNegative = NO;
    }
    else if (l.mantissa > r.mantissa) {
      res->mantissa   = l.mantissa - r.mantissa;
      res->exponent   = l.exponent;
      res->isNegative = NO;
    }
    else {
      res->mantissa   = r.mantissa - l.mantissa;
      res->exponent   = l.exponent;
      res->isNegative = YES;
    }
  }
  
  return NSCalculationOK;
}

NSCalculationError NSDecimalSubtract
(NSDecimal *result, const NSDecimal *l, const NSDecimal *r, NSRoundingMode rmod)
{
  /* negate rightside, then add */
  NSDecimal d;
  
  NSDecimalCopy(&d, r);
  d.isNegative = r->isNegative ? NO : YES;
  
  return NSDecimalAdd(result, l, &d, rmod);
}

NSCalculationError NSDecimalMultiply
(NSDecimal *res, const NSDecimal *_l, const NSDecimal *_r, NSRoundingMode rmod)
{
  /* WARNING: no overflow checks ... */
  NSCalculationError e;
  NSDecimal l, r;
  
  NSDecimalCopy(&l, _l);
  NSDecimalCopy(&r, _r);
  
  if ((e = NSDecimalNormalize(&l, &r, rmod)) != NSCalculationOK)
    return e;
  
  res->exponent   = l.exponent;
  res->mantissa   = l.mantissa * r.mantissa;
  res->isNegative = l.isNegative==r.isNegative ? NO : YES;
  
  return NSCalculationOK;
}

NSCalculationError NSDecimalDivide
(NSDecimal *result, const NSDecimal *l, const NSDecimal *r, NSRoundingMode rmod)
{
  if (r->mantissa == 0)
    return NSCalculationDivideByZero;
  
  return NSCalculationNotImplemented;
}

NSCalculationError NSDecimalMultiplyByPowerOf10
(NSDecimal *result, const NSDecimal *n, short p, NSRoundingMode rmod)
{
  /* simple left shift .. */
  if (n->exponent + p > 127)
    return NSCalculationOverflow;
  if (n->exponent + p < -128)
    return NSCalculationUnderflow;
  
  NSDecimalCopy(result, n);
  result->exponent += p;
  return NSCalculationNotImplemented;
}

NSCalculationError NSDecimalPower
(NSDecimal *result, const NSDecimal *n, unsigned int p, NSRoundingMode rmod)
{
  return NSCalculationNotImplemented;
}

/* comparisons */

NSComparisonResult NSDecimalCompare(const NSDecimal *l, const NSDecimal *r)
{
  if (l == r) return NSOrderedSame;
  return NSOrderedAscending;
}

BOOL NSDecimalIsNotANumber(const NSDecimal *decimal)
{
  return NO;
}

/* misc */

void NSDecimalRound
(NSDecimal *result, const NSDecimal *n, int scale, NSRoundingMode rmode)
{
}

void NSDecimalCompact(NSDecimal *number)
{
}

void NSDecimalCopy(NSDecimal *dest, const NSDecimal *src)
{
  memcpy(dest, src, sizeof(NSDecimal));
}

NSCalculationError NSDecimalNormalize
(NSDecimal *number1, NSDecimal *number2, NSRoundingMode rmod)
{
  if (number1->exponent == number2->exponent)
    return NSCalculationOK;
  
  return NSCalculationNotImplemented;
}

NSString *NSDecimalString(const NSDecimal *_num, NSDictionary *locale)
{
  NSString *s;
  
  s = [NSString stringWithFormat:@"%si",
                  _num->isNegative ? "-" : "",
                  (int)_num->mantissa];
  
  if (_num->exponent >= 0) {
    /* add exp zeros to the end */
    switch (_num->exponent) {
      case 0: break;
      case 1: s = [s stringByAppendingString:@"0"]; break;
      case 2: s = [s stringByAppendingString:@"00"]; break;
      case 3: s = [s stringByAppendingString:@"000"]; break;
      case 4: s = [s stringByAppendingString:@"0000"]; break;
      default: {
        int i;
        for (i = 0; i < _num->exponent; i++)
          s = [s stringByAppendingString:@"0"];
        break;
      }
    }
  }
  else {
    /* insert a decimal separator */
    unsigned len;
    
    len = [s length];

    /* TO BE COMPLETED !!! */

    {
      double d;
      d = ((double)_num->mantissa) * pow(10, _num->exponent);
      s = [NSString stringWithFormat:@"%s%g",
                      _num->isNegative ? "-" : "",
                      d];
    }
  }
  
  return s;
}
