/* 
   NSString+MySQL4.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge@mdlink.de)

   This file is part of the MySQL4 Adaptor Library

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#if LIB_FOUNDATION_BOEHM_GC
#  include <objc/gc.h>
#endif

#include "NSString+MySQL4.h"
#include "common.h"

@implementation NSString(MySQL4MiscStrings)

- (NSString *)_mySQL4ModelMakeInstanceVarName {
  unsigned clen = 0;
  char     *s   = NULL;
  int      cnt, cnt2;
  
  if ([self length] == 0)
    return @"";

  clen = [self cStringLength];
  s = malloc(clen + 10);

  [self getCString:s maxLength:clen];
    
  for (cnt = cnt2 = 0; cnt < clen; cnt++, cnt2++) {
    if ((s[cnt] == '_') && (s[cnt + 1] != '\0')) {
      s[cnt2] = toupper(s[cnt + 1]);
      cnt++;
    }
    else if ((s[cnt] == '2') && (s[cnt + 1] != '\0')) {
      s[cnt2] = s[cnt];
      cnt++;
      cnt2++;
      s[cnt2] = toupper(s[cnt]);
    }
    else
      s[cnt2] = tolower(s[cnt]);
  }
  s[cnt2] = '\0';
  
  return [[[NSString alloc] 
	    initWithCStringNoCopy:s length:strlen(s) freeWhenDone:YES] 
	   autorelease];
}

- (NSString *)_mySQL4ModelMakeClassName {
  unsigned clen = 0;
  char     *s   = NULL;
  int      cnt, cnt2;
  
  if ([self length] == 0)
    return @"";

  clen = [self cStringLength];
  s = malloc(clen + 10);

  [self getCString:s maxLength:clen];
    
  for (cnt = cnt2 = 0; cnt < clen; cnt++, cnt2++) {
      if ((s[cnt] == '_') && (s[cnt + 1] != '\0')) {
        s[cnt2] = toupper(s[cnt + 1]);
        cnt++;
      }
      else if ((s[cnt] == '2') && (s[cnt + 1] != '\0')) {
        s[cnt2] = s[cnt];
        cnt++;
        cnt2++;
        s[cnt2] = toupper(s[cnt]);
      }
      else
        s[cnt2] = tolower(s[cnt]);
  }
  s[cnt2] = '\0';

  s[0] = toupper(s[0]);

  return [[[NSString alloc] 
                       initWithCStringNoCopy:s length:strlen(s)
                       freeWhenDone:YES]
                       autorelease];
}

- (NSString *)_mySQL4StringWithCapitalizedFirstChar {
  NSCharacterSet  *upperSet;
  NSMutableString *str;
  
  if ([self length] == 0)
    return @"";
  
  upperSet = [NSCharacterSet uppercaseLetterCharacterSet];
  if ([upperSet characterIsMember:[self characterAtIndex:0]])
    return [[self copy] autorelease];
  
  str = [NSMutableString stringWithCapacity:[self length]];
  [str appendString:[[self substringToIndex:1] uppercaseString]];
  [str appendString:[self substringFromIndex:1]];
  return [[str copy] autorelease];
}

- (NSString *)_mySQL4StripEndSpaces {
  NSCharacterSet  *spaceSet;
  NSMutableString *str;
  unichar         (*charAtIndex)(id, SEL, int);
  NSRange         range;
  
  if ([self length] == 0)
    return [[self copy] autorelease];
  
  spaceSet = [NSCharacterSet whitespaceCharacterSet];
  str      = [NSMutableString stringWithCapacity:[self length]];
  charAtIndex  = (unichar (*)(id, SEL, int))
    [self methodForSelector:@selector(characterAtIndex:)];
  range.length = 0;

  for (range.location = ([self length] - 1);
         range.location >= 0;
         range.location++, range.length++) {
      unichar c;
      
      c = charAtIndex(self, @selector(characterAtIndex:), range.location);
      if (![spaceSet characterIsMember:c])
        break;
  }
    
  if (range.length > 0) {
      [str appendString:self];
      [str deleteCharactersInRange:range];
      return [[str copy] autorelease];
  }
  return [[self copy] autorelease];
}
 
@end

void __link_NSStringMySQL4() {
  // used to force linking of object file
  __link_NSStringMySQL4();
}
