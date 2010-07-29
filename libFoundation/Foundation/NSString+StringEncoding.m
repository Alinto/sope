/* 
   NSString.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

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

#include <stdio.h>
#include <ctype.h>

#include <Foundation/common.h>
#include <Foundation/NSData.h>
#include <Foundation/NSException.h>
#include <Foundation/exceptions/StringExceptions.h>
#include <Foundation/exceptions/GeneralExceptions.h>

#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSString.h>

#include <locale.h>

#include <netinet/in.h>

int NSConvertUTF16toUTF8(unichar             **sourceStart,
                         const unichar       *sourceEnd, 
                         unsigned char       **targetStart,
                         const unsigned char *targetEnd);
int NSConvertUTF8toUTF16(unsigned char **sourceStart, unsigned char *sourceEnd, 
                         unichar **targetStart, const unichar *targetEnd);

#define MaxStringEncodingBufStackSize 200

NSData *dataUsingEncoding(NSString *self, NSStringEncoding encoding,
                          BOOL flag)
{
  unsigned len   = [self length];
  NSRange  range = { 0, len };

  unichar  *buf16;
  unichar  tmpBuf16[MaxStringEncodingBufStackSize];
  unichar  *tmpMalloc16 = NULL;

  NSData *data;

  if (len < MaxStringEncodingBufStackSize) {
    [self getCharacters:tmpBuf16 range:range];
    buf16 = tmpBuf16;
  }
  else {
    tmpMalloc16 = malloc((sizeof(unichar) * len) + 1);
    [self getCharacters:tmpMalloc16 range:range];
    buf16 = tmpMalloc16;
  }
  
  // UNICODE
  // ENCODINGS
  data = nil;
    
  switch (encoding) {
    case NSUnicodeStringEncoding:
      data = [NSData dataWithBytes:buf16
                     length:(len * sizeof(unichar))];
      break;

    case NSISOLatin1StringEncoding: {
      register unsigned int euroCnt = 0;
      register unsigned int i;
            
      for (i = 0; i < len; i++) {
        if (buf16[i] == 8364)
          euroCnt++;
        else if (buf16[i] > 255 && !flag) {
          NSLog(@"cannot convert without loosing information");
          /* cannot convert without loosing information */
          goto END_OF_SWITCH;
        }
      }
      {
        unsigned char     *buf;
        unsigned char     tmpBuf[MaxStringEncodingBufStackSize];
        unsigned char     *tmpMalloc = NULL;
        register unsigned j;

        j = len + (euroCnt*2);
                
        if (j < MaxStringEncodingBufStackSize) {
          buf = tmpBuf;
        }
        else {
          tmpMalloc = malloc((sizeof(unsigned char) * j) + 1);
          buf = tmpMalloc;
        }
                
        for (i = 0, j = 0; i < len; j++,i++) {
          /* Euro encoding, ignory lossy conversions*/
          if (buf16[i] == 8364 /* unicode euro charcode */) {
            buf[j++] = 'E';
            buf[j++] = 'U';
            buf[j]   = 'R';
          }
          else
            buf[j] = buf16[i];
        }
        data = (tmpMalloc)
          ?[NSData dataWithBytesNoCopy:buf length:j]
          :[NSData dataWithBytes:buf length:j];
      }
      break;
    }
      /* from http://lists.w3.org/Archives/Public/www-international/1998JulSep/0022.html */
    case NSWindowsCP1252StringEncoding: { 
      register unsigned int i;
      unsigned char     *buf;
      unsigned char     tmpBuf[MaxStringEncodingBufStackSize];
      unsigned char     *tmpMalloc = NULL;

      if (len < MaxStringEncodingBufStackSize) {
        buf = tmpBuf;
      }
      else {
        tmpMalloc = malloc((sizeof(char) * len) + 1);
        buf       = tmpMalloc;
      }
            
      for (i = 0; i < len;i++) {
        buf[i] = 0;
        switch (buf16[i]) {
          case 0x20AC: /* EURO SIGN */
            buf[i] = 0x80;
            break;
          case 0x201A: /* SINGLE LOW-9 QUOTATION MARK */
            buf[i] = 0x82;
            break;
          case 0x0192: /* LATIN SMALL LETTER F WITH HOOK */
            buf[i] = 0x83;
            break;
          case 0x201E: /* DOUBLE LOW-9 QUOTATION MARK */
            buf[i] = 0x84;
            break;
          case 0x2026: /* HORIZONTAL ELLIPSIS */
            buf[i] = 0x85;
            break;
          case 0x2020: /* DAGGER */
            buf[i] = 0x86;
            break;
          case 0x2021: /* DOUBLE DAGGER */
            buf[i] = 0x87;
            break;
          case 0x02C6: /* MODIFIER LETTER CIRCUMFLEX ACCENT */
            buf[i] = 0x88;
            break;
          case 0x2030: /* PER MILLE SIGN */
            buf[i] = 0x89;
            break;
          case 0x0160: /* LATIN CAPITAL LETTER S WITH CARON */
            buf[i] = 0x8A;
            break;
          case 0x2039: /* SINGLE LEFT-POINTING ANGLE QUOTATION MARK */
            buf[i] = 0x8B;
            break;
          case 0x0152: /* LATIN CAPITAL LIGATURE OE */
            buf[i] = 0x8C;
            break;
          case 0x017D: /* LATIN CAPITAL LETTER Z WITH CARON */
            buf[i] = 0x8E;
            break;
          case 0x2018: /* LEFT SINGLE QUOTATION MARK */
            buf[i] = 0x91;
            break;
          case 0x2019: /* RIGHT SINGLE QUOTATION MARK */
            buf[i] = 0x92;
            break;
          case 0x201C: /* LEFT DOUBLE QUOTATION MARK */
            buf[i] = 0x93;
            break;
          case 0x201D: /* RIGHT DOUBLE QUOTATION MARK */
            buf[i] = 0x94;
            break;
          case 0x2022: /* BULLET */
            buf[i] = 0x95;
            break;
          case 0x2013: /* EN DASH */
            buf[i] = 0x96;
            break;
          case 0x2014: /* EM DASH */
            buf[i] = 0x97;
            break;
          case 0x02DC: /* SMALL TILDE */
            buf[i] = 0x98;
            break;
          case 0x2122: /* TRADE MARK SIGN */
            buf[i] = 0x99;
            break;
          case 0x0161: /* LATIN SMALL LETTER S WITH CARON */
            buf[i] = 0x9A;
            break;
          case 0x203A: /* SINGLE RIGHT-POINTING ANGLE QUOTATION MARK */
            buf[i] = 0x9B;
            break;
          case 0x0153: /* LATIN SMALL LIGATURE OE */
            buf[i] = 0x9C;
            break;
          case 0x017E: /* LATIN SMALL LETTER Z WITH CARON */
            buf[i] = 0x9E;
            break;
          case 0x0178: /* LATIN CAPITAL LETTER Y WITH DIAERESIS */
            buf[i] = 0x9F;
            break;
        }
        if (buf[i] == 0) {
          if ((buf16[i] > 255) && !flag) {
            /* cannot convert without loosing information */
            if (tmpMalloc) {
              free(tmpMalloc); tmpMalloc = NULL;
            }
            goto END_OF_SWITCH;
          }
          else {
            buf[i] = buf16[i]; /* invalid */
          }
        }
      }
      data = (tmpMalloc)
        ? [NSData dataWithBytesNoCopy:buf length:i]
        : [NSData dataWithBytes:buf length:i];
      break;
    }
      /* from ftp://ftp.unicode.org/Public/MAPPINGS/ISO8859/8859-2.TXT */
    case NSISOLatin2StringEncoding: {
      register unsigned int i;
      unsigned char     *buf;
      unsigned char     tmpBuf[MaxStringEncodingBufStackSize];
      unsigned char     *tmpMalloc = NULL;

      if (len < MaxStringEncodingBufStackSize) {
        buf = tmpBuf;
      }
      else {
        tmpMalloc = malloc((sizeof(char) * len) + 1);
        buf       = tmpMalloc;
      }
            
      for (i = 0; i < len;i++) {
        buf[i] = 0;
        switch (buf16[i]) {
          case 0x0104:
            buf[i] = 0xA1; /* LATIN CAPITAL LETTER A WITH OGONEK */
            break;
          case 0x02D8:
            buf[i] = 0xA2; /* BREVE */
            break;
          case 0x0141:
            buf[i] = 0xA3; /* LATIN CAPITAL LETTER L WITH STROKE */
            break;
          case 0x013D:
            buf[i] = 0xA5; /* LATIN CAPITAL LETTER L WITH CARON */
            break;
          case 0x015A:
            buf[i] = 0xA6; /* LATIN CAPITAL LETTER S WITH ACUTE */
            break;
          case 0x0160:
            buf[i] = 0xA9; /* LATIN CAPITAL LETTER S WITH CARON */
            break;
          case 0x015E:
            buf[i] = 0xAA; /* LATIN CAPITAL LETTER S WITH CEDILLA */
            break;
          case 0x0164:
            buf[i] = 0xAB; /* LATIN CAPITAL LETTER T WITH CARON */
            break;
          case 0x0179:
            buf[i] = 0xAC; /* LATIN CAPITAL LETTER Z WITH ACUTE */
            break;
          case 0x017D:
            buf[i] = 0xAE; /* LATIN CAPITAL LETTER Z WITH CARON */
            break;
          case 0x017B:
            buf[i] = 0xAF; /* LATIN CAPITAL LETTER Z WITH DOT ABOVE */
            break;
          case 0x0105:
            buf[i] = 0xB1; /* LATIN SMALL LETTER A WITH OGONEK */
            break;
          case 0x02DB:
            buf[i] = 0xB2; /* OGONEK */
            break;
          case 0x0142:
            buf[i] = 0xB3; /* LATIN SMALL LETTER L WITH STROKE */
            break;
          case 0x013E:
            buf[i] = 0xB5; /* LATIN SMALL LETTER L WITH CARON */
            break;
          case 0x015B:
            buf[i] = 0xB6; /* LATIN SMALL LETTER S WITH ACUTE */
            break;
          case 0x02C7:
            buf[i] = 0xB7; /* CARON */
            break;
          case 0x0161:
            buf[i] = 0xB9; /* LATIN SMALL LETTER S WITH CARON */
            break;
          case 0x015F:
            buf[i] = 0xBA; /* LATIN SMALL LETTER S WITH CEDILLA */
            break;
          case 0x0165:
            buf[i] = 0xBB; /* LATIN SMALL LETTER T WITH CARON */
            break;
          case 0x017A:
            buf[i] = 0xBC; /* LATIN SMALL LETTER Z WITH ACUTE */
            break;
          case 0x02DD:
            buf[i] = 0xBD; /* DOUBLE ACUTE ACCENT */
            break;
          case 0x017E:
            buf[i] = 0xBE; /* LATIN SMALL LETTER Z WITH CARON */
            break;
          case 0x017C:
            buf[i] = 0xBF; /* LATIN SMALL LETTER Z WITH DOT ABOVE */
            break;
          case 0x0154:
            buf[i] = 0xC0; /* LATIN CAPITAL LETTER R WITH ACUTE */
            break;
          case 0x0102:
            buf[i] = 0xC3; /* LATIN CAPITAL LETTER A WITH BREVE */
            break;
          case 0x0139:
            buf[i] = 0xC5; /* LATIN CAPITAL LETTER L WITH ACUTE */
            break;
          case 0x0106:
            buf[i] = 0xC6; /* LATIN CAPITAL LETTER C WITH ACUTE */
            break;
          case 0x010C:
            buf[i] = 0xC8; /* LATIN CAPITAL LETTER C WITH CARON */
            break;
          case 0x0118:
            buf[i] = 0xCA; /* LATIN CAPITAL LETTER E WITH OGONEK */
            break;
          case 0x011A:
            buf[i] = 0xCC; /* LATIN CAPITAL LETTER E WITH CARON */
            break;
          case 0x010E:
            buf[i] = 0xCF; /* LATIN CAPITAL LETTER D WITH CARON */
            break;
          case 0x0110:
            buf[i] = 0xD0; /* LATIN CAPITAL LETTER D WITH STROKE */
            break;
          case 0x0143:
            buf[i] = 0xD1; /* LATIN CAPITAL LETTER N WITH ACUTE */
            break;
          case 0x0147:
            buf[i] = 0xD2; /* LATIN CAPITAL LETTER N WITH CARON */
            break;
          case 0x0150:
            buf[i] = 0xD5; /* LATIN CAPITAL LETTER O WITH DOUBLE ACUTE */
            break;
          case 0x0158:
            buf[i] = 0xD8; /* LATIN CAPITAL LETTER R WITH CARON */
            break;
          case 0x016E:
            buf[i] = 0xD9; /* LATIN CAPITAL LETTER U WITH RING ABOVE */
            break;
          case 0x0170:
            buf[i] = 0xDB; /* LATIN CAPITAL LETTER U WITH DOUBLE ACUTE */
            break;
          case 0x0162:
            buf[i] = 0xDE; /* LATIN CAPITAL LETTER T WITH CEDILLA */
            break;
          case 0x0155:
            buf[i] = 0xE0; /* LATIN SMALL LETTER R WITH ACUTE */
            break;
          case 0x0103:
            buf[i] = 0xE3; /* LATIN SMALL LETTER A WITH BREVE */
            break;
          case 0x013A:
            buf[i] = 0xE5; /* LATIN SMALL LETTER L WITH ACUTE */
            break;
          case 0x0107:
            buf[i] = 0xE6; /* LATIN SMALL LETTER C WITH ACUTE */
            break;
          case 0x010D:
            buf[i] = 0xE8; /* LATIN SMALL LETTER C WITH CARON */
            break;
          case 0x0119:
            buf[i] = 0xEA; /* LATIN SMALL LETTER E WITH OGONEK */
            break;
          case 0x011B:
            buf[i] = 0xEC; /* LATIN SMALL LETTER E WITH CARON */
            break;
          case 0x010F:
            buf[i] = 0xEF; /* LATIN SMALL LETTER D WITH CARON */
            break;
          case 0x0111:
            buf[i] = 0xF0; /* LATIN SMALL LETTER D WITH STROKE */
            break;
          case 0x0144:
            buf[i] = 0xF1; /* LATIN SMALL LETTER N WITH ACUTE */
            break;
          case 0x0148:
            buf[i] = 0xF2; /* LATIN SMALL LETTER N WITH CARON */
            break;
          case 0x0151:
            buf[i] = 0xF5; /* LATIN SMALL LETTER O WITH DOUBLE ACUTE */
            break;
          case 0x0159:
            buf[i] = 0xF8; /* LATIN SMALL LETTER R WITH CARON */
            break;
          case 0x016F:
            buf[i] = 0xF9; /* LATIN SMALL LETTER U WITH RING ABOVE */
            break;
          case 0x0171:
            buf[i] = 0xFB; /* LATIN SMALL LETTER U WITH DOUBLE ACUTE */
            break;
          case 0x0163:
            buf[i] = 0xFE; /* LATIN SMALL LETTER T WITH CEDILLA */
            break;
          case 0x02D9:
            buf[i] = 0xFF; /* DOT ABOVE */
            break;
        }
        if (buf[i] == 0) {
          if ((buf16[i] > 255) && !flag) {
            /* cannot convert without loosing information */
            if (tmpMalloc) {
              free(tmpMalloc); tmpMalloc = NULL;
            }
            goto END_OF_SWITCH;
          }
          else {
            buf[i] = buf16[i]; /* invalid */
          }
        }
      }
      data = (tmpMalloc)
        ? [NSData dataWithBytesNoCopy:buf length:i]
        : [NSData dataWithBytes:buf length:i];
      break;
    }
    case NSISOLatin9StringEncoding: {
      register unsigned int i;
      unsigned char     *buf;
      unsigned char     tmpBuf[MaxStringEncodingBufStackSize];
      unsigned char     *tmpMalloc = NULL;

      if (len < MaxStringEncodingBufStackSize) {
        buf = tmpBuf;
      }
      else {
        tmpMalloc = malloc((sizeof(char) * len) + 1);
        buf       = tmpMalloc;
      }
            
      for (i = 0; i < len;i++) {
        buf[i] = 0;
        switch (buf16[i]) {
                
          case 0x20AC:	/* EURO SIGN */
            buf[i] = 0xA4;
            break;
          case 0x0160:	/* LATIN CAPITAL LETTER S WITH CARON */
            buf[i] = 0xA6;
            break;
          case 0x0161:	/* LATIN SMALL LETTER S WITH CARON */
            buf[i] = 0xA8;
            break;
          case 0x017D:	/* LATIN CAPITAL LETTER Z WITH CARON */
            buf[i] = 0xB4;
            break;
          case 0x017E:	/* LATIN SMALL LETTER Z WITH CARON */
            buf[i] = 0xB8;
            break;
          case 0x0152:	/* LATIN CAPITAL LIGATURE OE */
            buf[i] = 0xBC;
            break;
          case 0x0153:	/* LATIN SMALL LIGATURE OE */
            buf[i] = 0xBD;
            break;
          case 0x0178:	/* LATIN CAPITAL LETTER Y WITH DIAERESIS */
            buf[i] = 0xBE;
            break;
                
        }
        if (buf[i] == 0) {
          if ((buf16[i] > 255) && !flag) {
            /* cannot convert without loosing information */
            if (tmpMalloc) {
              free(tmpMalloc); tmpMalloc = NULL;
            }
            goto END_OF_SWITCH;
          }
          else {
            buf[i] = buf16[i]; /* invalid */
          }
        }
      }
      data = (tmpMalloc)
        ? [NSData dataWithBytesNoCopy:buf length:i]
        : [NSData dataWithBytes:buf length:i];
      break;
    }
    case NSASCIIStringEncoding: {
      register unsigned i;
      unsigned char     *buf;
      unsigned char     tmpBuf[MaxStringEncodingBufStackSize];
      unsigned char     *tmpMalloc = NULL;

      if (len < MaxStringEncodingBufStackSize) {
        buf = tmpBuf;
      }
      else {
        tmpMalloc = malloc((sizeof(char) * len) + 1);
        buf       = tmpMalloc;
      }
            
      for (i = 0; i < len; i++) {
        if (buf16[i] > 127) {
            if (!flag) {
              /* cannot convert without loosing information */
              if (tmpMalloc) {
                free(tmpMalloc); tmpMalloc = NULL;
              }
              goto END_OF_SWITCH;
            }
            else {
              buf[i] = ' ';
            }
        }
        else 
          buf[i] = buf16[i];
      }
      data = (tmpMalloc)
        ? [NSData dataWithBytesNoCopy:buf length:i]
        : [NSData dataWithBytes:buf length:i];
      break;
    }
    case NSUTF8StringEncoding: {
      unsigned char *buf;
      unsigned      bufLen;
      int           result;
            
      /* empty UTF16 becomes empty UTF8 .. */
      if (len == 0) {
        data = [NSData data];
        goto END_OF_SWITCH;
      }
            
      bufLen = (len + (len / 2));
      buf    = NSZoneMallocAtomic(NULL, bufLen + 1);
            
      do {
        unichar       *start16, *end16;
        unsigned char *start, *end;
                
        start16 = &(buf16[0]);
        end16   = buf16 + len;
        start   = &(buf[0]);
        end     = start + bufLen;
                
        result = NSConvertUTF16toUTF8(&start16, end16, &start, end);
                
        NSCAssert(result != 1, @"not enough chars in source buffer !");
                
        if (result == 2) {
          /* not enough memory in target buffer */
          bufLen *= 2;
          buf = NSZoneRealloc(NULL, buf, bufLen + 1);
        }
        else {
          len = start - buf;
          break;
        }
      }
      while (1);
            
      data = [NSData dataWithBytesNoCopy:buf length:len];
      break;
    }
    default:
      if (flag) {
        NSLog(@"%s: unsupported string encoding: %@ "
              @"(returning string as ISO-Latin-1)",
              __PRETTY_FUNCTION__,
              [NSString localizedNameOfStringEncoding:encoding]);
                
        data = [self dataUsingEncoding:NSISOLatin9StringEncoding
                     allowLossyConversion:YES];
      }
      else {
        NSLog(@"%s: unsupported string encoding: %@ "
              @"(returning nil)",
              __PRETTY_FUNCTION__,
              [NSString localizedNameOfStringEncoding:encoding]);
        goto END_OF_SWITCH;
      }
  }
 END_OF_SWITCH:
  if (tmpMalloc16) {
    free(tmpMalloc16); tmpMalloc16 = NULL;
  }
  return data;
}

id NSInitStringWithData(NSString *self, NSData *data,
                        NSStringEncoding encoding)
{
  // UNICODE
  // ENCODINGS
  unsigned      len;
  unsigned char *buf;
    
  len = [data length];
  buf = MallocAtomic(len + 1);

  if (len > 0) [data getBytes:buf];
  buf[len] = '\0';

  switch (encoding) {
    case NSWindowsCP1252StringEncoding: { 
      register unsigned int i;
      unichar *newBuf;

      newBuf = MallocAtomic((len + 1)* sizeof(unichar));
            
      for (i = 0; i < len;i++) {
        newBuf[i] = 0;
        switch (buf[i]) {
          case 0x80: /* EURO SIGN */
            newBuf[i] = 0x20AC;
            break;
          case 0x82: /* SINGLE LOW-9 QUOTATION MARK */
            newBuf[i] = 0x201A;
            break;
          case 0x83: /* LATIN SMALL LETTER F WITH HOOK */
            newBuf[i] = 0x0192;
            break;
          case 0x84: /* DOUBLE LOW-9 QUOTATION MARK */
            newBuf[i] = 0x201E;
            break;
          case 0x85: /* HORIZONTAL ELLIPSIS */
            newBuf[i] = 0x2026;
            break;
          case 0x86: /* DAGGER */
            newBuf[i] = 0x2020;
            break;
          case 0x87: /* DOUBLE DAGGER */
            newBuf[i] = 0x2021;
            break;
          case 0x88: /* MODIFIER LETTER CIRCUMFLEX ACCENT */
            newBuf[i] = 0x02C6;
            break;
          case 0x89: /* PER MILLE SIGN */
            newBuf[i] = 0x2030;
            break;
          case 0x8A: /* LATIN CAPITAL LETTER S WITH CARON */
            newBuf[i] = 0x0160;
            break;
          case 0x8B: /* SINGLE LEFT-POINTING ANGLE QUOTATION MARK */
            newBuf[i] = 0x2039;
            break;
          case 0x8C: /* LATIN CAPITAL LIGATURE OE */
            newBuf[i] = 0x0152;
            break;
          case 0x8E: /* LATIN CAPITAL LETTER Z WITH CARON */
            newBuf[i] = 0x017D;
            break;
          case 0x91: /* LEFT SINGLE QUOTATION MARK */
            newBuf[i] = 0x2018;
            break;
          case 0x92: /* RIGHT SINGLE QUOTATION MARK */
            newBuf[i] = 0x2019;
            break;
          case 0x93: /* LEFT DOUBLE QUOTATION MARK */
            newBuf[i] = 0x201C;
            break;
          case 0x94: /* RIGHT DOUBLE QUOTATION MARK */
            newBuf[i] = 0x201D;
            break;
          case 0x95: /* BULLET */
            newBuf[i] = 0x2022;
            break;
          case 0x96: /* EN DASH */
            newBuf[i] = 0x2013;
            break;
          case 0x97: /* EM DASH */
            newBuf[i] = 0x2014;
            break;
          case 0x98: /* SMALL TILDE */
            newBuf[i] = 0x02DC;
            break;
          case 0x99: /* TRADE MARK SIGN */
            newBuf[i] = 0x2122;
            break;
          case 0x9A: /* LATIN SMALL LETTER S WITH CARON */
            newBuf[i] = 0x0161;
            break;
          case 0x9B: /* SINGLE RIGHT-POINTING ANGLE QUOTATION MARK */
            newBuf[i] = 0x203A;
            break;
          case 0x9C: /* LATIN SMALL LIGATURE OE */
            newBuf[i] = 0x0153;
            break;
          case 0x9E: /* LATIN SMALL LETTER Z WITH CARON */
            newBuf[i] = 0x017E;
            break;
          case 0x9F: /* LATIN CAPITAL LETTER Y WITH DIAERESIS */
            newBuf[i] = 0x0178;
            break;
        }
        if (newBuf[i] == 0)
          newBuf[i] = buf[i];
      }
      {
        id tmp;
                
        tmp = self;
                
        // TODO: this breaks NSMutableString !!!
        self = [NSInlineUTF16String allocForCapacity:len
                                    zone:[self zone]];
        self = [self initWithCharacters:newBuf length:len];
        RELEASE(tmp);
      }
      lfFree(newBuf);
      lfFree(buf);
      return self;
    }
        
    case NSISOLatin9StringEncoding: {
      register unsigned int i;
      unichar *newBuf;
            
      newBuf = MallocAtomic((len + 1)* sizeof(unichar));
            
      for (i = 0; i < len; i++) {
        newBuf[i] = 0;
                
        switch (buf[i]) {
          case 0xA4:	/* EURO SIGN */
            newBuf[i] = 0x20AC;
            break;
          case 0xA6:	/* LATIN CAPITAL LETTER S WITH CARON */
            newBuf[i] = 0x0160;
            break;
          case 0xA8:	/* LATIN SMALL LETTER S WITH CARON */
            newBuf[i] = 0x0161;
            break;
          case 0xB4:	/* LATIN CAPITAL LETTER Z WITH CARON */
            newBuf[i] = 0x017D;
            break;
          case 0xB8:	/* LATIN SMALL LETTER Z WITH CARON */
            newBuf[i] = 0x017E;
            break;
          case 0xBC:	/* LATIN CAPITAL LIGATURE OE */
            newBuf[i] = 0x0152;
            break;
          case 0xBD:	/* LATIN SMALL LIGATURE OE */
            newBuf[i] = 0x0153;
            break;
          case 0xBE:	/* LATIN CAPITAL LETTER Y WITH DIAERESIS */
            newBuf[i] = 0x0178;
            break;
        }
        if (newBuf[i] == 0)
          newBuf[i] = buf[i];
      }
      {
        id tmp;
                
        tmp = self;
                
        // TODO: this breaks NSMutableString !!!
        self = [NSInlineUTF16String allocForCapacity:len
                                    zone:[self zone]];
        self = [self initWithCharacters:newBuf length:len];
        RELEASE(tmp);
      }
      lfFree(newBuf);
      lfFree(buf);
      return self;
    }
          
    case NSISOLatin2StringEncoding: {
      register unsigned int i;
      unichar *newBuf;
            
      newBuf = MallocAtomic((len + 1)* sizeof(unichar));
            
      for (i = 0; i < len; i++) {
        newBuf[i] = 0;
                
        switch (buf[i]) {
          case 0xA1:
            newBuf[i] = 0x0104; /* LATIN CAPITAL LETTER A WITH OGONEK */
            break;
          case 0xA2:
            newBuf[i] = 0x02D8; /* BREVE */
            break;
          case 0xA3:
            newBuf[i] = 0x0141; /* LATIN CAPITAL LETTER L WITH STROKE */
            break;
          case 0xA5:
            newBuf[i] = 0x013D; /* LATIN CAPITAL LETTER L WITH CARON */
            break;
          case 0xA6:
            newBuf[i] = 0x015A; /* LATIN CAPITAL LETTER S WITH ACUTE */
            break;
          case 0xA9:
            newBuf[i] = 0x0160; /* LATIN CAPITAL LETTER S WITH CARON */
            break;
          case 0xAA:
            newBuf[i] = 0x015E; /* LATIN CAPITAL LETTER S WITH CEDILLA */
            break;
          case 0xAB:
            newBuf[i] = 0x0164; /* LATIN CAPITAL LETTER T WITH CARON */
            break;
          case 0xAC:
            newBuf[i] = 0x0179; /* LATIN CAPITAL LETTER Z WITH ACUTE */
            break;
          case 0xAE:
            newBuf[i] = 0x017D; /* LATIN CAPITAL LETTER Z WITH CARON */
            break;
          case 0xAF:
            newBuf[i] = 0x017B; /* LATIN CAPITAL LETTER Z WITH DOT ABOVE */
            break;
          case 0xB1:
            newBuf[i] = 0x0105; /* LATIN SMALL LETTER A WITH OGONEK */
            break;
          case 0xB2:
            newBuf[i] = 0x02DB; /* OGONEK */
            break;
          case 0xB3:
            newBuf[i] = 0x0142; /* LATIN SMALL LETTER L WITH STROKE */
            break;
          case 0xB5:
            newBuf[i] = 0x013E; /* LATIN SMALL LETTER L WITH CARON */
            break;
          case 0xB6:
            newBuf[i] = 0x015B; /* LATIN SMALL LETTER S WITH ACUTE */
            break;
          case 0xB7:
            newBuf[i] = 0x02C7; /* CARON */
            break;
          case 0xB9:
            newBuf[i] = 0x0161; /* LATIN SMALL LETTER S WITH CARON */
            break;
          case 0xBA:
            newBuf[i] = 0x015F; /* LATIN SMALL LETTER S WITH CEDILLA */
            break;
          case 0xBB:
            newBuf[i] = 0x0165; /* LATIN SMALL LETTER T WITH CARON */
            break;
          case 0xBC:
            newBuf[i] = 0x017A; /* LATIN SMALL LETTER Z WITH ACUTE */
            break;
          case 0xBD:
            newBuf[i] = 0x02DD; /* DOUBLE ACUTE ACCENT */
            break;
          case 0xBE:
            newBuf[i] = 0x017E; /* LATIN SMALL LETTER Z WITH CARON */
            break;
          case 0xBF:
            newBuf[i] = 0x017C; /* LATIN SMALL LETTER Z WITH DOT ABOVE */
            break;
          case 0xC0:
            newBuf[i] = 0x0154; /* LATIN CAPITAL LETTER R WITH ACUTE */
            break;
          case 0xC3:
            newBuf[i] = 0x0102; /* LATIN CAPITAL LETTER A WITH BREVE */
            break;
          case 0xC5:
            newBuf[i] = 0x0139; /* LATIN CAPITAL LETTER L WITH ACUTE */
            break;
          case 0xC6:
            newBuf[i] = 0x0106; /* LATIN CAPITAL LETTER C WITH ACUTE */
            break;
          case 0xC8:
            newBuf[i] = 0x010C; /* LATIN CAPITAL LETTER C WITH CARON */
            break;
          case 0xCA:
            newBuf[i] = 0x0118; /* LATIN CAPITAL LETTER E WITH OGONEK */
            break;
          case 0xCC:
            newBuf[i] = 0x011A; /* LATIN CAPITAL LETTER E WITH CARON */
            break;
          case 0xCF:
            newBuf[i] = 0x010E; /* LATIN CAPITAL LETTER D WITH CARON */
            break;
          case 0xD0:
            newBuf[i] = 0x0110; /* LATIN CAPITAL LETTER D WITH STROKE */
            break;
          case 0xD1:
            newBuf[i] = 0x0143; /* LATIN CAPITAL LETTER N WITH ACUTE */
            break;
          case 0xD2:
            newBuf[i] = 0x0147; /* LATIN CAPITAL LETTER N WITH CARON */
            break;
          case 0xD5:
            newBuf[i] = 0x0150; /* LATIN CAPITAL LETTER O WITH DOUBLE ACUTE */
            break;
          case 0xD8:
            newBuf[i] = 0x0158; /* LATIN CAPITAL LETTER R WITH CARON */
            break;
          case 0xD9:
            newBuf[i] = 0x016E; /* LATIN CAPITAL LETTER U WITH RING ABOVE */
            break;
          case 0xDB:
            newBuf[i] = 0x0170; /* LATIN CAPITAL LETTER U WITH DOUBLE ACUTE */
            break;
          case 0xDE:
            newBuf[i] = 0x0162; /* LATIN CAPITAL LETTER T WITH CEDILLA */
            break;
          case 0xE0:
            newBuf[i] = 0x0155; /* LATIN SMALL LETTER R WITH ACUTE */
            break;
          case 0xE3:
            newBuf[i] = 0x0103; /* LATIN SMALL LETTER A WITH BREVE */
            break;
          case 0xE5:
            newBuf[i] = 0x013A; /* LATIN SMALL LETTER L WITH ACUTE */
            break;
          case 0xE6:
            newBuf[i] = 0x0107; /* LATIN SMALL LETTER C WITH ACUTE */
            break;
          case 0xE8:
            newBuf[i] = 0x010D; /* LATIN SMALL LETTER C WITH CARON */
            break;
          case 0xEA:
            newBuf[i] = 0x0119; /* LATIN SMALL LETTER E WITH OGONEK */
            break;
          case 0xEC:
            newBuf[i] = 0x011B; /* LATIN SMALL LETTER E WITH CARON */
            break;
          case 0xEF:
            newBuf[i] = 0x010F; /* LATIN SMALL LETTER D WITH CARON */
            break;
          case 0xF0:
            newBuf[i] = 0x0111; /* LATIN SMALL LETTER D WITH STROKE */
            break;
          case 0xF1:
            newBuf[i] = 0x0144; /* LATIN SMALL LETTER N WITH ACUTE */
            break;
          case 0xF2:
            newBuf[i] = 0x0148; /* LATIN SMALL LETTER N WITH CARON */
            break;
          case 0xF5:
            newBuf[i] = 0x0151; /* LATIN SMALL LETTER O WITH DOUBLE ACUTE */
            break;
          case 0xF8:
            newBuf[i] = 0x0159; /* LATIN SMALL LETTER R WITH CARON */
            break;
          case 0xF9:
            newBuf[i] = 0x016F; /* LATIN SMALL LETTER U WITH RING ABOVE */
            break;
          case 0xFB:
            newBuf[i] = 0x0171; /* LATIN SMALL LETTER U WITH DOUBLE ACUTE */
            break;
          case 0xFE:
            newBuf[i] = 0x0163; /* LATIN SMALL LETTER T WITH CEDILLA */
            break;
          case 0xFF:
            newBuf[i] = 0x02D9; /* DOT ABOVE */
            break;
        }
        if (newBuf[i] == 0)
          newBuf[i] = buf[i];
      }
      {
        id tmp;
                
        tmp = self;
                
        // TODO: this breaks NSMutableString !!!
        self = [NSInlineUTF16String allocForCapacity:len
                                    zone:[self zone]];
        self = [self initWithCharacters:newBuf length:len];
        RELEASE(tmp);
      }
      lfFree(newBuf);
      lfFree(buf);
      return self;
    }
          
    case NSUnicodeStringEncoding: {
      self = [self initWithCharacters:(unichar *)buf
                   length:(len / sizeof(unichar))];
      lfFree(buf);
      return self;
    }
    case NSASCIIStringEncoding: 
    case NSISOLatin1StringEncoding: {
      self = [self initWithCString:(char *)buf length:len];
      lfFree(buf);
      return self;
    }
        
    case NSUTF8StringEncoding: {
      unichar       *buf16;
      unsigned char *start,   *end;
      unichar       *start16, *end16;
      int result;
            
      buf16 = MallocAtomic((len + 1) * sizeof(unichar));
#if DEBUG
      NSCAssert(buf16,
                @"couldn't allocate proper buffer of len %i", len);
#endif
            
      start   = &(buf[0]);
      end     = start + len;
      start16 = &(buf16[0]);
      end16   = start16 + len;

      result = NSConvertUTF8toUTF16(&start, end, &start16, end16);
      if (buf) {
        lfFree(buf);
        start = end = buf = NULL;
      }
            
      if (result == 2) { /* target exhausted */
        if (buf16) { lfFree(buf16); buf16 = NULL; }
        [NSException raise:@"UTFConversionException"
                     format:
                     @"couldn't convert UTF8 to UTF16, "
                     @"target buffer is to small !"];
      }
      else if (result == 1) { /* source exhausted */
        if (buf16) { lfFree(buf16); buf16 = NULL; }
        [NSException raise:@"UTFConversionException"
                     format:
                     @"couldn't convert UTF8 to UTF16, "
                     @"source buffer is to small "
                     @"(probably invalid input) !"];
      }
      else {
        /* length correct ? */
        {
          id tmp;
                    
          tmp = self;
          // TODO: this breaks NSMutableString !!!
          self = [[NSInlineUTF16String class] allocForCapacity:(start16 - buf16)
                                              zone:[self zone]];
          self = [self initWithCharacters:buf16
                       length:(start16 - buf16)];
          RELEASE(tmp);
        }
        if (buf16) { lfFree(buf16); buf16 = NULL; }
        return self;
      }
    }
        
    default:
      NSLog(@"%s: unsupported string encoding: %@ "
            @"(returning string as ISO-Latin-1)",
            __PRETTY_FUNCTION__,
            [NSString localizedNameOfStringEncoding:encoding]);
	    
      self = NSInitStringWithData(self, data, NSISOLatin1StringEncoding);
      lfFree(buf);
      return self;
  }
}
