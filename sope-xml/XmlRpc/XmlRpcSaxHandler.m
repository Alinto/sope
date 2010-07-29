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

#include "XmlRpcSaxHandler.h"
#include "XmlRpcMethodCall.h"
#include "XmlRpcMethodResponse.h"
#include "NSObject+XmlRpc.h"
#include "XmlRpcValue.h"
#include "common.h"

@implementation XmlRpcSaxHandler
/*"
  The SAX handler used to decode XML-RPC responses and requests. If the
  parsing finishes successfully, either -methodCall or -methodResponse will
  return an properly initialized object representing the XML-RPC response.
  
  The SAX handler is used by the XmlRpcDecoder class internally, in most
  cases you shouldn't need to access it directly.
"*/

static Class ArrayClass      = Nil;
static Class DictionaryClass = Nil;
static BOOL  doDebug         = NO;

+ (void)initialize {
  if (ArrayClass      == Nil) ArrayClass      = [NSMutableArray      class];
  if (DictionaryClass == Nil) DictionaryClass = [NSMutableDictionary class];
}

- (void)reset {
  if (doDebug) NSLog(@"%s: begin ...", __PRETTY_FUNCTION__);
  [self->response   release]; self->response   = nil;
  [self->call       release]; self->call       = nil;
  [self->methodName release]; self->methodName = nil;
  [self->params     release]; self->params     = nil;
  
  // for recursive structures (struct, array)
  [self->valueStack removeAllObjects];

  [self->className release]; self->className = nil;
  
  [self->memberNameStack  removeAllObjects];
  [self->memberValueStack removeAllObjects];
  [self->timeZone release]; self->timeZone = nil;
  [self->dateTime release]; self->dateTime = nil;
  
  [self->characters setString:@""];
  
  self->valueNestingLevel = 0;
  self->nextCharactersProcessor = NULL;
  self->invalidCall = NO;
  [self->tagStack removeAllObjects];
}
- (void)dealloc {
  [self reset];
  
  [self->characters release];
  [self->tagStack   release];
  [self->valueStack release];
  
  [self->memberNameStack  release];
  [self->memberValueStack release];
  
  [super dealloc];
}

/* accessors */

- (XmlRpcMethodCall *)methodCall {
  return self->call;
}

- (XmlRpcMethodResponse *)methodResponse {
  return self->response;
}

- (id)result {
  return [self->params lastObject]; // => NSException || XmlRpcValue
}

/* *** */

- (void)_addValueToParas:(id)_value {
  id topValue = [(XmlRpcValue *)[self->valueStack lastObject] value];

  if ([topValue isKindOfClass:ArrayClass])
    [topValue addObject:_value];
  else if ([topValue isKindOfClass:DictionaryClass])
    [self->memberValueStack addObject:_value];
  else
    [self->params addObject:_value];
}

/* document */

- (void)startDocument {
  if (doDebug) NSLog(@"%s: begin ...", __PRETTY_FUNCTION__);
  [self reset];
  
  if (self->tagStack == nil)
    self->tagStack = [[NSMutableArray alloc] initWithCapacity:8];
  if (self->valueStack == nil)
    self->valueStack = [[NSMutableArray alloc] initWithCapacity:8];
  if (self->characters == nil)
    self->characters = [[NSMutableString alloc] initWithCapacity:128];
  
  if (doDebug) NSLog(@"%s: done ...", __PRETTY_FUNCTION__);
}
- (void)endDocument {
  if (doDebug) NSLog(@"%s: begin ...", __PRETTY_FUNCTION__);
  
  if ([self->tagStack count] > 0) {
    self->invalidCall = YES;
    NSLog(@"Warning(%s): tagStack is not empty (%@)",
          __PRETTY_FUNCTION__,
          self->tagStack);
  }

  if (self->call != nil && self->response != nil) {
    self->invalidCall = YES;
    NSLog(@"Warning(%s): got methodCall *AND* methodResponse!!! (%@<->%@)",
          __PRETTY_FUNCTION__,
          self->call,
          self->response);
  }

  if (self->invalidCall) {
    if (doDebug) NSLog(@"%s:   marked as invalid call!", __PRETTY_FUNCTION__);
    [self->call     release]; self->call     = nil;
    [self->response release]; self->response = nil;
  }
  if (doDebug) NSLog(@"%s: done ...", __PRETTY_FUNCTION__);
}

/* elements */

- (void)start_name:(id<SaxAttributes>)_attrs {
  self->nextCharactersProcessor = @selector(_name:length:);
}
- (void)end_name {
  self->nextCharactersProcessor = NULL;
}
- (void)_name:(unichar *)_chars length:(int)_len {
  NSString *name;
  name = [NSString stringWithCharacters:_chars length:_len];
  [self->memberNameStack addObject:name];
}

- (void)start_params:(id<SaxAttributes>)_attrs {
  if (self->params) {
    self->invalidCall = YES;
    return;
  }
  self->params = [[NSMutableArray alloc] initWithCapacity:8];
}
- (void)end_params {
  if (self->params == nil)
    self->invalidCall =YES;
}

- (void)start_value:(id<SaxAttributes>)_attrs {
  self->valueNestingLevel++;
  self->nextCharactersProcessor = @selector(_baseValue:length:);
}
- (void)end_value {
  self->valueNestingLevel--;
}

- (void)_dateValue:(unichar *)_chars length:(int)_len {
  if (self->dateTime)
    return;
  
  self->dateTime = [[NSObject objectWithXmlRpcType:@"dateTime.iso8601"
                              characters:_chars length:_len]
                              retain];
}

- (void)_baseValue:(unichar *)_chars length:(int)_len {
  id value;

  if (self->valueNestingLevel == 0) {
    NSLog(@"%s: invalidCall......... self->valueNestingLevel = 0",
          __PRETTY_FUNCTION__);
    return;
  }
  
  value = [NSObject objectWithXmlRpcType:[self->tagStack lastObject]
                    characters:_chars length:_len];
  
  if (value == nil)
    value = [NSNull null];

  value = [[XmlRpcValue alloc] initWithValue:value className:self->className];
    
  if (self->params == nil) {
    NSLog(@"%s: invalidCall......... self->params = nil",
          __PRETTY_FUNCTION__);
    return;
  }
  [self _addValueToParas:value];
  
  [value release];
}

- (void)start_i4:(id<SaxAttributes>)_attrs {
  self->nextCharactersProcessor = @selector(_baseValue:length:);
}
- (void)start_int:(id<SaxAttributes>)_attrs {
  self->nextCharactersProcessor = @selector(_baseValue:length:);
}
- (void)start_double:(id<SaxAttributes>)_attrs {
  self->nextCharactersProcessor = @selector(_baseValue:length:);
}
- (void)start_base64:(id<SaxAttributes>)_attrs {
  self->nextCharactersProcessor = @selector(_baseValue:length:);
}
- (void)start_boolean:(id<SaxAttributes>)_attrs {
  self->nextCharactersProcessor = @selector(_baseValue:length:);
}
- (void)start_string:(id<SaxAttributes>)_attrs {
  self->nextCharactersProcessor = @selector(_baseValue:length:);
}
- (void)start_dateTime:(id<SaxAttributes>)_attrs {
  NSString *tz;
  int      idx;
  
  [self->timeZone release]; self->timeZone = nil;
  [self->dateTime release]; self->dateTime = nil;
  
  tz = ((idx = [_attrs indexOfRawName:@"timeZone"]) != NSNotFound)
    ? (id)[_attrs valueAtIndex:idx]
    : nil;
  
  if (tz) {
    self->timeZone = [[NSTimeZone timeZoneWithAbbreviation:tz] retain];
  }
  self->nextCharactersProcessor = @selector(_dateValue:length:);
}

- (void)end_dateTime {
  if (self->dateTime) {
    NSCalendarDate *date;
    XmlRpcValue    *value;
    int            secFromGMT;
    
    if ([self->dateTime respondsToSelector:@selector(setTimeZone:)]) {
      secFromGMT = [self->timeZone secondsFromGMT];
      [self->dateTime setTimeZone:self->timeZone];
      date = [self->dateTime dateByAddingYears:0 months:0 days:0
                             hours:0 minutes:0 seconds:-secFromGMT];
    }
    else {
      NSLog(@"WARNING(%s): cannot set timezone on date: %@", 
            __PRETTY_FUNCTION__, self->dateTime);
      date = self->dateTime;
    }
    
    value = [[XmlRpcValue alloc] initWithValue:date
                                 className:@"NSCalendarDate"];
    [value autorelease];
    [self _addValueToParas:value];
  }
  
  [self->timeZone release]; self->timeZone = nil;
  [self->dateTime release]; self->dateTime = nil;
  self->nextCharactersProcessor = NULL;
}


- (void)start_array:(id<SaxAttributes>)_attrs {
  id value = [NSMutableArray arrayWithCapacity:8];

  value = [[XmlRpcValue alloc] initWithValue:value className:self->className];
  
  [self _addValueToParas:value];
  [self->valueStack addObject:value];
  
  self->nextCharactersProcessor = NULL;
  [value release];
}

- (void)end_array {
  if ([self->valueStack count] > 0)
    [self->valueStack removeLastObject];
  else {
    NSLog(@"%s: valueStack should be empty: %@",
          __PRETTY_FUNCTION__,
          self->valueStack);
  }
}

- (void)start_struct:(id<SaxAttributes>)_attrs {
  id value = [NSMutableDictionary dictionaryWithCapacity:8];

  value = [[XmlRpcValue alloc] initWithValue:value className:self->className];
  
  [self _addValueToParas:value];
  [self->valueStack addObject:value];

  self->nextCharactersProcessor = NULL;
  [value release];
}

- (void)end_struct {
  if ([self->valueStack count] > 0)
    [self->valueStack removeLastObject];
  else {
    NSLog(@"%s: valueStack should be empty: %@",
          __PRETTY_FUNCTION__,
          self->valueStack);
  }
}

- (void)start_member:(id<SaxAttributes>)_attrs {
  if (![[(XmlRpcValue *)[self->valueStack lastObject] value] 
	 isKindOfClass:DictionaryClass]) {
    self->invalidCall = YES;
  }
  else {
    if (self->memberNameStack == nil)
      self->memberNameStack = [[NSMutableArray alloc] initWithCapacity:8];
    if (self->memberValueStack == nil)
      self->memberValueStack = [[NSMutableArray alloc] initWithCapacity:8];
  }
  self->nextCharactersProcessor = NULL;
}

- (void)end_member {
  id tmp; // TODO: can't we type the var?

  tmp = [(XmlRpcValue *)[self->valueStack lastObject] value];

  if ([self->memberNameStack count] != [self->memberValueStack count]) {
    NSLog(@"Warning(%s): memberNameStack.count != memberValueStack.count"
          @" (%@ <--> %@)",
          __PRETTY_FUNCTION__,
          self->memberNameStack,
          self->memberValueStack,
          nil);
    [self->memberValueStack release]; self->memberValueStack = nil;
    [self->memberNameStack  release]; self->memberNameStack  = nil;
    self->invalidCall = YES;
  }
  else if ([self->memberNameStack count] == 0) {
    NSLog(@"Warning(%s): memberNameStack and memberValueStack are empty!",
          __PRETTY_FUNCTION__,
          nil);
    [self->memberValueStack release]; self->memberValueStack = nil;
    [self->memberNameStack  release]; self->memberNameStack  = nil;
    self->invalidCall = YES;
  }
  else if (![tmp isKindOfClass:DictionaryClass])
    self->invalidCall = YES;
  else {
    [(NSMutableDictionary *)tmp
			    setObject:[self->memberValueStack lastObject]
			    forKey:[self->memberNameStack lastObject]];
    
    [self->memberNameStack  removeLastObject];
    [self->memberValueStack removeLastObject];
  }
}

- (void)start_methodCall:(id<SaxAttributes>)_attrs {
  /* can't create call here, args unknown !!! */
  if (self->call != nil) {
    if (doDebug) 
      NSLog(@"%s: method-call already setup!", __PRETTY_FUNCTION__);
    self->invalidCall = YES;
    return;
  }
  if (doDebug) NSLog(@"%s: ...", __PRETTY_FUNCTION__);
}
- (void)end_methodCall {
  if (self->call != nil) {
    if (doDebug) 
      NSLog(@"%s: method-call already setup!", __PRETTY_FUNCTION__);
    self->invalidCall = YES;
    return;
  }
  
  self->call = [[XmlRpcMethodCall alloc] initWithMethodName:self->methodName
                                         parameters:self->params];
  
  /* reset args */
  [self->methodName release]; self->methodName = nil;
  [self->params     release]; self->params     = nil;
}

- (void)start_methodResponse:(id<SaxAttributes>)_attrs {
  if (self->response != nil) {
    if (doDebug) 
      NSLog(@"%s: method-response already setup!", __PRETTY_FUNCTION__);
    self->invalidCall = YES;
    return;
  }
}

- (void)end_methodResponse {
  if (doDebug) NSLog(@"%s: begin ...", __PRETTY_FUNCTION__);
  
  if (self->response != nil) {
    if (doDebug) 
      NSLog(@"%s:   method-response already setup!", __PRETTY_FUNCTION__);
    self->invalidCall = YES;
    return;
  }

  if ([self->params count] > 1) {
    if (doDebug) {
      NSLog(@"%s:   has more than one params (%i)!", __PRETTY_FUNCTION__, 
      [self->params count]);
    }
    self->invalidCall = YES;
  }
  
  if (self->invalidCall) {
    NSException *error;

    if (doDebug)
      NSLog(@"%s:   response marked as invalid!", __PRETTY_FUNCTION__);
    
    error = [NSException exceptionWithName:@"error while parsing response"
                         reason:@"error while parsing response"
                         userInfo:nil];
    
    [self->params release];
    self->params = [[NSMutableArray arrayWithObject:error] retain];
  }

  self->response =
    [[XmlRpcMethodResponse alloc] initWithResult:[self->params lastObject]];
  if (doDebug)
    NSLog(@"%s:   response: %@", __PRETTY_FUNCTION__, self->response);

  /* reset args */
  [self->params release]; self->params = nil;
  if (doDebug) NSLog(@"%s: done.", __PRETTY_FUNCTION__);
}

- (void)start_methodName:(id<SaxAttributes>)_attrs {
  if (self->call != nil) {
    self->invalidCall = YES;
    return;
  }
  self->nextCharactersProcessor = @selector(_methodName:length:);
}

- (void)end_methodName {
  self->nextCharactersProcessor = NULL;
}
- (void)_methodName:(unichar *)_chars length:(int)_len {
  [self->methodName release];
  self->methodName = [[NSString alloc] initWithCharacters:_chars length:_len];
}

- (void)start_fault:(id<SaxAttributes>)_attrs {
  if (self->params) {
    self->invalidCall = YES;
    return;
  }
  else
    self->params = [[NSMutableArray alloc] initWithCapacity:2];
  
  self->nextCharactersProcessor = NULL;
}
- (void)end_fault {
  if (self->params == nil)
    self->invalidCall = YES;

  self->nextCharactersProcessor = NULL;

  /* fixup result class */
  if ([self->params count] != 1) {
    NSLog(@"XML-RPC: incorrect params count (should be 1 for faults) ?: %@",
          self->params);
  }
  else {
    XmlRpcValue *fault;
    
    fault = [self->params objectAtIndex:0];
    if (![fault isException]) {
      if ([fault isDictionary]) {
        [fault setClassName:@"NSException"];
      }
      else {
        NSException *e;
        NSString *name;
        NSString *reason;
        
        NSLog(@"XML-RPC: got incorrect fault object (class=%@) ?: %@",
              [fault className], fault);
        name = [NSString stringWithFormat:@"XmlRpcFault<%@>", 
                           [fault valueForKey:@"faultCode"]];
        if (name == nil) name = @"GenericXmlRpcFault";
        reason = [fault valueForKey:@"faultString"];
        if (reason == nil) reason = name;
        
        e = [NSException exceptionWithName:name reason:reason userInfo:nil];
        [self->params replaceObjectAtIndex:0 withObject:e];
      }
    }
  }
}

/* generic dispatcher */

- (void)startElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
  attributes:(id<SaxAttributes>)_attrs
{
  NSString *tmp = nil;
  SEL      sel;
  int      idx;
  
  [self->tagStack addObject:_rawName];

  tmp = ((idx = [_attrs indexOfRawName:@"NSObjectClass"]) != NSNotFound)
    ? (id)[_attrs valueAtIndex:idx]
    : nil;
    
  [self->className autorelease];
  self->className = [tmp retain];

  if (self->invalidCall) return;

  if ([_rawName isEqualToString:@"dateTime.iso8601"])
    _rawName = @"dateTime";

  [self->characters setString:@""];

  tmp = [NSString stringWithFormat:@"start_%@:",_rawName];
  if ((sel = NSSelectorFromString(tmp))) {
    if ([self respondsToSelector:sel])
      [self performSelector:sel withObject:_attrs];
  }
}

- (void)endElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
{
  unsigned stackDepth, lastIdx;
  NSString *tmp;
  SEL sel;

  if (self->nextCharactersProcessor != NULL) {
    void (*m)(id, SEL, unichar *, int);
    unichar *chars;
    unsigned len;

    len   = [self->characters length];
    chars = malloc(sizeof(unichar)*len);
    [self->characters getCharacters:chars];
    
    if ((m = (void*)[self methodForSelector:self->nextCharactersProcessor]))
      m(self, self->nextCharactersProcessor, chars, len);
    
    free(chars);
  }
  
  self->nextCharactersProcessor = NULL;
  
  if ((stackDepth = [self->tagStack count]) == 0) {
    self->invalidCall = YES;
    return;
  }
  lastIdx = stackDepth - 1;
  if (![[self->tagStack objectAtIndex:lastIdx] isEqualToString:_rawName]) {
    self->invalidCall = YES;
    return;
  }
  [self->tagStack removeObjectAtIndex:lastIdx];
  stackDepth--;

  if (self->invalidCall) {
    return;
  }
  
  if ([_rawName isEqualToString:@"dateTime.iso8601"])
    _rawName = @"dateTime";
  
  tmp = [NSString stringWithFormat:@"end_%@", _rawName];
  if ((sel = NSSelectorFromString(tmp))) {
    if ([self respondsToSelector:sel])
      [self performSelector:sel];
  }
}

- (void)characters:(unichar *)_chars length:(int)_len {
  if (_len > 0) {
    [self->characters appendString:
         [NSString stringWithCharacters:_chars length:_len]];
  }
}

/* errors */

- (void)warning:(SaxParseException *)_exception {
  NSLog(@"XML-RPC warning: %@", _exception);
}
- (void)error:(SaxParseException *)_exception {
  NSLog(@"XML-RPC error: %@", _exception);
}

@end /* XmlRpcSaxHandler */
