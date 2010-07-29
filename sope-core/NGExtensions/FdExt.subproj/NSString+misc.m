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

#include "NSString+misc.h"
#include "common.h"

@interface NSStringVariableBindingException : NSException
@end

@implementation NSStringVariableBindingException
@end

@implementation NSObject(StringBindings)

- (NSString *)valueForStringBinding:(NSString *)_key {
  if (_key == nil) return nil;
  return [[self valueForKeyPath:_key] stringValue];
}

@end /* NSObject(StringBindings) */

@implementation NSString(misc)

- (NSSet *)bindingVariables
{
  unsigned        len, pos = 0;
  unichar         *wbuf    = NULL;
  NSMutableSet    *result  = nil;
  
  result = [NSMutableSet setWithCapacity:16];
  len    = [self length];  
  wbuf   = malloc(sizeof(unichar) * (len + 4));
  [self getCharacters:wbuf];
  
  while (pos < len) {
    unsigned startPos;
    
    if (pos + 1 == len) { /* last entry */
      if (wbuf[pos] == '$') { /* found $ without end-char */
        [[[NSStringVariableBindingException alloc]
	   initWithFormat:@"did not find end of variable for string %@", self]
	   raise];
      }
      break;
    }
    if (wbuf[pos] != '$') {
      pos++;
      continue;
    }
    
    if (wbuf[pos + 1] == '$') { /* found $$ --> ignore*/
      pos += 2;
      continue;
    }

    /* process binding */
    
    startPos = pos;
    
    pos += 2; /* wbuf[pos + 1] != '$' */
    while (pos < len) {
      if (wbuf[pos] != '$')
	pos++;
      else
	break;
    }
    if (pos == len) { /* end of string was reached */
      [[[NSStringVariableBindingException alloc]
	 initWithFormat:@"did not find end of variable for string %@", self]
	 raise];
    }
    else {
      NSString *key = nil;
      
      key = [[NSString alloc]
                       initWithCharacters:(unichar *)wbuf + startPos + 1
	               length:(pos - startPos - 1)];
      [result addObject:key];
      [key release];
    }
    pos++;
  }
  if (wbuf != NULL) { free(wbuf); wbuf = NULL; }
  
  return [[result copy] autorelease];
}

- (NSString *)stringByReplacingVariablesWithBindings:(id)_bindings
  stringForUnknownBindings:(NSString *)_unknown
{
  unsigned        len, pos = 0;
  unichar         *wbuf    = NULL;
  NSMutableString *str     = nil;
  
  str = [self mutableCopy];
  len = [str length];  
  wbuf   = malloc(sizeof(unichar) * (len + 4));
  [self getCharacters:wbuf];
  
  while (pos < len) {
    if (pos + 1 == len) { /* last entry */
      if (wbuf[pos] == '$') { /* found $ without end-char */
        [[[NSStringVariableBindingException alloc]
	   initWithFormat:@"did not find end of variable for string %@", self]
	  raise];
      }
      break;
    }
    if (wbuf[pos] == '$') {
      if (wbuf[pos + 1] == '$') { /* found $$ --> $ */
        [str deleteCharactersInRange:NSMakeRange(pos, 1)];
	
	if (wbuf != NULL) { free(wbuf); wbuf = NULL; }
        len  = [str length];
	wbuf = malloc(sizeof(unichar) * (len + 4));
	[str getCharacters:wbuf];
      }
      else {
        unsigned startPos = pos;

        pos += 2; /* wbuf[pos + 1] != '$' */
        while (pos < len) {
          if (wbuf[pos] != '$')
            pos++;
          else
            break;
        }
        if (pos == len) { /* end of string was reached */
          [[[NSStringVariableBindingException alloc]
	     initWithFormat:@"did not find end of variable for string %@", 
	     self] raise];
	}
        else {
          NSString *key;
          NSString *value;

          key = [[NSString alloc]
		  initWithCharacters:(wbuf + startPos + 1)
		  length:(pos - startPos - 1)];
	  
          if ((value = [_bindings valueForStringBinding:key]) == nil) {
            if (_unknown == nil) {
              [[[NSStringVariableBindingException alloc]
                          initWithFormat:@"did not find binding for "
                                         @"name %@ in binding-dictionary %@",
                                         [key autorelease], _bindings] raise];
            }
            else
              value = _unknown;
          }
          [key release]; key = nil;
	  
          [str replaceCharactersInRange:
		 NSMakeRange(startPos, pos - startPos + 1)
               withString:value];
	  
	  if (wbuf != NULL) { free(wbuf); wbuf = NULL; }
	  len  = [str length];
	  wbuf = malloc(sizeof(unichar) * (len + 4));
	  [str getCharacters:wbuf];
	  
          pos = startPos - 1 + [value length];
        }
      }
    }
    pos++;
  }
  if (wbuf != NULL) { free(wbuf); wbuf = NULL; }
  {
    id tmp = str;
    str = [str copy];
    [tmp release]; tmp = nil;
  }
  return [str autorelease];
}

- (NSString *)stringByReplacingVariablesWithBindings:(id)_bindings {
  return [self stringByReplacingVariablesWithBindings:_bindings
               stringForUnknownBindings:nil];
}

@end /* NSString(misc) */


@implementation NSString(FilePathVersioningMethods)

/*
  "/path/file.txt;1"
*/
- (NSString *)pathVersion {
  NSRange r;

  r = [self rangeOfString:@";"];
  if (r.length > 0) {
    return ([self length] > r.location)
      ? [self substringFromIndex:(r.location + r.length)]
      : (NSString *)@"";
  }
  return nil;
}

- (NSString *)stringByDeletingPathVersion {
  NSRange r;

  r = [self rangeOfString:@";"];
  return (r.length > 0)
    ? [self substringToIndex:r.location]
    : self;
}

- (NSString *)stringByAppendingPathVersion:(NSString *)_version {
  return [[self stringByAppendingString:@";"] 
	        stringByAppendingString:_version];
}

@end /* NSString(FilePathMethodsVersioning) */

@implementation NSString(NGScanning)

- (NSRange)rangeOfString:(NSString *)_s 
  skipQuotes:(NSString *)_quotes
  escapedByChar:(unichar)_escape
{
  // TODO: speed ...
  // TODO: check correctness with invalid input !
  static NSRange notFound = { 0, 0 };
  NSCharacterSet *quotes;
  unsigned i, len, slen;
  unichar sc;
  
  if ((slen = [_s length]) == 0)
    return notFound;
  if ((len = [self length]) < slen) /* to short */
    return notFound;
  
  if ([_quotes length] == 0)
    _quotes = @"'\"";
  quotes = [NSCharacterSet characterSetWithCharactersInString:_quotes];
  
  sc = [_s characterAtIndex:0];
  
  for (i = 0; i < len; i++) {
    unichar c;
    
    c = [self characterAtIndex:i];
    
    if (c == sc) {
      /* start search section */
      if (slen == 1)
        return NSMakeRange(i, 1);
      
      if ([[self substringFromIndex:i] hasPrefix:_s])
        return NSMakeRange(i, slen);
    }
    else if ([quotes characterIsMember:c]) {
      /* skip quotes */
      i++;
      c = [self characterAtIndex:i];
      for (; i < len && ![quotes characterIsMember:c]; i++) {
	c = [self characterAtIndex:i];
        if (c == _escape) {
          i++; /* skip next char (eg \') */
          continue;
        }
      }
    }
  }
  
  return notFound;
}

- (NSRange)rangeOfString:(NSString *)_s skipQuotes:(NSString *)_quotes {
  return [self rangeOfString:_s skipQuotes:_quotes escapedByChar:'\\'];
}

@end /* NSString(NGScanning) */


@implementation NSString(MailQuoting)

- (NSString *)stringByApplyingMailQuoting {
  NSString *s;
  unsigned i, len, nl;
  unichar  *sourceBuf, *targetBuf;
  
  if ((len = [self length]) == 0)
    return @"";
  
  sourceBuf = malloc((len + 4) * sizeof(unichar));
  [self getCharacters:sourceBuf];
  
  for (nl = 0, i = 0; i < len; i++) {
    if (sourceBuf[i] == '\n') 
      nl++;
  }
  
  if (nl == 0) {
    if (sourceBuf) free(sourceBuf);
    return [@"> " stringByAppendingString:self];
  }
  
  targetBuf = malloc((len + 8 + (nl * 3)) * sizeof(unichar));
  targetBuf[0] = '>';
  targetBuf[1] = ' ';
  nl = 2;
  
  for (i = 0; i < len; i++) {
    targetBuf[nl] = sourceBuf[i];
    nl++;
    
    if (sourceBuf[i] == '\n' && (i + 1 != len)) {
      targetBuf[nl] = '>'; nl++;
      targetBuf[nl] = ' '; nl++;
    }
  }
  
  s = [[NSString alloc] initWithCharacters:targetBuf length:nl];
  if (targetBuf) free(targetBuf);
  if (sourceBuf) free(sourceBuf);
  return [s autorelease];
}

@end /* NSString(MailQuoting) */

// linking

void __link_NSString_misc(void) {
  __link_NSString_misc();
}
