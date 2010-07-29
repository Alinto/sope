/* 
   NSDecimalNumber.m

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

#include <Foundation/NSDecimalNumber.h>
#include <Foundation/NSUtilities.h>
#include <common.h>
#include <math.h>

@interface NSDecimalZeroNumber : NSDecimalNumber
@end

@interface NSDecimalOneNumber : NSDecimalNumber
@end

@interface NSDecimalNotANumber : NSDecimalNumber
@end

@implementation NSDecimalNumber

static id<NSObject,NSDecimalNumberBehaviors> defBehavior = nil; // THREAD
static NSDecimalNumber *zero = nil; // THREAD
static NSDecimalNumber *one  = nil; // THREAD
static NSDecimalNumber *nan  = nil; // THREAD

+ (void)setDefaultBehavior:(id<NSDecimalNumberBehaviors>)_beh
{
  ASSIGN(defBehavior, _beh);
}
+ (id<NSDecimalNumberBehaviors>)defaultBehavior
{
  return defBehavior;
}

+ (NSDecimalNumber *)zero
{
  if (zero == nil)
    zero = [[NSDecimalZeroNumber alloc] init];
  return zero;
}
+ (NSDecimalNumber *)one
{
  if (one == nil)
    one = [[NSDecimalOneNumber alloc] init];
  return one;
}
+ (NSDecimalNumber *)notANumber
{
  if (nan == nil)
    nan = [[NSDecimalNotANumber alloc] init];
  return nan;
}

+ (NSDecimalNumber *)maximumDecimalNumber
{
  return [self notImplemented:_cmd];
}
+ (NSDecimalNumber *)minimumDecimalNumber
{
  return [self notImplemented:_cmd];
}

+ (NSDecimalNumber *)decimalNumberWithDecimal:(NSDecimal)_num
{
  return AUTORELEASE([[self alloc] initWithDecimal:_num]);
}
+ (NSDecimalNumber *)decimalNumberWithMantissa:(unsigned long long)_mantissa
  exponent:(short)_exp
  isNegative:(BOOL)_flag
{
  return AUTORELEASE([[self alloc] initWithMantissa:_mantissa
                                   exponent:_exp isNegative:_flag]);
}

+ (NSDecimalNumber *)decimalNumberWithString:(NSString *)_s
{
  return AUTORELEASE([[self alloc] initWithString:_s]);
}
+ (NSDecimalNumber *)decimalNumberWithString:(NSString *)_s
  locale:(NSDictionary *)_locale
{
  return AUTORELEASE([[self alloc] initWithString:_s locale:_locale]);
}

+ (NSDecimalNumber *)decimalNumberWithNumber:(NSNumber *)_number
{
  /* TO BE FIXED ! */
  return (id)[self numberWithDouble:[_number doubleValue]];
}

- (id)initWithDecimal:(NSDecimal)_num
{
  /* designated initializer */
  if (_num.exponent == 0) {
    if (_num.mantissa == 0) {
      RELEASE(self);
      if (zero) return RETAIN(zero);
      return [[[self class] zero] retain];
    }
    else if (_num.mantissa == 1) {
      RELEASE(self);
      if (one) return RETAIN(one);
      return [[[self class] one] retain];
    }
  }
  
  self->decimal = _num;
  return self;
}
- (id)init
{
  return [self initWithMantissa:0 exponent:0 isNegative:NO];
}

- (id)initWithMantissa:(unsigned long long)_mantissa
  exponent:(short)_exp
  isNegative:(BOOL)_flag
{
  NSDecimal d;
  d.mantissa   = _mantissa;
  d.exponent   = _exp;
  d.isNegative = _flag ? YES : NO;
  return [self initWithDecimal:d];
}

- (id)initWithString:(NSString *)_s locale:(NSDictionary *)_locale
{
  return [self initWithDouble:[_s doubleValue]];
}
- (id)initWithString:(NSString *)_s
{
  return [self initWithString:_s locale:nil];
}

/* integer init's */

- (id)initWithBool:(BOOL)value
{
  return [self initWithInt:value ? 1 : 0];
}
- (id)initWithChar:(signed char)value
{
  return [self initWithInt:value];
}
- (id)initWithUnsignedChar:(unsigned char)value
{
  return [self initWithInt:value];
}
- (id)initWithShort:(signed short)value
{
  return [self initWithInt:value];
}
- (id)initWithUnsignedShort:(unsigned short)value
{
  return [self initWithInt:value];
}

- (id)initWithInt:(signed int)value
{
  NSDecimal d;
  d.exponent   = 0;
  if (value < 0) {
    d.mantissa   = -value;
    d.isNegative = YES;
  }
  else {
    d.mantissa   = value;
    d.isNegative = NO;
  }
  return [self initWithDecimal:d];
}
- (id)initWithUnsignedInt:(unsigned int)value
{
  NSDecimal d;
  d.exponent   = 0;
  d.mantissa   = value;
  d.isNegative = NO;
  return [self initWithDecimal:d];
}

- (id)initWithLong:(signed long)value
{
  NSDecimal d;
  d.exponent   = 0;
  if (value < 0) {
    d.mantissa   = -value;
    d.isNegative = YES;
  }
  else {
    d.mantissa   = value;
    d.isNegative = NO;
  }
  return [self initWithDecimal:d];
}
- (id)initWithUnsignedLong:(unsigned long)value
{
  NSDecimal d;
  d.exponent   = 0;
  d.mantissa   = value;
  d.isNegative = NO;
  return [self initWithDecimal:d];
}

- (id)initWithLongLong:(signed long long)value
{
  NSDecimal d;
  d.exponent   = 0;
  if (value < 0) {
    d.mantissa   = -value;
    d.isNegative = YES;
  }
  else {
    d.mantissa   = value;
    d.isNegative = NO;
  }
  return [self initWithDecimal:d];
}
- (id)initWithUnsignedLongLong:(unsigned long long)value
{
  NSDecimal d;
  d.exponent   = 0;
  d.mantissa   = value;
  d.isNegative = NO;
  return [self initWithDecimal:d];
}

/* floating point inits */

- (id)initWithFloat:(float)value
{
  return [self initWithDouble:(double)value];
}
- (id)initWithDouble:(double)value
{
  char buf[128];
  char      *comma, *start;
  NSDecimal d;
  
  /* TODO: snprintf doesn't seem to exist on Solaris 2.5, add to configure */
  if (snprintf(buf, sizeof(buf), "%g", value) < 1) {
    RELEASE(self);
    return nil;
  }
  
  d.isNegative = value < 0.0 ? YES : NO;
  
  start = d.isNegative ? &(buf[1]) : buf; /* strip the minus */
  
  if ((comma = index(buf, '.'))) {
    /* decimal sep */
    unsigned long int vk, nk;
    *comma = '\0';
    comma++;
    sscanf(start, "%lu", &vk);
    sscanf(comma, "%lu", &nk);
    d.exponent = strlen(comma);
    d.mantissa = vk * d.exponent + nk;
  }
  else {
    /* no decimal sep */
    unsigned long int vk;
    sscanf(start, "%lu", &vk);
    d.exponent = 0;
    d.mantissa = vk;
  }
  return [self initWithDecimal:d];
}

/* type */

- (const char *)objCType
{
  return "d";
}

/* values */

- (int)intValue
{
  if (self->decimal.exponent == 0) {
    return self->decimal.isNegative
      ? -(self->decimal.mantissa)
      : self->decimal.mantissa;
  }
  return [self doubleValue];
}
- (BOOL)boolValue
{
  return [self intValue] ? YES : NO;
}
- (signed char)charValue
{
  return [self intValue];
}
- (unsigned char)unsignedCharValue
{
  return [self intValue];
}
- (signed short)shortValue
{
  return [self intValue];
}
- (unsigned short)unsignedShortValue
{
  return [self intValue];
}

- (unsigned int)unsignedIntValue
{
  if (self->decimal.exponent == 0 && !self->decimal.isNegative)
    return self->decimal.mantissa;
  return [self doubleValue];
}
- (signed long)longValue
{
  return [self doubleValue];
}
- (unsigned long)unsignedLongValue
{
  if (self->decimal.exponent == 0 && !self->decimal.isNegative)
    return self->decimal.mantissa;
  return [self doubleValue];
}
- (signed long long)longLongValue
{
  return [self doubleValue];
}
- (unsigned long long)unsignedLongLongValue
{
  if (self->decimal.exponent == 0 && !self->decimal.isNegative)
    return self->decimal.mantissa;
  return [self doubleValue];
}
- (float)floatValue
{
  return [self doubleValue];
}

- (double)doubleValue
{
  double d;
  
  d = (self->decimal.exponent == 0)
    ? (double)self->decimal.mantissa
    : ((double)self->decimal.mantissa) * pow(10, self->decimal.exponent);
  
  if (self->decimal.isNegative) d = -d;
  
  return d;
}

- (NSDecimal)decimalValue
{
  return self->decimal;
}

/* operations */

- (NSDecimalNumber *)decimalNumberByAdding:(NSDecimalNumber *)_num
{
  return [self decimalNumberByAdding:_num withBehavior:defBehavior];
}
- (NSDecimalNumber *)decimalNumberBySubtracting:(NSDecimalNumber *)_num
{
  return [self decimalNumberBySubtracting:_num withBehavior:defBehavior];
}
- (NSDecimalNumber *)decimalNumberByMultiplyingBy:(NSDecimalNumber *)_num
{
  return [self decimalNumberByMultiplyingBy:_num withBehavior:defBehavior];
}
- (NSDecimalNumber *)decimalNumberByDividingBy:(NSDecimalNumber *)_num
{
  return [self decimalNumberByDividingBy:_num withBehavior:defBehavior];
}

- (NSDecimalNumber *)decimalNumberByAdding:(NSDecimalNumber *)_num
  withBehavior:(id<NSDecimalNumberBehaviors>)_beh
{
  NSDecimal          res, r;
  NSCalculationError err;
  
  r = [_num decimalValue];
  
  err = NSDecimalAdd(&res, &(self->decimal), &r, [_beh roundingMode]);
  
  if (err != NSCalculationOK) {
    return [_beh exceptionDuringOperation:_cmd
                 error:err
                 leftOperand:self
                 rightOperand:_num];
  }
  
  return [NSDecimalNumber decimalNumberWithDecimal:res];
}

- (NSDecimalNumber *)decimalNumberBySubtracting:(NSDecimalNumber *)_num
  withBehavior:(id<NSDecimalNumberBehaviors>)_beh
{
  NSDecimal          res, r;
  NSCalculationError err;
  
  r = [_num decimalValue];
  
  err = NSDecimalSubtract(&res, &(self->decimal), &r, [_beh roundingMode]);
  
  if (err != NSCalculationOK) {
    return [_beh exceptionDuringOperation:_cmd
                 error:err
                 leftOperand:self
                 rightOperand:_num];
  }
  
  return [NSDecimalNumber decimalNumberWithDecimal:res];
}

- (NSDecimalNumber *)decimalNumberByMultiplyingBy:(NSDecimalNumber *)_num
  withBehavior:(id<NSDecimalNumberBehaviors>)_beh
{
  NSDecimal          res, r;
  NSCalculationError err;
  
  r = [_num decimalValue];
  
  err = NSDecimalMultiply(&res, &(self->decimal), &r, [_beh roundingMode]);
  
  if (err != NSCalculationOK) {
    return [_beh exceptionDuringOperation:_cmd
                 error:err
                 leftOperand:self
                 rightOperand:_num];
  }
  
  return [NSDecimalNumber decimalNumberWithDecimal:res];
}

- (NSDecimalNumber *)decimalNumberByDividingBy:(NSDecimalNumber *)_num
  withBehavior:(id<NSDecimalNumberBehaviors>)_beh
{
  NSDecimal          res, r;
  NSCalculationError err;
  
  r = [_num decimalValue];
  
  err = NSDecimalDivide(&res, &(self->decimal), &r, [_beh roundingMode]);
  
  if (err != NSCalculationOK) {
    return [_beh exceptionDuringOperation:_cmd
                 error:err
                 leftOperand:self
                 rightOperand:_num];
  }
  
  return [NSDecimalNumber decimalNumberWithDecimal:res];
}

/* comparison */

- (NSComparisonResult)compareWithDecimalNumber:(NSDecimalNumber *)_num
{
  return NSOrderedSame;
}
- (NSComparisonResult)compare:(NSNumber *)_num
{
  NSDecimalNumber *num;
  
  if (_num == self) return NSOrderedSame;
  
  if ([_num isKindOfClass:[NSDecimalNumber class]])
    num = (NSDecimalNumber *)_num;
  else
    num = [NSDecimalNumber decimalNumberWithNumber:_num];
  
  return [self compareWithDecimalNumber:num];
}

/* description */

- (NSString *)stringValue
{
  return [self description];
}

- (NSString *)descriptionWithLocale:(NSDictionary *)_locale
{
  return NSDecimalString(&(self->decimal), _locale);
}

- (NSString *)description
{
  return [self descriptionWithLocale:nil];
}

@end /* NSDecimalNumber */

@implementation NSDecimalZeroNumber

- (id)init
{
  self->decimal.exponent   = 0;
  self->decimal.mantissa   = 0;
  self->decimal.isNegative = NO;
  return self;
}

/* operations */

- (NSDecimalNumber *)decimalNumberByAdding:(NSDecimalNumber *)_num
  withBehavior:(id<NSDecimalNumberBehaviors>)_beh
{
  return _num;
}

- (NSDecimalNumber *)decimalNumberBySubtracting:(NSDecimalNumber *)_num
  withBehavior:(id<NSDecimalNumberBehaviors>)_beh
{
  NSDecimal d;
  d = [_num decimalValue];
  d.isNegative = d.isNegative ? NO : YES;
  return [NSDecimalNumber decimalNumberWithDecimal:d];
}

- (NSDecimalNumber *)decimalNumberByMultiplyingBy:(NSDecimalNumber *)_num
  withBehavior:(id<NSDecimalNumberBehaviors>)_beh
{
  return self;
}

- (NSDecimalNumber *)decimalNumberByDividingBy:(NSDecimalNumber *)_num
  withBehavior:(id<NSDecimalNumberBehaviors>)_beh
{
  /* should check for _num==zero ??? */
  return self;
}

/* description */

- (NSString *)descriptionWithLocale:(NSDictionary *)_locale
{
  return @"0";
}
- (NSString *)description
{
  return @"0";
}

@end /* NSDecimalZeroNumber */

@implementation NSDecimalOneNumber

- (id)init
{
  self->decimal.mantissa   = 1;
  self->decimal.exponent   = 0;
  self->decimal.isNegative = NO;
  return self;
}

/* operations */

- (NSDecimalNumber *)decimalNumberByAdding:(NSDecimalNumber *)_num
  withBehavior:(id<NSDecimalNumberBehaviors>)_beh
{
  return _num;
}

- (NSDecimalNumber *)decimalNumberByMultiplyingBy:(NSDecimalNumber *)_num
  withBehavior:(id<NSDecimalNumberBehaviors>)_beh
{
  /* 1 * x = x */
  return _num;
}

/* description */

- (NSString *)descriptionWithLocale:(NSDictionary *)_locale
{
  return @"1";
}
- (NSString *)description
{
  return @"1";
}

@end /* NSDecimalOneNumber */

@implementation NSDecimalNotANumber

- (id)init
{
  self->decimal.mantissa   = 1;
  self->decimal.exponent   = 0;
  self->decimal.isNegative = NO;
  return self;
}

/* operations */

- (NSDecimalNumber *)decimalNumberByAdding:(NSDecimalNumber *)_num
  withBehavior:(id<NSDecimalNumberBehaviors>)_beh
{
  return self;
}
- (NSDecimalNumber *)decimalNumberBySubtracting:(NSDecimalNumber *)_num
  withBehavior:(id<NSDecimalNumberBehaviors>)_beh
{
  return self;
}

- (NSDecimalNumber *)decimalNumberByMultiplyingBy:(NSDecimalNumber *)_num
  withBehavior:(id<NSDecimalNumberBehaviors>)_beh
{
  return self;
}

- (NSDecimalNumber *)decimalNumberByDividingBy:(NSDecimalNumber *)_num
  withBehavior:(id<NSDecimalNumberBehaviors>)_beh
{
  /* should check for 0-divide ?? */
  return self;
}

/* description */

- (NSString *)descriptionWithLocale:(NSDictionary *)_locale
{
  return @"NaN";
}

@end /* NSDecimalNotANumber */

@implementation NSDecimalNumberHandler

- (NSDecimalNumber *)exceptionDuringOperation:(SEL)method
  error:(NSCalculationError)_error
  leftOperand:(NSDecimalNumber *)_lhs
  rightOperand:(NSDecimalNumber *)_rhs
{
  return nil;
}

- (NSRoundingMode)roundingMode {
  return NSRoundBankers;
}

- (short)scale {
  return 0;
}

@end /* NSDecimalNumberHandler */
