/* ================================================================ */
/*
File:	ConvertUTF.h
Author: Mark E. Davis
Copyright (C) 1994 Taligent, Inc. All rights reserved.

This code is copyrighted. Under the copyright laws, this code may not
be copied, in whole or part, without prior written consent of Taligent. 

Taligent grants the right to use or reprint this code as long as this
ENTIRE copyright notice is reproduced in the code or reproduction.
The code is provided AS-IS, AND TALIGENT DISCLAIMS ALL WARRANTIES,
EITHER EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  IN
NO EVENT WILL TALIGENT BE LIABLE FOR ANY DAMAGES WHATSOEVER (INCLUDING,
WITHOUT LIMITATION, DAMAGES FOR LOSS OF BUSINESS PROFITS, BUSINESS
INTERRUPTION, LOSS OF BUSINESS INFORMATION, OR OTHER PECUNIARY
LOSS) ARISING OUT OF THE USE OR INABILITY TO USE THIS CODE, EVEN
IF TALIGENT HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
BECAUSE SOME STATES DO NOT ALLOW THE EXCLUSION OR LIMITATION OF
LIABILITY FOR CONSEQUENTIAL OR INCIDENTAL DAMAGES, THE ABOVE
LIMITATION MAY NOT APPLY TO YOU.

RESTRICTED RIGHTS LEGEND: Use, duplication, or disclosure by the
government is subject to restrictions as set forth in subparagraph
(c)(l)(ii) of the Rights in Technical Data and Computer Software
clause at DFARS 252.227-7013 and FAR 52.227-19.

This code may be protected by one or more U.S. and International
Patents.

TRADEMARKS: Taligent and the Taligent Design Mark are registered
trademarks of Taligent, Inc.
*/
/* ================================================================ */

#ifndef __cvtutf_H__
#define __cvtutf_H__

#include <stdio.h>
#include <stdlib.h>
// #include <types.h>
#include <string.h>

/* ================================================================ */
/*	The following 4 definitions are compiler-specific.
	I would use wchar_t for UCS2/UTF16, except that the C standard
	does not guarantee that it has at least 16 bits, so wchar_t is
	no less portable than unsigned short!
*/

typedef unsigned long	UCS4;
typedef unsigned short	UCS2;
typedef unsigned short	UTF16;
typedef unsigned char	UTF8;
#define unichar UTF16

typedef enum {false, true} Boolean;

const UCS4 kReplacementCharacter = 0x0000FFFDUL;
const UCS4 kMaximumUCS2          = 0x0000FFFFUL;
const UCS4 kMaximumUTF16         = 0x0010FFFFUL;
const UCS4 kMaximumUCS4          = 0x7FFFFFFFUL;

/* ================================================================ */
/*	Each of these routines converts the text between *sourceStart and 
sourceEnd, putting the result into the buffer between *targetStart and
targetEnd. Note: the end pointers are *after* the last item: e.g. 
*(sourceEnd - 1) is the last item.

	The return result indicates whether the conversion was successful,
and if not, whether the problem was in the source or target buffers.

	After the conversion, *sourceStart and *targetStart are both
updated to point to the end of last text successfully converted in
the respective buffers.
*/

typedef enum {
	ok, 				/* conversion successful */
	sourceExhausted,	/* partial character in source, but hit end */
	targetExhausted		/* insuff. room in target for conversion */
} ConversionResult;

ConversionResult ConvertUCS4toUTF16 (
		UCS4** sourceStart, const UCS4* sourceEnd, 
		UTF16** targetStart, const UTF16* targetEnd);

ConversionResult ConvertUTF16toUCS4 (
		UTF16** sourceStart, UTF16* sourceEnd, 
		UCS4** targetStart, const UCS4* targetEnd);

int NSConvertUTF16toUTF8(unichar             **sourceStart,
                         const unichar       *sourceEnd, 
                         unsigned char       **targetStart,
                         const unsigned char *targetEnd);
int NSConvertUTF8toUTF16(unsigned char **sourceStart, unsigned char *sourceEnd, 
                         unichar **targetStart, const unichar *targetEnd);

ConversionResult ConvertUCS4toUTF8 (
		UCS4** sourceStart, const UCS4* sourceEnd, 
		UTF8** targetStart, const UTF8* targetEnd);
		
ConversionResult ConvertUTF8toUCS4 (
		UTF8** sourceStart, UTF8* sourceEnd, 
		UCS4** targetStart, const UCS4* targetEnd);

/* ================================================================ */

#endif /* __cvtutf_H__ */
