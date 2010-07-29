/* 
   PrintfScannerHandler.h

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

#ifndef __PrintfScannerHandler_h__
#define __PrintfScannerHandler_h__

#include <stdarg.h>
#include <extensions/DefaultScannerHandler.h>

@class NSString;
@class FormatScanner;

@interface PrintfScannerHandler : DefaultScannerHandler
- (NSString *)convertInt:(va_list*)pInt scanner:(FormatScanner*)scanner;
- (NSString *)convertChar:(va_list*)pChar scanner:(FormatScanner*)scanner;
- (NSString *)convertString:(va_list*)pString scanner:(FormatScanner*)scanner;
- (NSString *)convertFloat:(va_list*)pFloat scanner:(FormatScanner*)scanner;
- (NSString *)convertPointer:(va_list*)pPointer scanner:(FormatScanner*)scanner;
@end

@interface PrintfEnumScannerHandler : DefaultEnumScannerHandler
- (NSString *)convertInt:(NSEnumerator **)pInt scanner:(FormatScanner*)scanner;
- (NSString *)convertChar:(NSEnumerator **)pChar scanner:(FormatScanner*)scanner;
- (NSString *)convertString:(NSEnumerator **)pString scanner:(FormatScanner*)scanner;
- (NSString *)convertFloat:(NSEnumerator **)pFloat scanner:(FormatScanner*)scanner;
- (NSString *)convertPointer:(NSEnumerator **)pPointer scanner:(FormatScanner*)scanner;
@end

@interface FSObjectFormat : PrintfScannerHandler
- (NSString *)convertObject:(va_list *)pId scanner:scanner;
@end

#endif /* __PrintfScannerHandler_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
