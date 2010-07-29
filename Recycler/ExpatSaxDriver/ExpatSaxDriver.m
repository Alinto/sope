/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id: ExpatSaxDriver.m 1 2004-08-20 10:08:27Z znek $

#import <Foundation/NSObject.h>
#include <SaxObjC/SaxXMLReader.h>
#include <SaxObjC/SaxContentHandler.h>
#include <SaxObjC/SaxDTDHandler.h>
#include <SaxObjC/SaxErrorHandler.h>
#include <SaxObjC/SaxEntityResolver.h>
#include <SaxObjC/SaxLexicalHandler.h>
#include <SaxObjC/SaxLocator.h>
#include <SaxObjC/SaxDeclHandler.h>
#include <expat.h>
#include <NGExtensions/NGExtensions.h>

@class NSMutableArray, NSMutableDictionary;
@class SaxAttributes;

@interface ExpatSaxDriver : NSObject < SaxXMLReader >
{
@private
  id<NSObject,SaxContentHandler> contentHandler;
  id<NSObject,SaxDTDHandler>     dtdHandler;
  id<NSObject,SaxErrorHandler>   errorHandler;
  id<NSObject,SaxEntityResolver> entityResolver;
  
  id<NSObject,SaxLexicalHandler> lexicalHandler;
  id<NSObject,SaxDeclHandler>    declHandler;

  /* expat */
  XML_Parser expat;
  
  /* features */
  BOOL           fNamespaces;
  BOOL           fNamespacePrefixes;
  NSMutableDictionary *declNS;

  /* cached buffers */
  char     *nameBuf;
  unsigned nameBufLen;
  SaxAttributes *attrs;
}

@end

#include <SaxObjC/SaxException.h>
#include "common.h"

static NSString *SaxDeclHandlerProperty =
  @"http://xml.org/sax/properties/declaration-handler";
static NSString *SaxLexicalHandlerProperty =
  @"http://xml.org/sax/properties/lexical-handler";
#if 0
static NSString *SaxDOMNodeProperty =
  @"http://xml.org/sax/properties/dom-node";
static NSString *SaxXMLStringProperty =
  @"http://xml.org/sax/properties/xml-string";
#endif

@interface ExpatSaxDriver(Privates)
- (BOOL)_setupParser;
- (void)_tearDownParser;
@end

static int _UTF8ToUTF16(unsigned char **sourceStart, unsigned char *sourceEnd, 
                        unichar **targetStart, const unichar *targetEnd);

typedef struct {
  NSString *raw;
  NSString *tag;
  NSString *uri;
} TagTriple;

@implementation ExpatSaxDriver

static NSMapTable *uniqueStrings = NULL; // THREAD
static Class NSStringClass = Nil;

// ZNeK: bad idea, no?
#define NSNonOwnedCStringMapKeyCallBacks NSNonOwnedPointerMapKeyCallBacks

static inline NSString *uniqueStringUTF8(const char *utf8) {
  NSString *s;
  char *newkey;
  
  if (utf8 == NULL) return nil;
  
  if (uniqueStrings == NULL) {
    uniqueStrings = NSCreateMapTable(NSNonOwnedCStringMapKeyCallBacks,
                                     NSObjectMapValueCallBacks,
                                     128);
  }
  else if ((s = NSMapGet(uniqueStrings, utf8))) {
    /* found a string in cache ... */
    return RETAIN(s);
  }
  
  newkey = malloc(strlen(utf8) + 1);
  strcpy(newkey, utf8);

  if (NSStringClass == Nil)
    NSStringClass = [NSString class];
  
  s = [[NSStringClass alloc] initWithUTF8String:newkey];
  NSMapInsert(uniqueStrings, newkey, s);
  
  return s;
}

- (id)init {
  if ((self = [super init])) {
    /* feature defaults */
    self->fNamespaces        = YES;
    self->fNamespacePrefixes = NO;
  }
  return self;
}

- (void)dealloc {
  [self _tearDownParser];
  RELEASE(self->attrs);
  RELEASE(self->declNS);
  RELEASE(self->declHandler);
  RELEASE(self->lexicalHandler);
  RELEASE(self->contentHandler);
  RELEASE(self->dtdHandler);
  RELEASE(self->errorHandler);
  RELEASE(self->entityResolver);
  [super dealloc];
}

/* properties */

- (void)setProperty:(NSString *)_name to:(id)_value {
  if ([_name isEqualToString:SaxLexicalHandlerProperty]) {
    ASSIGN(self->lexicalHandler, _value);
    return;
  }
  if ([_name isEqualToString:SaxDeclHandlerProperty]) {
    ASSIGN(self->declHandler, _value);
    return;
  }
  
  [SaxNotRecognizedException raise:@"PropertyException"
                             format:@"don't know property %@", _name];
}
- (id)property:(NSString *)_name {
  if ([_name isEqualToString:SaxLexicalHandlerProperty])
    return self->lexicalHandler;
  if ([_name isEqualToString:SaxDeclHandlerProperty])
    return self->declHandler;
  
  [SaxNotRecognizedException raise:@"PropertyException"
                             format:@"don't know property %@", _name];
  return nil;
}

/* features */

- (void)setFeature:(NSString *)_name to:(BOOL)_value {
  if ([_name isEqualToString:@"http://xml.org/sax/features/namespaces"]) {
    self->fNamespaces = _value;
    return;
  }
  
  if ([_name isEqualToString:
               @"http://xml.org/sax/features/namespace-prefixes"]) {
    self->fNamespacePrefixes = _value;
    return;
  }

  [SaxNotRecognizedException raise:@"FeatureException"
                             format:@"don't know feature %@", _name];
}
- (BOOL)feature:(NSString *)_name {
  if ([_name isEqualToString:@"http://xml.org/sax/features/namespaces"])
    return self->fNamespaces;
  
  if ([_name isEqualToString:
               @"http://xml.org/sax/features/namespace-prefixes"])
    return self->fNamespacePrefixes;
  
  if ([_name isEqualToString:
               @"http://www.skyrix.com/sax/features/predefined-namespaces"])
    return YES;
  
  [SaxNotRecognizedException raise:@"FeatureException"
                             format:@"don't know feature %@", _name];
  return NO;
}

/* pre-defining namespaces */

- (void)declarePrefix:(NSString *)_prefix namespaceURI:(NSString *)_uri {
  NSAssert(_prefix, @"invalid prefix ...");
  NSAssert(_uri,    @"invalid uri ...");
  
  if (self->declNS == nil) {
    self->declNS = [[NSMutableDictionary alloc] initWithCapacity:8];
    
    [self->declNS
         setObject:@"http://www.w3.org/XML/1998/namespace"
         forKey:@"xml"];
    [self->declNS setObject:@"" forKey:@":"];
  }
  
  [self->declNS setObject:_uri forKey:_prefix];
}

/* handlers */

#if 0
- (void)setDocumentHandler:(id<NSObject,SaxDocumentHandler>)_handler {
  SaxDocumentHandlerAdaptor *a;

  a = [[SaxDocumentHandlerAdaptor alloc] initWithDocumentHandler:_handler];
  [self setContentHandler:a];
  RELEASE(a);
}
#endif

- (void)setDTDHandler:(id<NSObject,SaxDTDHandler>)_handler {
  ASSIGN(self->dtdHandler, _handler);
}
- (id<NSObject,SaxDTDHandler>)dtdHandler {
  return self->dtdHandler;
}

- (void)setErrorHandler:(id<NSObject,SaxErrorHandler>)_handler {
  ASSIGN(self->errorHandler, _handler);
}
- (id<NSObject,SaxErrorHandler>)errorHandler {
  return self->errorHandler;
}

- (void)setEntityResolver:(id<NSObject,SaxEntityResolver>)_handler {
  ASSIGN(self->entityResolver, _handler);
}
- (id<NSObject,SaxEntityResolver>)entityResolver {
  return self->entityResolver;
}

- (void)setContentHandler:(id<NSObject,SaxContentHandler>)_handler {
  ASSIGN(self->contentHandler, _handler);
}
- (id<NSObject,SaxContentHandler>)contentHandler {
  return self->contentHandler;
}

/* parsing */

- (void)_reportParseError:(enum XML_Error)_error systemId:(NSString *)_sysId {
  NSMutableDictionary *ui;
  NSException *e;
  NSString    *ename;
  NSString    *ereason;
  SEL         sel;

  ename   = @"SaxException";
  ereason = @"XML parse error";
  sel     = @selector(fatalError:);

  switch (_error) {
    case XML_ERROR_NONE: /* no error ... */
      return;
    case XML_ERROR_SYNTAX:
      sel     = @selector(error:);
      ereason = @"XML syntax error";
      break;
    case XML_ERROR_NO_MEMORY:
      sel     = @selector(fatalError:);
      ereason = @"out of memory";
      break;
    case XML_ERROR_NO_ELEMENTS:
      sel     = @selector(error:);
      ereason = @"no elements";
      break;
    case XML_ERROR_INVALID_TOKEN:
      sel     = @selector(error:);
      ereason = @"invalid token";
      break;
    case XML_ERROR_UNCLOSED_TOKEN:
      sel     = @selector(error:);
      ereason = @"unclosed token";
      break;
    case XML_ERROR_PARTIAL_CHAR:
      sel     = @selector(error:);
      ereason = @"partial character";
      break;
    case XML_ERROR_TAG_MISMATCH:
      sel     = @selector(error:);
      ereason = @"tag mismatch";
      break;
    case XML_ERROR_DUPLICATE_ATTRIBUTE:
      sel     = @selector(error:);
      ereason = @"duplicate attribute";
      break;
    case XML_ERROR_JUNK_AFTER_DOC_ELEMENT:
      sel     = @selector(warning:);
      ereason = @"junk after document element";
      break;
    case XML_ERROR_PARAM_ENTITY_REF:
      sel     = @selector(error:);
      ereason = @"parameter entity reference";
      break;
    case XML_ERROR_UNDEFINED_ENTITY:
      sel     = @selector(error:);
      ereason = @"undefined entity";
      break;
    case XML_ERROR_RECURSIVE_ENTITY_REF:
      sel     = @selector(error:);
      ereason = @"recursive entity reference";
      break;
    case XML_ERROR_ASYNC_ENTITY:
      sel     = @selector(error:);
      ereason = @"async entity";
      break;
    case XML_ERROR_BAD_CHAR_REF:
      sel     = @selector(error:);
      ereason = @"bad character reference";
      break;
    case XML_ERROR_BINARY_ENTITY_REF:
      sel     = @selector(error:);
      ereason = @"binary entity reference";
      break;
    case XML_ERROR_ATTRIBUTE_EXTERNAL_ENTITY_REF:
      sel     = @selector(error:);
      ereason = @"attibute external entity reference";
      break;
    case XML_ERROR_MISPLACED_XML_PI:
      sel     = @selector(error:);
      ereason = @"misplaced processing instruction";
      break;
    case XML_ERROR_UNKNOWN_ENCODING:
      sel     = @selector(error:);
      ereason = @"unknown encoding";
      break;
    case XML_ERROR_INCORRECT_ENCODING:
      sel     = @selector(error:);
      ereason = @"incorrect encoding";
      break;
    case XML_ERROR_UNCLOSED_CDATA_SECTION:
      sel     = @selector(error:);
      ereason = @"unclosed CDATA section";
      break;
    case XML_ERROR_EXTERNAL_ENTITY_HANDLING:
      sel     = @selector(error:);
      ereason = @"external entity handling";
      break;
    case XML_ERROR_NOT_STANDALONE:
      sel     = @selector(error:);
      ereason = @"XML is not standalone";
      break;
    case XML_ERROR_UNEXPECTED_STATE:
      sel     = @selector(fatalError:);
      ereason = @"unexpected status";
      break;
  }
  
  ui = [NSMutableDictionary dictionaryWithCapacity:4];
  
  if (_sysId) [ui setObject:_sysId forKey:@"systemId"];
  [ui setObject:self forKey:@"parser"];
  if (self->expat) {
    int line;
    
    if ((line = XML_GetCurrentLineNumber(self->expat)) > 0)
      [ui setObject:[NSNumber numberWithInt:line] forKey:@"line"];
  }
  [ui setObject:[NSNumber numberWithUnsignedInt:_error]
      forKey:@"expatErrorCode"];
  
  e = (id)[SaxParseException exceptionWithName:ename
                             reason:ereason
                             userInfo:ui];
  
  [self->errorHandler performSelector:sel withObject:e];
}

- (void)parseFromSource:(id)_source systemId:(NSString *)_sysId {
  if (_source == nil) {
    /* no source ??? */
    return;
  }

  if ([_source isKindOfClass:[NSData class]]) {
    if ([self _setupParser]) {
      NSAutoreleasePool *pool;
      
      pool = [[NSAutoreleasePool alloc] init];
      {
        int res;

        [self->contentHandler startDocument];
        res = XML_Parse(self->expat, [_source bytes], [_source length], 1);
        
        if (res == 0) {
          [self _reportParseError:XML_GetErrorCode(self->expat)
                systemId:_sysId];
        }
        [self->contentHandler endDocument];
      }
      RELEASE(pool);
      [self _tearDownParser];
    }
  }
  else if ([_source isKindOfClass:[NSString class]]) {
    [self parseFromSource:
            [_source dataUsingEncoding:NSUTF8StringEncoding]
          systemId:_sysId];
  }
  else if ([_source isKindOfClass:[NSURL class]]) {
    if (_sysId == nil)
      _sysId = [_source absoluteString];
    
    [self parseFromSource:[_source resourceDataUsingCache:NO]
          systemId:_sysId];
  }
  else
    [self parseFromSource:[_source stringValue] systemId:_sysId];
}

- (void)parseFromSource:(id)_source {
  [self parseFromSource:_source systemId:nil];
}

- (void)parseFromSystemId:(NSString *)_sysId {
  if (![_sysId hasPrefix:@"file:"]) {
    SaxParseException *e;
    NSDictionary      *ui;
    NSURL *url;
    
    if ((url = [NSURL URLWithString:_sysId]))
      return [self parseFromSource:url systemId:_sysId];
    
    ui = [NSDictionary dictionaryWithObjectsAndKeys:
                         _sysId ? _sysId : @"<nil>", @"systemID",
                         self,                       @"parser",
                         nil];
    
    e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
                               reason:@"can't handle system-id"
                               userInfo:ui];
    
    [self->errorHandler fatalError:e];
    return;
  }
  else {
    NSData *data;
    
    _sysId = [_sysId substringFromIndex:7];
    
    if ((data = [NSData dataWithContentsOfMappedFile:_sysId]) == nil) {
      NSLog(@"couldn't load file '%@'", _sysId);
      return;
    }
    
    return [self parseFromSource:data systemId:_sysId];
  }
}

/* expat */

static TagTriple splitName(ExpatSaxDriver *self, const char *el) {
  TagTriple t;
  char      *el_tag;
  char      *buf;
  unsigned  len;
  
  if ((len = strlen(el)) == 0) {
    t.raw = @"";
    t.tag = @"";
    t.uri = nil;
    return t;
  }
  
  if (len >= self->nameBufLen) {
    if (self->nameBuf) free(self->nameBuf);
    self->nameBuf    = malloc(len + 8);
    self->nameBufLen = len + 6;
  }
  buf = self->nameBuf;
  
  strcpy(buf, el);
  buf[len] = '\0';
  
  t.raw = uniqueStringUTF8(el);
  
  if ((el_tag = index(buf, '\t'))) {
    unsigned idx;
    
    t.tag = uniqueStringUTF8(el_tag + 1);
    
    idx   = [t.raw rangeOfString:@"\t"].location;
    t.uri = [[t.raw substringToIndex:idx] copy];
  }
  else if ((self->declNS != nil) && ((el_tag = index(buf, ':')) != NULL)) {
    /* check predefined namespaces ... */
    NSString *prefix;
    
    *el_tag = '\0';
    prefix = uniqueStringUTF8(buf);
    
    if ((t.uri = [self->declNS objectForKey:prefix])) {
      t.tag = uniqueStringUTF8(el_tag + 1);
      t.uri = [t.uri copy];
    }
    else {
      t.uri = nil;
      t.tag = [t.raw copy];
    }

    RELEASE(prefix);
  }
  else {
    t.uri = nil;
    t.tag = [t.raw copy];
  }
  
  return t;
}
static void releaseTag(TagTriple t) {
  RELEASE(t.raw);
  RELEASE(t.tag);
  RELEASE(t.uri);
}

static void _startElem(void *data, const char *el, const char **attr) {
  ExpatSaxDriver *self = (ExpatSaxDriver *)data;
  TagTriple     t;
  unsigned      i;
  
  t     = splitName(self, el);
  
  /* process attributes */
  
  if (self->attrs == nil)
    self->attrs = [[SaxAttributes alloc] init];
  else
    [self->attrs clear];
  if (NSStringClass == Nil) NSStringClass = [NSString class];
  
  for (i = 0; attr[i] != NULL; i += 2) {
    TagTriple at;
    NSString *value;
    
    at    = splitName(self, attr[i]);
    value = [[NSStringClass alloc] initWithUTF8String:attr[i + 1]];
    
    [self->attrs
         addAttribute:at.tag
         uri:at.uri ? at.uri : t.uri
         rawName:at.raw
         type:@"CDATA" value:value];

    releaseTag(at);
    RELEASE(value);
  }
  
  /* notify handler ... */
  
  [self->contentHandler
       startElement:t.tag namespace:t.uri rawName:t.raw
       attributes:self->attrs];
  
  releaseTag(t);
  [self->attrs clear];
}
static void _endElem(void *data, const char *el) {
  ExpatSaxDriver *self = (ExpatSaxDriver *)data;
  TagTriple  t;
  
  t = splitName(self, el);
  
  [self->contentHandler endElement:t.tag namespace:t.uri rawName:t.raw];
  
  releaseTag(t);
}

static void _startNS(void *data, const char *_prefix, const char *_uri) {
  ExpatSaxDriver *self = (ExpatSaxDriver *)data;
  NSString *spre, *suri;
  
  spre = _prefix ? uniqueStringUTF8(_prefix) : @"";
  suri = _uri    ? uniqueStringUTF8(_uri)    : @"";
  [self->contentHandler startPrefixMapping:spre uri:suri];
  RELEASE(suri);
  RELEASE(spre);
}
static void _endNS(void *data, const char *_prefix) {
  ExpatSaxDriver *self = (ExpatSaxDriver *)data;
  NSString *spre;
  
  spre = _prefix ? uniqueStringUTF8(_prefix) : @"";
  [self->contentHandler endPrefixMapping:spre];
  RELEASE(spre);
}

static void _characters(void *_data, const char *chars, int len) {
  ExpatSaxDriver *self = (ExpatSaxDriver *)_data;
  void *data, *ts;
  
  if (len == 0) {
    unichar c = 0;
    data = &c;
    [self->contentHandler characters:data length:len];
    return;
  }
  if (chars == NULL) {
    [self->contentHandler characters:NULL length:0];
    return;
  }
  
  data = ts = calloc(len + 1, sizeof(unichar)); /* GC ?! */
  
  if (_UTF8ToUTF16((void *)&chars, (void *)(chars + len),
                   (void *)&ts, ts + (len * sizeof(unichar)))) {
    free(data);
    NSLog(@"ERROR(%s:%i): couldn't convert UTF8 to UTF16 !",
          __PRETTY_FUNCTION__, __LINE__);
  }
  else {
    [self->contentHandler characters:data length:(unsigned)(ts - data)];
    free(data);
  }
}

static void _pi(void *_udata, const char *_target, const char *_data) {
  ExpatSaxDriver *self = (ExpatSaxDriver *)_udata;
  NSString *target, *data;
  
  target = uniqueStringUTF8(_target);
  data   = uniqueStringUTF8(_data);
  [self->contentHandler processingInstruction:target data:data];
  RELEASE(target);
  RELEASE(data);
}

static void _comment(void *_data, const char *chars) {
  ExpatSaxDriver *self = (ExpatSaxDriver *)_data;
  void *data, *ts;
  unsigned len;
  
  len = strlen(chars);
  
  if (len == 0) {
    unichar c = 0;
    data = &c;
    [self->lexicalHandler comment:data length:0];
    return;
  }
  if (chars == NULL) {
    [self->lexicalHandler comment:NULL length:0];
    return;
  }
  
  data = ts = calloc(len + 1, sizeof(unichar)); /* GC ?! */
  
  if (_UTF8ToUTF16((void *)&chars, (void *)(chars + len),
                   (void *)&ts, ts + (len * sizeof(unichar)))) {
    free(data);
    NSLog(@"ERROR(%s:%i): couldn't convert UTF8 to UTF16 !",
          __PRETTY_FUNCTION__, __LINE__);
  }
  else {
    [self->lexicalHandler comment:data length:(ts - data)];
    free(data);
  }
}

static void _startCDATA(void *data) {
}
static void _endCDATA(void *data) {
}

- (BOOL)_setupParser {
  [self _tearDownParser];
  
  if ((self->expat = XML_ParserCreateNS(NULL, '\t')) == NULL) {
#if DEBUG
    NSLog(@"%s: couldn't create expat parser ..", __PRETTY_FUNCTION__);
#endif
    return NO;
  }
  
  XML_SetUserData(self->expat, self);
  XML_SetReturnNSTriplet(self->expat, 1); /* also return NS prefix */
  
  if (self->contentHandler) {
    XML_SetElementHandler(self->expat, _startElem, _endElem);
    XML_SetNamespaceDeclHandler(self->expat, _startNS, _endNS);
    
    XML_SetCharacterDataHandler(self->expat, _characters);
    XML_SetProcessingInstructionHandler(self->expat, _pi);
    
    XML_SetCdataSectionHandler(self->expat, _startCDATA, _endCDATA);
  }
  
  if (self->lexicalHandler) {
    XML_SetCommentHandler(self->expat, _comment);
  }

  return YES;
}

- (void)_tearDownParser {
  if (self->expat) {
    XML_ParserFree(self->expat);
    self->expat = NULL;
  }
  if (self->nameBuf) {
    free(self->nameBuf);
    self->nameBuf    = NULL;
    self->nameBufLen = 0;
  }
}

@end /* ExpatSaxDriver */

#include "unicode.h"
