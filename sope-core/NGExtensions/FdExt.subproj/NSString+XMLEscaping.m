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

@implementation NSString(XMLEscaping)

- (NSString *)stringByEscapingXMLStringUsingCharacters {
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
  
  buf = malloc(((len + 3) * sizeof(unichar)) +
	       (escapeCount * 8 * sizeof(unichar)));
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

- (NSString *)stringByEscapingXMLString {
  return [self stringByEscapingXMLStringUsingCharacters];
}

- (NSString *)stringByEscapingXMLAttributeValue {
  return [self stringByEscapingHTMLAttributeValue];
}

/* XML FQNs */

- (BOOL)xmlIsFQN {
  if ([self length] == 0) return NO;
  return [self characterAtIndex:0] == '{' ? YES : NO;
}

- (NSString *)xmlNamespaceURI {
  NSRange r;
  
  r = [self rangeOfString:@"}" options:(NSLiteralSearch | NSBackwardsSearch)];
  if (r.length == 0) return nil;
  if ([self characterAtIndex:0] != '{') return nil;
  
  r.length   = (r.location - 1);
  r.location = 1;
  return [self substringWithRange:r];
}

- (NSString *)xmlLocalName {
  NSRange r;
  
  r = [self rangeOfString:@"}" options:(NSLiteralSearch | NSBackwardsSearch)];
  if (r.length == 0) return nil;
  if ([self characterAtIndex:0] != '{') return nil;
  
  return [self substringFromIndex:(r.location + r.length)];
}

@end /* NSString(XMLEscaping) */
