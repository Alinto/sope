/*
  Copyright (C) 2000-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess

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

#include "XmlRpcCoder.h"
#include "XmlRpcValue.h"
#include "XmlRpcSaxHandler.h"
#include <SaxObjC/SaxXMLReaderFactory.h>
#include "XmlRpcMethodCall.h"
#include "XmlRpcMethodResponse.h"
#include "common.h"

/* self->unarchivedObjects does *not* store objects with xmlrpc base type! */

@interface XmlRpcDecoder(PrivateMethodes)
- (id)_decodeObject:(XmlRpcValue *)_value;
@end

@interface NSData(NGExtensions)
- (NSData *)dataByDecodingBase64;
@end

@implementation XmlRpcDecoder

- (BOOL)profileXmlRpcCoding {
  return [[NSUserDefaults standardUserDefaults]
                          boolForKey:@"ProfileXmlRpcCoding"];
}

#if HAVE_NSXMLPARSER && 0
#warning using NSXMLParser!
static BOOL useNSXMLParser = YES;
#else
static BOOL useNSXMLParser = NO;
#endif
static id saxHandler   = nil;
static id xmlRpcParser = nil;

static Class ArrayClass      = Nil;
static Class DictionaryClass = Nil;
static Class DataClass       = Nil;
static Class NumberClass     = Nil;
static Class StringClass     = Nil;
static Class DateClass       = Nil;
static BOOL  doDebug         = NO;

+ (void)initialize {
  if (ArrayClass      == Nil) ArrayClass      = [NSArray        class];
  if (DictionaryClass == Nil) DictionaryClass = [NSDictionary   class];
  if (DataClass       == Nil) DataClass       = [NSData         class];
  if (NumberClass     == Nil) NumberClass     = [NSNumber       class];
  if (StringClass     == Nil) StringClass     = [NSString       class];
  if (DateClass       == Nil) DateClass       = [NSCalendarDate class];
}

- (id)init {
  if ((self = [super init])) {
    self->unarchivedObjects = [[NSMutableArray alloc] init];
    self->awakeObjects      = [[NSMutableSet alloc] init];
    self->valueStack        = [[NSMutableArray alloc] initWithCapacity:4];
    self->timeZone = [[NSTimeZone timeZoneWithAbbreviation:@"GMT"] retain];
  }
  return self;
}

- (NSStringEncoding)encodingForXMLEncodingString:(NSString *)_enc {
  _enc = [_enc lowercaseString];
  if ([_enc isEqualToString:@"utf-8"])
    return NSUTF8StringEncoding;
  else if ([_enc isEqualToString:@"iso-8859-1"])
    return NSISOLatin1StringEncoding;
#if !(NeXT_Foundation_LIBRARY || APPLE_Foundation_LIBRARY)
  else if ([_enc isEqualToString:@"iso-8859-9"])
    return NSISOLatin9StringEncoding;
#endif
  else if ([_enc isEqualToString:@"ascii"])
    return NSASCIIStringEncoding;
  else
    NSLog(@"%s: UNKNOWN XML ENCODING '%@'", __PRETTY_FUNCTION__, _enc);
  return 0;
}

- (id)initForReadingWithString:(NSString *)_string {
  if ((self = [self init])) {
    NSRange r;
    
    r = [_string rangeOfString:@"?>"];
    if ([_string hasPrefix:@"<?xml "] && r.length != 0) {
      NSString *xmlDecl;
      
      xmlDecl = [_string substringToIndex:r.location];

      r = [xmlDecl rangeOfString:@"encoding='"];
      if (r.length != 0) {
        xmlDecl = [_string substringFromIndex:(r.location + 10)];
        r = [xmlDecl rangeOfString:@"'"];
        xmlDecl = r.length == 0
          ? (NSString *)nil
          : [xmlDecl substringToIndex:r.location];
      }
      else {
        r = [xmlDecl rangeOfString:@"encoding=\""];
        if (r.length != 0) {
          xmlDecl = [_string substringFromIndex:(r.location + 10)];
          r = [xmlDecl rangeOfString:@"\""];
          xmlDecl = r.length == 0
            ? (NSString *)nil
            : [xmlDecl substringToIndex:r.location];
        }
        else
          xmlDecl = nil;
      }
      
      if ([xmlDecl length] > 0) {
        NSStringEncoding enc;
        
        if ((enc = [self encodingForXMLEncodingString:xmlDecl]) != 0) {
          self->data = [[_string dataUsingEncoding:enc] retain];
          if (self->data == nil) {
            NSLog(@"WARNING(%s): couldn't get data for string '%@', "
                  @"encoding %i !", __PRETTY_FUNCTION__, _string, enc);
            [self release];
            return nil;
          }
        }
      }
    }
    
    if (self->data == nil)
      self->data = [[_string dataUsingEncoding:NSUTF8StringEncoding] retain];
  }
  return self;
}
- (id)initForReadingWithData:(NSData *)_data {
  if ((self = [self init])) {
    self->data = [_data retain];
  }
  return self;
}

- (void)dealloc {
  [self->data         release];
  [self->valueStack   release];
  [self->unarchivedObjects release];
  [self->awakeObjects release];
  
  [self->timeZone release];
  [super dealloc];
}

/* accessors */

- (void)setDefaultTimeZone:(NSTimeZone *)_timeZone {
  [self->timeZone autorelease];
  self->timeZone = [_timeZone retain];
}

- (NSTimeZone *)defaultTimeZone {
  return self->timeZone;
}

/* *** */

- (void)_ensureSaxAndParser {
  if (saxHandler == nil) {
    if ((saxHandler = [[XmlRpcSaxHandler alloc] init]) == nil) {
      NSLog(@"%s: did not find sax handler ...", __PRETTY_FUNCTION__);
      return;
    }
  }

  if (useNSXMLParser)      return;
  if (xmlRpcParser != nil) return;
  
  xmlRpcParser =
    [[SaxXMLReaderFactory standardXMLReaderFactory] 
                          createXMLReaderForMimeType:@"text/xml"];
  if (xmlRpcParser == nil) {
    NSLog(@"%s: did not find an XML parser ...", __PRETTY_FUNCTION__);
    return;
  }

  [xmlRpcParser setContentHandler:saxHandler];
  [xmlRpcParser setDTDHandler:saxHandler];
  [xmlRpcParser setErrorHandler:saxHandler];
  [xmlRpcParser retain];
}

- (id)_decodeValueOfClass:(Class)_class {
  id obj;
  
  obj = [(XmlRpcValue *)[self->valueStack lastObject] value];

  if ([obj isKindOfClass:_class])
    return obj;
  
  NSLog(@"WARNING(%s): obj (%@) is not of proper class ('%@'<-->'%@'",
        __PRETTY_FUNCTION__,
        obj,
        NSStringFromClass(_class),
        NSStringFromClass([obj class]),
        nil);
  return nil;
}

- (XmlRpcMethodCall *)_decodeMethodCall:(XmlRpcMethodCall *)_baseCall {
  NSArray          *params;
  NSEnumerator     *paramEnum;
  XmlRpcMethodCall *result    = nil;
  XmlRpcValue    *param       = nil;
  NSMutableArray *decParams   = nil;  // decoded parameters

  params    = [_baseCall parameters]; // XmlRpcValues!!
  decParams = [[NSMutableArray alloc] initWithCapacity:[params count]];
  
  paramEnum = [params objectEnumerator];
  while ((param = [paramEnum nextObject])) {
    id obj;

    if ((obj = [self _decodeObject:param]) != nil)
      [decParams addObject:obj];
  }

  result = [[XmlRpcMethodCall alloc] initWithMethodName:[_baseCall methodName]
                                     parameters:decParams];

  [decParams release];

  return [result autorelease];
}

- (XmlRpcMethodResponse *)_decodeMethodResponse:(XmlRpcMethodResponse *)_resp {
  static Class ExceptionClass = Nil;
  XmlRpcMethodResponse *response = nil;
  id                   result    = [_resp result];
  
  if (ExceptionClass == Nil)
    ExceptionClass = [NSException class];

  if (![result isKindOfClass:ExceptionClass]) {

    result = [self _decodeObject:result]; // => XmlRpcValue
  }
  response = [[XmlRpcMethodResponse alloc] initWithResult:result];
  
  return [response autorelease];
}

- (NSStringEncoding)logEncoding {
  return NSUTF8StringEncoding;
}
- (id)decodeRootObject {
  id tmp = nil;
  
  if (doDebug) {
    NSLog(@"%s: begin (data: %i bytes, nesting: %i)", __PRETTY_FUNCTION__, 
          [self->data length], self->nesting);
  }
  if ([self->data length] == 0) return nil;
  
  self->nesting++;
  
  [self _ensureSaxAndParser];
  NSAssert(saxHandler,   @"missing sax handler ...");
  NSAssert(xmlRpcParser || useNSXMLParser, @"missing parser handler ...");
  
  [saxHandler reset];
  if (doDebug) NSLog(@"%s:  SAX handler: %@", __PRETTY_FUNCTION__, saxHandler);
#if HAVE_NSXMLPARSER
  if (useNSXMLParser) {
    NSXMLParser *parser;
    
    parser = [[NSXMLParser alloc] initWithData:self->data];
    if (doDebug) 
      NSLog(@"%s:  using NSXMLParser: %@", __PRETTY_FUNCTION__, parser);
    [parser setDelegate:saxHandler];
    [parser setShouldProcessNamespaces:NO];
    [parser setShouldReportNamespacePrefixes:NO];
    [parser setShouldResolveExternalEntities:NO];
    [parser parse];
    [parser release];
  }
  else
#endif
    [xmlRpcParser parseFromSource:self->data systemId:@"<xmlrpc-data>"];
  
  if ((tmp = [saxHandler methodCall]) != nil) {
    tmp = [self _decodeMethodCall:tmp];
  }
  else if ((tmp = [saxHandler methodResponse]) != nil) {
    tmp = [self _decodeMethodResponse:tmp];
  }
  else if (tmp == nil) {
    NSString *s;
    
    s = [[NSString alloc] initWithData:self->data encoding:[self logEncoding]];
    NSLog(@"%s: couldn't parse source\n"
          @"  parser:  %@\n"
          @"  handler: %@\n"
          @"  data:    %@"
          @"  string:  '%@'",
          __PRETTY_FUNCTION__, xmlRpcParser, saxHandler, self->data, s);
    [s release];
  }
  else {
    NSLog(@"%s: neither call nor response (handler=%@): %@ ..",
          __PRETTY_FUNCTION__,
          saxHandler, tmp);
  }
  
  self->nesting--;

  // [saxHandler reset]; // hh asks: why is that commented out?
  if (doDebug) NSLog(@"%s: end: %@", __PRETTY_FUNCTION__, tmp);
  return tmp;  
}

- (XmlRpcMethodCall *)decodeMethodCall {
  XmlRpcMethodCall *result;
  NSTimeInterval st     = 0.0;
    
  if ([self profileXmlRpcCoding])
    st = [[NSDate date] timeIntervalSince1970];  

  result = [self decodeRootObject];

  if ([self profileXmlRpcCoding]) {
    NSTimeInterval diff;
    diff = [[NSDate date] timeIntervalSince1970] - st;
    
    printf("+++     decodeMethodCall: %0.5fs\n", diff);
  }
  
  return ([result isKindOfClass:[XmlRpcMethodCall class]])
    ? result
    : (XmlRpcMethodCall *)nil;
}

- (XmlRpcMethodResponse *)decodeMethodResponse {
  XmlRpcMethodResponse *result;
  NSTimeInterval st    = 0.0;

  if ([self profileXmlRpcCoding])
    st = [[NSDate date] timeIntervalSince1970];

  result = [self decodeRootObject];

  if ([self profileXmlRpcCoding]) {
    NSTimeInterval diff;
    diff = [[NSDate date] timeIntervalSince1970] - st;
    
    printf("+++ decodeMethodResponse: %0.5fs\n", diff);
  }
  
  return [result isKindOfClass:[XmlRpcMethodResponse class]]
    ? result
    : (XmlRpcMethodResponse *)nil;
}

- (id)_decodeObject:(XmlRpcValue *)_value {
  id result;
  
  if (_value == nil) return nil;
  
  [self->valueStack addObject:_value];
  result = [self decodeObject];
  [self->valueStack removeLastObject];
  return result;
}

- (id)decodeObject {
  Class objClass = Nil;
  id    object   = nil;
  
  self->nesting++;

  if ((self->nesting == 1) && ([self->valueStack count] == 0)) {
    object = [self decodeRootObject];
  }
  else {
    NSString *className;
    id value = [self->valueStack lastObject];
    
    className = [value className];

    if ([className length] == 0) {
      object = [(XmlRpcValue *)value value];
    }
    else if ((objClass = NSClassFromString(className)) != Nil) {
      object = [objClass decodeObjectWithXmlRpcCoder:self];
    }
    else {
      NSLog(@"%s: class (%@) specified by value (%@) wasn't found.",
            __PRETTY_FUNCTION__, className, value);
      object = [(XmlRpcValue *)value value];
    }

    if (object) [self->unarchivedObjects addObject:object];
  }
 
  self->nesting--;
  
  return object;
}

- (NSDictionary *)decodeStruct {
  NSDictionary *dict;
  id           result = nil;
  NSMutableDictionary *tmp;
  NSEnumerator        *keyEnum;
  NSString            *key;
  
  dict  = (NSDictionary *)[(XmlRpcValue *)[self->valueStack lastObject] value];
  
  if (!([dict respondsToSelector:@selector(keyEnumerator)] &&
        [dict respondsToSelector:@selector(objectForKey:)]))
    return nil;
  
  keyEnum  = [dict keyEnumerator];
  tmp = [[NSMutableDictionary alloc] initWithCapacity:8];
    
  while ((key = [keyEnum nextObject])) {
    XmlRpcValue *v;
    id          obj;

    v = [dict objectForKey:key];
    if ((obj = [self _decodeObject:v]) != nil)
        [tmp setObject:obj forKey:key];
  }
  result = [NSDictionary dictionaryWithDictionary:tmp];
  [tmp release];
  return result;
}

- (NSArray *)decodeArray {
  NSArray        *array;
  id             result = nil;
  NSMutableArray *tmp      = nil;
  NSEnumerator   *valEnum;
  XmlRpcValue    *val      = nil;
  
  array = (NSArray *)[(XmlRpcValue *)[self->valueStack lastObject] value];
  if (![array respondsToSelector:@selector(objectEnumerator)])
    return nil;

  valEnum = [array objectEnumerator];
  tmp = [[NSMutableArray alloc] initWithCapacity:8];
    
  while ((val = [valEnum nextObject])) {
    id obj;

    if ((obj = [self _decodeObject:val]) != nil)
        [tmp addObject:obj];
  }
  result = [NSArray arrayWithArray:tmp];
  [tmp release];
  return result;
}

- (NSData *)decodeBase64 {
#if 0 /* data is already decoded in the XmlRpcValue */
  tmp = [tmp dataByDecodingBase64];
#endif
  return [self _decodeValueOfClass:DataClass];
}

- (BOOL)decodeBoolean {
  return [[self _decodeValueOfClass:NumberClass] boolValue];
}

- (int)decodeInt {
  return [[self _decodeValueOfClass:NumberClass] intValue];
}

- (double)decodeDouble {
  return [[self _decodeValueOfClass:NumberClass] doubleValue];
}

- (NSString *)decodeString {
  return [self _decodeValueOfClass:StringClass];
}

- (NSCalendarDate *)decodeDateTime {
  NSCalendarDate *date;
  NSTimeZone     *tz;
  int            secFromGMT;
  
  if ((date = [self _decodeValueOfClass:DateClass]) == nil)
    return nil;
  
  if ((tz = [date timeZone]))
    return date;
  
  if (![date respondsToSelector:@selector(setTimeZone:)]) {
    /* a plain date ... */
    NSLog(@"cannot set timezone on date: %@", date);
    return date;
  }
  
  /* apply timezone correction */
  secFromGMT = [self->timeZone secondsFromGMT];
  [date setTimeZone:self->timeZone];
  date = [date dateByAddingYears:0 months:0 days:0
               hours:0 minutes:0 seconds:-secFromGMT];
  return date;
}

- (XmlRpcValue *)beginDecodingKey:(NSString *)_key {
  XmlRpcValue  *newValue;
  NSDictionary *obj;
  
  obj = (NSDictionary *)[(XmlRpcValue *)[self->valueStack lastObject] value];
  NSAssert(_key != nil, @"_key is not allowed to be nil");
  
  if (![obj isKindOfClass:DictionaryClass]) {
    NSLog(@"WARNING(%s): obj (%@) is not kind of class NSDictionary !!",
          __PRETTY_FUNCTION__, obj, nil);
    return nil;
  }
  
  if ((newValue = [obj objectForKey:_key]) == nil)
    /* got no value for key ... */
    return nil;
  
  [self->valueStack addObject:newValue];
  return newValue;
}
- (void)finishedDecodingKey {
  [self->valueStack removeLastObject];
}

- (id)_decodeValueForKey:(NSString *)_key selector:(SEL)_selector {
  XmlRpcValue *newValue;
  id result;
  
  if ((newValue = [self beginDecodingKey:_key]) == nil)
    return nil;
  
  result = [[self performSelector:_selector] retain];
  [self finishedDecodingKey];
  return [result autorelease];
}

- (NSDictionary *)decodeStructForKey:(NSString *)_key {
  return [self _decodeValueForKey:_key selector:@selector(decodeStruct)];
}

- (NSArray *)decodeArrayForKey:(NSString *)_key {
  return [self _decodeValueForKey:_key selector:@selector(decodeArray)];
}

- (NSData *)decodeBase64ForKey:(NSString *)_key {
  return [self _decodeValueForKey:_key selector:@selector(decodeBase64)];
}

- (BOOL)decodeBooleanForKey:(NSString *)_key {
  XmlRpcValue *newValue;
  BOOL result;
  
  if ((newValue = [self beginDecodingKey:_key]) == nil)
    /* any useful alternatives ? */
    return NO;
  
  result = [self decodeBoolean];
  [self finishedDecodingKey];
  return result;
}

- (int)decodeIntForKey:(NSString *)_key {
  XmlRpcValue *newValue;
  int result;
  
  if ((newValue = [self beginDecodingKey:_key]) == nil)
    /* any useful alternatives ? */
    return NSNotFound;
  
  result = [self decodeInt];
  [self finishedDecodingKey];
  return result;
}

- (double)decodeDoubleForKey:(NSString *)_key {
  XmlRpcValue *newValue;
  double result;
  
  if ((newValue = [self beginDecodingKey:_key]) == nil)
    /* any useful alternatives ? */
    return 0.0;
  
  result = [self decodeDouble];
  [self finishedDecodingKey];
  return result;
}

- (NSString *)decodeStringForKey:(NSString *)_key {
  return [self _decodeValueForKey:_key selector:@selector(decodeString)];
}

- (NSCalendarDate *)decodeDateTimeForKey:(NSString *)_key {
  return [self _decodeValueForKey:_key selector:@selector(decodeDateTime)];
}

- (id)decodeObjectForKey:(NSString *)_key {
 return [self _decodeValueForKey:_key selector:@selector(decodeObject)];
}

/* operations */

- (void)ensureObjectAwake:(id)_object {
  if ([self->awakeObjects containsObject:_object])
    return;
  
  if ([_object respondsToSelector:@selector(awakeFromXmlRpcDecoder:)])
    [_object awakeFromXmlRpcDecoder:self];
  [self->awakeObjects addObject:_object];
}
- (void)awakeObjects {
  NSEnumerator *e;
  id obj;

  e = [self->unarchivedObjects objectEnumerator];
  while ((obj = [e nextObject]))
    [self ensureObjectAwake:obj];
}

- (void)finishInitializationOfObjects {
  NSEnumerator *e;
  id obj;

  e = [self->unarchivedObjects objectEnumerator];
  while ((obj = [e nextObject])) {
    if ([obj respondsToSelector:
               @selector(finishInitializationWithXmlRpcDecoder:)])
      [obj finishInitializationWithXmlRpcDecoder:self];
  }
}

@end /* XmlRpcDecoder */
