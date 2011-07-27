/* 
   NSString+PostgreSQL72.m

   Copyright (C) 1999      MDlink online service center GmbH and Helge Hess
   Copyright (C) 2000-2006 SKYRIX Software AG and Helge Hess

   Author: Helge Hess (helge.hess@opengroupware.org)

   This file is part of the PostgreSQL72 Adaptor Library

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

#include "common.h"
#import "NSString+PostgreSQL72.h"

@implementation NSString(PostgreSQL72MiscStrings)

- (NSString *)_pgModelMakeInstanceVarName {
  unsigned clen;
  unichar  *us;
  int      cnt, cnt2;
  
  if ([self length] == 0)
    return @"";
  
  // TODO: do use UTF-8 here
  clen = [self length];
  us   = malloc((clen + 10) * sizeof(unichar));
  
  [self getCharacters:us];
  us[clen] = 0;
  
  // Note: upper/lower detection is not strictly correct ... (no unicode)
  for (cnt = cnt2 = 0; cnt < clen; cnt++, cnt2++) {
    if ((us[cnt] == '_') && (us[cnt + 1] != '\0')) {
      us[cnt2] = toupper(us[cnt + 1]);
      cnt++;
    }
    else if ((us[cnt] == '2') && (us[cnt + 1] != '\0')) {
      us[cnt2] = us[cnt];
      cnt++;
      cnt2++;
      us[cnt2] = toupper(us[cnt]);
    }
    else
      us[cnt2] = tolower(us[cnt]);
  }
  us[cnt2] = '\0';
  
  return [NSString stringWithCharacters:us length:cnt2];
}

- (NSString *)_pgModelMakeClassName {
  unsigned clen = 0;
  unichar  *us;
  int      cnt, cnt2;

  if ([self length] == 0)
    return @"";

  // TODO: use UTF-8 here
  clen = [self length];
  us   = malloc((clen + 10) * sizeof(unichar));
  
  [self getCharacters:us];
  us[clen] = 0;
  
  for (cnt = cnt2 = 0; cnt < clen; cnt++, cnt2++) {
    if ((us[cnt] == '_') && (us[cnt + 1] != '\0')) {
      us[cnt2] = toupper(us[cnt + 1]);
      cnt++;
    }
    else if ((us[cnt] == '2') && (us[cnt + 1] != '\0')) {
      us[cnt2] = us[cnt];
      cnt++;
      cnt2++;
      us[cnt2] = toupper(us[cnt]);
    }
    else
      us[cnt2] = tolower(us[cnt]);
  }
  us[cnt2] = '\0';

  us[0] = toupper(us[0]);

  return [NSString stringWithCharacters:us length:cnt2];
}

static NSCharacterSet *upperSet = nil;
static NSCharacterSet *spaceSet = nil;

- (NSString *)_pgStringWithCapitalizedFirstChar {
  if (upperSet == nil) 
    upperSet = [[NSCharacterSet uppercaseLetterCharacterSet] retain];
  
  if ([self length] == 0)
    return @"";

  if ([upperSet characterIsMember:[self characterAtIndex:0]])
    return [[self copy] autorelease];
  
  {
    NSMutableString *str = [NSMutableString stringWithCapacity:[self length]];

    [str appendString:[[self substringToIndex:1] uppercaseString]];
    [str appendString:[self substringFromIndex:1]];

    return [[str copy] autorelease];
  }
}

- (NSString *)_pgStripEndSpaces {
  NSMutableString *str;
  unichar         (*charAtIndex)(id, SEL, int);
  NSRange         range;

  if ([self length] == 0)
    return @"";

  if (spaceSet == nil) 
    spaceSet = [[NSCharacterSet whitespaceCharacterSet] retain];
    
  str = [NSMutableString stringWithCapacity:[self length]];
    
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
    return AUTORELEASE([str copy]);
  }
  
  return AUTORELEASE([self copy]);
}
 
@end /* NSString(PostgreSQL72MiscStrings) */

void __link_NSStringPostgreSQL72() {
  // used to force linking of object file
  __link_NSStringPostgreSQL72();
}
