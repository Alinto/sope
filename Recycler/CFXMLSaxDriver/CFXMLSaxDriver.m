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

#import "CFXMLSaxDriver.h"
#import <Foundation/Foundation.h>

@interface CFXMLTagHolder : NSObject
{
@public
  NSString *localName;
  NSString *uri;
  NSString *prefix;
  NSString *rawName;
}
@end

static NSString *SaxDeclHandlerProperty =
  @"http://xml.org/sax/properties/declaration-handler";
static NSString *SaxLexicalHandlerProperty =
  @"http://xml.org/sax/properties/lexical-handler";

@interface CFXMLSaxDriver(Privates)
- (NSString *)nsUriForPrefix:(NSString *)_prefix;
- (NSString *)defaultNamespace;
- (void)declarePrefix:(NSString *)_prefix namespaceURI:(NSString *)_uri;
@end

@implementation CFXMLSaxDriver

static BOOL debugNS = NO;

- (id)init {
  if ((self = [super init])) {
    self->pubIdToValue = [[NSMutableDictionary alloc] init];
    [self->pubIdToValue setObject:@"<"  forKey:@"lt"];
    [self->pubIdToValue setObject:@">"  forKey:@"gt"];
    [self->pubIdToValue setObject:@"\"" forKey:@"quot"];
    [self->pubIdToValue setObject:@"&"  forKey:@"amp"];

    self->nsStack = [[NSMutableArray alloc] init];
  
    /* feature defaults */
    self->fNamespaces        = YES;
    self->fNamespacePrefixes = NO;
  }
  return self;
}

- (void)dealloc {
  [self->attrs   release];
  [self->nsStack release];

  if (self->buffer) free(self->buffer);

  [self->pubIdToValue   release];
  [self->lexicalHandler release];
  [self->contentHandler release];
  [self->errorHandler   release];
  [self->entityResolver release];
  [super dealloc];
}

/* properties */

- (void)setProperty:(NSString *)_name to:(id)_value {
  if ([_name isEqualToString:SaxLexicalHandlerProperty]) {
    [self->lexicalHandler autorelease];
    self->lexicalHandler = [_value retain];
    return;
  }
  if ([_name isEqualToString:SaxDeclHandlerProperty]) {
    return;
  }
  
  [SaxNotRecognizedException raise:@"PropertyException"
                             format:@"don't know property %@", _name];
}
- (id)property:(NSString *)_name {
  if ([_name isEqualToString:SaxLexicalHandlerProperty])
    return self->lexicalHandler;
  if ([_name isEqualToString:SaxDeclHandlerProperty])
    return nil;
  
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

/* handlers */

- (void)setContentHandler:(id<NSObject,SaxContentHandler>)_handler {
  [self->contentHandler autorelease];
  self->contentHandler = [_handler retain];
}
- (id<NSObject,SaxContentHandler>)contentHandler {
  return self->contentHandler;
}

- (void)setLexicalHandler:(id<NSObject,SaxLexicalHandler>)_handler {
  [self->lexicalHandler autorelease];
  self->lexicalHandler = [_handler retain];
}
- (id<NSObject,SaxLexicalHandler>)lexicalHandler {
  return self->lexicalHandler;
}

- (void)setDTDHandler:(id<NSObject,SaxDTDHandler>)_handler {
}
- (id<NSObject,SaxDTDHandler>)dtdHandler {
  return nil;
}

- (void)setErrorHandler:(id<NSObject,SaxErrorHandler>)_handler {
  [self->errorHandler autorelease];
  self->errorHandler = [_handler retain];
}
- (id<NSObject,SaxErrorHandler>)errorHandler {
  return self->errorHandler;
}

- (void)setEntityResolver:(id<NSObject,SaxEntityResolver>)_handler {
  [self->entityResolver autorelease];
  self->entityResolver = [_handler retain];
}
- (id<NSObject,SaxEntityResolver>)entityResolver {
  return self->entityResolver;
}

/* method callbacks */

- (void)beginDocument:(CFXMLNodeRef)_node {
  const CFXMLDocumentInfo *docInfoPtr;
  
  docInfoPtr = CFXMLNodeGetInfoPtr(_node);
  //NSLog(@"begin-doc: url=%@", docInfoPtr->sourceURL);
}
- (void)endDocument:(id)_node {
  //NSLog(@"end-doc.");
}

- (id<SaxAttributes>)handleAttributesOfNode:(CFXMLNodeRef)_node 
  nsdecls:(NSDictionary **)_ns
  defaultPrefix:(NSString *)_defAttrNS
{
  const CFXMLElementInfo *elemInfo;
  unsigned count, i, nsCount;
  NSMutableDictionary *ns = nil;
  
  if ((elemInfo = CFXMLNodeGetInfoPtr(_node)) == NULL)
    return nil;
  
  if ((count = [(NSArray *)elemInfo->attributeOrder count]) == 0)
    return nil;
  
  /* pass one: collect all namespace declarations */
  
  for (i = 0, nsCount = 0; i < count; i++) {
    NSString *attrName, *prefix, *uri;
    NSRange r;
    
    attrName = [(NSArray *)elemInfo->attributeOrder objectAtIndex:i];
    if (![attrName hasPrefix:@"xmlns"]) continue;

    /* ok, found ns decl */
    if (ns == nil) ns = [[[NSMutableDictionary alloc] init] autorelease];
    
    nsCount++;
    r = [attrName rangeOfString:@"xmlns:"];
    prefix = r.length == 0
      ? nil
      : [attrName substringFromIndex:(r.location + r.length)];
    uri = [(NSDictionary *)elemInfo->attributes objectForKey:attrName];
    
    if (prefix) {
      /* eg <x xmlns:nl="http://www.w3.org"/> */
      [ns setObject:uri forKey:prefix];
        
      if (self->fNamespaces)
        [self->contentHandler startPrefixMapping:prefix uri:uri];
    }
    else {
      /* eg <x xmlns="http://www.w3.org"/> */
      [ns setObject:uri forKey:@":"];
    }
  }
  *_ns = (ns != nil) ? [[ns copy] autorelease] : nil;
  
  if (nsCount == count) /* all attrs were namespace declarations */
    return nil;
    
  /* pass two: user attributes */
  
  for (i = 0; i < count; i++) {
    NSString *attrName, *prefix, *localName, *uri;
    NSString *value;
    NSRange  r;
    
    attrName = [(NSArray *)elemInfo->attributeOrder objectAtIndex:i];
    if (nsCount > 0) { /* do not consider namespace decls */
      if ([attrName hasPrefix:@"xmlns"])  {
        nsCount--;
        continue;
      }
    }
    
    r = [attrName rangeOfString:@":"];
    if (r.length == 0) { /* no prefix, use element namespace */
      prefix    = nil;
      localName = attrName;
      
      /* def-namespace for attributes is 1. element, 2. context */
      if (_defAttrNS) {
        if ((uri = [ns objectForKey:_defAttrNS]) == nil) {
          if ((uri = [self nsUriForPrefix:_defAttrNS]) == nil) {
            NSLog(@"ERROR: did not find namespace for element prefix '%@' !",
                  _defAttrNS);
            uri = [self defaultNamespace];
          }
        }
      }
      else
        uri = [self defaultNamespace];
    }
    else { /*  has prefix, lookup namespace */
      prefix    = [attrName substringToIndex:r.location];
      localName = [attrName substringFromIndex:(r.location + r.length)];
      if ((uri = [ns objectForKey:prefix]) == nil)
        uri = [self nsUriForPrefix:prefix];
    }
    
    value = [(NSDictionary *)elemInfo->attributes objectForKey:attrName];
    
    [self->attrs addAttribute:localName uri:uri rawName:attrName
                 type:@"CDATA" value:value];
  }
  return self->attrs;
}

- (CFXMLTagHolder *)beginElementNode:(CFXMLNodeRef)_node {
  CFXMLTagHolder    *info;
  id<SaxAttributes> lattrs;
  NSDictionary      *nsDict = nil;
  NSRange r;
  
  info = [[CFXMLTagHolder alloc] init];
  info->rawName = [(NSString *)CFXMLNodeGetString(_node) copy];
  
  /* prepare tagname processing */
  
  r = [info->rawName rangeOfString:@":"];
  if (r.length == 0) { /* no namespace prefix */
    info->prefix    = nil;
    info->localName = [info->rawName copy];
  }
  else { /* has a namespace prefix */
    info->prefix    =
      [[info->rawName substringToIndex:r.location] copy];
    info->localName = 
      [[info->rawName substringFromIndex:(r.location + r.length)] copy];
  }
  
  /* process attribute information (first for ns declarations) */
  
  if (self->attrs == nil)
    self->attrs = [[SaxAttributes alloc] init];
  else
    [self->attrs clear];
  
  if (debugNS) NSLog(@"PROCESS attributes ...");
  lattrs = [self handleAttributesOfNode:_node 
                 nsdecls:&nsDict
                 defaultPrefix:info->prefix];
  if (nsDict == nil)
    nsDict = [NSDictionary dictionary];
  
  NSCAssert(self->nsStack, @"missing namespace stack");
  [self->nsStack addObject:nsDict];
  
  /* do namespace processing */
  
  info->uri = (info->prefix == nil)
    ? nil /* no namespace prefix */
    : [[self nsUriForPrefix:info->prefix] copy];
  if (info->uri == nil) info->uri = [[self defaultNamespace] copy];
  if (debugNS)
    NSLog(@"TAG PREFIX: %@ URI: %@", info->prefix, info->uri);
  
  /* pass on */
  
  self->depth++;
  [self->contentHandler startElement:info->localName
                        namespace:info->uri
                        rawName:info->rawName
                        attributes:lattrs /* id<SaxAttributes> */];
  return info; /* pass back an object */
}
- (void)endElementNode:(CFXMLTagHolder *)_info {
  [self->contentHandler endElement:_info->localName
                        namespace:_info->uri
                        rawName:_info->rawName];
  self->depth--;
  [_info release];

  /* process namespace stack */

  if (self->fNamespaces) {
    NSDictionary *ns;
    NSEnumerator *keys;
    NSString     *key;
    
    ns = [self->nsStack lastObject];
    keys = [ns keyEnumerator];
    while ((key = [keys nextObject])) {
      if ([key isEqualToString:@":"])
        continue;
      [self->contentHandler endPrefixMapping:key];
    }
  }
  [self->nsStack removeLastObject];
}

- (void)piNode:(CFXMLNodeRef)_node {
  [self->contentHandler processingInstruction:(id)CFXMLNodeGetString(_node)
                        data:nil];
}

- (void)commentNode:(CFXMLNodeRef)_node {
  NSString *s;
  unichar  *buf;
  unsigned len;
  
  s   = (NSString *)CFXMLNodeGetString(_node);
  len = [s length];
  buf = calloc(len + 4, sizeof(unichar));
  [s getCharacters:buf];
  
  [self->lexicalHandler comment:buf length:len];
  if (buf) free(buf);
}

- (void)_unicharNode:(CFXMLNodeRef)_node selector:(SEL)_sel {
  NSString *s;
  unsigned len;
  unichar *ownBuf = NULL, *useBuf;
  void (*cb)(id, SEL, unichar *, int);
  
  if (self->contentHandler == nil)
    return;
  if ((s = (NSString *)CFXMLNodeGetString(_node)) == nil)
    return;
  if ((len = [s length]) == 0)
    return;
  
  if ((cb = (void *)[(id)self->contentHandler methodForSelector:_sel])==NULL) {
    /* content-handler does not respond to the selector */
    NSLog(@"ERROR(%s): content handler does not implement %@: %@",
          __PRETTY_FUNCTION__,
          NSStringFromSelector(_sel), self->contentHandler);
    return;
  }
  
  if (self->buffer == NULL) {
    self->buffer  = calloc(256, sizeof(unichar));
    self->bufSize = 250;
  }
  if (len > 250) { /* use an own buffer for larger bodies */
    ownBuf = calloc(len + 10, sizeof(unichar));
    useBuf = ownBuf;
  }
  else
    useBuf = self->buffer;
  
  [s getCharacters:useBuf];
  cb(self->contentHandler, _sel, useBuf, len);
  
  if (ownBuf) free(ownBuf);
}

- (void)textNode:(CFXMLNodeRef)_node {
  if (self->contentHandler == nil) return;
  [self _unicharNode:_node selector:@selector(characters:length:)];
}
- (void)cdataNode:(CFXMLNodeRef)_node {
  if (self->contentHandler == nil) return;
  [self _unicharNode:_node selector:@selector(characters:length:)];
}
- (void)whiteSpaceNode:(CFXMLNodeRef)_node {
  if (self->contentHandler == nil) return;
  [self _unicharNode:_node selector:@selector(ignorableWhitespace:length:)];
}

- (void)dtdNode:(CFXMLNodeRef)_node {
  NSLog(@"DTD: %@", CFXMLNodeGetString(_node));
}

- (void)entityReference:(NSString *)_rid {
  NSString *value;
  
  if (self->contentHandler == nil)
    return;
  
  if ((value = [self->pubIdToValue objectForKey:_rid]) == nil) {
    NSLog(@"ERROR(%s): found no value for entity reference %@", 
          __PRETTY_FUNCTION__, _rid);
  }
  
  if ([value isKindOfClass:[NSString class]]) {
    unsigned len;
    unichar  *ownBuf;
    
    len = [value length];
    ownBuf = calloc(len + 4, sizeof(unichar));
    [value getCharacters:ownBuf];
    [self->contentHandler characters:ownBuf length:len];
    if (ownBuf) free(ownBuf);
  }
  else
    NSLog(@"unknown value class for entity reference %@", _rid);
}

- (NSData *)resolveEntityWithPublicId:(NSString *)_pubId
  systemId:(NSURL *)_sysId
{
  NSLog(@"found to value for entity %@/%@", _pubId, _sysId);
  return nil;
}

- (BOOL)handleErrorCode:(unsigned int)_code
  description:(NSString *)_info 
  line:(int)_line position:(int)_pos
{
  NSLog(@"Parse error (%d) %@ on line %d, character %d\n",
        (int)_code, _info, _line, _pos);
  return NO;
}

/* callbacks */

typedef struct {
  id  info;
  int typeCode;
} ResInfo;

void *createStructure(CFXMLParserRef parser, 
                      CFXMLNodeRef node, void *info) 
{
  CFXMLSaxDriver *self = info;
  CFStringRef myTypeStr = NULL;
  CFStringRef myDataStr = NULL;
  ResInfo *result = NULL;
  
  result = malloc(sizeof(ResInfo));
  result->info = nil;
  result->typeCode = CFXMLNodeGetTypeCode(node);
  
  // Use the dataTypeID to determine what to print.
  switch (CFXMLNodeGetTypeCode(node)) {
    case kCFXMLNodeTypeDocument:
      [self beginDocument:node];
      break;
    
    case kCFXMLNodeTypeElement:
      result->info = [self beginElementNode:node];
      break;
    
    case kCFXMLNodeTypeProcessingInstruction:
      [self piNode:node];
      break;
      
    case kCFXMLNodeTypeComment:
      [self commentNode:node];
      break;
      
    case kCFXMLNodeTypeText:
      [self textNode:node];
      break;
      
    case kCFXMLNodeTypeCDATASection:
      [self cdataNode:node];
      break;
      
    case kCFXMLNodeTypeEntityReference:
      [self entityReference:(NSString *)CFXMLNodeGetString(node)];
      break;
        
    case kCFXMLNodeTypeDocumentType:
      [self dtdNode:node];
      break;
    
    case kCFXMLNodeTypeWhitespace:
      [self whiteSpaceNode:node];
      break;
      
    default:
      NSLog(@"%s: unknown node ID %i", result->typeCode);
      break;
  }

  // Print the contents.
  if (myTypeStr) {
    printf("---Create Structure Called--- \n");
    NSLog(@"type: %@", myTypeStr);
    NSLog(@"data: %@", myDataStr);
  }
  
  // Release the strings.
  if (myTypeStr) CFRelease(myTypeStr);
  
  // Return the data string for use by the addChild and 
  // endStructure callbacks.
  return result;
}

void addChild(CFXMLParserRef parser, void *p, void *child, void *info) {
#if 0 /* a noop */
  NSLog(@"add child %@ to %@ ...", (id)child, (id)p);
#endif
}

void endStructure(CFXMLParserRef parser, void *xmlType, void *info) {
  CFXMLSaxDriver *self = info;
  ResInfo *result = xmlType;
  NSCAssert(self, @"missing self");
  
  switch (result->typeCode) {
    case kCFXMLNodeTypeDocument: /* never called ? */
      [self endDocument:result->info];
      break;
    
    case kCFXMLNodeTypeElement:
      [self endElementNode:result->info];
      break;
    
    /* most nodes do not have an "end" event */
    case kCFXMLNodeTypeProcessingInstruction:
    case kCFXMLNodeTypeComment:
    case kCFXMLNodeTypeText:
    case kCFXMLNodeTypeCDATASection:
    case kCFXMLNodeTypeEntityReference:
    case kCFXMLNodeTypeDocumentType:
    case kCFXMLNodeTypeWhitespace:
      break;
    
    default:
      NSLog(@"%s: unknown node: %i: %@", __PRETTY_FUNCTION__,
            result->typeCode, result->info);
      break;
  }
  if (result) free(result);
}

CFDataRef resolveEntity(CFXMLParserRef parser, CFXMLExternalID *extID, 
                        void *info)
{
  CFXMLSaxDriver *self = info;
  return (CFDataRef)[self resolveEntityWithPublicId:(NSString *)extID->publicID
                          systemId:(NSURL *)extID->systemID];
}

Boolean handleError(CFXMLParserRef parser, CFXMLParserStatusCode error, void *info) {
  CFXMLSaxDriver *self = info;
  NSString *s;
  BOOL     cont;
  
  s = [(id)CFXMLParserCopyErrorDescription(parser) autorelease];
  cont = [self handleErrorCode:error description:s
               line:(int)CFXMLParserGetLineNumber(parser)
               position:(int)CFXMLParserGetLocation(parser)];
  return cont ? TRUE : FALSE;
}

/* parsing */

- (NSStringEncoding)encodingForXMLEncodingString:(NSString *)_enc {
  if ([_enc isEqualToString:@"utf-8"])
    return NSUTF8StringEncoding;
  else if ([_enc isEqualToString:@"iso-8859-1"])
    return NSISOLatin1StringEncoding;
  else if ([_enc isEqualToString:@"ascii"])
    return NSASCIIStringEncoding;
  else {
    NSLog(@"%s: UNKNOWN XML ENCODING '%@'",
          __PRETTY_FUNCTION__, _enc);
  }
  return 0;
}

- (NSData *)dataForXMLString:(NSString *)_string {
  NSData  *data;
  NSRange r;

  data = nil;
  
  r = [_string rangeOfString:@"?>"];
  if ([_string hasPrefix:@"<?xml "] && (r.length != 0)) {
    NSString *xmlDecl;
    
    xmlDecl = [_string substringToIndex:r.location];
    
    r = [xmlDecl rangeOfString:@"encoding='"];
    if (r.length > 0) {
      xmlDecl = [_string substringFromIndex:(r.location + 10)];
      r = [xmlDecl rangeOfString:@"'"];
      xmlDecl = (r.length > 0)
        ? [xmlDecl substringToIndex:r.location]
        : nil;
    }
    else {
      r = [xmlDecl rangeOfString:@"encoding=\""];
      if (r.length > 0) {
        xmlDecl = [_string substringFromIndex:(r.location + 10)];
        r = [xmlDecl rangeOfString:@"'"];
        xmlDecl = r.length > 0
          ? [xmlDecl substringToIndex:r.location]
          : nil;
      }
      else
      xmlDecl = nil;
    }
    
    if ([xmlDecl length] > 0) {
      NSStringEncoding enc;
        
      if ((enc = [self encodingForXMLEncodingString:xmlDecl]) != 0) {
        data = [_string dataUsingEncoding:enc];
        if (data == nil) {
          NSLog(@"WARNING(%s): couldn't get data for string '%@', "
                @"encoding %i !", __PRETTY_FUNCTION__, _string, enc);
          return nil;
        }
      }
    }
  }
  
  if (data == nil)
    data = [_string dataUsingEncoding:NSUTF8StringEncoding];

  return data;
}

static const void *retainParser(const void *info) {
  return [(id)info retain];
}
static void releaseParser(const void *info) {
  [(id)info release];
}
static CFStringRef parserDescription(const void *info) {
  return (CFStringRef)[(id)info description];
}

- (void)parseFromSource:(id)_source systemId:(NSString *)_sysId {
  CFXMLParserCallBacks callbacks = {
    0,
    createStructure,
    addChild,
    endStructure, 
    resolveEntity,
    handleError
  };
  CFXMLParserContext ctx = {
    0    /* version */,
    self /* info */,
    retainParser,
    releaseParser,
    parserDescription /* copyDescription */
  };
  CFXMLParserRef parser;
  NSData *content;
  NSURL  *url = nil;
  
  if (_source == nil) {
    /* no source ??? */
    return;
  }
  
  if ([_source isKindOfClass:[NSString class]]) {
    /* convert strings to UTF8 data */
    if (_sysId == nil) _sysId = @"<string>";
    _source = [self dataForXMLString:_source];
  }
  else if ([_source isKindOfClass:[NSURL class]]) {
    if (_sysId == nil) _sysId = [_source absoluteString];
    _source = [_source resourceDataUsingCache:NO];
  }
  else if ([_source isKindOfClass:[NSData class]]) {
    if (_sysId == nil) _sysId = @"<data>";
  }
  else {
    SaxParseException *e;
    NSDictionary      *ui;
    
    ui = [NSDictionary dictionaryWithObjectsAndKeys:
                         _source ? _source : @"<nil>", @"source",
                         self,                         @"parser",
                         nil];
    
    e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
                               reason:@"can't handle data-source"
                               userInfo:ui];
    
    [self->errorHandler fatalError:e];
    return;
  }
  
  /* get data from source */
  
  content = _source;
  
  if (url == nil) {
    url = _sysId 
      ? [NSURL URLWithString:_sysId] 
      : [NSURL URLWithString:@"object://unknown"];
  }
  
  /* create parser */
  
  parser = CFXMLParserCreate(kCFAllocatorDefault, 
                             (CFDataRef)content, 
                             (CFURLRef)url,
                             kCFXMLParserSkipWhitespace,
                             kCFXMLNodeCurrentVersion, 
                             &callbacks,
                             &ctx);
  if (parser == nil) {
    NSLog(@"got no parser ...");
    exit(1);
  }
  
  /* invoke the parser */
  
  [self->contentHandler startDocument];
  
  if (!CFXMLParserParse(parser))
    printf("parse failed\n");

  [self->contentHandler endDocument];
  
  /* cleanup */
  if (parser) CFRelease(parser);
}

- (void)parseFromSource:(id)_source {
  [self parseFromSource:_source systemId:nil];
}
- (void)parseFromSystemId:(NSString *)_sysId {
  NSURL *url;
  
  if ([_sysId rangeOfString:@"://"].length == 0) {
    /* not a URL */
    if (![_sysId isAbsolutePath])
      _sysId = [[NSFileManager defaultManager] currentDirectoryPath];
    url = [NSURL fileURLWithPath:_sysId];
  }
  else
    url = [NSURL URLWithString:_sysId];
  
  [self parseFromSource:url systemId:_sysId];
}

/* namespace support */

- (NSString *)nsUriForPrefix:(NSString *)_prefix {
  NSEnumerator *e;
  NSDictionary *ns;
  
  if (debugNS)
    NSLog(@"lookup prefix: '%@'", _prefix);
  
  e = [self->nsStack reverseObjectEnumerator];
  while ((ns = [e nextObject])) {
    NSString *uri;
    
    if ((uri = [ns objectForKey:_prefix])) {
      if (debugNS)
        NSLog(@"prefix %@ -> uri '%@'", _prefix, uri);
      return uri;
    }
  }
  if (debugNS)
    NSLog(@"prefix %@ -> NO uri", _prefix);
  //return nil;
  return @"";
}

- (NSString *)defaultNamespace {
  return [self nsUriForPrefix:@":"];
}

- (void)declarePrefix:(NSString *)_prefix namespaceURI:(NSString *)_uri {
  NSMutableDictionary *ns = nil;
  NSDictionary *newns;
  unsigned count;
  
  NSCAssert(self->nsStack, @"missing namespace stack");
  
  if ((count = [self->nsStack count]) == 0)
    ns = [[NSMutableDictionary alloc] initWithCapacity:2];
  else
    ns = [[self->nsStack lastObject] mutableCopy];
  
  if ([_prefix length] == 0)
    _prefix = @":";
  
  [ns setObject:_uri forKey:_prefix];

  newns = [ns copy];
  [ns release];

  if (count == 0)
    [self->nsStack addObject:newns];
  else
    [self->nsStack replaceObjectAtIndex:(count - 1) withObject:newns];
  
  [newns release];
}

@end /* CFXMLSaxDriver */

@implementation CFXMLTagHolder

- (void)dealloc {
  [self->localName release];
  [self->uri       release];
  [self->prefix    release];
  [self->rawName   release];
  [super dealloc];
}

@end /* CFXMLTagHolder */
