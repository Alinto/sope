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

#import "libxmlHTMLSAXDriver.h"
#import "libxmlSAXLocator.h"
#include "TableCallbacks.h"
#include <SaxObjC/SaxObjC.h>
#include <SaxObjC/SaxException.h>
#include "common.h"
#include <string.h>

#include <libxml/HTMLparser.h>
#include <libxml/HTMLtree.h>

@interface NSObject(contentHandlerExtensions)

- (xmlCharEncoding)contentEncoding;

@end

@interface libxmlHTMLSAXDriver(PrivateMethods)

- (void)tearDownParser;

- (BOOL)walkDocumentTree:(xmlDocPtr)_doc;
- (BOOL)processNode:(xmlNodePtr)_node;
- (BOOL)processChildren:(xmlNodePtr)children;

@end

static int _UTF8ToUTF16(unsigned char **sourceStart, unsigned char *sourceEnd, 
                        unichar **targetStart, const unichar *targetEnd);

static BOOL       logUnsupportedFeatures = NO;
static BOOL       reportInvalidTags      = NO;
static BOOL       reportUnclosedEntities = NO;
static NSMapTable *uniqueStrings = NULL; // THREAD
static Class      NSStringClass = Nil;

/* error string detection */
/*
  TODO: obviously this may change between libxml versions or even
        localisations ... why doesn't libxml support error codes ?
        (or does it ?)
*/
static const char *tagInvalidMsg = "tag %s invalid";
static const char *unclosedEntityInvalidMsg = 
  "htmlParseEntityRef: expecting ';'";
#if 0
static const char *unexpectedNobrCloseMsg = 
  "Unexpected end tag : %s";
#endif

static inline NSString *xmlCharsToString(const xmlChar *_s) {
  NSString *s;
  char *newkey;
  
  if (_s == NULL) return nil;
  
  if (uniqueStrings == NULL) {
    uniqueStrings = NSCreateMapTable(libxmlNonOwnedCStringMapKeyCallBacks,
                                     NSObjectMapValueCallBacks,
                                     128);
  }
  else if ((s = NSMapGet(uniqueStrings, _s))) {
    /* found a string in cache ... */
    return [s retain];
  }
  
  newkey = malloc(strlen((char *)_s) + 2);
  strcpy(newkey, (char *)_s);
  
  if (NSStringClass == Nil)
    NSStringClass = [NSString class];
  
  s = [[NSStringClass alloc] initWithUTF8String:(const char *)_s];
  NSMapInsert(uniqueStrings, newkey, s);
  return s;
}

static NSString *SaxDeclHandlerProperty =
  @"http://xml.org/sax/properties/declaration-handler";
static NSString *SaxLexicalHandlerProperty =
  @"http://xml.org/sax/properties/lexical-handler";

static NSString *XMLNS_XHTML = @"http://www.w3.org/1999/xhtml";

@implementation libxmlHTMLSAXDriver

static libxmlHTMLSAXDriver *activeDriver = nil;
static void warning(void *udata, const char *msg, ...);
static void error(void *udata, const char *msg, ...);
static void fatalError(void *udata, const char *msg, ...);
static void setLocator(void *udata, xmlSAXLocatorPtr _locator);

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  reportInvalidTags  = [ud boolForKey:@"libxmlHTMLSAXDriverReportInvalidTags"];
  reportUnclosedEntities = 
    [ud boolForKey:@"libxmlHTMLSAXDriverReportUnclosedEntityRefs"];
}

- (id)init {
  if ((self = [super init])) {
    self->namespaceURI   = [XMLNS_XHTML copy];
    self->encodeEntities = NO;
  }
  return self;
}

- (void)dealloc {
  [self tearDownParser];
  
  [self->attributes     release];
  [self->namespaceURI   release];
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
  if (logUnsupportedFeatures)
    NSLog(@"%s: don't know feature %@", __PRETTY_FUNCTION__, _name);
}
- (BOOL)feature:(NSString *)_name {
  if (logUnsupportedFeatures)
    NSLog(@"%s: don't know feature %@", __PRETTY_FUNCTION__, _name);
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

- (void)setContentHandler:(id <NSObject,SaxContentHandler>)_handler {
  ASSIGN(self->contentHandler, _handler);
}
- (id <NSObject,SaxContentHandler>)contentHandler {
  return self->contentHandler;
}

/* libxml */

- (void)setupParserWithDocumentPath:(NSString *)_path {
  xmlSAXHandler   sax;
  xmlCharEncoding charEncoding;
  
  if (self->ctxt != NULL) {
    NSLog(@"WARNING(%s): HTML parser context already setup !",
          __PRETTY_FUNCTION__);
    [self tearDownParser];
  }
  
  memcpy(&sax, &htmlDefaultSAXHandler, sizeof(xmlSAXHandler));
  sax.error              = error;
  sax.warning            = warning;
  sax.fatalError         = fatalError;
  sax.setDocumentLocator = setLocator;
  
  if (activeDriver != nil) {
    NSLog(@"WARNING(%s): %@ there is an active driver set (%@), override !",
          __PRETTY_FUNCTION__, self, activeDriver);
  }
  activeDriver = self;
  
  // hh: thats really a very ugly hack. The content-handler is for handling
  //     content, not for dealing with the input data.
  // TBD: the charset should be derived from the input (and this method should
  //      probably take a charset)
  if ([self->contentHandler respondsToSelector:@selector(contentEncoding)])
    charEncoding = [self->contentHandler contentEncoding];
  else
    charEncoding = XML_CHAR_ENCODING_8859_1;
  
  // TBD: do not use cString (nor UTF8String) but NSFileManager to convert
  //      a string into a path
  self->ctxt = htmlCreatePushParserCtxt(&sax             /* sax      */,
                                        NULL /*self*/    /* userdata */,
                                        NULL             /* chunk    */,
                                        0                /* chunklen */,
                                        [_path cString]  /* filename */,
                                        charEncoding     /* encoding */);
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
    htmlFreeParserCtxt(self->ctxt);
    self->ctxt = NULL;
  }
}

/* IO */

- (void)pushBytes:(const char *)_bytes count:(unsigned)_len {
  if (_len == 0) return;
  NSAssert(self->ctxt, @"missing HTML parser context");
  htmlParseChunk(self->ctxt, _bytes, _len, 0);
}
- (void)pushEOF {
  char dummyByte;
  htmlParseChunk(self->ctxt, &dummyByte, 0, 1 /* terminate */);
  self->doc = ((xmlParserCtxtPtr)ctxt)->myDoc;
}

/* parsing */

- (void)_handleEmptyDataInSystemId:(NSString *)_sysId {
  /*
     An empty HTML file _is_ valid?!
     I guess it equals to <html><body></body></html>, wrong? => hh
  */
  [self->contentHandler startDocument];
  [self->contentHandler startPrefixMapping:@"" uri:self->namespaceURI];

  [self->contentHandler
       startElement:@"html" namespace:XMLNS_XHTML
       rawName:@"html" attributes:nil];
  [self->contentHandler
       startElement:@"body" namespace:XMLNS_XHTML
       rawName:@"body" attributes:nil];
  
  [self->contentHandler
       endElement:@"body" namespace:XMLNS_XHTML rawName:@"body"];
  [self->contentHandler
       endElement:@"html" namespace:XMLNS_XHTML rawName:@"html"];
  
  [self->contentHandler endPrefixMapping:@""];
  [self->contentHandler endDocument];
}

- (void)_parseFromData:(NSData *)_data systemId:(NSString *)_sysId {
  NSAutoreleasePool *pool;

  if ([_data length] == 0) {
    [self _handleEmptyDataInSystemId:_sysId];
    return;
  }
  
  pool = [[NSAutoreleasePool alloc] init];

  /* parse into structure */
  [self setupParserWithDocumentPath:_sysId];
  [self pushBytes:[_data bytes] count:[_data length]];
  [self pushEOF];
  
  if (self->doc == NULL) {
    NSLog(@"Could not parse HTML file: %@", _sysId);
    [self tearDownParser];
  }
  else {
    [self walkDocumentTree:self->doc];
    [self tearDownParser];
  }
  
  [pool release];
}

- (void)parseFromSource:(id)_source systemId:(NSString *)_sysId {
  NSAutoreleasePool *pool;

  pool = [[NSAutoreleasePool alloc] init];
  
  if ([_source isKindOfClass:[NSData class]]) {
    [self _parseFromData:_source systemId:_sysId];
    return;
  }
  if ([_source isKindOfClass:[NSString class]]) {
    [self _parseFromData:[_source dataUsingEncoding:NSISOLatin1StringEncoding]
          systemId:_sysId];
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
                               reason:@"can not handle data-source"
                               userInfo:ui];
    [ui release]; ui = nil;
    
    [self->errorHandler fatalError:e];
  }

  [self tearDownParser];
  
  [pool release];
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

- (void)processAttributes:(xmlAttrPtr)_attributes {
  xmlAttrPtr  attribute;
  
  /* setup or clear attribute cache */
  if (self->attributes == nil)
    attributes = [[SaxAttributes alloc] init];
  else
    [attributes clear];
  
  if (_attributes == NULL)
    /* nothing to process */
    return;

  /* add attributes */
  
  for (attribute = _attributes; attribute; attribute = attribute->next) {
    NSString *name, *xhtmlName;
    NSString *value;
#if 0
    printf("attr name '%s' has NS '%s'\n",
           attribute->name, attribute->ns ? "yes" : "no");
#endif
    
    name      = xmlCharsToString(attribute->name);
    xhtmlName = [name lowercaseString];
    value     = @"";
    
    if (attribute->children) {
      xmlChar  *t;
      
      if ((t = xmlNodeListGetString(doc, attribute->children, 0))) {
        value = xmlCharsToString(t);
	free(t); /* should be xmlFree ?? */
      }
    }
    
    [attributes addAttribute:xhtmlName
                uri:self->namespaceURI
                rawName:name
                type:@"CDATA" value:value];

    [name  release]; name  = nil;
    [value release]; value = nil;
  }
  
  return;
}

/* walking the tree, generating SAX events */

- (BOOL)processEntityRefNode:(xmlNodePtr)node {
  NSLog(@"Ignoring entity ref: '%s'\n", node->name);
  return YES;
}

- (BOOL)processDocumentNode:(xmlNodePtr)node {
  BOOL result;
  
  [self->contentHandler startDocument];
  [self->contentHandler startPrefixMapping:@"" uri:self->namespaceURI];
  result = [self processChildren:node->children];
  [self->contentHandler endPrefixMapping:@""];
  [self->contentHandler endDocument];
  
  return result;
}

- (BOOL)processTextNode:(xmlNodePtr)_node {
  static unichar c = '\0';
  xmlChar  *chars;
  unsigned len;
  
  if (self->contentHandler == nil)
    return YES;

  if (_node->content == NULL) {
    [self->contentHandler characters:&c length:0];
    return YES;
  }
  
  if (self->encodeEntities) {
    /* should use the HTML encoding routine (htmlEncodeEntities) ??? */
      
    chars = xmlEncodeEntitiesReentrant(self->doc, _node->content);
  }
  else
    chars = _node->content;
  
  if (chars == NULL) {
    [self->contentHandler characters:&c length:0];
    return YES;
  }
  if ((len = strlen((char *)chars)) == 0) {
    unichar c = '\0';
    [self->contentHandler characters:&c length:0];
    return YES;
  }
  
  {
    void *data, *ts;
    
    data = ts = calloc(len + 2, sizeof(unichar)); /* GC ?! */
  
    if (_UTF8ToUTF16((void *)&chars, (void *)(chars + len),
                     (void *)&ts, ts + (len * sizeof(unichar)))) {
      NSLog(@"ERROR(%s:%i): couldn't convert UTF8 to UTF16 !",
            __PRETTY_FUNCTION__, __LINE__);
      if (data) free(data);
      return NO;
    }

    len = (ts - data) / 2;
    [self->contentHandler characters:data length:len];
    
    if (data) free(data);
  }
  
  return YES;
}

- (BOOL)processCommentNode:(xmlNodePtr)_node {
  unichar c = '\0';
  
  if (self->lexicalHandler == nil)
    return YES;
  
  if (_node->content) {
    xmlChar  *chars;
    
    /* uses the HTML encoding routine !!!!!!!!!! */
    chars = xmlEncodeEntitiesReentrant(self->doc, _node->content);
    
    if (chars == NULL) {
      [self->lexicalHandler comment:&c length:0];
    }
    else {
      unsigned len;
      
      if ((len = strlen((char *)chars)) > 0) {
        void *data, *ts;
        
        data = ts = calloc(len + 1, sizeof(unichar)); /* GC ?! */
  
        if (_UTF8ToUTF16((void *)&chars, (void *)(chars + len),
                         (void *)&ts, ts + (len * sizeof(unichar)))) {
          free(data);
          NSLog(@"ERROR(%s:%i): couldn't convert UTF8 to UTF16 !",
                __PRETTY_FUNCTION__, __LINE__);
          return NO;
        }
        
        len = (ts - data) / 2;
        [self->lexicalHandler comment:data length:len];
        
        free(data);
      }
      else {
        unichar c = '\0';
        [self->lexicalHandler comment:&c length:0];
      }
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
  NSLog(@"%s:%i: ignoring entity node ..", __PRETTY_FUNCTION__, __LINE__);
  return YES;
}
- (BOOL)processPINode:(xmlNodePtr)node {
  /* do nothing with PI nodes .. */
  return YES;
}

- (BOOL)processElementNode:(xmlNodePtr)node {
  const htmlElemDesc *tagInfo;
  NSString *tagName, *xhtmlName;
  BOOL     result;
  
  self->depth++;
  
  tagInfo   = htmlTagLookup(node->name);
  tagName   = xmlCharsToString(node->name);
  xhtmlName = [tagName lowercaseString];
  
  [self processAttributes:node->properties];
  
  [self->contentHandler
       startElement:xhtmlName
       namespace:self->namespaceURI
       rawName:tagName
       attributes:self->attributes];
  
  [self->attributes clear];
  
  result = [self processChildren:node->children];
  
  [self->contentHandler
       endElement:xhtmlName
       namespace:self->namespaceURI
       rawName:tagName];
  
  self->depth--;
  
  [tagName release];
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
      
    case HTML_TEXT_NODE:
      return [self processTextNode:_node];

    case XML_CDATA_SECTION_NODE:
      return [self processTextNode:_node];
      
    case HTML_ENTITY_REF_NODE:
      return [self processEntityRefNode:_node];

    case XML_ENTITY_NODE:
      return [self processEntityNode:_node];
      
    case XML_PI_NODE:
      return [self processPINode:_node];
      
    case HTML_COMMENT_NODE:
      return [self processCommentNode:_node];
      
    case XML_HTML_DOCUMENT_NODE:
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
  ((xmlDocPtr)self->doc)->type = XML_HTML_DOCUMENT_NODE;
  
  result = [self processNode:(xmlNodePtr)self->doc];
  
  ((xmlDocPtr)self->doc)->type = type;
  
  return result;
}

/* callbacks */

static SaxParseException *
mkException(libxmlHTMLSAXDriver *self, NSString *key,
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
  keys[1] = @"depth";
  values[1] = [NSNumber numberWithInt:self->depth]; count++;
  
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
  
  if (activeDriver == nil) {
    NSLog(@"ERROR(%s): no driver is active !", __PRETTY_FUNCTION__);
    return;
  }
  
  va_start(args, msg);
  e = mkException(activeDriver, @"SAXWarning", msg, args);
  va_end(args);
  
  [activeDriver->errorHandler warning:e];
}

static void error(void *udata, const char *msg, ...) {
  va_list           args;
  SaxParseException *e;
  
  if (!reportInvalidTags && msg != NULL) {
    if (toupper(msg[0]) == 'T') {
      if (strncasecmp(tagInvalidMsg, msg, strlen(tagInvalidMsg)) == 0)
        return;
    }
#if 0
    else if (toupper(msg[0]) == 'U') {
      if (strncasecmp(unexpectedNobrCloseMsg, msg, 
                      strlen(unexpectedNobrCloseMsg)) == 0)
        return;
      printf("MSG: '%s'\n", msg);
    }
#endif
  }
  if (!reportUnclosedEntities && msg != NULL && toupper(msg[0]) == 'H') {
    if (strncasecmp(unclosedEntityInvalidMsg, msg, 
                    strlen(unclosedEntityInvalidMsg)) == 0)
      return;
  }
  
  if (activeDriver == nil) {
    NSLog(@"ERROR(%s): no driver is active !", __PRETTY_FUNCTION__);
    return;
  }
  
  /* msg is a format, eg 'tag %s is invalid' */
  
  va_start(args, msg);
  e = mkException(activeDriver, @"SAXError", msg, args);
  va_end(args);
  
  [activeDriver->errorHandler error:e];
}

static void fatalError(void *udata, const char *msg, ...) {
  va_list           args;
  SaxParseException *e;
  
  if (activeDriver == nil) {
    NSLog(@"ERROR(%s): no driver is active !", __PRETTY_FUNCTION__);
    return;
  }
  
  va_start(args, msg);
  e = mkException(activeDriver, @"SAXFatalError", msg, args);
  va_end(args);
  
  [activeDriver->errorHandler fatalError:e];
}

static void setLocator(void *udata, xmlSAXLocatorPtr _locator) {
  if (activeDriver == nil) {
    NSLog(@"ERROR(%s): no driver is active !", __PRETTY_FUNCTION__);
    return;
  }
  
  [activeDriver->locator release];
  
  activeDriver->locator = [[libxmlSAXLocator alloc]
                                             initWithSaxLocator:_locator
                                             parser:activeDriver];
  activeDriver->locator->ctx = activeDriver->ctxt;
  
  [activeDriver->contentHandler setDocumentLocator:activeDriver->locator];
}

@end /* libxmlHTMLSAXDriver */

#include "unicode.h"
