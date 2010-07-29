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

#include "NGMailAddressParser.h"
#include "NGMailAddress.h"
#include "NGMailAddressList.h"
#include "common.h"
#include <string.h>

@interface NGMailAddressParser(PrivateMethods)
- (id)parseQuotedString:(BOOL)_guestMode;
- (id)parseWord:(BOOL)_guestMode;
- (id)parsePhrase:(BOOL)_guestMode;
- (id)parseLocalPart:(BOOL)_guestMode;
- (id)parseDomain:(BOOL)_guestMode;
- (id)parseAddrSpec:(BOOL)_guestMode;
- (id)parseRouteAddr:(BOOL)_guessMode;
- (id)parseGroup:(BOOL)_guessMode;
- (id)parseMailBox:(BOOL)_guessMode;
- (id)parseAddress:(BOOL)_guessMode;
@end

@implementation NGMailAddressParser

static Class    StrClass = Nil;
static NSNumber *yesNum  = nil;

+ (int)version {
  return 2;
}

+ (void)initialize {
  if (yesNum == nil) yesNum = [[NSNumber numberWithBool:YES] retain];
  StrClass = [NSString class];
}

static inline NSString *mkStrObj(const unichar *s, unsigned int l) {
  // TODO: unicode
  return [(NSString *)[StrClass alloc] initWithCharacters:s length:l];
}

static inline id parseWhiteSpaces(NGMailAddressParser *self, BOOL _guessMode) {
  id   returnValue = nil;
  char text[self->maxLength];
  int  length      = 0;
  
  while ((self->data[self->dataPos] == ' ')  ||
         (self->data[self->dataPos] == '\n')) {
    text[length++] = ' ';    
    self->dataPos++;
  }
  if (length) {
    if (_guessMode)
      returnValue = yesNum;
    else {
      returnValue =
        [[(NSString *)[StrClass alloc] initWithCString:text length:length] 
          autorelease];
    }
  }
  return returnValue;
}

static void dumpBadString(unichar *text, int length) {
  char *bytes;
  NSMutableString *logString;
  int count, max;

  max = length * sizeof (unichar);
  logString = [NSMutableString stringWithCapacity: max];
  [logString appendString: @"dumping buggy atom string: "];
  bytes = (char *) text;
  for (count = 0; count < max; count++) {
    [logString appendFormat: @"0x%X", bytes[count]];
    if (count < (max - 1))
      [logString appendString: @", "];
  }

  NSLog (@"%@", logString);
}

static inline id parseAtom(NGMailAddressParser *self, BOOL _guessMode) {
  int  keepPos     = self->dataPos; // keep reference for backtracking
  id   returnValue = nil;
  BOOL isAtom      = YES;
  unichar text[self->maxLength + 2];  // token text
  int  length      = 0;  // token text length
  BOOL done        = NO;

  do {
    if (self->dataPos == self->maxLength) { // end of text is reached
      isAtom = (length > 0);
      done   = YES;
    }
    else {
      register unichar c = self->data[self->dataPos];
      
      switch (c) {
        case '(' :  case ')': case '<': case '>':
        case '@' :  case ',': case ';': case ':':
        case '\\':  case '"': case '.': case '[':
        case ']' :  case ' ': case 127:
          isAtom = (length > 0);
          done   = YES;
          break;

        default:
          if (c < 32) {
            isAtom = (length > 0);
            done   = YES;
          }
          else {
            text[length] = c;  // store char in text
            length++;          // increase text size
            (self->dataPos)++; // go ahead
          }
      }
    }
  }
  while (!done);
  
  if (isAtom) {
    if (_guessMode) {
      NSCAssert(length > 0, @"no atom with length=0");
      returnValue =  yesNum;
    }
    else {
      NSCAssert(length > 0, @"no atom with length=0");
      returnValue = [mkStrObj(text, length) autorelease];
      if (!returnValue) {
        dumpBadString(text, length);
      }
      NSCAssert([returnValue isKindOfClass:StrClass], @"got no string ..");
    }
  }
  else {
    self->dataPos = keepPos;
    returnValue = nil;
  }
  return returnValue;
}

static inline id parseQuotedPair(NGMailAddressParser *self, BOOL _guessMode) {
  id   returnValue  = nil;

  if ((self->maxLength - (self->dataPos)) < 3) {
    returnValue =  nil;
  }
  else {
    if (self->data[self->dataPos] == '\\') {
      self->dataPos = self->dataPos + 2;      
      if (_guessMode)
        returnValue = yesNum;
      else {
        returnValue =
          [mkStrObj(&(self->data[self->dataPos - 1]), 1) autorelease];
      }
    }
  }
  return returnValue;
}

static inline id parseQText(NGMailAddressParser *self, BOOL _guessMode) {
  int  keepPos     = self->dataPos; // keep reference for backtracking
  id   returnValue = nil;
  BOOL isQText    = YES;
  unichar text[self->maxLength + 4];  // token text
  int  length      = 0;  // token text length
  BOOL done        = YES;

  do {
    if (self->dataPos == self->maxLength) { // end of text is reached
      isQText = (length > 0);
      done    = YES;
    }
    else {
      register unichar c = self->data[self->dataPos];
      
      switch (c) {
        case '"' :  
        case '\\':
        case 13  :
          isQText = (length > 0);
          done    = YES;
          break;

        default: {
            text[length] = c;  // store char in text
            length++;          // increase text size
            (self->dataPos)++; // go ahead
          }
      }
    }
  }
  while (!done);

  if (isQText) {
    if (_guessMode) {
      NSCAssert(length > 0, @"no qtext with length=0");
      returnValue = yesNum;
    }
    else {
      NSCAssert(length > 0, @"no qtext with length=0");
      returnValue = [mkStrObj(text, length) autorelease];
      NSCAssert([returnValue isKindOfClass:StrClass],
               @"got no string ..");
    }
  }
  else {
    self->dataPos = keepPos;
    returnValue = nil;
  }
  return returnValue;
}

static inline id parseDText(NGMailAddressParser *self, BOOL _guessMode) {
  int  keepPos     = self->dataPos; // keep reference for backtracking
  id   returnValue = nil;
  BOOL isDText    = YES;
  unichar text[self->maxLength];  // token text
  int  length      = 0;  // token text length
  BOOL done        = YES;

  do {
    if (self->dataPos == self->maxLength) { // end of text is reached
      isDText = (length > 0);
      done    = YES;
    }
    else {
      register unichar c = self->data[self->dataPos];
      
      switch (c) {
        case '[':  case ']':
        case '\\': case 13:
          isDText = (length > 0);
          done    = YES;
          break;

        default: {
            text[length] = c;  // store char in text
            length++;          // increase text size
            (self->dataPos)++; // go ahead
          }
      }
    }
  }
  while (!done);

  if (isDText) {
    if (_guessMode) {
      NSCAssert(length > 0, @"no dtext with length=0");
      returnValue =  yesNum;
    }
    else {
      NSCAssert(length > 0, @"no dtext with length=0");
      returnValue = [mkStrObj(text, length) autorelease];
      NSCAssert([returnValue isKindOfClass:StrClass],
               @"got no string ..");
    }
  }
  else {
    self->dataPos = keepPos;
    returnValue = nil;
  }
  return returnValue;
}

static inline id parseDomainLiteral(NGMailAddressParser *self, BOOL _guessMode) {
  int             keepPos          = self->dataPos;
  id              returnValue      = nil;
  BOOL            returnOK         = NO;

  if (_guessMode) {
    if (self->data[self->dataPos] != '[')
      return nil;

    (self->dataPos)++; // skip starting '"'

    // parses: "suafdjksfd \"sdafsadf"
    while (self->data[self->dataPos] != ']') {
      if (self->data[self->dataPos] == '\\') {// skip quoted chars 
        (self->dataPos)++;
      }
      (self->dataPos)++;
      if (self->dataPos >= self->maxLength) {
        return nil;
      }
    }
    (self->dataPos)++; // skip closing '"'
    returnValue = yesNum;
  }
  else {
    if (self->data[self->dataPos++] == '[') {
      NSMutableString *ms;
      id result = nil;
      
      ms = [NSMutableString stringWithCapacity:10];
      do {
        if ((result = parseQuotedPair(self, NO)))
          [ms appendString:result];
        else {
          if ((result = parseDText(self, NO))) 
            [ms appendString:result];        
        }
      }
      while (result);
      returnValue = ms;
      
      if (self->data[self->dataPos++] == ']')
        returnOK = YES;
    }
    if (!returnOK) {
      if (returnValue)
        returnValue = nil;
      
      self->dataPos = keepPos;
    }
  }
  return returnValue;
}

/* constructors */

+ (id)mailAddressParserWithData:(NSData *)_data {
  NSString *uniString;

  uniString = [NSString stringWithCharacters:(unichar *)[_data bytes]
			length:([_data length] / sizeof(unichar))];

  return [(NGMailAddressParser *)self mailAddressParserWithString:uniString];
}

+ (id)mailAddressParserWithCString:(char *)_cString {
  NSString *nsCString;

  nsCString = [NSString stringWithCString:_cString];

  return [(NGMailAddressParser *)self mailAddressParserWithString:nsCString];
}

+ (id)mailAddressParserWithString:(NSString *)_string {
  return [[(NGMailAddressParser *)[self alloc] initWithString:_string] 
	   autorelease];
}

- (id)initWithString:(NSString *)_str {
  if ((self = [super init])) {
    // TODO: remember some string encoding?
    self->maxLength = [_str length];
    self->data      = malloc(self->maxLength*sizeof(unichar));
    [_str getCharacters:self->data];
    self->dataPos   = 0;
    self->errorPos  = -1;
  }
  return self;
}

- (id)init {
  return [self initWithString:nil];
}

- (void)dealloc {
  if (self->data != NULL) {
    free(self->data);
  }
  self->data      = NULL;
  self->maxLength = 0;
  self->dataPos   = 0;
  [super dealloc];
}

/* parsing */

- (id)_parseQuotedStringInGuessMode {
  int keepPos;
  
  if (self->data[self->dataPos] != '"')
    return nil;

  keepPos = self->dataPos;
  (self->dataPos)++; // skip starting '"'

  // parses: "suafdjksfd \"sdafsadf"
  while (self->data[self->dataPos] != '"') {
    if (self->data[self->dataPos] == '\\') /* skip quoted chars  */
      (self->dataPos)++;

    (self->dataPos)++;
    if (self->dataPos >= self->maxLength) {
      self->dataPos = keepPos;
      return nil;
    }
  }
  (self->dataPos)++; // skip closing '"'
  return yesNum;
}

- (id)parseQuotedString:(BOOL)_guessMode {
  int  keepPos     = self->dataPos;
  id   returnValue = nil;
  BOOL returnOK    = NO;

  if (_guessMode)
    return [self _parseQuotedStringInGuessMode];

  if (data[dataPos++] == '"') {
    NSMutableString *ms;
    id result = nil;
    
    ms = [NSMutableString stringWithCapacity:10];
    do {
      if ((result = parseQuotedPair(self, NO)))
        [ms appendString:result];
      else {
        if ((result = parseQText(self, NO))) 
          [ms appendString:result];        
      }
    }
    while (result);
    returnValue = ms;
    
    if (data[dataPos++] == '"')
      returnOK = YES;
  }
  if (!returnOK) {
    returnValue = nil;
    dataPos = keepPos;
  }
  return returnValue;  
}

- (id)parseWord:(BOOL)_guessMode {
  id returnValue;
  
  if ((returnValue = [self parseQuotedString:_guessMode]) == nil)
    returnValue = parseAtom(self, _guessMode);
  
  return returnValue;
}

- (id)_parsePhraseInGuessMode {
  BOOL isPhrase    = NO;
  id   returnValue = nil;
  id   result;
  
  do {
    if ((result = parseWhiteSpaces(self, YES))) {
      isPhrase = YES;
      continue;
    }
    
    if ((result = [self parseWord:YES])) {
      isPhrase = YES;
      [(NSMutableString *)returnValue appendString:result];
      result = parseWhiteSpaces(self, YES);
    }
  }
  while (result);
  
  return !isPhrase ? (NSNumber *)nil : yesNum;
}

- (id)parsePhrase:(BOOL)_guessMode {
  BOOL isPhrase    = NO;
  id   returnValue = nil;
  id   result      = nil;      
  NSString *tmp;

  if (_guessMode)
    return [self _parsePhraseInGuessMode];

  returnValue = [NSMutableString stringWithCapacity:10];
  tmp         = nil;

  do {
    if ((result = parseWhiteSpaces(self, _guessMode))) {
        tmp = result;
        ;
        //        isPhrase = YES;
        //        [returnValue appendString:result];
    }
    else if ((result = [self parseWord:_guessMode])) {
        isPhrase = YES;

        if (tmp)
          [(NSMutableString *)returnValue appendString:tmp];

        tmp = nil;
          
        [(NSMutableString *)returnValue appendString:result];
        if (self->dataPos < self->maxLength) {
          if (self->data[self->dataPos] == '.') {
            [(NSMutableString *)returnValue appendString:@"."];
            self->dataPos++;
          }
        }
    }
  } 
  while (result);
  
  if (!isPhrase || ([returnValue length] == 0))
      returnValue = nil;
  
  return returnValue;
}

- (id)_parseLocalPartInGuessMode {
  id result;
  
  if (![self parseWord:YES])
    return nil;

  do {
    result = nil;
    if (self->data[self->dataPos] == '.') {
      self->dataPos++;
      result = [self parseWord:YES];
    }
  }
  while (result);
  
  return yesNum;
}

- (id)parseLocalPart:(BOOL)_guessMode {
  NSMutableString *ms;
  id       returnValue = nil;
  NSString *result = nil;
  
  if (_guessMode)
    return [self _parseLocalPartInGuessMode];
  
  if ((returnValue = [self parseWord:NO]) == nil)
    return nil;
  
  ms = [[returnValue mutableCopy] autorelease];
      
  do {
    if (self->data[self->dataPos] == '.') {
      self->dataPos++;
      result = [self parseWord:NO];
      
      if (result) {
	NSAssert([result isKindOfClass:StrClass],
		 @"parseWord should return string");
            
	[ms appendString:@"."];
	[ms appendString:result];
      }
    }
    else
      result = nil;
  } 
  while (result != nil);
  
  return ms;
}

- (id)_parseDomainInGuessMode {
  id returnValue = nil;
  id result      = nil;

    returnValue = parseAtom(self, YES);
    if (!result)
      returnValue = parseDomainLiteral(self, YES);
    if (returnValue) {
      do {
        result = nil;
        if (self->data[self->dataPos] == '.') {
          self->dataPos++;
          result = parseAtom(self,YES);
          if (!result)
            result = parseDomainLiteral(self, YES);
        }
      } while (result);
    }
    return returnValue;
}

- (id)parseDomain:(BOOL)_guessMode {
  NSMutableString *ms;
  id result;

  if (_guessMode)
    return [self _parseDomainInGuessMode];

  if ((result = parseAtom(self, NO)) == nil)
    result = parseDomainLiteral(self, NO);
  
  if (result == nil)
    return nil;

  ms = [[result mutableCopyWithZone:[self zone]] autorelease];
  do {
    if (self->data[self->dataPos] == '.') {
      self->dataPos++;
          
      result = parseAtom(self,NO);
      if (result == nil)
	result = parseDomainLiteral(self, NO);
          
      if (result) {
	[ms appendString:@"."];
	[ms appendString:result];
      }
    }
    else
      result = nil;
  }
  while (result);
  return ms;
}

- (id)parseAddrSpec:(BOOL)_guessMode {
  NSMutableString *returnValue  = nil;
  id   result;
  int  keepPos      = self->dataPos;
  BOOL returnStatus = NO;
  
  if (_guessMode) {
    id ret;
    
    ret = nil;
    if ([self parseLocalPart:YES]) {
      if (self->data[self->dataPos] == '@') {
        dataPos++;
        if ([self parseDomain:YES]) {
          ret = yesNum;
        }
      }
    }
    return ret;
  }
  
  if ((result = [self parseLocalPart:NO]) != nil) {
    returnValue = [[result mutableCopy] autorelease];
    result = nil;
    
    if (self->data[self->dataPos] == '@') {
      self->dataPos++;
	
      if ((result = [self parseDomain:NO])) {
        [returnValue appendString:@"@"];
        [returnValue appendString:result];
        returnStatus = YES;
      }
    }
  }
  if (!returnStatus) {
      returnValue = nil;
      dataPos = keepPos;
  }
  return returnValue;
}

- (id)_parseRouteInGuessMode {
  id   result  = nil;
  int  keepPos = self->dataPos;
  BOOL status  = YES;
    
  if (self->data[self->dataPos] == '@') {
    status = NO;
    if ((result = [self parseDomain:YES]))
      status = YES;
  }
  if (status) {
    parseWhiteSpaces(self,YES);
    status = (self->data[self->dataPos] == ':') ? YES : NO;
  }
  if (status)
    return yesNum;

  self->dataPos = keepPos;
  return nil;
}
- (id)parseRoute:(BOOL)_guessMode {
  NSMutableString *returnValue;
  id   result      = nil;
  int  keepPos;
  BOOL status = YES;
  
  if (_guessMode)
    return [self _parseRouteInGuessMode];

  keepPos     = self->dataPos;
  returnValue = [NSMutableString stringWithCapacity:10];
  if (self->data[self->dataPos] == '@') {
      status = NO;
      self->dataPos++;
      if ((result = [self parseDomain:NO])) {
        status = YES;
        [returnValue appendString:result];
      }
  }
  if (status) {
      parseWhiteSpaces(self,NO);
      if (self->data[self->dataPos] == ':') {
        status = YES;
        self->dataPos++;        
      }
      else {
        status = NO;
      }
  }
  if (!status) {
    returnValue = nil;
    self->dataPos = keepPos;
  }
  return returnValue;
}

- (id)_parseRouteAddrInGuessMode {
  int  keepPos      = self->dataPos;
  id   returnValue  = nil;
  id   result       = nil;
  BOOL returnStatus = NO;

    if (self->data[self->dataPos] == '<') {
      dataPos++;
      result = [self parseRoute:YES];
      parseWhiteSpaces(self, YES);      
      if ((result = [self parseAddrSpec:YES])) {
        parseWhiteSpaces(self, YES);
        if (self->data[self->dataPos] == '>') {
          self->dataPos++;
          returnStatus = YES;
        }
      }
      else if ((result = [self parseWord:YES])) {
        parseWhiteSpaces(self, YES);
        if (self->data[self->dataPos] == '>') {
          self->dataPos++;
          returnStatus = YES;
        }
      }
    }
    if (returnStatus) {
      returnValue = yesNum;
    }
    else {
      returnValue = nil;
      dataPos     = keepPos;      
    }
    return returnValue;
}

- (id)parseRouteAddr:(BOOL)_guessMode {
  NSMutableDictionary *returnValue  = nil;
  int  keepPos;
  id   result       = nil;
  BOOL returnStatus = NO;
  
  if (_guessMode) 
    return [self _parseRouteAddrInGuessMode];

  keepPos     = self->dataPos;
  returnValue = [NSMutableDictionary dictionaryWithCapacity:2];
  if (self->data[self->dataPos] == '<') {
    dataPos++;
    if ((result = [self parseRoute:NO]))
      [returnValue setObject:result forKey:@"route"];

    parseWhiteSpaces(self, NO);
    if ((result = [self parseAddrSpec:NO])) {
        parseWhiteSpaces(self, NO);
        if (self->data[self->dataPos] == '>') {
          self->dataPos++;
          [returnValue setObject:result forKey:@"address"];
          returnStatus = YES;
        }
    }
    else if ((result = [self parseWord:NO])) {
        parseWhiteSpaces(self, NO);
        if (self->data[self->dataPos] == '>') {
          self->dataPos++;
          [returnValue setObject:result forKey:@"address"];
          returnStatus = YES;
        }
    }
  }
  if (!returnStatus) {
    returnValue = nil;
    if (!(self->errorPos == -1))
      self->errorPos = self->dataPos;
    self->dataPos    = keepPos;
  }
  return returnValue;
}

- (id)parseMailBox:(BOOL)_guessMode {
  id   returnValue  = nil;
  id   result       = nil;
  int  keepPos      = self->dataPos;
  BOOL returnStatus = NO;

  if (_guessMode) {
    if ((result = [self parseAddrSpec:YES])) {
      returnStatus = YES;
    }
    else {
      if ((result = [self parsePhrase:YES])) {
        parseWhiteSpaces(self, YES);
        if ((result = [self parseRouteAddr:YES])) {
          returnStatus = YES;
        }
      }
    }
    if (!returnStatus) {
      self->dataPos = keepPos;
      returnValue  = nil;
    }
    else {
      returnValue = yesNum;
    }
  }
  else {
    if ((result = [self parseAddrSpec:NO])) {
      returnValue = [NGMailAddress mailAddressWithAddress:result
                                   displayName:nil
                                   route:nil];
      returnStatus = YES;
    }
    else if ((result = [self parseRouteAddr:NO])) {
      returnValue =
        [NGMailAddress mailAddressWithAddress:
                         [(NSDictionary *)result objectForKey:@"address"]
                       displayName:nil
                       route:nil];
      returnStatus = YES;
    }
    else {
      returnValue = [[[NGMailAddress alloc] init] autorelease];
      
      if ((result = [self parsePhrase:NO])) {
        [returnValue setDisplayName:result];
        parseWhiteSpaces(self, NO);        
        if ((result = [self parseRouteAddr:NO])) {
          [returnValue setAddress:
                         [(NSDictionary *)result objectForKey:@"address"]];
          [returnValue setRoute:
                         [(NSDictionary *)result objectForKey:@"route"]];
          returnStatus = YES;
        }
      }
    }
    if (!returnStatus) { /* try to read until eof or next ',' */
      self->dataPos = keepPos;
      
      if ((result = [self parseRouteAddr:NO])) {
        returnValue = [[[NGMailAddress alloc] init] autorelease];
        [returnValue setAddress:
                       [(NSDictionary *)result objectForKey:@"address"]];
        returnStatus = YES;
      }
    }
    if (!returnStatus) { /* try to read until eof or next ',' */
      self->dataPos = keepPos;
      
      if ((result = [self parseWord:NO])) {
        returnValue = [[[NGMailAddress alloc] init] autorelease];
        [returnValue setAddress:result];
        returnStatus = YES;
      }
    }
    if (!returnStatus) {
      if (!(self->errorPos == -1))
        self->errorPos = self->dataPos;

      self->dataPos = keepPos;
      returnValue  = nil;
    }
  }
  return returnValue;
}

- (id)parseGroup:(BOOL)_guessMode {
  id   returnValue  = nil;
  id   result       = nil;
  int  keepPos      = self->dataPos;
  BOOL returnStatus = NO;
  
  if (_guessMode) {
    if ((result = [self parsePhrase:YES])) {
      if (self->data[self->dataPos] == ':') { 
        self->dataPos++;
        parseWhiteSpaces(self, YES);                      
        if ((result = [self parseMailBox:YES])) {
          do {
            parseWhiteSpaces(self, YES);              
            result = nil;
            if (self->data[self->dataPos] == ',') {
              self->dataPos++;
              parseWhiteSpaces(self, YES);              
              result = [self parseMailBox:YES];
            }
          } while (result);
          parseWhiteSpaces(self, YES);                        
          if (self->data[self->dataPos] == ';') {
            self->dataPos++;
            returnStatus = YES;
          }
        }
      }
    }
    if (!returnStatus) {
      returnValue = nil;
      self->dataPos = keepPos;
    }
    else {
      returnValue = yesNum;
    }
  }
  else {
    returnValue = [[[NGMailAddressList alloc] init] autorelease];
    if ((result = [self parsePhrase:NO])) {
      [returnValue setGroupName:result];
      if (self->data[self->dataPos] == ':') {
        self->dataPos++;
        parseWhiteSpaces(self, NO);
        if ((result = [self parseMailBox:NO])) {
          [returnValue addAddress:result];
          do {
            parseWhiteSpaces(self, NO);
            result = nil;            
            if (self->data[self->dataPos] == ',') {
              self->dataPos++;
              parseWhiteSpaces(self, NO);              
              result = [self parseMailBox:NO];
              if (result) {
                [returnValue addAddress:result];
              }
            }
          } while (result);
          parseWhiteSpaces(self, NO);                        
          if (self->data[self->dataPos] == ';') {
            self->dataPos++;
            returnStatus = YES;
          }
        }
      }
    }
    if (!returnStatus) {
      returnValue = nil;
      self->dataPos = keepPos;
    }
  }
  return returnValue;
}

- (id)parseAddress:(BOOL)_guessMode {
  id  returnValue = nil;
  int keepPos     = self->dataPos;
  
  if (_guessMode) {
    returnValue = [self parseMailBox:YES];
    if (!returnValue)
      returnValue = [self parseGroup:YES];
    if (!returnValue)
      self->dataPos = keepPos;
  }
  else {
    returnValue = [self parseMailBox:NO];
    if (!returnValue)
      returnValue = [self parseGroup:NO];
    if (!returnValue)
      self->dataPos = keepPos;
  }
  return returnValue;
}

- (NSArray *)parseAddressList {
  NGMailAddress  *address = nil;
  NSMutableArray *addrs   = nil;

  addrs = [NSMutableArray arrayWithCapacity:16];
  while (self->dataPos < self->maxLength) {
    address = [self parseAddress:NO];
    if (address)
      [addrs addObject:address];
    else
      break;
    
    if (self->dataPos < self->maxLength) {
      parseWhiteSpaces(self, NO);
      if (self->dataPos < self->maxLength) {
        if (self->data[self->dataPos] == ',') {
          self->dataPos++;
          if (self->dataPos < self->maxLength)
            parseWhiteSpaces(self, NO);
        }
      }
    }
  }
  return [[addrs copy] autorelease];
}

- (id)parse { 
  dataPos  = 0;
  errorPos = -1;
  return [self parseAddress:NO];
}

- (int)errorPosition {
  return self->errorPos;
}

/* description */

- (NSString *)description {
  return [StrClass stringWithFormat:@"<%@[0x%p]>",
                     NSStringFromClass([self class]), self];
}

@end /* NGMailAddressParser */
