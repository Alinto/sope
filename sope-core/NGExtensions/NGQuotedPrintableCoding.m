/*
  Copyright (C) 2000-2008 SKYRIX Software AG
  Copyright (C) 2006-2008 Helge Hess

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "NGQuotedPrintableCoding.h"
#include "common.h"
#include "NGMemoryAllocation.h"


@implementation NSString(QuotedPrintableCoding)

- (NSString *)stringByDecodingQuotedPrintable {
  NSData *data;
  
  data = ([self length] > 0)
    ? [self dataUsingEncoding:NSASCIIStringEncoding]
    : [NSData data];
  
  data = [data dataByDecodingQuotedPrintable];
  
  // TODO: should we default to some specific charset instead? (either
  //       Latin1 or UTF-8
  //       or the charset of the receiver?
  return [NSString stringWithCString:[data bytes] length:[data length]];
}

- (NSString *)stringByEncodingQuotedPrintable {
  NSData *data;
  
  // TBD: which encoding to use?
  data = ([self length] > 0)
    ? [self dataUsingEncoding:[NSString defaultCStringEncoding]]
    : [NSData data];
  
  data = [data dataByEncodingQuotedPrintable];
  
  return [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]
	             autorelease];
}

@end /* NSString(QuotedPrintableCoding) */


@implementation NSData(QuotedPrintableCoding)

- (NSData *)dataByDecodingQuotedPrintable {
  char   *dest;
  size_t destSize;
  size_t resSize;
  
  destSize = [self length];
  dest     = malloc(destSize * sizeof(char) + 2);

  resSize = 
    NGDecodeQuotedPrintableX([self bytes], [self length], dest, destSize, YES);
  
  return ((int)resSize != -1)
    ? [NSData dataWithBytesNoCopy:dest length:resSize]
    : nil;
}
- (NSData *)dataByDecodingQuotedPrintableTransferEncoding {
  char   *dest;
  size_t destSize;
  size_t resSize;
  
  destSize = [self length];
  dest     = malloc(destSize * sizeof(char) + 2);

  resSize = 
    NGDecodeQuotedPrintableX([self bytes], [self length], dest, destSize, NO);
  
  return ((int)resSize != -1)
    ? [NSData dataWithBytesNoCopy:dest length:resSize]
    : nil;
}

- (NSData *)dataByEncodingQuotedPrintable {
  const char   *bytes  = [self bytes];
  unsigned int length  = [self length];
  char         *des    = NULL;
  unsigned int desLen  = 0;

  // length/64*3 should be plenty for soft newlines
  desLen = (length + length/64) *3;
  des = NGMallocAtomic(sizeof(char) * desLen);

  desLen = NGEncodeQuotedPrintable(bytes, length, des, desLen);

  return (int)desLen != -1
    ? [NSData dataWithBytesNoCopy:des length:desLen]
    : nil;
}

@end /* NSData(QuotedPrintableCoding) */


// implementation

static inline signed char __hexToChar(char c) {
  if ((c > 47) && (c < 58)) // '0' .. '9'
    return c - 48;
  if ((c > 64) && (c < 71)) // 'A' .. 'F'
    return c - 55;
  if ((c > 96) && (c < 103)) // 'a' .. 'f'
    return c - 87;
  return -1;
}

int NGDecodeQuotedPrintableX(const char *_src, unsigned _srcLen,
                             char *_dest, unsigned _destLen,
			     BOOL _replaceUnderline)
{
  /*
    Eg: "Hello=20World" => "Hello World"

    =XY where XY is a hex encoded byte. In addition '_' is decoded as 0x20
    (not as space!, this depends on the charset, see RFC 2047 4.2).
  */
  unsigned cnt     = 0;
  unsigned destCnt = 0;

  if (_srcLen < _destLen)
    return -1;

  for (cnt = 0; ((cnt < _srcLen) && (destCnt < _destLen)); cnt++) {
    if (_src[cnt] != '=') {
      _dest[destCnt] = 
	(_replaceUnderline && _src[cnt] == '_') ? 0x20 : _src[cnt];
      destCnt++;
    }
    else {
      if ((_srcLen - cnt) > 1) {
        signed char c1, c2;

	cnt++;          // skip '='
        c1 = _src[cnt]; // first hex digit
	
        if (c1 == '\r' || c1 == '\n') {
          if (_src[cnt + 1] == '\r' || _src[cnt + 1] == '\n' )
            cnt++;
          continue;
        }
        c1 = __hexToChar(c1);
	
	cnt++; // skip first hex digit
        c2 = __hexToChar(_src[cnt]);
        
        if ((c1 == -1) || (c2 == -1)) {
          if ((_destLen - destCnt) > 1) {
            _dest[destCnt] = _src[cnt - 1]; destCnt++;
            _dest[destCnt] = _src[cnt];     destCnt++;
          }
          else
            break;
        }
        else {
          register unsigned char c = ((c1 << 4) | c2);
          _dest[destCnt] = c;
	  destCnt++;
        }
      }
      else 
        break;
    }
  }
  if (cnt < _srcLen && ((_srcLen - cnt) > 1 || _src[_srcLen-1] != '='))
    return -1;
  return destCnt;
}
int NGDecodeQuotedPrintable(const char *_src, unsigned _srcLen,
                            char *_dest, unsigned _destLen)
{
  // should we deprecated that?
  return NGDecodeQuotedPrintableX(_src, _srcLen, _dest, _destLen, YES);
}

/*
  From RFC 2045 Multipurpose Internet Mail Extensions

  6.7. Quoted-Printable Content-Transfer-Encoding

  ...

  In this encoding, octets are to be represented as determined by the
  following rules: 


    (1)   (General 8bit representation) Any octet, except a CR or
          LF that is part of a CRLF line break of the canonical
          (standard) form of the data being encoded, may be
          represented by an "=" followed by a two digit
          hexadecimal representation of the octet's value.  The
          digits of the hexadecimal alphabet, for this purpose,
          are "0123456789ABCDEF".  Uppercase letters must be
          used; lowercase letters are not allowed.  Thus, for
          example, the decimal value 12 (US-ASCII form feed) can
          be represented by "=0C", and the decimal value 61 (US-
          ASCII EQUAL SIGN) can be represented by "=3D".  This
          rule must be followed except when the following rules
          allow an alternative encoding.

    (2)   (Literal representation) Octets with decimal values of
          33 through 60 inclusive, and 62 through 126, inclusive,
          MAY be represented as the US-ASCII characters which
          correspond to those octets (EXCLAMATION POINT through
          LESS THAN, and GREATER THAN through TILDE,
          respectively).

    (3)   (White Space) Octets with values of 9 and 32 MAY be
          represented as US-ASCII TAB (HT) and SPACE characters,
          respectively, but MUST NOT be so represented at the end
          of an encoded line. Any TAB (HT) or SPACE characters on an
          encoded line MUST thus be followed on that line by a printable
          character. In particular, an "=" at the end of an encoded line,
          indicating a soft line break (see rule #5) may follow one or
          more TAB (HT) or SPACE characters. It follows that an octet
          with decimal value 9 or 32 appearing at the end of an encoded line
          must be represented according to Rule #1. This rule is necessary
          because some MTAs (Message Transport Agents, programs which transport
          messages from one user to another, or perform a portion of such
          transfers) are known to pad lines of text with SPACEs, and others
          are known to remove "white space" characters from the end of a line.
          Therefore, when decoding a Quoted-Printable body, any trailing white
          space on a line must be deleted, as it will necessarily have been
          added by intermediate transport agents. 


    (4)   (Line Breaks) A line break in a text body, represented
          as a CRLF sequence in the text canonical form, must be
          represented by a (RFC 822) line break, which is also a
          CRLF sequence, in the Quoted-Printable encoding.  Since
          the canonical representation of media types other than
          text do not generally include the representation of
          line breaks as CRLF sequences, no hard line breaks
          (i.e. line breaks that are intended to be meaningful
          and to be displayed to the user) can occur in the
          quoted-printable encoding of such types.  Sequences
          like "=0D", "=0A", "=0A=0D" and "=0D=0A" will routinely
          appear in non-text data represented in quoted-
          printable, of course.

    (5)   (Soft Line Breaks) The Quoted-Printable encoding
          REQUIRES that encoded lines be no more than 76
          characters long.  If longer lines are to be encoded
          with the Quoted-Printable encoding, "soft" line breaks
          must be used.  An equal sign as the last character on a
          encoded line indicates such a non-significant ("soft")
          line break in the encoded text.

*/          

int NGEncodeQuotedPrintable(const char *_src, unsigned _srcLen,
                            char *_dest, unsigned _destLen) {
  unsigned cnt      = 0;
  unsigned destCnt  = 0;
  unsigned lineStart= destCnt;
  char     hexT[16] = {'0','1','2','3','4','5','6','7','8',
                       '9','A','B','C','D','E','F'};

  if (_srcLen > _destLen)
    return -1;

  for (cnt = 0; (cnt < _srcLen) && (destCnt < _destLen); cnt++) {
    if (destCnt - lineStart > 70) { // Possibly going to exceed 76 chars this line
      if (_destLen - destCnt > 2) {
        _dest[destCnt++] = '=';
        _dest[destCnt++] = '\r';
        _dest[destCnt++] = '\n';
        lineStart = destCnt;
      }
      else
        break;
    }
    char c = _src[cnt];
    if (c == 95) {  // we encode the _, otherwise we'll always decode it as a space!
      if (_destLen - destCnt > 2) {
        _dest[destCnt++] = '=';
        _dest[destCnt++] = '5';
        _dest[destCnt++] = 'F';
      }
      else
        break;
    }
    else if ((c == 9)  ||
        (c == 13) ||
        ((c > 31) && (c < 61)) ||
        ((c > 61) && (c < 127))) { // no quoting
      _dest[destCnt++] = c;
    }
    else if (c == 10) { // Reset line length counter
      _dest[destCnt++] = c;
      lineStart = destCnt;
    }
    else { // need to be quoted
      if (_destLen - destCnt > 2) {
        _dest[destCnt++] = '=';
        _dest[destCnt++] = hexT[(c >> 4) & 15];
        _dest[destCnt++] = hexT[c & 15];
      }
      else
        break;
    }
  }
  if (cnt < _srcLen)
    return -1;
  return destCnt;
}

// static linking

void __link_NGQuotedPrintableCoding(void) {
  __link_NGQuotedPrintableCoding();
}
