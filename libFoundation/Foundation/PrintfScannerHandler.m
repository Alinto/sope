/* 
   PrintfScannerHandler.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
           Helge Hess <helge.hess@mdlink.de>

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

#include <stdarg.h>
#include <stdio.h>
#include <Foundation/NSString.h>
#include <Foundation/NSValue.h>

#include <extensions/FormatScanner.h>
#include <extensions/PrintfScannerHandler.h>

@implementation PrintfScannerHandler

- (id)init
{
    [super init];

    specHandler['d'] = [self methodForSelector:@selector(convertInt:scanner:)];
    specHandler['i'] = [self methodForSelector:@selector(convertInt:scanner:)];
    specHandler['o'] = [self methodForSelector:@selector(convertInt:scanner:)];
    specHandler['x'] = [self methodForSelector:@selector(convertInt:scanner:)];
    specHandler['X'] = [self methodForSelector:@selector(convertInt:scanner:)];
    specHandler['u'] = [self methodForSelector:@selector(convertInt:scanner:)];
    specHandler['c']
	    = [self methodForSelector:@selector(convertChar:scanner:)];
    specHandler['s']
	    = [self methodForSelector:@selector(convertString:scanner:)];
    specHandler['f']
	    = [self methodForSelector:@selector(convertFloat:scanner:)];
    specHandler['e']
	    = [self methodForSelector:@selector(convertFloat:scanner:)];
    specHandler['E']
	    = [self methodForSelector:@selector(convertFloat:scanner:)];
    specHandler['g']
	    = [self methodForSelector:@selector(convertFloat:scanner:)];
    specHandler['G']
	    = [self methodForSelector:@selector(convertFloat:scanner:)];
    specHandler['p']
	    = [self methodForSelector:@selector(convertPointer:scanner:)];
    return self;
}

- (NSString*)convertInt:(va_list*)pInt scanner:(FormatScanner*)scanner
{
    char buffer[256];
    sprintf(buffer, [scanner currentSpecifier], va_arg(*pInt, int));
    return [NSString stringWithCString:buffer];
}

- (NSString*)convertChar:(va_list*)pChar scanner:(FormatScanner*)scanner
{
#if 0
    char buffer[2] = { (char)va_arg(*pChar, char), 0 };
    return [NSString stringWithCString:buffer];
#else
    char buffer[256];
    sprintf(buffer, [scanner currentSpecifier], (char)va_arg(*pChar, int));
    return [NSString stringWithCString:buffer];
#endif
}

- (NSString*)convertString:(va_list*)pString scanner:(FormatScanner*)scanner
{
    char *string = va_arg(*pString, char*);
    return string ? [NSString stringWithCString:string] : (id)@"";
}

- (NSString*)convertFloat:(va_list*)pFloat scanner:(FormatScanner*)scanner
{
    char buffer[256];
    sprintf(buffer, [scanner currentSpecifier], va_arg(*pFloat, double));
    return [NSString stringWithCString:buffer];
}

- (NSString*)convertPointer:(va_list*)pPointer scanner:(FormatScanner*)scanner
{
    char buffer[256];
    sprintf(buffer, [scanner currentSpecifier], va_arg(*pPointer, void*));
    return [NSString stringWithCString:buffer];
}

@end /* PrintfScannerHandler */

@implementation PrintfEnumScannerHandler

- (id)init
{
    [super init];

    specHandler['d'] = [self methodForSelector:@selector(convertInt:scanner:)];
    specHandler['i'] = [self methodForSelector:@selector(convertInt:scanner:)];
    specHandler['o'] = [self methodForSelector:@selector(convertInt:scanner:)];
    specHandler['x'] = [self methodForSelector:@selector(convertInt:scanner:)];
    specHandler['X'] = [self methodForSelector:@selector(convertInt:scanner:)];
    specHandler['u'] = [self methodForSelector:@selector(convertInt:scanner:)];
    specHandler['c']
	    = [self methodForSelector:@selector(convertChar:scanner:)];
    specHandler['s']
	    = [self methodForSelector:@selector(convertString:scanner:)];
    specHandler['f']
	    = [self methodForSelector:@selector(convertFloat:scanner:)];
    specHandler['e']
	    = [self methodForSelector:@selector(convertFloat:scanner:)];
    specHandler['E']
	    = [self methodForSelector:@selector(convertFloat:scanner:)];
    specHandler['g']
	    = [self methodForSelector:@selector(convertFloat:scanner:)];
    specHandler['G']
	    = [self methodForSelector:@selector(convertFloat:scanner:)];
    specHandler['p']
	    = [self methodForSelector:@selector(convertPointer:scanner:)];
    return self;
}

- (NSString *)convertInt:(NSEnumerator **)pInt scanner:(FormatScanner*)scanner
{
    char buffer[256];
    sprintf(buffer, [scanner currentSpecifier], [[*pInt nextObject] intValue]);
    return [NSString stringWithCString:buffer];
}

- (NSString*)convertChar:(NSEnumerator **)pChar scanner:(FormatScanner*)scanner
{
#if 0
    char buffer[2] = { (char)va_arg(*pChar, char), 0 };
    return [NSString stringWithCString:buffer];
#else
    char buffer[256];
    sprintf(buffer, [scanner currentSpecifier],
            [[*pChar nextObject] charValue]);
    return [NSString stringWithCString:buffer];
#endif
}

- (NSString *)convertString:(NSEnumerator **)pString
  scanner:(FormatScanner *)scanner
{
    id str;

    if ((str = [*pString nextObject]) == nil)
        str = @"";
    else if ([str isKindOfClass:[NSString class]])
        ;
    else if ([str respondsToSelector:@selector(stringValue)])
        str = [str stringValue];
    else
        str = [str description];

    if (str == nil)
        str = @"";
    return str;
}

- (NSString *)convertFloat:(NSEnumerator **)pFloat
  scanner:(FormatScanner *)scanner
{
    char buffer[256];
    sprintf(buffer, [scanner currentSpecifier],
            [[*pFloat nextObject] doubleValue]);
    return [NSString stringWithCString:buffer];
}

- (NSString *)convertPointer:(NSEnumerator **)pPointer
  scanner:(FormatScanner *)scanner
{
    char buffer[256];
    sprintf(buffer, [scanner currentSpecifier],
            [[*pPointer nextObject] pointerValue]);
    return [NSString stringWithCString:buffer];
}

@end /* PrintfEnumScannerHandler */

@implementation FSObjectFormat

- (id)init
{
    [super init];
    specHandler['@']
	    = [self methodForSelector:@selector(convertObject:scanner:)];
    return self;
}

- (NSString *)convertObject:(va_list*)pId scanner:(id)scanner
{
    id object;
    object = va_arg(*pId, id);
    return [object description];
}

@end /* FSObjectFormat */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
