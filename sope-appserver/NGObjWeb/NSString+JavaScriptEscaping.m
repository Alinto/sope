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

#include <NGObjWeb/NSString+JavaScriptEscaping.h>
#include "common.h"

@implementation NSString(JavascriptEscaping)

static inline unichar HEX_NIBBLE(unichar v) {
  return (v > 9) ? (v - 10 + 'a') : (v + '0');
}

- (NSString *)stringByApplyingJavaScriptEscaping {
  /* Replaces \b, \f, \n, \r, \t, ', " by \-escaped sequences.
     Replaces non-ASCII characters by either \xXX escape sequences, 
     when character is in ISOLatin1, or \uXXXX escape sequences.
     Result string can be used safely as a Javascript string value.
  */
  NSString  *javascriptEscapedString = self;
  unsigned  additionalCharCount = 0;
  unsigned  length = [self length];
  int       i, firstEscapedCharIndex = -1, lastEscapedCharIndex = length;
  
  for(i = length - 1; i >= 0; i -=1) {
    unichar aChar = [self characterAtIndex:i];
    
    if (aChar > 255) {
      additionalCharCount += 5; // \uXXXX
      firstEscapedCharIndex = i;
    }
    else if (aChar > 127) {
      additionalCharCount += 3; // \xXX
      firstEscapedCharIndex = i;
    }
    else if (aChar == '\b' || aChar == '\f' || aChar == '\n' || 
	     aChar == '\r' || 
             aChar == '\t' || aChar == '\'' || aChar == '"' || aChar == '\\') {
      additionalCharCount += 1;
      firstEscapedCharIndex = i;
    }
    if (lastEscapedCharIndex == length && additionalCharCount != 0)
      lastEscapedCharIndex = i;
  }
  
  if (additionalCharCount > 0) {
    unsigned  newLength = length + additionalCharCount;
    unichar   *newChars = NSZoneMalloc(NSDefaultMallocZone(), 
                            sizeof(unichar) * newLength);
    unsigned  offset = 0;
    
    [self getCharacters:newChars range:NSMakeRange(0, firstEscapedCharIndex)];
    for(i = firstEscapedCharIndex; i <= lastEscapedCharIndex; i += 1) {
      unichar aChar = [self characterAtIndex:i];
      
      if (aChar > 255) {
        newChars[i + offset] = '\\';
        newChars[i + offset + 1] = 'u';
        newChars[i + offset + 2] = HEX_NIBBLE((aChar >> 12) & 0x0F);
        newChars[i + offset + 3] = HEX_NIBBLE((aChar >> 8)  & 0x0F);
        newChars[i + offset + 4] = HEX_NIBBLE((aChar >> 4)  & 0x0F);
        newChars[i + offset + 5] = HEX_NIBBLE( aChar        & 0x0F);
        offset += 5;
      }
      else if (aChar > 127) {
        newChars[i + offset] = '\\';
        newChars[i + offset + 1] = 'x';
        newChars[i + offset + 2] = HEX_NIBBLE((aChar >> 4)  & 0x0F);
        newChars[i + offset + 3] = HEX_NIBBLE( aChar        & 0x0F);
        offset += 3;
      }
      else if (aChar == '\b') {
        newChars[i + offset] = '\\';
        newChars[i + offset + 1] = 'b';
        offset += 1;
      }
      else if (aChar == '\f') {
        newChars[i + offset] = '\\';
        newChars[i + offset + 1] = 'f';
        offset += 1;
      }
      else if (aChar == '\n') {
        newChars[i + offset] = '\\';
        newChars[i + offset + 1] = 'n';
        offset += 1;
      }
      else if (aChar == '\r') {
        newChars[i + offset] = '\\';
        newChars[i + offset + 1] = 'r';
        offset += 1;
      }
      else if (aChar == '\t') {
        newChars[i + offset] = '\\';
        newChars[i + offset + 1] = 't';
        offset += 1;
      }
      else if (aChar == '\'') {
        newChars[i + offset] = '\\';
        newChars[i + offset + 1] = '\'';
        offset += 1;
      }
      else if (aChar == '"') {
        newChars[i + offset] = '\\';
        newChars[i + offset + 1] = '"';
        offset += 1;
      }
      else if (aChar == '\\') {
        newChars[i + offset] = '\\';
        newChars[i + offset + 1] = '\\';
        offset += 1;
      }
      else
        newChars[i + offset] = aChar;
    }
    if (lastEscapedCharIndex < length)
      [self getCharacters:(newChars + offset + lastEscapedCharIndex + 1) 
              range:NSMakeRange(lastEscapedCharIndex + 1, 
                      length - lastEscapedCharIndex - 1)];
    javascriptEscapedString = [NSString stringWithCharacters:newChars 
                                          length:newLength];
  }
  
  return javascriptEscapedString;
}

@end /* NSString(JavascriptEscaping) */
