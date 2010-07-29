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

#include "libxmlSAXDriver.h"
#include "libxmlSAXLocator.h"
#include "TableCallbacks.h"
#include <SaxObjC/SaxException.h>
#include <SaxObjC/SaxAttributes.h>
#include "common.h"
#include <string.h>

#include <libxml/parser.h>

/*
  TODO: xmlChar is really UTF-8, not cString !!!
*/

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

static int _UTF8ToUTF16(unsigned char **sourceStart, unsigned char *sourceEnd, 
                        unichar **targetStart, const unichar *targetEnd);

static NSMapTable *uniqueStrings = NULL; // THREAD
static Class NSStringClass = Nil;

static inline NSString *xmlCharsToString(const xmlChar *_s) {
  NSString *s;
  char *newkey;
  
  if (_s == NULL) return nil;

  // TODO: does the uniquer really make sense?
  //       best would to have an -initWithUTF...nocopy:YES
  if (uniqueStrings == NULL) {
    uniqueStrings = NSCreateMapTable(libxmlNonOwnedCStringMapKeyCallBacks,
                                     NSObjectMapValueCallBacks,
                                     128);
  }
  else if ((s = NSMapGet(uniqueStrings, _s))) {
    /* found a string in cache ... */
    return [s retain];
  }
  
  newkey = malloc(strlen((const char *)_s) + 2);
  strcpy(newkey, (const char *)_s);
  
  if (NSStringClass == Nil)
    NSStringClass = [NSString class];
  
  s = [[NSStringClass alloc] initWithUTF8String:(const char *)_s];
  NSMapInsert(uniqueStrings, newkey, s);
  return s;
}

static inline NSString *xmlCharsToDecodedString(const xmlChar *_s) {
  NSString *s;
  BOOL     needsDecoding = NO;
  unichar  (*charAt)(id, SEL, unsigned int);
  unsigned i, len, last;

  if (_s == NULL) return nil;
  
  if (NSStringClass == Nil)
    NSStringClass = [NSString class];
  
  s      = [[NSStringClass alloc] initWithUTF8String:(const char *)_s];
  len    = [s length];
  charAt = (void *)[s methodForSelector:@selector(characterAtIndex:)];

  for (i = 0; i < len; i++) {
    if (charAt(s, @selector(characterAtIndex:), i) == '&') {
      needsDecoding = YES;
      last          = 0;
      break;
    }
  }
  
  if (needsDecoding) {
    // TODO: This needs *serious* cleanup. Two small unichar buffers
    //       would be 10x faster and half the codesize.
    NSMutableString *ds;
    
    ds = [[NSMutableString alloc] initWithCapacity:len];
    for (; i < len; i++) {
      if (charAt(s, @selector(characterAtIndex:), i) == '&') {
        NSRange r;
        
        r = NSMakeRange(last, i - last);
        [ds appendString:[s substringWithRange:r]];
        if (charAt(s, @selector(characterAtIndex:), i + 1) == '#') {
          NSRange vr;
          unichar c;

          r = NSMakeRange(i + 2, len - i - 2);
          r = [s rangeOfString:@";" options:0 range:r];
          c = (unichar)charAt(s, @selector(characterAtIndex:), i + 2);
          /* hex value? */
          if (c == 'x' || c == 'X') {
            const char *shex;
            unsigned   value;
            
            vr    = NSMakeRange(i + 3, r.location - i - 3);
            shex  = [[s substringWithRange:vr] cString];
            sscanf(shex, "%x", &value);
            c = (unichar)value;
          }
          else {
            vr = NSMakeRange(i + 2, r.location - i - 2);
            c  = (unichar)[[s substringWithRange:vr] intValue];
          }
          [ds appendString:[NSString stringWithCharacters:&c length:1]];
          i    = NSMaxRange(r);
          last = i;
        }
        else {
          if ((charAt(s, @selector(characterAtIndex:), i + 1) == 'a') &&
              (charAt(s, @selector(characterAtIndex:), i + 2) == 'm') &&
              (charAt(s, @selector(characterAtIndex:), i + 3) == 'p'))
          {
            [ds appendString:@"&"];
            i += 5;
          }
          else if ((charAt(s, @selector(characterAtIndex:), i + 1) == 'q') &&
                   (charAt(s, @selector(characterAtIndex:), i + 2) == 'u') &&
                   (charAt(s, @selector(characterAtIndex:), i + 3) == 'o') &&
                   (charAt(s, @selector(characterAtIndex:), i + 4) == 't'))
          {
            [ds appendString:@"\""];
            i += 6;
          }
          else if ((charAt(s, @selector(characterAtIndex:), i + 1) == 'a') &&
                   (charAt(s, @selector(characterAtIndex:), i + 2) == 'p') &&
                   (charAt(s, @selector(characterAtIndex:), i + 3) == 'o') &&
                   (charAt(s, @selector(characterAtIndex:), i + 4) == 's'))
          {
            [ds appendString:@"'"];
            i += 6;
          }
          else if ((charAt(s, @selector(characterAtIndex:), i + 1) == 'l') &&
                   (charAt(s, @selector(characterAtIndex:), i + 2) == 't'))
          {
            [ds appendString:@"<"];
            i += 4;
          }
          else if ((charAt(s, @selector(characterAtIndex:), i + 1) == 'g') &&
                   (charAt(s, @selector(characterAtIndex:), i + 2) == 't'))
          {
            [ds appendString:@">"];
            i += 4;
          }
          else {
            NSRange r;
            
            r = NSMakeRange(i + 1, len - i - 1);
            r = [s rangeOfString:@";" options:0 range:r];
            r = NSMakeRange(i, r.location - i);
            [ds appendString:[s substringWithRange:r]];
            i = NSMaxRange(r);
          }
          last = i;
        }
      }
    }
    if (last != (len - 1))
      [ds appendString:[s substringFromIndex:last]];
    [s release];
    s = ds;
  }
  return s;
}

extern xmlParserCtxtPtr xmlCreateMemoryParserCtxt(char *buffer, int size);

@implementation libxmlSAXDriver

static libxmlSAXDriver *activeDriver = nil; // THREAD

#define SETUP_ACTDRIVER \
  { if (activeDriver != nil) { \
      NSLog(@"ERROR(%s): %@ there is an active driver set (0x%p), " \
            @"override!", \
            __PRETTY_FUNCTION__, self, activeDriver);\
    }\
    activeDriver = self;}

#define TEARDOWN_ACTDRIVER \
  { if (activeDriver == self) activeDriver = nil; \
    else if (activeDriver != nil) {               \
      NSLog(@"ERROR(%s): %@ activeDriver global var mixed up 0x%p, " \
            @"probably a THREAD issue.", \
            __PRETTY_FUNCTION__, self, activeDriver); } }

static void
_startElement(libxmlSAXDriver *self, const xmlChar *name, const xmlChar **atts);
static void _endElement(libxmlSAXDriver *self, const xmlChar *name);
static void _startDocument(libxmlSAXDriver *self);
static void _endDocument(libxmlSAXDriver *self);
static void _characters(libxmlSAXDriver *self, const xmlChar *chars, int len);
static void
_ignorableWhiteSpace(libxmlSAXDriver *self, const xmlChar *chars, int len);
static void __pi(libxmlSAXDriver *self, const xmlChar *target, const xmlChar *data);
static void _comment(libxmlSAXDriver *self, const xmlChar *value);
static xmlParserInputPtr
_resolveEntity(libxmlSAXDriver *self, const xmlChar *pub, const xmlChar *sys)
     __attribute__((unused));
static xmlEntityPtr _getEntity(libxmlSAXDriver *self, const xmlChar *name)
     __attribute__((unused));
static void _warning(libxmlSAXDriver *self, const char *msg, ...);
static void _error(libxmlSAXDriver *self, const char *msg, ...);
static void _fatalError(libxmlSAXDriver *self, const char *msg, ...);
static void _setLocator(void *udata, xmlSAXLocatorPtr _locator);
static void _cdataBlock(libxmlSAXDriver *self, const xmlChar *value, int len);
static void _entityDecl(libxmlSAXDriver *self, const xmlChar *name, int type,
                       const xmlChar *publicId, const xmlChar *systemId,
                       xmlChar *content)
     __attribute__((unused));
static void _notationDecl(libxmlSAXDriver *self, const xmlChar *name,
                         const xmlChar *publicId, const xmlChar *systemId)
     __attribute__((unused));
static void
_unparsedEntityDecl(libxmlSAXDriver *self, const xmlChar *name,
                   const xmlChar *publicId, const xmlChar *systemId,
                   const xmlChar *notationName)
     __attribute__((unused));
static void _elementDecl(libxmlSAXDriver *self, const xmlChar *name, int type,
                        xmlElementContentPtr content)
     __attribute__((unused));
static void _attrDecl(libxmlSAXDriver *self, const xmlChar *elem,
                     const xmlChar *name, int type, int def,
                     const xmlChar *defaultValue, xmlEnumerationPtr tree)
     __attribute__((unused));
static void _internalSubset(libxmlSAXDriver *ctx, const xmlChar *name,
                           const xmlChar *ExternalID, const xmlChar *SystemID);
static void _externalSubset(libxmlSAXDriver *ctx, const xmlChar *name,
                           const xmlChar *ExternalID, const xmlChar *SystemID);
static void _reference(libxmlSAXDriver *ctx, const xmlChar *name);
#if 0
static int _isStandalone(libxmlSAXDriver *self);
static int _hasInternalSubset(libxmlSAXDriver *self);
static int _hasExternalSubset(libxmlSAXDriver *self);
#endif

static xmlSAXHandler saxHandler = {
  (void*)_internalSubset,      /* internalSubset */
#if 1
  NULL,NULL,NULL,
#else
  (void*)_isStandalone,        /* isStandalone */
  (void*)_hasInternalSubset,   /* hasInternalSubset */
  (void*)_hasExternalSubset,   /* hasExternalSubset */
#endif
#if HANDLE_XML_ENTITIES
  (void*)_resolveEntity,       /* resolveEntity */
  (void*)_getEntity,           /* getEntity */
#else
  NULL, NULL,
#endif
#if HANDLE_XML_DELCS
  (void*)_entityDecl,          /* entityDecl */
  (void*)_notationDecl,        /* notationDecl */
  (void*)_attrDecl,            /* attributeDecl */
  (void*)_elementDecl,         /* elementDecl */
  (void*)_unparsedEntityDecl,  /* unparsedEntityDecl */
#else
  NULL, NULL, NULL, NULL, NULL,
#endif
  (void*)_setLocator,          /* setDocumentLocator */
  (void*)_startDocument,       /* startDocument */
  (void*)_endDocument,         /* endDocument */
  (void*)_startElement,        /* startElement */
  (void*)_endElement,          /* endElement */
  (void*)_reference,           /* reference */
  (void*)_characters,          /* characters */
  (void*)_ignorableWhiteSpace, /* ignorableWhitespace */
  (void*)__pi,                  /* processingInstruction */
  (void*)_comment,             /* comment */
  (void*)_warning,             /* warning */
  (void*)_error,               /* error */
  (void*)_fatalError,          /* fatalError */
  NULL,       /* getParameterEntity */
  (void*)_cdataBlock,          /* cdataBlock */
  (void*)_externalSubset       /* externalSubset */
};

- (id)init {
  self->sax     = &saxHandler;
  self->nsStack = [[NSMutableArray alloc] init];
  
  /* feature defaults */
  self->fNamespaces        = YES;
  self->fNamespacePrefixes = NO;
  
  return self;
}

- (void)dealloc {
  [self->attrs   release];
  [self->nsStack release];
  
  [self->declHandler    release];
  [self->lexicalHandler release];
  [self->contentHandler release];
  [self->dtdHandler     release];
  [self->errorHandler   release];
  [self->entityResolver release];
  
  [self->locator clear];
  [self->locator release];

  if (self->entity) free(self->entity);
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

/* parsing */

- (NSStringEncoding)encodingForXMLEncodingString:(NSString *)_enc {
  // TODO: use the string-charset functions in NGExtensions
  _enc = [_enc lowercaseString];

  if ([_enc isEqualToString:@"utf-8"])
    return NSUTF8StringEncoding;
  if ([_enc isEqualToString:@"iso-8859-1"])
    return NSISOLatin1StringEncoding;
  
#ifndef NeXT_Foundation_LIBRARY
  if ([_enc isEqualToString:@"iso-8859-9"])
    return NSISOLatin9StringEncoding;
#endif

  if ([_enc isEqualToString:@"iso-8859-2"])
    return NSISOLatin2StringEncoding;

  if ([_enc isEqualToString:@"ascii"])
    return NSASCIIStringEncoding;

  NSLog(@"%s: UNKNOWN XML ENCODING '%@'",
        __PRETTY_FUNCTION__, _enc);
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
        : (NSString *)nil;
    }
    else {
      r = [xmlDecl rangeOfString:@"encoding=\""];
      if (r.length > 0) {
        xmlDecl = [_string substringFromIndex:(r.location + r.length)];
        r = [xmlDecl rangeOfString:@"\""];
        xmlDecl = r.length > 0
          ? [xmlDecl substringToIndex:r.location]
          : (NSString *)nil;
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

- (void)parseFromSource:(id)_source systemId:(NSString *)_sysId {
  NSAutoreleasePool *pool;
  
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
    
    ui = [[NSDictionary alloc] initWithObjectsAndKeys:
				 _source ? _source : (id)@"<nil>", @"source",
			         self,                             @"parser",
			       nil];
    
    e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
                               reason:@"cannot handle data-source"
                               userInfo:ui];
    [ui release]; ui = nil;
    
    [self->errorHandler fatalError:e];
    return;
  }
  
  pool = [[NSAutoreleasePool alloc] init];

  /* start parsing */
  {
    unsigned char *src, *start;
    unsigned len;
    void     *oldsax;
    
    if ((len = [_source length]) == 0) {
      /* no content ... */
      return;
    }
    
    /* zero-terminate the data !!! */
    src = malloc(len + 2);
    [_source getBytes:src length:len];
    src[len] = '\0';
    start = src;
    
    if (len > 5) {
      unsigned char *tmp;
      
      if ((tmp = (unsigned char *)strstr((char *)src, "<?xml"))) {
        if (tmp != src) {
          /* skip leading spaces till <?xml ...*/
          while (*start != '\0' && isspace(*start)) {
            start++;
            len--;
          }
        }
      }
    }
    
    SETUP_ACTDRIVER;
    
    self->ctxt = xmlCreateMemoryParserCtxt((void *)start, len);
    
    if (self->ctxt == nil) {
      SaxParseException *e;
      NSDictionary *ui;
      
      NSLog(@"%s: couldn't create memory parser ctx (src=0x%p, len=%d) !",
            __PRETTY_FUNCTION__, src, len);
    
      TEARDOWN_ACTDRIVER;
      
      ui = nil;
      e = (id)[SaxParseException
                exceptionWithName:@"SaxIOException"
                reason:@"couldn't create memory parser context"
                userInfo:ui];
      
      [self->errorHandler fatalError:e];
      return;
    }
    
    if (((xmlParserCtxtPtr)self->ctxt)->input != NULL && [_sysId length] > 0) {
      ((xmlParserInputPtr)((xmlParserCtxtPtr)self->ctxt)->input)->filename =
        [_sysId cString];
    }
    
    oldsax = ((xmlParserCtxtPtr)self->ctxt)->sax;
    ((xmlParserCtxtPtr)self->ctxt)->sax = self->sax;
    ((xmlParserCtxtPtr)self->ctxt)->userData = self;
    
    xmlParseDocument(ctxt);
    
    if (!(((xmlParserCtxtPtr)self->ctxt)->wellFormed))
      NSLog(@"%@: not well formed 1", _sysId);
    
    if (((xmlParserCtxtPtr)self->ctxt)->input != NULL && [_sysId length] > 0) {
      ((xmlParserInputPtr)((xmlParserCtxtPtr)self->ctxt)->input)->filename 
	= NULL;
    }
    
    ((xmlParserCtxtPtr)self->ctxt)->sax = oldsax;
    ((xmlParserCtxtPtr)self->ctxt)->userData = NULL;
    xmlFreeParserCtxt(ctxt);

    TEARDOWN_ACTDRIVER;

    if (src != NULL) { 
      free(src); 
      src = NULL;
    }
  }
  
  [pool release];
}
- (void)parseFromSource:(id)_source {
  [self parseFromSource:_source systemId:nil];
}

static int mfread(void *f, char *buf, int len) {
  int l;
  l = fread(buf, 1, len, f);
  //printf("read %i bytes\n", l);
  return l;
}
static int mfclose(void *f) {
  return fclose(f);
}

- (void)parseFromSystemId:(NSString *)_sysId {
  /* _sysId is a URI */
  NSAutoreleasePool *pool;
  
  if (![_sysId hasPrefix:@"file:"]) {
    SaxParseException *e;
    NSDictionary      *ui;
    NSURL *url;
    
    if ((url = [NSURL URLWithString:_sysId])) {
      [self parseFromSource:url systemId:_sysId];
      return;
    }
    
    ui = [[NSDictionary alloc] initWithObjectsAndKeys:
			 _sysId ? _sysId : (NSString *)@"<nil>", @"systemID",
                         self,                       @"parser",
                         nil];
    
    e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
                               reason:@"cannot handle system-id"
                               userInfo:ui];
    [ui release]; ui = nil;
    
    [self->errorHandler fatalError:e];
    return;
  }
  
  pool = [[NSAutoreleasePool alloc] init];
  
  /* cut off file:// */
  if ([_sysId hasPrefix:@"file://"])
    _sysId = [_sysId substringFromIndex:7];
  else
    _sysId = [_sysId substringFromIndex:5];
  
  /* start parsing .. */
#if 0
  ret = xmlSAXUserParseFile(self->sax, (void *)self, [_sysId cString]);
#else
  {
    FILE *f;
    f = fopen([_sysId cString], "r");

    if (f == NULL) {
      SaxParseException *e;
      NSDictionary *ui;
#if DEBUG
      NSLog(@"%s: missing file '%@'", __PRETTY_FUNCTION__, _sysId);
#endif
      ui = [[NSDictionary alloc] initWithObjectsAndKeys:
                           _sysId ? _sysId : (NSString *)@"<nil>", @"path",
                           self,                       @"parser",
                           nil];
      e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
                                 reason:@"can't find file"
                                 userInfo:ui];
      [ui release]; ui = nil;
      
      [self->errorHandler fatalError:e];
      [pool release];
      return;
    }
    
    self->ctxt =
      xmlCreateIOParserCtxt(self->sax, self /* userdata */,
			    mfread,  /* ioread  */
			    mfclose, /* ioclose */
			    f,       /* ioctx   */
			    XML_CHAR_ENCODING_UTF8 /* encoding */);
    
    if (((xmlParserCtxtPtr)self->ctxt)->input != NULL && [_sysId length] > 0) {
      ((xmlParserInputPtr)((xmlParserCtxtPtr)self->ctxt)->input)->filename =
        [_sysId cString];
    }
    
    SETUP_ACTDRIVER;
    
    xmlParseDocument(self->ctxt);
    
    TEARDOWN_ACTDRIVER;
    
    if (((xmlParserCtxtPtr)self->ctxt)->input != NULL && [_sysId length] > 0) {
      ((xmlParserInputPtr)((xmlParserCtxtPtr)self->ctxt)->input)->filename =
	NULL;
    }
    
    if (!(((xmlParserCtxtPtr)self->ctxt)->wellFormed))
      NSLog(@"%@: not well formed 2", _sysId);
    
    ((xmlParserCtxtPtr)self->ctxt)->sax = NULL;
    xmlFreeParserCtxt(self->ctxt);
  }
#endif

  [pool release];
}

/* entities */

- (NSString *)replacementStringForEntityNamed:(NSString *)_entityName {
  // TODO: check, how this is used, could explain some problems
  //NSLog(@"get entity: %@", _entityName);
  return [[@"&amp;" stringByAppendingString:_entityName]
                    stringByAppendingString:@";"];
}

/* namespace support */

- (NSString *)nsUriForPrefix:(NSString *)_prefix {
  NSEnumerator *e;
  NSDictionary *ns;
  
  e = [self->nsStack reverseObjectEnumerator];
  while ((ns = [e nextObject])) {
    NSString *uri;
    
    if ((uri = [ns objectForKey:_prefix])) {
      //NSLog(@"prefix %@ -> uri %@", _prefix, uri);
      return uri;
    }
  }
  //NSLog(@"prefix %@ -> uri %@", _prefix, nil);
  return nil;
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

/* ---------- libxml sax connection ---------- */

static void
_startElement(libxmlSAXDriver *self, const xmlChar *name, const xmlChar **atts)
{
  NSString *ename, *rawName, *euri;
  NSDictionary *nsDict = nil;
  NSRange r;
  
  /* first scan for namespace declaration */
  
  if (atts) {
    NSMutableDictionary *ns = nil;
    int i;
    
    for (i = 0; atts[i]; i += 2) {
      const xmlChar *an = atts[i];
      
      /* check for attr-names beginning with 'xmlns' */
      if (an[0] != 'x') continue;
      if (an[1] != 'm') continue;
      if (an[2] != 'l') continue;
      if (an[3] != 'n') continue;
      if (an[4] != 's') continue;
      
      /* ok, found ns decl */
      
      if (ns == nil) ns = [[NSMutableDictionary alloc] init];
      
      if (an[5] == ':') {
        /* eg <x xmlns:nl="http://www.w3.org"/> */
        NSString *prefix, *uri;
        
        if (an[6] == '\0') {
          /* invalid, namespace name may not be empty ! */
          NSLog(@"WARNING(%s): empty namespace prefix !", __PRETTY_FUNCTION__);
        }
        
        prefix = xmlCharsToString(&(an[6]));
        uri    = xmlCharsToString(atts[i + 1]);
        
        //NSLog(@"prefix %@ uri %@", prefix, uri);
        
        NSCAssert(ns, @"missing namespace dictionary");
        [ns setObject:uri forKey:prefix];
        
        if (self->fNamespaces)
          [self->contentHandler startPrefixMapping:prefix uri:uri];

        [prefix release]; prefix = nil;
        [uri release];    uri    = nil;
      }
      else {
        /* eg <x xmlns="http://www.w3.org"/> */
        NSString *uri;
        
        uri = xmlCharsToString(atts[i + 1]);
        [ns setObject:uri forKey:@":"];

        //NSLog(@"prefix default uri %@", uri);
        [uri release]; uri = nil;
      }
    }
    
    nsDict = [ns copy];
    [nsDict autorelease];
    [ns release];
  }
  
  /* manage namespace stack */
  
  if (nsDict == nil)
    nsDict = [NSDictionary dictionary];
  
  NSCAssert(self->nsStack, @"missing namespace stack");
  [self->nsStack addObject:nsDict];
  
  /* process element name */
  
  rawName = xmlCharsToString(name);
  r = [rawName rangeOfString:@":"];
  if (r.length > 0) {
    /* eg: <edi:bill/> */
    NSString *prefix;
    
    prefix = [rawName substringToIndex:r.location];
    ename  = [rawName substringFromIndex:(r.location + r.length)];
    euri   = [self nsUriForPrefix:prefix];
  }
  else {
    ename = rawName;
    euri  = [self defaultNamespace];
  }
  
  /* create sax attrs */

  if (self->attrs == nil)
    self->attrs = [[SaxAttributes alloc] init];
  else
    [self->attrs clear];
  
  if (atts) {
    int i;
    
    for (i = 0; atts[i]; i += 2) {
      NSString *name, *rawName, *uri;
      NSString *type, *value;
      NSRange  r;

      if (!self->fNamespacePrefixes) {
        if (atts[i][0] == 'x') {
          const unsigned char *an = atts[i];
        
          if (strstr((char *)an, "xmlns") == (char *)an)
            continue;
        }
      }
      
      rawName = xmlCharsToString(atts[i]);
      r = [rawName rangeOfString:@":"];
      
      if (r.length > 0) {
        /* explicit attribute namespace, eg '<d edi:bill="100"/>' */
        NSString *prefix;
        
        prefix = [rawName substringToIndex:r.location];
        name   = [rawName substringFromIndex:(r.location + r.length)];
        uri    = [self nsUriForPrefix:prefix];
      }
      else {
        /* plain attribute, eg '<d bill="100"/>' */
        name   = rawName;
        uri    = euri; /* attr inherits namespace from element-name */
      }
      
      type  = @"CDATA";
      value = xmlCharsToDecodedString(atts[i + 1]);
      
      [self->attrs
           addAttribute:name uri:uri rawName:rawName
           type:type value:value];

      [value   release]; value   = nil;
      [rawName release]; rawName = nil;
    }
  }
  
  self->depth++;
  
  /* send notification */
  
  [self->contentHandler startElement:ename namespace:euri
                        rawName:rawName
                        attributes:self->attrs];

  [rawName release]; rawName = nil;
  
  [self->attrs clear];
}

static void _endElement(libxmlSAXDriver *self, const xmlChar *name) {
  NSString *ename, *rawName, *uri;
  NSRange  r;
  
  rawName = xmlCharsToString(name);
  r = [rawName rangeOfString:@":"];
  
  if (r.length > 0) {
    /* eg: <edi:bill/> */
    NSString *prefix;
    
    prefix = [rawName substringToIndex:r.location];
    ename  = [rawName substringFromIndex:(r.location + r.length)];
    uri    = [self nsUriForPrefix:prefix];
  }
  else {
    ename = rawName;
    uri   = [self defaultNamespace];
  }
  
  [self->contentHandler endElement:ename namespace:uri rawName:rawName];
  self->depth--;
  [rawName release]; rawName = nil;

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

static void _startDocument(libxmlSAXDriver *self) {
  static NSDictionary *defNS = nil;
  id keys[2], values[2];

  //NSLog(@"start doc 0x%p", self);

  if (defNS == nil) {
    keys[0] = @"xml"; values[0] = @"http://www.w3.org/XML/1998/namespace";
    keys[1] = @":";   values[1] = @"";
    defNS = [[NSDictionary alloc] initWithObjects:values forKeys:keys count:2];
  }
  if ([self->nsStack count] == 0)
    [self->nsStack addObject:defNS];
  else
    [self->nsStack insertObject:defNS atIndex:0];
  
  [self->contentHandler startDocument];
}
static void _endDocument(libxmlSAXDriver *self) {
  [self->contentHandler endDocument];
  
  if ([self->nsStack count] > 0)
    [self->nsStack removeObjectAtIndex:0];
  else {
    NSLog(@"libxmlSAXDriver: inconsistent state, "
          @"nothing on NS stack in endDocument !");
  }
}

static void _characters(libxmlSAXDriver *self, const xmlChar *chars, int len) {
  /* need to transform UTF8 to UTF16 */
  unichar *data, *ts;
  
  if (len == 0) {
    unichar c = 0;
    data = &c;
    [self->contentHandler characters:data length:0];
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
    [self->contentHandler characters:data length:((unsigned)(ts - data))];
    free(data);
  }
}

static void
_ignorableWhiteSpace(libxmlSAXDriver *self, const xmlChar *chars, int len)
{
  /* need to transform UTF8 to UTF16 */
  unichar *data, *ts;
  
  if (len == 0) {
    unichar c = 0;
    data = &c;
    [self->contentHandler ignorableWhitespace:data length:len];
    return;
  }
  if (chars == NULL) {
    [self->contentHandler ignorableWhitespace:NULL length:0];
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
    [self->contentHandler ignorableWhitespace:data length:(ts - data)];
    free(data);
  }
}

static void __pi(libxmlSAXDriver *self, const xmlChar *pi, const xmlChar *data) {
  NSString *epi, *edata;
  
  epi   = xmlCharsToString(pi);
  edata = xmlCharsToString(data);
  
  [self->contentHandler processingInstruction:epi data:edata];

  [epi   release]; epi   = nil;
  [edata release]; edata = nil;
}

static void _comment(libxmlSAXDriver *self, const xmlChar *value) {
  if (self->lexicalHandler) {
    /* need to transform UTF8 to UTF16 */
    unichar *data;
    register int i, len;
    
    len = strlen((const char *)value);
    
    data = calloc(len +1 ,sizeof(unichar)); /* GC ?! */

    for (i = 0; i < len; i++)
      data[i] = value[i];

    [self->lexicalHandler comment:data length:len];
    
    if (data) { free(data); data = NULL; }
  }
}

static void _setLocator(void *udata, xmlSAXLocatorPtr _locator) {
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

static xmlParserInputPtr
_resolveEntity(libxmlSAXDriver *self, const xmlChar *pub, const xmlChar *sys)
{
  NSString *pubId, *sysId;
  id src;

  pubId = xmlCharsToString(pub);
  sysId = xmlCharsToString(sys);
  
  src = [self->entityResolver resolveEntityWithPublicId:pubId systemId:sysId];
  if (src == nil) {
    //return xmlLoadExternalEntity(sys, pub, self);
    return NULL;
  }
  
  NSLog(@"ignored entity src %@", src);
  
  [pubId release]; pubId = nil;
  [sysId release]; sysId = nil;
  return NULL;
}

static xmlEntityPtr _getEntity(libxmlSAXDriver *self, const xmlChar *name) {
  xmlEntityPtr p;
  NSString *ename, *s;
  
  if ((p = xmlGetPredefinedEntity(name)))
    return p;
  
  if (self->entity == NULL)
    /* setup shared entity structure */
    self->entity = calloc(1, sizeof(xmlEntity));
  
  ename = xmlCharsToString(name);
  s     = [self replacementStringForEntityNamed:ename];

  /* need to convert to unicode ! */
  
  /* fill entity structure */
  p = self->entity;
  p->name    = (unsigned char *)[ename cString];
  p->etype   = XML_INTERNAL_GENERAL_ENTITY;
  p->orig    = (void *)[ename cString];
  p->content = (void *)[s cString];
  p->length  = [s cStringLength];
  
  [ename release]; ename = nil;
  
  return p;
}

static void _cdataBlock(libxmlSAXDriver *self, const xmlChar *value, int len) {
  [self->lexicalHandler startCDATA];
  _characters(self, value, len);
  [self->lexicalHandler endCDATA];
}

static SaxParseException *
mkException(libxmlSAXDriver *self, NSString *key, const char *msg, va_list va)
{
  NSString          *s, *reason;
  NSDictionary      *ui;
  SaxParseException *e;
  NSRange r;
  int count = 0, i;
  id  keys[7], values[7];
  id  tmp;
  
  s = [NSString stringWithCString:msg];
  s = [[[NSString alloc]
                  initWithFormat:s arguments:va]
                  autorelease];
  r = [s rangeOfString:@"\n"];
  reason = r.length > 0
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

static void _warning(libxmlSAXDriver *self, const char *msg, ...) {
  va_list           args;
  SaxParseException *e;

  va_start(args, msg);
  e = mkException(self, @"SAXWarning", msg, args);
  va_end(args);
  
  [self->errorHandler warning:e];
}
static void _error(libxmlSAXDriver *self, const char *msg, ...) {
  va_list           args;
  SaxParseException *e;

  va_start(args, msg);
  e = mkException(self, @"SAXError", msg, args);
  va_end(args);
  
  [self->errorHandler error:e];
}
static void _fatalError(libxmlSAXDriver *self, const char *msg, ...) {
  va_list           args;
  SaxParseException *e;

  va_start(args, msg);
  e = mkException(self, @"SAXFatalError", msg, args);
  va_end(args);
  
  [self->errorHandler fatalError:e];
}

static void _entityDecl(libxmlSAXDriver *self, const xmlChar *name, int type,
                       const xmlChar *publicId, const xmlChar *systemId,
                       xmlChar *content)
{
  NSString *ename, *pubId, *sysId;
  NSString *value;
  
  ename = xmlCharsToString(name);
  pubId = xmlCharsToString(publicId);
  sysId = xmlCharsToString(systemId);
  value = xmlCharsToString(content);
  
  switch (type) {
    case XML_INTERNAL_GENERAL_ENTITY:
    case XML_INTERNAL_PARAMETER_ENTITY:
    case XML_INTERNAL_PREDEFINED_ENTITY:
      [self->declHandler internalEntityDeclaration:ename value:value];
      break;
    
    case XML_EXTERNAL_GENERAL_PARSED_ENTITY:
    case XML_EXTERNAL_PARAMETER_ENTITY:
      [self->declHandler externalEntityDeclaration:ename
                         publicId:pubId systemId:sysId];
      break;
      
    case XML_EXTERNAL_GENERAL_UNPARSED_ENTITY:
      /* is content really =notationName ??? */
      NSLog(@"unparsed ext entity ..");
      [self->dtdHandler unparsedEntityDeclaration:ename
                        publicId:pubId systemId:sysId
                        notationName:value];
      break;
      
    default:
      [NSException raise:@"InvalidEntityType"
                   format:@"don't know entity type with code %i", type];
  }

  [ename release];
  [pubId release];
  [sysId release];
  [value release];
}

static void
_unparsedEntityDecl(libxmlSAXDriver *self,const xmlChar *name,
                    const xmlChar *publicId, const xmlChar *systemId,
                    const xmlChar *notationName)
{
  if (self->dtdHandler) {
    NSString *ename, *nname, *pubId, *sysId;
    
    ename = xmlCharsToString(name);
    nname = xmlCharsToString(notationName);
    pubId = xmlCharsToString(publicId);
    sysId = xmlCharsToString(systemId);
    
    [self->dtdHandler unparsedEntityDeclaration:ename
                      publicId:pubId systemId:sysId
                      notationName:nname];

    [ename release];
    [nname release];
    [pubId release];
    [sysId release];
  }
}

static void _notationDecl(libxmlSAXDriver *self, const xmlChar *name,
                         const xmlChar *publicId, const xmlChar *systemId)
{
  if (self->dtdHandler) {
    NSString *nname, *pubId, *sysId;
    
    nname = xmlCharsToString(name);
    pubId = xmlCharsToString(publicId);
    sysId = xmlCharsToString(systemId);
    
    [self->dtdHandler notationDeclaration:nname publicId:pubId systemId:sysId];

    [nname release];
    [pubId release];
    [sysId release];
  }
}

static NSString *_occurString(xmlElementContentOccur _occurType)
     __attribute__((unused));
static NSString *_occurString(xmlElementContentOccur _occurType) {
  switch (_occurType) {
    case XML_ELEMENT_CONTENT_ONCE: return @"";
    case XML_ELEMENT_CONTENT_OPT:  return @"?";
    case XML_ELEMENT_CONTENT_MULT: return @"*";
    case XML_ELEMENT_CONTENT_PLUS: return @"+";
  }
  return @"";
}

static void _addElemModel(xmlElementContentPtr p, NSMutableString *s, int pt) {
  if (p == NULL) return;

  switch (p->type) {
    case XML_ELEMENT_CONTENT_PCDATA:
      if (pt == -1) [s appendString:@"("];
      [s appendString:@"#PCDATA"];
      if (pt == -1) [s appendString:@")"];
      break;
      
    case XML_ELEMENT_CONTENT_ELEMENT: {
      NSString *ename;
      
      ename = xmlCharsToString(p->name);
      
      if (pt == -1) [s appendString:@"("];
      [s appendString:ename];
      if (pt == -1) [s appendString:@")"];

      [ename release]; ename = nil;
      break;
    }
    
    case XML_ELEMENT_CONTENT_SEQ:
      if (pt != XML_ELEMENT_CONTENT_SEQ) [s appendString:@"("];
      _addElemModel(p->c1, s, XML_ELEMENT_CONTENT_SEQ);
      [s appendString:@","];
      _addElemModel(p->c2, s, XML_ELEMENT_CONTENT_SEQ);
      if (pt != XML_ELEMENT_CONTENT_SEQ) [s appendString:@")"];
      break;
      
    case XML_ELEMENT_CONTENT_OR:
      if (pt != XML_ELEMENT_CONTENT_OR) [s appendString:@"("];
      _addElemModel(p->c1, s, XML_ELEMENT_CONTENT_OR);
      [s appendString:@"|"];
      _addElemModel(p->c2, s, XML_ELEMENT_CONTENT_OR);
      if (pt != XML_ELEMENT_CONTENT_OR) [s appendString:@")"];
      break;
  }
  switch (p->ocur) {
    case XML_ELEMENT_CONTENT_ONCE: break;
    case XML_ELEMENT_CONTENT_OPT:  [s appendString:@"?"]; break;
    case XML_ELEMENT_CONTENT_MULT: [s appendString:@"*"]; break;
    case XML_ELEMENT_CONTENT_PLUS: [s appendString:@"+"]; break;
  }
}

static void _elementDecl(libxmlSAXDriver *self, const xmlChar *name, int type,
                        xmlElementContentPtr content)
{
  if (self->declHandler) {
    NSString *ename, *model;
    
    ename = xmlCharsToString(name);
    
    if (content) {
      NSMutableString *emodel;
      
      emodel = [[NSMutableString alloc] init];
      _addElemModel(content, emodel, -1);
      model = [[emodel copy] autorelease];
      [emodel release];
    }
    else
      model = nil;
    
    [self->declHandler elementDeclaration:ename contentModel:model];
    [ename release]; ename = nil;
  }
}

static void _attrDecl(libxmlSAXDriver *self, const xmlChar *elem,
                     const xmlChar *name, int type, int def,
                     const xmlChar *defaultValue, xmlEnumerationPtr tree)
{
  if (self->declHandler) {
    NSString *ename, *aname, *defValue, *atype, *defType;
    
    ename    = xmlCharsToString(elem);
    aname    = xmlCharsToString(name);
    defValue = xmlCharsToString(defaultValue);
    atype    = nil;
    defType  = nil;

    switch (type) {
      case XML_ATTRIBUTE_CDATA:       atype = @"CDATA";       break;
      case XML_ATTRIBUTE_ID:          atype = @"ID";          break;
      case XML_ATTRIBUTE_IDREF:       atype = @"IDREF";       break;
      case XML_ATTRIBUTE_IDREFS:      atype = @"IDREFS";      break;
      case XML_ATTRIBUTE_ENTITY:      atype = @"ENTITY";      break;
      case XML_ATTRIBUTE_ENTITIES:    atype = @"ENTITIES";    break;
      case XML_ATTRIBUTE_NMTOKEN:     atype = @"NMTOKEN";     break;
      case XML_ATTRIBUTE_NMTOKENS:    atype = @"NMTOKENS";    break;
      case XML_ATTRIBUTE_ENUMERATION: atype = @"ENUMERATION"; break;
      case XML_ATTRIBUTE_NOTATION:    atype = @"NOTATION";    break;
      
      default:
        [NSException raise:@"InvalidAttributeType"
                     format:@"don't know attr type with code %i", type];
    }
    switch (def) {
      case XML_ATTRIBUTE_NONE:     defType = nil;          break;
      case XML_ATTRIBUTE_REQUIRED: defType = @"#REQUIRED"; break;
      case XML_ATTRIBUTE_IMPLIED:  defType = @"#IMPLIED";  break;
      case XML_ATTRIBUTE_FIXED:    defType = @"#FIXED";    break;
        
      default:
        [NSException raise:@"InvalidAttributeDefaultType"
                     format:@"don't know attr default type with code %i", def];
    }
    
    [self->declHandler attributeDeclaration:aname elementName:ename
                       type:atype
                       defaultType:defType defaultValue:defValue];
    [ename release];
    [aname release];
    [defValue release];
  }
}

#if 0
static int isStandalone(libxmlSAXDriver *self) {
}
static int hasInternalSubset(libxmlSAXDriver *self) {
}
static int hasExternalSubset(libxmlSAXDriver *self) {
}
#endif

static void _externalSubset(libxmlSAXDriver *ctx, const xmlChar *name,
                           const xmlChar *ExternalID, const xmlChar *SystemID)
{
}
static void _internalSubset(libxmlSAXDriver *ctx, const xmlChar *name,
                           const xmlChar *ExternalID, const xmlChar *SystemID)
{
}

static void _reference(libxmlSAXDriver *ctx, const xmlChar *name) {
#if 0
  NSString *refName;

  refName = xmlCharsToString(name);
  NSLog(@"reference: '%@'", refName);
  [refName release];
#endif
}

@end /* libxmlSAXDriver */

#include "unicode.h"
