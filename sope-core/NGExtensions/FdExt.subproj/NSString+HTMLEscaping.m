/*
  Copyright (C) 2000-2005 SKYRIX Software AG

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

#include "NSString+misc.h"
#include "common.h"

@implementation NSString(HTMLEscaping)

- (NSString *)stringByEscapingHTMLStringUsingCharacters {
  register unsigned i, len, j;
  register unichar  *chars, *buf;
  unsigned escapeCount;
  
  if ((len = [self length]) == 0) return @"";
  
  chars = malloc((len + 3) * sizeof(unichar));
  [self getCharacters:chars];
  
  /* check for characters to escape ... */
  for (i = 0, escapeCount = 0; i < len; i++) {
    switch (chars[i]) {
      case '&': case '"': case '<': case '>':
        escapeCount++;
        break;
      default:
        if (chars[i] > 127)
          escapeCount++;
        break;
    }
  }
  if (escapeCount == 0 ) {
    /* nothing to escape ... */
    if (chars) free(chars);
    return [[self copy] autorelease];
  }
  
  buf = calloc((len + 5) + (escapeCount * 8), sizeof(unichar));
  for (i = 0, j = 0; i < len; i++) {
    switch (chars[i]) {
      /* escape special chars */
      case '&':
        buf[j] = '&'; j++; buf[j] = 'a'; j++; buf[j] = 'm'; j++;
        buf[j] = 'p'; j++; buf[j] = ';'; j++;
        break;
      case '"':
        buf[j] = '&'; j++; buf[j] = 'q'; j++; buf[j] = 'u'; j++;
        buf[j] = 'o'; j++; buf[j] = 't'; j++; buf[j] = ';'; j++;
        break;
      case '<':
        buf[j] = '&'; j++; buf[j] = 'l'; j++; buf[j] = 't'; j++;
        buf[j] = ';'; j++;
        break;
      case '>':
        buf[j] = '&'; j++; buf[j] = 'g'; j++; buf[j] = 't'; j++;
        buf[j] = ';'; j++;
        break;
      case 223: /* &szlig; */
        buf[j] = '&'; j++; buf[j] = 's'; j++; buf[j] = 'z'; j++;
        buf[j] = 'l'; j++; buf[j] = 'i'; j++; buf[j] = 'g'; j++;
        buf[j] = ';'; j++;
        break;
        // TODO: this is missing a LOT?
      case 252: /* &uuml; */
        buf[j] = '&'; j++; buf[j] = 'u'; j++; buf[j] = 'u'; j++;
        buf[j] = 'm'; j++; buf[j] = 'l'; j++; buf[j] = ';'; j++;
        break;
      case 220: /* &Uuml; */
        buf[j] = '&'; j++; buf[j] = 'U'; j++; buf[j] = 'u'; j++;
        buf[j] = 'm'; j++; buf[j] = 'l'; j++; buf[j] = ';'; j++;
        break;
      case 228: /* &auml; */
        buf[j] = '&'; j++; buf[j] = 'a'; j++; buf[j] = 'u'; j++;
        buf[j] = 'm'; j++; buf[j] = 'l'; j++; buf[j] = ';'; j++;
        break;
      case 196: /* &Auml; */
        buf[j] = '&'; j++; buf[j] = 'A'; j++; buf[j] = 'u'; j++;
        buf[j] = 'm'; j++; buf[j] = 'l'; j++; buf[j] = ';'; j++;
        break;
      case 246: /* &ouml; */
        buf[j] = '&'; j++; buf[j] = 'o'; j++; buf[j] = 'u'; j++;
        buf[j] = 'm'; j++; buf[j] = 'l'; j++; buf[j] = ';'; j++;
        break;
      case 214: /* &Ouml; */
        buf[j] = '&'; j++; buf[j] = 'O'; j++; buf[j] = 'u'; j++;
        buf[j] = 'm'; j++; buf[j] = 'l'; j++; buf[j] = ';'; j++;
        break;
        
      default:
        /* escape big chars */
        if (chars[i] > 127) {
          unsigned char nbuf[16];
          unsigned int k;
          
          sprintf((char *)nbuf, "&#%i;", (int)chars[i]);
          for (k = 0; nbuf[k] != '\0'; k++) {
            buf[j] = nbuf[k];
            j++;
          }
        }
        else {
          /* nothing to escape */
          buf[j] = chars[i];
          j++;
        }
        break;
    }
  }
  
  self = [NSString stringWithCharacters:buf length:j];
  
  if (chars) free(chars);
  if (buf)   free(buf);
  return self;
}

- (NSString *)stringByEscapingHTMLAttributeValueUsingCharacters {
  register unsigned i, len, j;
  register unichar  *chars, *buf;
  unsigned escapeCount;
  
  if ((len = [self length]) == 0) return @"";
  
  chars = malloc((len + 3) * sizeof(unichar));
  [self getCharacters:chars];
  
  /* check for characters to escape ... */
  for (i = 0, escapeCount = 0; i < len; i++) {
    switch (chars[i]) {
      case '&':
      case '"':
      case '<':
      case '>':
      case '\t':
      case '\n':
      case '\r':
        escapeCount++;
        break;
      default:
        if (chars[i] > 127)
          escapeCount++;
        break;
    }
  }
  if (escapeCount == 0 ) {
    /* nothing to escape ... */
    if (chars) free(chars);
    return [[self copy] autorelease];
  }
  
  buf = calloc((len + 3) + (escapeCount * 8), sizeof(unichar));
  for (i = 0, j = 0; i < len; i++) {
    switch (chars[i]) {
      /* escape special chars */
      case '&':
        buf[j] = '&'; j++; buf[j] = 'a'; j++; buf[j] = 'm'; j++;
        buf[j] = 'p'; j++; buf[j] = ';'; j++;
        break;
      case '"':
        buf[j] = '&'; j++; buf[j] = 'q'; j++; buf[j] = 'u'; j++;
        buf[j] = 'o'; j++; buf[j] = 't'; j++; buf[j] = ';'; j++;
        break;
      case '<':
        buf[j] = '&'; j++; buf[j] = 'l'; j++; buf[j] = 't'; j++;
        buf[j] = ';'; j++;
        break;
      case '>':
        buf[j] = '&'; j++; buf[j] = 'g'; j++; buf[j] = 't'; j++;
        buf[j] = ';'; j++;
        break;
        
      case '\t':
        buf[j] = '&'; j++; buf[j] = '#'; j++; buf[j] = '9'; j++;
        buf[j] = ';'; j++;
        break;
      case '\n':
        buf[j] = '&'; j++; buf[j] = '#'; j++; buf[j] = '1'; j++;
        buf[j] = '0'; j++; buf[j] = ';'; j++;
        break;
      case '\r':
        buf[j] = '&'; j++; buf[j] = '#'; j++; buf[j] = '1'; j++;
        buf[j] = '3'; j++; buf[j] = ';'; j++;
        break;
        
      default:
        /* escape big chars */
        if (chars[i] > 127) {
          unsigned char nbuf[16];
          unsigned int k;
          
          sprintf((char *)nbuf, "&#%i;", (int)chars[i]);
          for (k = 0; nbuf[k] != '\0'; k++) {
            buf[j] = nbuf[k];
            j++;
          }
        }
        else {
          /* nothing to escape */
          buf[j] = chars[i]; j++;
        }
        break;
    }
  }
  
  self = [NSString stringWithCharacters:buf length:j];
  
  if (chars) free(chars);
  if (buf)   free(buf);
  return self;
}

- (NSString *)stringByEscapingHTMLString {
  return [self stringByEscapingHTMLStringUsingCharacters];
}
- (NSString *)stringByEscapingHTMLAttributeValue {
  return [self stringByEscapingHTMLAttributeValueUsingCharacters];
}

@end /* NSString(HTMLEscaping) */
