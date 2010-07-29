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

#include <DOM/DOMDocument.h>
#include <DOM/DOMImplementation.h>
#include <DOM/DOMCharacterData.h>
#include <DOM/DOMAttribute.h>
#include <DOM/DOMElement.h>
#include <DOM/DOMDocumentType.h>
#include <DOM/DOMProcessingInstruction.h>
#include "NSObject+StringValue.h"
#include "common.h"

/*
  Differences to DOM JavaScript

    Differences are due to JavaScript bridge retain-cycle issues with parent
    properties (properties are cached by the JS engine, while function return
    values are not) ...
    
    Node:
      original property | SKYRiX function
      parentNode        | getParentNode()
      childNodes        | getChildNodes()
      firstChild        | getFirstChild()
      lastChild         | getLastChild()
      previousSibling   | getPreviousSibling()
      nextSibling       | getNextSibling()
      attributes        | getAttributes()
      ownerDocument     | getOwnerDocument()

    Attr:
      ownerElement      | getOwnerElement()
      
    Document:
      original property | SKYRiX function
      documentElement   | getDocumentElement()
*/

@implementation NGDOMImplementation(JSSupport)

- (id)_jsfunc_createDocument:(NSArray *)_args {
  NSString *nsuri = nil, *qname = nil, *doctype = nil;
  unsigned count;

  count = [_args count];
  if (count > 0) nsuri   = [[_args objectAtIndex:0] stringValue];
  if (count > 1) qname   = [[_args objectAtIndex:1] stringValue];
  if (count > 2) doctype = [[_args objectAtIndex:2] stringValue];

  return [self createDocumentWithName:qname
               namespaceURI:nsuri
               documentType:doctype];
}

- (id)_jsfunc_createDocumentType:(NSArray *)_args {
  NSString *qname = nil, *pubId = nil, *sysId = nil;
  unsigned count;

  count = [_args count];
  if (count > 0) qname = [[_args objectAtIndex:0] stringValue];
  if (count > 1) pubId = [[_args objectAtIndex:1] stringValue];
  if (count > 2) sysId = [[_args objectAtIndex:2] stringValue];
  
  return [self createDocumentType:qname publicId:pubId systemId:sysId];
}

@end /* NGDOMImplementation(JSSupport) */

@implementation NGDOMDocument(JSSupport)

- (id)_jsprop_doctype {
  return [self doctype];
}
- (id)_jsprop_implementation {
  return [self implementation];
}

- (id)_jsfunc_getDocumentElement:(NSArray *)_args {
  return [self documentElement];
}

/* lookup */

- (id)_jsfunc_getElementsByTagName:(NSArray *)_args {
  unsigned count;
  if ((count = [_args count]) == 0) return nil;

  if (count == 1)
    return [self getElementsByTagName:[[_args objectAtIndex:0] stringValue]];
  else {
    return [self getElementsByTagName:[[_args objectAtIndex:1] stringValue]
                 namespaceURI:[[_args objectAtIndex:0] stringValue]];
  }
}
- (id)_jsfunc_getElementsByTagNameNS:(NSArray *)_args {
  return [self _jsfunc_getElementsByTagName:_args];
}

- (id)_jsfunc_getElementById:(NSArray *)_args {
  unsigned count;
  if ((count = [_args count]) == 0) return nil;

  return [self getElementById:[[_args objectAtIndex:0] stringValue]];
}

/* factory */

- (id)_jsfunc_createElement:(NSArray *)_args {
  unsigned count;
  if ((count = [_args count]) == 0) return nil;
  if (count == 1)
    return [self createElement:[[_args objectAtIndex:0] stringValue]];
  else {
    return [self createElement:[[_args objectAtIndex:1] stringValue]
                 namespaceURI:[[_args objectAtIndex:0] stringValue]];
  }
}
- (id)_jsfunc_createElementNS:(NSArray *)_args {
  return [self _jsfunc_createElement:_args];
}

- (id)_jsfunc_createDocumentFragment:(NSArray *)_args {
  return [self createDocumentFragment];
}
- (id)_jsfunc_createTextNode:(NSArray *)_args {
  unsigned count;
  if ((count = [_args count]) == 0) return nil;
  return [self createTextNode:[[_args objectAtIndex:0] stringValue]];
}
- (id)_jsfunc_createComment:(NSArray *)_args {
  unsigned count;
  if ((count = [_args count]) == 0) return nil;
  return [self createComment:[[_args objectAtIndex:0] stringValue]];
}
- (id)_jsfunc_createCDATASection:(NSArray *)_args {
  unsigned count;
  if ((count = [_args count]) == 0) return nil;
  return [self createCDATASection:[[_args objectAtIndex:0] stringValue]];
}

- (id)_jsfunc_createProcessingInstruction:(NSArray *)_args {
  unsigned count;
  if ((count = [_args count]) < 2) return nil;

  return [self createProcessingInstruction:
                 [[_args objectAtIndex:0] stringValue]
               data:[[_args objectAtIndex:1] stringValue]];
}
- (id)_jsfunc_createAttribute:(NSArray *)_args {
  unsigned count;
  if ((count = [_args count]) == 0) return nil;
  if (count == 1)
    return [self createAttribute:[[_args objectAtIndex:0] stringValue]];
  else {
    return [self createAttribute:[[_args objectAtIndex:1] stringValue]
                 namespaceURI:[[_args objectAtIndex:0] stringValue]];
  }
}
- (id)_jsfunc_createAttributeNS:(NSArray *)_args {
  return [self _jsfunc_createAttribute:_args];
}

- (id)_jsfunc_createEntityReference:(NSArray *)_args {
  unsigned count;
  if ((count = [_args count]) == 0) return nil;
  return [self createEntityReference:[[_args objectAtIndex:0] stringValue]];
}

@end /* NGDOMDocument(JSSupport) */

@implementation NGDOMNode(JSSupport)

- (NSString *)_jsprop_nodeName {
  return [self nodeName];
}
- (NSString *)_jsprop_nodeValue {
  return [self nodeValue];
}
- (NSNumber *)_jsprop_nodeType {
  return [NSNumber numberWithShort:[self nodeType]];
}

- (NSString *)_jsprop_namespaceURI {
  return [self namespaceURI];
}
- (NSString *)_jsprop_prefix {
  return [self prefix];
}
- (NSString *)_jsprop_localName {
  return [self localName];
}

- (id)_jsfunc_getParentNode:(NSArray *)_args {
  return [self parentNode];
}
- (id)_jsfunc_getChildNodes:(NSArray *)_args {
  return [self childNodes];
}
- (id)_jsfunc_getFirstChild:(NSArray *)_args {
  return [self firstChild];
}
- (id)_jsfunc_getLastChild:(NSArray *)_args {
  return [self lastChild];
}
- (id)_jsfunc_getPreviousSibling:(NSArray *)_args {
  return [self previousSibling];
}
- (id)_jsfunc_getNextSibling:(NSArray *)_args {
  return [self nextSibling];
}
- (id)_jsfunc_getAttributes:(NSArray *)_args {
  return [self attributes];
}
- (id)_jsfunc_getOwnerDocument:(NSArray *)_args {
  return [self ownerDocument];
}

- (NSNumber *)_jsfunc_hasChildNodes:(NSArray *)_args {
  return [NSNumber numberWithBool:[self hasChildNodes]];
}

- (id)_jsfunc_normalize:(NSArray *)_args {
  return nil;
}

- (id)_jsfunc_appendChild:(NSArray *)_args {
  unsigned i, count;
  id last = nil;
  for (i = 0, count = [_args count]; i < count; i++)
    last = [self appendChild:[_args objectAtIndex:i]];
  return last;
}
- (id)_jsfunc_removeChild:(NSArray *)_args {
  unsigned i, count;
  id last = nil;
  for (i = 0, count = [_args count]; i < count; i++)
    last = [self removeChild:[_args objectAtIndex:i]];
  return last;
}

// #warning some JS DOMNode API missing

@end /* NGDOMNode(JSSupport) */

@implementation NGDOMCharacterData(JSSupport)

- (void)_jsprop_data:(NSString *)_data {
  _data = [_data stringValue];
  [self setData:_data];
}
- (NSString *)_jsprop_data {
  return [self data];
}

- (NSNumber *)_jsprop_length {
  return [NSNumber numberWithInt:[self length]];
}

- (NSString *)_jsfunc_substringData:(NSArray *)_args {
  unsigned count;
  if ((count = [_args count]) < 2) return nil;
  return [self substringData:[[_args objectAtIndex:0] intValue]
               count:[[_args objectAtIndex:1] intValue]];
}
- (id)_jsfunc_appendData:(NSArray *)_args {
  unsigned i, count;
  for (i = 0, count = [_args count]; i < count; i++)
    [self appendData:[[_args objectAtIndex:i] stringValue]];
  return self;
}
- (id)_jsfunc_insertData:(NSArray *)_args {
  unsigned count;
  if ((count = [_args count]) == 0) return nil;
  if (count == 1)
    [self insertData:[[_args objectAtIndex:0] stringValue] offset:0];
  else {
    [self insertData:[[_args objectAtIndex:0] stringValue]
          offset:[[_args objectAtIndex:1] intValue]];
  }
  return self;
}
- (id)_jsfunc_deleteData:(NSArray *)_args {
  unsigned count;
  if ((count = [_args count]) < 2) return nil;
  [self deleteData:[[_args objectAtIndex:0] intValue]
        count:[[_args objectAtIndex:1] intValue]];
  return self;
}
- (id)_jsfunc_replaceData:(NSArray *)_args {
  unsigned count;
  if ((count = [_args count]) < 3) return nil;
  [self replaceData:[[_args objectAtIndex:0] intValue]
        count:[[_args objectAtIndex:1] intValue]
        with:[[_args objectAtIndex:2] stringValue]];
  return self;
}

@end /* NGDOMCharacterData(JSSupport) */

@implementation NGDOMAttribute(JSSupport)

- (NSString *)_jsprop_name {
  return [self name];
}
- (NSNumber *)_jsprop_specified {
  return [NSNumber numberWithBool:[self specified]];
}

- (void)_jsprop_value:(NSString *)_value {
  [self setValue:[_value stringValue]];
}
- (NSString *)_jsprop_value {
  return [self value];
}

- (id)_jsfunc_getOwnerElement:(NSArray *)_args {
  return [self ownerElement];
}

@end /* NGDOMAttribute(JSSupport) */

@implementation NGDOMElement(JSSupport)

- (NSString *)_jsprop_tagName {
  return [self tagName];
}

/* attributes */

- (NSString *)_jsfunc_getAttribute:(NSArray *)_args {
  unsigned count;
  
  if ((count = [_args count]) == 0) return nil;
  return [self attribute:[[_args objectAtIndex:0] stringValue]];
}
- (NSString *)_jsfunc_getAttributeNS:(NSArray *)_args {
  unsigned count;
  
  if ((count = [_args count]) == 0) return nil;
  return [self attribute:[[_args objectAtIndex:1] stringValue]
               namespaceURI:[[_args objectAtIndex:0] stringValue]];
}

- (id)_jsfunc_setAttribute:(NSArray *)_args {
  unsigned count;
  
  if ((count = [_args count]) < 2) return nil;
  [self setAttribute:[[_args objectAtIndex:0] stringValue]
        value:[[_args objectAtIndex:1] stringValue]];
  return self;
}
- (id)_jsfunc_setAttributeNS:(NSArray *)_args {
  unsigned count;
  
  if ((count = [_args count]) < 3) return nil;
  [self setAttribute:[[_args objectAtIndex:1] stringValue]
        namespaceURI:[[_args objectAtIndex:0] stringValue]
        value:[[_args objectAtIndex:2] stringValue]];
  return self;
}

- (id)_jsfunc_removeAttribute:(NSArray *)_args {
  unsigned i, count;
  for (i = 0, count = [_args count]; i < count; i++)
    [self removeAttribute:[[_args objectAtIndex:i] stringValue]];
  return self;
}
- (id)_jsfunc_removeAttributeNS:(NSArray *)_args {
  unsigned count;
  if ((count = [_args count]) < 2) return nil;
  [self removeAttribute:[[_args objectAtIndex:1] stringValue]
        namespaceURI:[[_args objectAtIndex:0] stringValue]];
  return self;
}

- (id)_jsfunc_getAttributeNode:(NSArray *)_args {
  unsigned count;
  
  if ((count = [_args count]) == 0) return nil;
  return [[self attributes] namedItem:[[_args objectAtIndex:0] stringValue]];
}
- (id)_jsfunc_setAttributeNode:(NSArray *)_args {
  unsigned i, count;
  id last = nil;

  for (i = 0, count = [_args count]; i < count; i++)
    last = [self setAttributeNode:[_args objectAtIndex:i]];
  return last;
}
- (id)_jsfunc_removeAttributeNode:(NSArray *)_args {
  unsigned i, count;
  id last = nil;

  for (i = 0, count = [_args count]; i < count; i++)
    last = [self removeAttributeNode:[_args objectAtIndex:i]];
  return last;
}

/* lookup */

- (id)_jsfunc_getElementsByTagName:(NSArray *)_args {
  unsigned count;
  
  if ((count = [_args count]) < 1) return nil;
  
  if (count == 1)
    return [self getElementsByTagName:[[_args objectAtIndex:0] stringValue]];
  else {
    return [self getElementsByTagName:[[_args objectAtIndex:1] stringValue]
                 namespaceURI:[[_args objectAtIndex:0] stringValue]];
  }
}
- (id)_jsfunc_getElementsByTagNameNS:(NSArray *)_args {
  unsigned count;
  
  if ((count = [_args count]) < 2) return nil;
  return [self getElementsByTagName:[[_args objectAtIndex:1] stringValue]
               namespaceURI:[[_args objectAtIndex:0] stringValue]];
}

@end /* NGDOMElement(JSSupport) */

@implementation NGDOMDocumentType(JSSupport)

- (NSString *)_jsprop_name {
  return [self name];
}
- (NSString *)_jsprop_publicId {
  return [self publicId];
}
- (NSString *)_jsprop_systemId {
  return [self systemId];
}
- (NSString *)_jsprop_internalSubset {
  return [self internalSubset];
}

@end /* NGDOMDocumentType(JSSupport) */

@implementation NGDOMProcessingInstruction(JSSupport)

- (NSString *)_jsprop_target {
  return [self target];
}

- (void)_jsprop_data:(NSString *)_data {
  [self setData:[_data stringValue]];
}
- (NSString *)_jsprop_data {
  return [self data];
}

@end /* NGDOMProcessingInstruction(JSSupport) */
