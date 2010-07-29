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

#import "libxmlDocSAXDriver.h"
#import "libxmlSAXLocator.h"
#include <SaxObjC/SaxObjC.h>
#include <SaxObjC/SaxException.h>
#include "common.h"
#include <string.h>

#include <libxml/parser.h>
#include <libxml/tree.h>

@interface libxmlDocSAXDriver(PrivateMethods)

- (void)tearDownParser;

- (BOOL)walkDocumentTree:(xmlDocPtr)_doc;
- (BOOL)processNode:(xmlNodePtr)_node;
- (BOOL)processTextNode:(xmlNodePtr)_node;
- (BOOL)processChildren:(xmlNodePtr)children;

@end

static int _UTF8ToUTF16(unsigned char **sourceStart, unsigned char *sourceEnd, 
                        unichar **targetStart, const unichar *targetEnd);

static inline NSString *xmlCharsToString(const xmlChar *_s) {
  static Class NSStringClass = Nil;
  if (NSStringClass == Nil)
    NSStringClass = [NSString class];
  return _s ? [[NSStringClass alloc] initWithUTF8String:(const char*)_s] : nil;
}

static NSString *SaxDeclHandlerProperty =
  @"http://xml.org/sax/properties/declaration-handler";
static NSString *SaxLexicalHandlerProperty =
  @"http://xml.org/sax/properties/lexical-handler";

@implementation libxmlDocSAXDriver

static libxmlDocSAXDriver *activeDriver = nil;
static void warning(void *udata, const char *msg, ...);
static void error(void *udata, const char *msg, ...);
static void fatalError(void *udata, const char *msg, ...);
static void setLocator(void *udata, xmlSAXLocatorPtr _locator);

- (id)init {
  if ((self = [super init])) {
    self->encodeEntities = NO;
  }
  return self;
}

- (void)dealloc {
  [self tearDownParser];
  [self->lexicalHandler release];
  [self->declHandler    release];
  [self->contentHandler release];
  [self->dtdHandler     release];
  [self->errorHandler   release];
  [self->entityResolver release];
  [super dealloc];
}

/* features & properties */

- (void)setFeature:(NSString *)_name to:(BOOL)_value {
  [SaxNotRecognizedException raise:@"FeatureException"
                             format:@"don't know feature %@", _name];
}
- (BOOL)feature:(NSString *)_name {
  [SaxNotRecognizedException raise:@"FeatureException"
                             format:@"don't know feature %@", _name];
  return NO;
}

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

/* handlers */

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

/* libxml */

- (void)setupParserWithDocumentPath:(NSString *)_path {
  static xmlSAXHandler sax;
  
  NSAssert(self->ctxt == NULL, @"DocSAX parser context already setup !");
  
  memcpy(&sax, &xmlDefaultSAXHandler, sizeof(xmlSAXHandler));
  sax.error              = error;
  sax.warning            = warning;
  sax.fatalError         = fatalError;
  sax.setDocumentLocator = setLocator;
  
  NSAssert(activeDriver == nil, @"a parser is already running !");
  activeDriver = self;
  
  self->ctxt = xmlCreatePushParserCtxt(&sax             /* sax      */,
                                       NULL /*self*/    /* userdata */,
                                       NULL             /* chunk    */,
                                       0                /* chunklen */,
                                       [_path cString]  /* filename */);
  self->doc = NULL;
}
- (void)tearDownParser {
  if (activeDriver == self)
    activeDriver = nil;
  
  if (self->doc) {
    xmlFreeDoc(self->doc);
    self->doc = NULL;
  }
  if (self->ctxt) {
    xmlFreeParserCtxt(self->ctxt);
    self->ctxt = NULL;
  }
}

/* IO */

- (void)pushBytes:(const char *)_bytes count:(unsigned)_len {
  if (_len == 0) return;
  NSAssert(self->ctxt, @"missing DocSAX parser context");
  xmlParseChunk(self->ctxt, _bytes, _len, 0);
}
- (void)pushEOF {
  char dummyByte;
  xmlParseChunk(self->ctxt, &dummyByte, 0, 1 /* terminate */);
  self->doc = ((xmlParserCtxtPtr)ctxt)->myDoc;
}

/* parsing */

- (void)_parseFromData:(NSData *)_data systemId:(NSString *)_sysId {
  NSAutoreleasePool *pool;
  
  pool = [[NSAutoreleasePool alloc] init];

  /* parse into structure */
  [self setupParserWithDocumentPath:_sysId];
  [self pushBytes:[_data bytes] count:[_data length]];
  [self pushEOF];
  
  if (self->doc == NULL) {
    NSLog(@"Couldn't parse file: %@", _sysId);
    [self tearDownParser];
  }
  else {
    //NSLog(@"parsed file: %@", _sysId);
    
    [self walkDocumentTree:self->doc];
    [self tearDownParser];
  }
  
  [pool release];
}

- (void)parseFromSource:(id)_source systemId:(NSString *)_sysId {
  if ([_source isKindOfClass:[NSData class]]) {
    [self _parseFromData:_source systemId:nil];
    return;
  }
  if ([_source isKindOfClass:[NSString class]]) {
    [self _parseFromData:[_source dataUsingEncoding:NSISOLatin1StringEncoding]
          systemId:nil];
    return;
  }
  if ([_source isKindOfClass:[NSURL class]]) {
    NSData *data;

    data = [_source isFileURL]
      ? (NSData *)[NSData dataWithContentsOfMappedFile:[_source path]]
      : [_source resourceDataUsingCache:YES];
    
    [self _parseFromData:data systemId:[_source absoluteString]];
    return;
  }
  
  {
    SaxParseException *e;
    NSDictionary      *ui;
    
    ui = [[NSDictionary alloc] initWithObjectsAndKeys:
				 _source ? _source : (id)@"<nil>", @"source",
			         self,                             @"parser",
			       nil];
    
    e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
                               reason:@"cannot handle data-source"
                               userInfo:ui];
    [ui release]; ui = nil;
    
    [self->errorHandler fatalError:e];
  }
}
- (void)parseFromSource:(id)_source {
  if ([_source isKindOfClass:[NSString class]])
    [self parseFromSource:_source systemId:@"<string>"];
  else if ([_source isKindOfClass:[NSData class]])
    [self parseFromSource:_source systemId:@"<data>"];
  else if ([_source isKindOfClass:[NSURL class]])
    [self parseFromSource:_source systemId:[_source absoluteString]];
  else
    [self parseFromSource:_source systemId:@"<memory>"];
}

- (void)parseFromSystemId:(NSString *)_sysId {
  NSAutoreleasePool *pool;
  NSData *data;
  
  if (![_sysId hasPrefix:@"file://"]) {
    /* exception */
    return;
  }
  
  pool = [[NSAutoreleasePool alloc] init];
  
  /* cut off file:// */
  _sysId = [_sysId substringFromIndex:7];
  
  /* load data */
  data = [NSData dataWithContentsOfFile:_sysId];

  [self _parseFromData:data systemId:_sysId];
  
  [pool release];
}

/* process attribute nodes */

- (SaxAttributes *)processAttributes:(xmlAttrPtr)_attributes {
  xmlAttrPtr    attribute;
  SaxAttributes *attributes;
  
  if (_attributes == NULL)
    /* nothing to process */
    return nil;

  /* setup or clear attribute cache */
  
  attributes = [[SaxAttributes alloc] init];
  
  /* add attributes */
  
  for (attribute = _attributes; attribute; attribute = attribute->next) {
    NSString *name;
    NSString *value;
    NSString *nsuri;
#if 0
    printf("attr name '%s' has NS '%s'\n",
           attribute->name, attribute->ns ? "yes" : "no");
#endif
    
    name      = xmlCharsToString(attribute->name);
    value     = @"";
    
    if (attribute->children) {
      xmlChar  *t;
      
      if ((t = xmlNodeListGetString(doc, attribute->children, 0))) {
        value = xmlCharsToString(t);
	free(t); /* should be xmlFree ?? */
      }
    }

    nsuri = (attribute->ns != NULL)
      ? xmlCharsToString(attribute->ns->href)
      : (NSString *)nil;
    
    [attributes addAttribute:name
                uri:nsuri
                rawName:name
                type:@"CDATA" value:value];
    
    [nsuri release]; nsuri = nil;
    [name  release]; name  = nil;
    [value release]; value = nil;
  }
  
  return attributes;
}

/* walking the tree, generating SAX events */

- (BOOL)_resolveEntityReferences {
  return YES;
}

- (BOOL)processEntityRefNode:(xmlNodePtr)_node {
  if ([self _resolveEntityReferences])
    return [self processTextNode:_node];
  else {
    NSString *refName;
    NSString *entityValue;

    refName     = xmlCharsToString(_node->name);
    entityValue = xmlCharsToString(_node->content);

#if 0
    NSLog(@"%s:%i: Ignoring entity ref: '%@' %s\n",
          __PRETTY_FUNCTION__, __LINE__, refName, _node->content);
#endif
  
    [entityValue release];
    [refName     release];
    return YES;
  }
}

- (BOOL)processDocumentNode:(xmlNodePtr)node {
  BOOL result;
  
  [self->contentHandler startDocument];
  [self->contentHandler
       startPrefixMapping:@""
       uri:@"http://www.w3.org/XML/1998/namespace"];
  result = [self processChildren:node->children];
  [self->contentHandler endPrefixMapping:@""];
  [self->contentHandler endDocument];
  
  return result;
}

- (BOOL)processTextNode:(xmlNodePtr)_node {
  static unichar c = '\0';
  
  if (self->contentHandler == nil)
    return YES;
  
  if (_node->content) {
    xmlChar *chars;
    
    if (self->encodeEntities) {
      /* should use the DocSAX encoding routine (htmlEncodeEntities) ??? */
      
      chars = xmlEncodeEntitiesReentrant(self->doc, _node->content);
    }
    else
      chars = _node->content;
    
    if (chars == NULL) {
      [self->contentHandler characters:&c length:0];
    }
    else {
      void     *data, *ts;
      unsigned len;
      
      len = strlen((char *)chars);
      data = ts = calloc(len + 1, sizeof(unichar)); /* GC ?! */
      
      if (_UTF8ToUTF16((void *)&chars, (void *)(chars + len),
                       (void *)&ts, ts + (len * sizeof(unichar)))) {
        free(data);
        NSLog(@"ERROR(%s:%i): couldn't convert UTF8 to UTF16 !",
              __PRETTY_FUNCTION__, __LINE__);
        return NO;
      }
      
      [self->contentHandler characters:data length:(unsigned)(ts - data)];
      
      free(data);
    }
  }
  else
    [self->contentHandler characters:&c length:0];
  
  return YES;
}

- (BOOL)processCommentNode:(xmlNodePtr)_node {
  unichar c = '\0';
  
  if (self->lexicalHandler == nil)
    return YES;
  
  if (_node->content) {
    xmlChar  *chars;
    
    /* uses the DocSAX encoding routine !!!!!!!!!! */
    chars = xmlEncodeEntitiesReentrant(self->doc, _node->content);
    
    if (chars == NULL) {
      [self->lexicalHandler comment:&c length:0];
    }
    else {
      void     *data, *ts;
      unsigned len;
    
      len = strlen((const char *)chars);
      data = ts = calloc(len + 1, sizeof(unichar)); /* GC ?! */
  
      if (_UTF8ToUTF16((void *)&chars, (void *)(chars + len),
                       (void *)&ts, ts + (len * sizeof(unichar)))) {
        free(data);
        NSLog(@"ERROR(%s:%i): couldn't convert UTF8 to UTF16 !",
              __PRETTY_FUNCTION__, __LINE__);
        return NO;
      }
      
      [self->lexicalHandler comment:data length:(ts - data)];
      
      free(data);
    }
  }
  else
    [self->lexicalHandler comment:&c length:0];
  
  return YES;
}

- (BOOL)processDTDNode:(xmlNodePtr)node {
  /* do nothing with DTD nodes .. */
  return YES;
}

- (BOOL)processEntityNode:(xmlNodePtr)node {
  /* do nothing with entity nodes .. */
  NSLog(@"%s:%i: ignoring entity node (name='%s') ...",
        __PRETTY_FUNCTION__, __LINE__, node->name);
  return YES;
}

- (BOOL)processPINode:(xmlNodePtr)node {
  NSString *piName;
  NSString *piValue;
  
  piName  = xmlCharsToString(node->name);
  piValue = xmlCharsToString(node->content);
  
  [self->contentHandler processingInstruction:piName data:piValue];

  [piName  release];
  [piValue release];
  return YES;
}

- (BOOL)processElementNode:(xmlNodePtr)node {
  id<NSObject,SaxAttributes> attrs;
  NSString *tagName;
  NSString *nsuri;
  BOOL     result;
  
  self->depth++;
  
  tagName = xmlCharsToString(node->name);
  nsuri = (node->ns != NULL)
    ? xmlCharsToString(node->ns->href)
    : (NSString *)nil;
  
  attrs = [self processAttributes:node->properties];
  
  [self->contentHandler
       startElement:tagName
       namespace:nsuri
       rawName:tagName
       attributes:attrs];
  
  [attrs release]; attrs = nil;
  
  result = [self processChildren:node->children];
  
  [self->contentHandler
       endElement:tagName
       namespace:nsuri
       rawName:tagName];
  
  self->depth--;

  [nsuri   release]; nsuri   = nil;
  [tagName release]; tagName = nil;
  [attrs   release]; attrs   = nil;
  return result;
}

- (BOOL)processChildren:(xmlNodePtr)children {
  xmlNodePtr node;
  
  if (children == NULL)
    return YES;
  
  for (node = children; node; node = node->next) {
    [self processNode:node];
  }
  
  return YES;
}

- (BOOL)processNode:(xmlNodePtr)_node {
  switch(_node->type) {
    case XML_ELEMENT_NODE:
      return [self processElementNode:_node];

    case XML_ATTRIBUTE_NODE:
      NSLog(@"invalid place for attribute-node !");
      return NO;
      
    case XML_TEXT_NODE:
      return [self processTextNode:_node];

    case XML_CDATA_SECTION_NODE:
      return [self processTextNode:_node];
      
    case XML_ENTITY_REF_NODE:
      return [self processEntityRefNode:_node];

    case XML_ENTITY_NODE:
      return [self processEntityNode:_node];
      
    case XML_PI_NODE:
      return [self processPINode:_node];
      
    case XML_COMMENT_NODE:
      return [self processCommentNode:_node];
      
    case XML_DOCUMENT_NODE:
      return [self processDocumentNode:_node];
      
    case XML_DTD_NODE:
      return [self processDTDNode:_node];
    
    default:
      NSLog(@"WARNING: UNKNOWN node type %i\n", _node->type);
      break;
  }
  return NO;
}

- (BOOL)walkDocumentTree:(xmlDocPtr)_doc {
  int  type;
  BOOL result;
  
  type = ((xmlDocPtr)self->doc)->type;
  ((xmlDocPtr)self->doc)->type = XML_DOCUMENT_NODE;
  
  result = [self processNode:(xmlNodePtr)self->doc];
  
  ((xmlDocPtr)self->doc)->type = type;
  
  return result;
}

/* callbacks */

static SaxParseException *
mkException(libxmlDocSAXDriver *self, NSString *key,
            const char *msg, va_list va)
{
  NSString          *s, *reason;
  NSDictionary      *ui;
  SaxParseException *e;
  int count = 0, i;
  id  keys[7], values[7];
  id  tmp;
  NSRange r;
  
  s = [NSString stringWithCString:msg];
  s = [[[NSString alloc]
                  initWithFormat:s arguments:va]
                  autorelease];
  
  r = [s rangeOfString:@"\n"];
  reason = (r.length > 0)
    ? [s substringToIndex:r.location]
    : s;
  
  if ([reason length] == 0)
    reason = @"unknown reason";
  
  keys[0] = @"parser"; values[0] = self; count++;
  keys[1] = @"depth";  values[1] = [NSNumber numberWithInt:self->depth]; count++;
  
  if ([s length] > 0) {
    keys[count]   = @"errorMessage";
    values[count] = s;
    count++;
  }

  // NSLog(@"locator: %@", self->locator);
  
  if ((i = [self->locator lineNumber]) >= 0) {
    keys[count] = @"line";
    values[count] = [NSNumber numberWithInt:i];
    count++;
  }
  if ((i = [self->locator columnNumber]) >= 0) {
    keys[count] = @"column";
    values[count] = [NSNumber numberWithInt:i];
    count++;
  }
  if ((tmp = [self->locator publicId])) {
    keys[count]   = @"publicId";
    values[count] = tmp;
    count++;
  }
  if ((tmp = [self->locator systemId])) {
    keys[count]   = @"systemId";
    values[count] = tmp;
    count++;
  }
  
  ui = [NSDictionary dictionaryWithObjects:values forKeys:keys count:count];
  
  e = (id)[SaxParseException exceptionWithName:key
                             reason:reason
                             userInfo:ui];
  return e;
}

static void warning(void *udata, const char *msg, ...) {
  va_list           args;
  SaxParseException *e;
  
  NSCAssert(activeDriver, @"no driver is active !");
  
  va_start(args, msg);
  e = mkException(activeDriver, @"SAXWarning", msg, args);
  va_end(args);
  
  [activeDriver->errorHandler warning:e];
}

static void error(void *udata, const char *msg, ...) {
  va_list           args;
  SaxParseException *e;

  NSCAssert(activeDriver, @"no driver is active !");
  
  va_start(args, msg);
  e = mkException(activeDriver, @"SAXError", msg, args);
  va_end(args);
  
  [activeDriver->errorHandler error:e];
}

static void fatalError(void *udata, const char *msg, ...) {
  va_list           args;
  SaxParseException *e;

  NSCAssert(activeDriver, @"no driver is active !");
  
  va_start(args, msg);
  e = mkException(activeDriver, @"SAXFatalError", msg, args);
  va_end(args);
  
  [activeDriver->errorHandler fatalError:e];
}

static void setLocator(void *udata, xmlSAXLocatorPtr _locator) {
  NSCAssert(activeDriver, @"no driver is active !");
  
  [activeDriver->locator release];
  
  activeDriver->locator = [[libxmlSAXLocator alloc]
                                             initWithSaxLocator:_locator
                                             parser:activeDriver];
  activeDriver->locator->ctx = activeDriver->ctxt;
  
  [activeDriver->contentHandler setDocumentLocator:activeDriver->locator];
}

@end /* libxmlDocSAXDriver */

#include "unicode.h"
