/* 
   FormatScanner.h

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

#ifndef __FormatScanner_h__
#define __FormatScanner_h__

#include <stdarg.h>
#include <Foundation/NSObject.h>

@class NSString;

/*
 * A FormatScanner scans a NSString format. When it reaches a specifier
 * similar to printf(3S), it calls a handler object previously registered to
 * it. The handler object is usually inherited from the DefaultScannerHandler
 * class. The handler object maintains a mapping between format characters and
 * selectors that have to be called when a specifier is found in the format
 * string. The selector must have exactly two arguments: the first one is a
 * pointer to a va_list and the second one is the format scanner. It is the
 * responsability of handler to increase the pointer to the va_list with the
 * size of the object it handles. During the execution of the method the
 * scanner calls, the handler can ask the scanner about the flags, width,
 * precision, modifiers and the specifier character. The method should return a
 * NSString object that represents the converted object.
 *
 * FormatScanner is an abstract class. Use the PrintfFormatScanner class that
 * is used to write printf-like functions. Additional classes can be inherited
 * to write scanf-like functions.
 */

typedef enum {
    FS_ALTERNATE_FORM	= 1,
    FS_ZERO		= 2,
    FS_MINUS_SIGN	= 4,
    FS_PLUS_SIGN	= 8,
    FS_BLANK		= 16
} FormatScannerFlags;

@interface FormatScanner : NSObject
{
    int		specifierLen, specifierSize;
    char        *currentSpecifier;
    id		handler;
    unsigned	flags;
    int		width;
    int		precision;
    char	modifier;
    char	characterSpecifier;
    BOOL	allowFlags:1;
    BOOL	allowWidth:1;
    BOOL	allowPeriod:1;
    BOOL	allowPrecision:1;
    BOOL	allowModifier:1;
}

/* This method start the searching of specifiers in `format'. `context' is
   passed in handleFormatSpecifierWithContext: unmodified. */
- (BOOL)parseFormatString:(NSString*)format context:(void*)context;

/* This method is called whenever a string between two specifiers is found.
   Rewrite it in subclasses to perform whatever action you want (for example
   to collect them in a result string if you're doing printf). The method 
   should return NO if the scanning of format should stop. */
- (BOOL)handleOrdinaryString:(NSString*)string;

/* This method is called whenever a format specifier is found in `format'.
   Again, rewrite this method in subclasses to perform whatever action you
   want. The method should return NO if the scanning of the format should stop.
*/
- (BOOL)handleFormatSpecifierWithContext:(void*)context;

- (void)setFormatScannerHandler:(id)anObject;
- (id)formatScannerHandler;

- (unsigned int)flags;
- (int)width;
- (int)precision;
- (char)modifier;
- (char)characterSpecifier;
- (const char*)currentSpecifier;

- (id)setAllowFlags:(BOOL)flag;
- (id)setAllowWidth:(BOOL)flag;
- (id)setAllowPeriod:(BOOL)flag;
- (id)setAllowPrecision:(BOOL)flag;
- (id)setAllowModifier:(BOOL)flag;

/* A shorthand for sending all -setAllow* messages with !flag as argument */
- (id)setAllowOnlySpecifier:(BOOL)flag;

- (BOOL)allowFlags;
- (BOOL)allowWidth;
- (BOOL)allowPeriod;
- (BOOL)allowPrecision;
- (BOOL)allowModifier;

@end

#endif /* __FormatScanner_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
