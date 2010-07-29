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

#include "NSString+German.h"
#include "common.h"

@implementation NSString(German)

- (BOOL)doesContainGermanUmlauts {
  register unsigned i, len;
  
  if ((len = [self length]) == 0)
    return NO;
  
  for (i = 0; i < len; i++) {
    switch ([self characterAtIndex:i]) {
      case 252: /* &uuml; */
      case 220: /* &Uuml; */
      case 228: /* &auml; */
      case 196: /* &Auml; */
      case 246: /* &ouml; */
      case 214: /* &Ouml; */
      case 223: /* &szlig; */
        return YES;
    }
  }
  return NO;
}

- (NSString *)stringByReplacingGermanUmlautsWithTwoCharsAndSzWith:(unichar)_c {
  /*
    a^ => ae, o^ => oe, u^ => ue, A^ => Ae, O^ => Oe, O^ => Ue
    s^ => sz or ss (_sz arg)
  */
  unsigned i, len, rlen;
  unichar  *buf;
  NSString *s;
  
  if ((len = [self length]) == 0)
    return @"";
  
  buf = calloc((len * 2) + 3, sizeof(unichar));
  
  for (i = 0, rlen = 0; i < len; i++) {
    // TODO
    register unichar c;
    
    c = [self characterAtIndex:i];
    switch (c) {
      case 252: /* ue */
        buf[rlen] = 'u'; rlen++;
        buf[rlen] = 'e'; rlen++;
        break;
      case 220: /* Ue */
        buf[rlen] = 'U'; rlen++;
        buf[rlen] = 'e'; rlen++;
        break;
      case 228: /* ae */
        buf[rlen] = 'a'; rlen++;
        buf[rlen] = 'e'; rlen++;
        break;
      case 196: /* Ae */
        buf[rlen] = 'A'; rlen++;
        buf[rlen] = 'e'; rlen++;
        break;
      case 246: /* oe */
        buf[rlen] = 'o'; rlen++;
        buf[rlen] = 'e'; rlen++;
        break;
      case 214: /* Oe */
        buf[rlen] = 'O'; rlen++;
        buf[rlen] = 'e'; rlen++;
        break;
      case 223: /* ss or sz */
        // TODO
        buf[rlen] = 's'; rlen++;
        buf[rlen] = _c;  rlen++;
        break;
        
    default: /* copy char and continue */
      buf[rlen] = c;
      rlen++;
      break;
    }
  }
  
  s = (rlen > len)
    ? [[NSString alloc] initWithCharacters:buf length:rlen]
    : [self copy];
  if (buf) free(buf);
  return [s autorelease];
}
- (NSString *)stringByReplacingGermanUmlautsWithTwoChars {
  // default sz mapping is "ss" (like Hess ;-)
  return [self stringByReplacingGermanUmlautsWithTwoCharsAndSzWith:'s'];
}

- (NSString *)stringByReplacingTwoCharEncodingsOfGermanUmlauts {
  /*
    ae => a^, oe => o^, ue => u^, Ae => A^, Oe => O^, Ue => U^
    sz => s^
    ss => s^
  */
  unsigned i, len, rlen;
  NSString *s;
  unichar  *buf;
  BOOL     didReplace;
  
  if ((len = [self length]) == 0)
    return @"";
  if (len == 1)
    return [[self copy] autorelease];
  
  buf = calloc(len + 3, sizeof(unichar));
  [self getCharacters:buf]; // Note: we can reuse that buffer!
  
  for (i = 0, rlen = 0, didReplace = NO; i < len; i++) {
    register unichar c, cn;
    
    c = buf[i];

    if ((i + 1) >= len) {
      buf[rlen] = c;
      rlen++;
      break; // end, found last char (so can't be a sequence)
    }

    cn = buf[i + 1];
    
    if ((c=='a' || c=='A' || c=='u' || c=='U' || c=='o' || c=='O')&&cn=='e') {
      /* an umlaut sequence */
      switch (c) {
      case 'a': buf[rlen] = 228; break;
      case 'A': buf[rlen] = 196; break;
      case 'o': buf[rlen] = 246; break;
      case 'O': buf[rlen] = 214; break;
      case 'u': buf[rlen] = 252; break;
      case 'U': buf[rlen] = 220; break;
      }
      rlen++;
      i++; // skip sequence char
      didReplace = YES;
    }
    else if (c == 's' && (cn == 's' || cn == 'z')) {
      /* a sz sequence */
      buf[rlen] = 223;
      rlen++;
      i++; // skip sequence char
      didReplace = YES;
    }
    else {
      /* regular char, copy */
      buf[rlen] = c;
      rlen++;
    }
  }
  
  s = didReplace
    ? [[NSString alloc] initWithCharacters:buf length:rlen]
    : [self copy];
  if (buf) free(buf);
  return [s autorelease];
}

- (NSArray *)germanUmlautVariantsOfString {
  /*
    The ^ is used to signal the single character umlaut to avoid non-ASCII
    source code.
    
    Note: we can only do a limited set of transformations! Eg you can only
          mix umlauts *OR* the "ue", "oe" variants!
    
    Q: what about names which contain encoded umlauts *and* the same sequence
       as a regular part of the name! For example "Neuendoerf".
    
    string with umlauts (two variants, ss and sz):
      a^ => ae
      o^ => oe
      u^ => ue
      A^ => Ae
      O^ => Oe
      O^ => Ue
      s^ => sz & ss
    
    string with umlaut workaround (three variants due to sz/ss):
      ae => a^
      oe => o^
      ue => u^
      Ae => A^
      Oe => O^
      Ue => U^
      sz => s^ & sz // ?
      ss => s^ & ss // ?
  */
  NSString *s1, *s2;
  unsigned len;
  
  if ((len = [self length]) == 0)
    return [NSArray arrayWithObjects:@"", nil];
  
  if ([self doesContainGermanUmlauts]) {
    s1 = [self stringByReplacingGermanUmlautsWithTwoCharsAndSzWith:'s'];
    s2 = [self stringByReplacingGermanUmlautsWithTwoCharsAndSzWith:'z'];
    
    if ([s2 isEqualToString:s1] || [s2 isEqualToString:self])
      s2 = nil;
    if ([s1 isEqualToString:self])
      s1 = s2;
    
    return [NSArray arrayWithObjects:self, s1, s2, nil];
  }
  
  if (len < 2) // a sequence would have at least 2 chars
    return [NSArray arrayWithObjects:self, nil];
  
  s1 = [self stringByReplacingTwoCharEncodingsOfGermanUmlauts];
  
  if ([self isEqualToString:s1])
    /* nothing was replaced */
    return [NSArray arrayWithObjects:self, nil];
  
  return [NSArray arrayWithObjects:self, s1, nil];
}

@end /* NSString(German) */
