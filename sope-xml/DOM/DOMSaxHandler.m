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

#include "DOMSaxHandler.h"
#include "DOMImplementation.h"
#include "DOMDocument.h"
#include "DOMElement.h"
#include "common.h"
#include <SaxObjC/SaxObjC.h>

@interface NSObject(LineInfoProtocol)
- (void)setLine:(int)_line;
@end

@implementation DOMSaxHandler

static BOOL printErrors = NO;

- (id)initWithDOMImplementation:(id)_domImpl {
  if ((self = [super init])) {
    self->dom = [_domImpl retain];
    self->maxErrorCount = 100; // this also includes NPSOBJ in HTML !
  }
  return self;
}
- (id)init {
  static id idom = nil;
  
  if (idom == nil)
    idom = [[NGDOMImplementation alloc] init];
  
  return [self initWithDOMImplementation:idom];
}

- (void)dealloc {
  [self->document release];
  [self->dom      release];
  [self->locator  release];
  [self->fatals   release];
  [self->errors   release];
  [self->warnings release];
  [super dealloc];
}

- (void)setDocumentLocator:(id<NSObject,SaxLocator>)_loc {
  ASSIGN(self->locator, _loc);
}

- (id)document {
  return self->document;
}

- (void)clear {
  ASSIGN(self->document, (id)nil);
  [self->fatals   removeAllObjects];
  [self->errors   removeAllObjects];
  [self->warnings removeAllObjects];
  self->errorCount = 0;
}

- (int)errorCount {
  return self->errorCount;
}
- (int)fatalErrorCount {
  return [self->fatals count];
}
- (int)warningCount {
  return [self->warnings count];
}
- (int)maxErrorCount {
  return self->maxErrorCount;
}

- (NSArray *)warnings {
  return [[self->warnings copy] autorelease];
}
- (NSArray *)errors {
  return [[self->errors copy] autorelease];
}
- (NSArray *)fatalErrors {
  return [[self->fatals copy] autorelease];
}

/* attributes */

- (id)_nodeForSaxAttrWithName:(NSString *)_name
  namespace:(NSString *)_uri
  rawName:(NSString *)_rawName
  type:(NSString *)_saxType value:(NSString *)_saxValue
{
  id attr;
  NSString *nsPrefix;
  
  attr = [self->document createAttribute:_name namespaceURI:_uri];
  if (attr == nil) 
    return nil;
  
  nsPrefix = nil;
  if (_uri) {
    NSRange r;
    
    r = [_rawName rangeOfString:@":"];
    if (r.length > 0)
      nsPrefix = [_rawName substringToIndex:r.location];
  }
  
  if (nsPrefix)
    [attr setPrefix:nsPrefix];
  
  /* add content to attribute */
  
  if ([_saxType isEqualToString:@"CDATA"] || (_saxType == nil)) {
    id content;

    NSAssert(self->document, @"missing document object");
    
    if ((content = [self->document createTextNode:_saxValue]))
      [attr appendChild:content];
    else
      NSLog(@"couldn't create text node !");
  }
  else
    NSLog(@"unsupported sax attr type '%@' !", _saxType);
  
  return attr;
}

/* document */

- (void)startDocument {
  id docType;
  
  [self->document release]; self->document = nil;
  self->errorCount = 0;
  self->tagDepth   = 0;
  
  docType = [self->dom createDocumentType:nil
                       publicId:[self->locator publicId]
                       systemId:[self->locator systemId]];
  
  self->document = [self->dom createDocumentWithName:nil
			      namespaceURI:nil
			      documentType:docType];
  self->document = [self->document retain];
  
  //NSLog(@"started doc: %@", self->document);
  
  self->currentElement = self->document;
}
- (void)endDocument {
  self->currentElement = nil;
}

- (void)startPrefixMapping:(NSString *)_prefix uri:(NSString *)_uri {
  //printf("ns-map: %s=%s\n", [_prefix cString], [_uri cString]);
}
- (void)endPrefixMapping:(NSString *)_prefix {
  //printf("ns-unmap: %s\n", [_prefix cString]);
}

- (void)startElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
  attributes:(id<SaxAttributes>)_attrs
{
  id       elem;
  NSString *nsPrefix;

  self->tagDepth++;
  elem = [self->document createElement:_localName namespaceURI:_ns];
  if (elem == nil) {
    NSLog(@"%s: couldn't create element for tag '%@'", __PRETTY_FUNCTION__,
          _rawName);
    return;
  }
  if ([elem respondsToSelector:@selector(setLine:)])
    [elem setLine:[self->locator lineNumber]];
  
  if (_ns) {
    NSRange r;
    
    r = [_rawName rangeOfString:@":"];
    nsPrefix = (r.length > 0)
      ? [_rawName substringToIndex:r.location]
      : (NSString *)nil;
  }
  else
    nsPrefix = nil;

  if (nsPrefix)
    [elem setPrefix:nsPrefix];
  
  NSAssert(self->currentElement, @"no current element !");
  
  [self->currentElement appendChild:elem];
  self->currentElement = elem;

  /* process attributes */
  {
    unsigned i, count;
    
    for (i = 0, count = [_attrs count]; i < count; i++) {
      id attr;
      
      // NSLog(@"attr %@", [_attrs nameAtIndex:i]);
      
      attr = [self _nodeForSaxAttrWithName:[_attrs nameAtIndex:i]
		   namespace:[_attrs uriAtIndex:i]
                   rawName:[_attrs rawNameAtIndex:i]
		   type:[_attrs typeAtIndex:i]
		   value:[_attrs valueAtIndex:i]];
      if (attr == nil) {
	NSLog(@"couldn't create attribute for SAX attr %@, element %@",
	      attr, elem);
	continue;
      }
      
      /* add node to element */
      
      if ([elem setAttributeNodeNS:attr] == nil)
	NSLog(@"couldn't add attribute %@ to element %@", attr, elem);
    }
  }
}
- (void)endElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
{
  id parent;

  parent = [self->currentElement parentNode];
#if DEBUG
  NSAssert1(parent, @"no parent for current element %@ !",
            self->currentElement);
#endif
  self->currentElement = parent;
  self->tagDepth--;
}

- (void)characters:(unichar *)_chars length:(int)_len {
  id       charNode;
  NSString *data;
  
  data     = [[NSString alloc] initWithCharacters:_chars length:_len];
  charNode = [self->document createTextNode:data];
  [data release]; data = nil;
  
  [self->currentElement appendChild:charNode];
}
- (void)ignorableWhitespace:(unichar *)_chars length:(int)_len {
}

- (void)processingInstruction:(NSString *)_pi data:(NSString *)_data {
  id piNode;

  piNode = [self->document createProcessingInstruction:_pi data:_data];

  [self->currentElement appendChild:piNode];
}

#if 0
- (xmlEntityPtr)getEntity:(NSString *)_name {
  NSLog(@"get entity %@", _name);
  return NULL;
}
- (xmlEntityPtr)getParameterEntity:(NSString *)_name {
  NSLog(@"get para entity %@", _name);
  return NULL;
}
#endif

/* lexical handler */

- (void)comment:(unichar *)_chars length:(int)_len {
  id       commentNode;
  NSString *data;
  
  if (_len == 0)
    return;
  
  data = [[NSString alloc] initWithCharacters:_chars length:_len];
  commentNode = [self->document createComment:data];
  [data release]; data = nil;
  
  [self->currentElement appendChild:commentNode];
}

- (void)startDTD:(NSString *)_name
  publicId:(NSString *)_pub
  systemId:(NSString *)_sys
{
  self->inDTD = YES;
}
- (void)endDTD {
  self->inDTD = NO;
}

- (void)startCDATA {
  self->inCDATA = YES;
}
- (void)endCDATA {
  self->inCDATA = NO;
}

/* entities */

- (id)resolveEntityWithPublicId:(NSString *)_pubId
  systemId:(NSString *)_sysId
{
  NSLog(@"shall resolve entity with '%@' '%@'", _pubId, _sysId);
  return nil;
}

/* errors */

- (void)warning:(SaxParseException *)_exception {
  NSString *sysId;
  int line;
  
  sysId = [[_exception userInfo] objectForKey:@"systemId"];
  line  = [[[_exception userInfo] objectForKey:@"line"] intValue];
  
  NSLog(@"DOM XML WARNING(%@:%i): %@", sysId, line, [_exception reason]);

  if (self->warnings == nil)
    self->warnings = [[NSMutableArray alloc] initWithCapacity:32];
  
  if (_exception)
    [self->warnings addObject:_exception];
}

- (void)error:(SaxParseException *)_exception {
  self->errorCount++;
  
  if (printErrors) {
    NSString *sysId;
    int line;
  
    sysId = [[_exception userInfo] objectForKey:@"systemId"];
    line  = [[[_exception userInfo] objectForKey:@"line"] intValue];
    
    NSLog(@"DOM XML ERROR(%@:%i[%@]): %@ (errcount=%i,max=%i)", sysId, line,
	  [[_exception userInfo] objectForKey:@"parser"],
	  [_exception reason],
	  self->errorCount, self->maxErrorCount);
  }
  
  if (self->errors == nil)
    self->errors = [[NSMutableArray alloc] initWithCapacity:32];
  
  if (_exception)
    [self->errors addObject:_exception];
}

- (void)fatalError:(SaxParseException *)_exception {
  NSString *sysId;
  int line;
  
  sysId = [[_exception userInfo] objectForKey:@"systemId"];
  line  = [[[_exception userInfo] objectForKey:@"line"] intValue];
  
  NSLog(@"DOM XML FATAL(%@:%i[%@]): %@", sysId, line,
        [[_exception userInfo] objectForKey:@"parser"],
        [_exception reason]);
  
  if (self->fatals == nil)
    self->fatals = [[NSMutableArray alloc] initWithCapacity:32];
  
  if (_exception)
    [self->fatals addObject:_exception];
  
  [_exception raise];
}

/* DTD */

- (void)notationDeclaration:(NSString *)_name
  publicId:(NSString *)_pubId
  systemId:(NSString *)_sysId
{
  NSLog(@"decl: notation %@ pub=%@ sys=%@", _name, _pubId, _sysId);
}

- (void)unparsedEntityDeclaration:(NSString *)_name
  publicId:(NSString *)_pubId
  systemId:(NSString *)_sysId
  notationName:(NSString *)_notName
{
  NSLog(@"decl: unparsed entity %@ pub=%@ sys=%@ not=%@",
        _name, _pubId, _sysId, _notName);
}

/* decl */

- (void)attributeDeclaration:(NSString *)_attributeName
  elementName:(NSString *)_elementName
  type:(NSString *)_type
  defaultType:(NSString *)_defType
  defaultValue:(NSString *)_defValue
{
  NSLog(@"decl: attr %@[%@] type '%@' default '%@'[%@]",
        _attributeName, _elementName, _type, _defValue, _defType);
}

- (void)elementDeclaration:(NSString *)_name contentModel:(NSString *)_model {
  NSLog(@"decl: element %@ model %@", _name, _model);
}

- (void)externalEntityDeclaration:(NSString *)_name
  publicId:(NSString *)_pub
  systemId:(NSString *)_sys
{
  NSLog(@"decl: e-entity %@ pub %@ sys %@", _name, _pub, _sys);
}

- (void)internalEntityDeclaration:(NSString *)_name value:(NSString *)_value {
  NSLog(@"decl: i-entity %@ value %@", _name, _value);
}

@end /* DOMSaxHandler */


@implementation DOMSaxHandler(SubHandler)

- (NSUInteger)tagDepth {
  return self->tagDepth;
}

- (id)object {
  return [self document];
}

- (void)setNamespaces:(NSString *)_namespaces {
  // not yet implemented
}

@end /* DOMSaxHandler(SubHandler) */
