/* 
   NSScanner.h

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

#ifndef __NSScanner_h__
#define __NSScanner_h__

#include <limits.h>
#include <float.h>

#include <Foundation/NSObject.h>

#ifndef LONG_LONG_MAX
# define LONG_LONG_MAX	(((unsigned long long)-1) >> 1)
#endif

#ifndef LONG_LONG_MIN
# define LONG_LONG_MIN	(-LONG_LONG_MAX - 1)
#endif

@class NSString;
@class NSDictionary;
@class NSCharacterSet;

@interface NSScanner : NSObject

/* Creation */
+ (id)scannerWithString:(NSString*)string;
+ (id)localizedScannerWithString:(NSString*)string;
- (id)initWithString:(NSString*)string;

/* Getting an NSScanner's string */
- (NSString*)string;

/* Configuring an NSScanner */
- (void)setScanLocation:(unsigned int)index;
- (unsigned int)scanLocation;
- (void)setCaseSensitive:(BOOL)flag;
- (BOOL)caseSensitive;
- (void)setCharactersToBeSkipped:(NSCharacterSet*)skipSet;
- (NSCharacterSet*)charactersToBeSkipped;

/* Setting and getting a locale */
- (void)setLocale:(NSDictionary*)locale;
- (NSDictionary*)locale;

/* Scanning a string */
- (BOOL)scanCharactersFromSet:(NSCharacterSet*)scanSet
  intoString:(NSString**)value;
- (BOOL)scanUpToCharactersFromSet:(NSCharacterSet*)stopSet
  intoString:(NSString **)value;
- (BOOL)scanDouble:(double*)value;
- (BOOL)scanFloat:(float*)value;
- (BOOL)scanInt:(int*)value;
- (BOOL)scanLongLong:(long long*)value;
- (BOOL)scanString:(NSString*)string intoString:(NSString**)value;
- (BOOL)scanUpToString:(NSString*)stopString intoString:(NSString**)value;
- (BOOL)isAtEnd;

@end

#endif /* __NSScanner_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
