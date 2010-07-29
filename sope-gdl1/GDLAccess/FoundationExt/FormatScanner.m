/* 
   FormatScanner.m

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

#include <ctype.h>

#include "common.h"

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSCharacterSet.h>

//#include <extensions/support.h>
#include "FormatScanner.h"

@implementation FormatScanner

enum { SPECIFIER_SIZE = 1000 }; /* This value should be sufficient */

- (id)init {
    specifierSize    = SPECIFIER_SIZE;
    currentSpecifier = MallocAtomic(specifierSize);
    allowFlags       = YES;
    allowWidth       = YES;
    allowPeriod      = YES;
    allowPrecision   = YES;
    allowModifier    = YES;
    return self;
}

- (void)dealloc {
    if (self->currentSpecifier) free(currentSpecifier);
    RELEASE(self->handler);
    [super dealloc];
}

- (void)setFormatScannerHandler:(id)anObject {
    ASSIGN(self->handler, anObject);
}

- (id)setAllowOnlySpecifier:(BOOL)flag {
    allowFlags     = !flag;
    allowWidth     = !flag;
    allowPeriod    = !flag;
    allowPrecision = !flag;
    allowModifier  = !flag;
    return self;
}

- (id)setAllowFlags:(BOOL)flag {
    allowFlags = flag;
    return self;
}
- (BOOL)allowFlags {
    return allowFlags;
}

- (id)setAllowWidth:(BOOL)flag {
    allowWidth = flag;
    return self;
}
- (BOOL)allowWidth {
    return allowWidth;
}

- (id)setAllowPeriod:(BOOL)flag {
    allowPeriod = flag;
    return self;
}
- (BOOL)allowPeriod {
    return allowPeriod;
}

- (id)setAllowPrecision:(BOOL)flag {
    allowPrecision = flag;
    return self;
}
- (BOOL)allowPrecision {
    return allowPrecision;
}

- (id)setAllowModifier:(BOOL)flag {
    allowModifier = flag;
    return self;
}
- (BOOL)allowModifier {
    return allowModifier;
}

- (id)formatScannerHandler {
    return handler;
}

- (unsigned int)flags {
    return self->flags;
}
- (int)width {
    return self->width;
}
- (int)precision {
    return self->precision;
}
- (char)modifier {
    return self->modifier;
}
- (char)characterSpecifier {
    return self->characterSpecifier;
}
- (const char *)currentSpecifier {
    return self->currentSpecifier;
}

#define CHECK_END \
    if(i >= length) { \
        /* An unterminated specifier. Break the loop. */ \
        [self handleOrdinaryString: \
                    [NSString stringWithCString:currentSpecifier]]; \
        goto _return; \
    }

/* Scans the format string looking after specifiers. Doesn't handle '*' as a
   valid width or precision. */
- (BOOL)parseFormatString:(NSString*)format context:(void *)context {
    NSRange        searchRange, foundRange;
    int            i, length;
    unichar        ch;
    NSCharacterSet *decimals;

    i        = 0;
    length   = [format length];
    decimals = [NSCharacterSet decimalDigitCharacterSet];
    
    *currentSpecifier = 0;
    specifierLen = 0;

    while (i < length) {
        searchRange.location = i;
        searchRange.length = length - i;

        foundRange = [format rangeOfString:@"%" options:0 range:searchRange];
        if (foundRange.length == 0)
            foundRange.location = length;
        searchRange.length = foundRange.location - searchRange.location;

        if (searchRange.length) {
            if (![self handleOrdinaryString:
                        [format substringWithRange:searchRange]])
                return NO;
        }

        i = foundRange.location;
        CHECK_END

        i++;
        strcpy(currentSpecifier, "%");
        specifierLen = 1;
        CHECK_END

        flags = width = precision = modifier = characterSpecifier = 0;

        /* Check for flags. */
        if (self->allowFlags) {
            for (; i < length; i++) {
                ch = [format characterAtIndex:i];
                switch(ch) {
                    case '#':   strcat(currentSpecifier, "#");
                                flags |= FS_ALTERNATE_FORM;
                                break;
                    case '0':   strcat(currentSpecifier, "0");
                                flags |= FS_ZERO;
                                break;
                    case '-':   strcat(currentSpecifier, "-");
                                flags |= FS_MINUS_SIGN;
                                break;
                    case '+':   strcat(currentSpecifier, "+");
                                flags |= FS_PLUS_SIGN;
                                break;
                    case ' ':   strcat(currentSpecifier, " ");
                                flags |= FS_BLANK;
                                break;
                    default:    goto quit;
                }
                if (++specifierLen == specifierSize) {
                    currentSpecifier =
                        Realloc(currentSpecifier,
                                specifierSize += SPECIFIER_SIZE);
                }
            }
        quit:
            CHECK_END
        }

        /* Check for width. */
        if (self->allowWidth) {
            for(; i < length; i++) {
                char str[2] = { 0, 0 };

                ch = [format characterAtIndex:i];
                if (![decimals characterIsMember:ch])
                    break;
                str[0] = ch;

                strcat(currentSpecifier, str);
                if(++specifierLen == specifierSize) {
                    currentSpecifier =
                        Realloc(currentSpecifier,
                                specifierSize += SPECIFIER_SIZE);
                }

                width = 10 * width + (ch - '0');
            }
            CHECK_END
        }

        /* Check for period. */
        if (self->allowPeriod) {
            ch = [format characterAtIndex:i];
            if(ch == '.') {
                char str[2] = { ch, 0 };

                strcat(currentSpecifier, str);
                if(++specifierLen == specifierSize) {
                    currentSpecifier =
                        Realloc(currentSpecifier,
                                specifierSize += SPECIFIER_SIZE);
                }

                i++;
                CHECK_END
            }
        }

        /* Check for precision. */
        if (self->allowPrecision) {
            for(; i < length; i++) {
                char str[2] = { 0, 0 };

                ch = [format characterAtIndex:i];
                if (![decimals characterIsMember:ch])
                    break;
                str[0] = ch;

                strcat(currentSpecifier, str);
                if(++specifierLen == specifierSize) {
                    currentSpecifier =
                        Realloc(currentSpecifier,
                                specifierSize += SPECIFIER_SIZE);
                }
                precision = 10 * precision + (ch - '0');
            }
            CHECK_END
        }

        /* Check for data-width modifier. */
        if (allowModifier) {
            ch = [format characterAtIndex:i];
            if (ch == 'h' || ch == 'l') {
                char str[2] = { ch, 0 };

                strcat(currentSpecifier, str);
                if (++specifierLen == specifierSize) {
                    currentSpecifier =
                        Realloc(currentSpecifier,
                                specifierSize += SPECIFIER_SIZE);
                }

                modifier = ch;
                i++;
                CHECK_END
            }
        }

        /* Finally, the conversion character. */
        {
            char str[2] = { 0, 0 };
            ch = [format characterAtIndex:i];
            str[0] = ch;

            strcat(currentSpecifier, str);
            if(++specifierLen == specifierSize) {
                currentSpecifier =
                    Realloc(currentSpecifier,
                            specifierSize += SPECIFIER_SIZE);
            }

            characterSpecifier = ch;
        }

        if (![self handleFormatSpecifierWithContext:context])
            return NO;

        i++;
        *currentSpecifier = 0;
        specifierLen = 0;

        CHECK_END
    }

_return:
    return YES;
}

- (BOOL)handleOrdinaryString:(NSString*)string
{
    return YES;
}

- (BOOL)handleFormatSpecifierWithContext:(void*)context
{
    return YES;
}

@end /* FormatScanner */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
