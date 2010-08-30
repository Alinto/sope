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

#ifndef __DOM_DOMProtocols_H__
#define __DOM_DOMProtocols_H__

/*
  Protocols for DOM objects ...
  
  IDL taken from
    http://www.w3.org/TR/2001/WD-DOM-Level-3-Core-20010913/DOM3-Core.html
*/

typedef enum {
  DOM_UNKNOWN_NODE                = 0,
  DOM_ATTRIBUTE_NODE              = 1,
  DOM_CDATA_SECTION_NODE          = 2,
  DOM_COMMENT_NODE                = 3,
  DOM_DOCUMENT_FRAGMENT_NODE      = 4,
  DOM_DOCUMENT_NODE               = 5,
  DOM_DOCUMENT_TYPE_NODE          = 6,
  DOM_ELEMENT_NODE                = 7,
  DOM_ENTITY_NODE                 = 8,
  DOM_ENTITY_REFERENCE_NODE       = 9,
  DOM_NOTATION_NODE               = 10,
  DOM_PROCESSING_INSTRUCTION_NODE = 11,
  DOM_TEXT_NODE                   = 12
} DOMNodeType;

// TODO: find out which GCC version started to have forward protocols decls ...
//#define HAVE_FORWARD_PROTOCOLS 1

#if HAVE_FORWARD_PROTOCOLS
@protocol DOMNode;
@protocol DOMAttr, DOMCDATASection, DOMComment, DOMDocumentFragment;
@protocol DOMDocument, DOMDocumentType, DOMElement, DOMEntity;
@protocol DOMEntityReference, DOMNotation, DOMProcessingInstruction;
@protocol DOMText;

// NOTE: _ONLY_ use those defines for forward declarations!

#define IDOMNode     id<NSObject,DOMNode>
#define IDOMDocument id<NSObject,DOMDocument>
#define IDOMElement  id<NSObject,DOMElement>

#else
#define IDOMNode     id
#define IDOMDocument id
#define IDOMElement  id
#endif

@protocol DOMNodeList

- (NSUInteger)length;
- (id)objectAtIndex:(NSUInteger)_idx; // returns the proper attribute node

@end /* DOMNodeList */

@protocol DOMNamedNodeMap

- (NSUInteger)length;
- (id)objectAtIndex:(NSUInteger)_idx; // returns the proper attribute node

- (IDOMNode)namedItem:(NSString *)_name;
- (IDOMNode)setNamedItem:(IDOMNode)_node;
- (IDOMNode)removeNamedItem:(NSString *)_name;

/* DOM2 access */

- (IDOMNode)namedItem:(NSString *)_name namespaceURI:(NSString *)_uri;
- (IDOMNode)setNamedItemNS:(IDOMNode)_node;
- (IDOMNode)removeNamedItem:(NSString *)_name namespaceURI:(NSString *)_uri;

@end /* DOMNamedNodeMap */

@protocol DOMNode

- (DOMNodeType)nodeType;
- (NSString *)nodeName;
- (NSString *)nodeValue;

- (NSString *)localName;
- (NSString *)namespaceURI;
- (void)setPrefix:(NSString *)_prefix;
- (NSString *)prefix;

/* element attributes */

- (id<NSObject,DOMNamedNodeMap>)attributes;

/* navigation */

- (id<NSObject,DOMNode>)parentNode;
- (id<NSObject,DOMNode>)previousSibling;
- (id<NSObject,DOMNode>)nextSibling;

- (id<NSObject,DOMNodeList>)childNodes;
- (BOOL)hasChildNodes;
- (id<NSObject,DOMNode>)firstChild;
- (id<NSObject,DOMNode>)lastChild;

/* modification */

- (id<NSObject,DOMNode>)appendChild:(id<NSObject,DOMNode>)_node;
- (id<NSObject,DOMNode>)removeChild:(id<NSObject,DOMNode>)_node;

/* owner */

- (IDOMDocument)ownerDocument;

@end /* DOMNode */

@protocol DOMDocumentFragment < DOMNode >
@end

@protocol DOMAttr < DOMNode >

- (NSString *)name;
- (BOOL)specified;
- (void)setValue:(NSString *)_value;
- (NSString *)value;

/* owner */

- (IDOMElement)ownerElement;

@end /* DOMAttr */

@protocol DOMCharacterData < DOMNode >

- (void)setData:(NSString *)_data;
- (NSString *)data;
- (NSUInteger)length;

- (NSString *)substringData:(NSUInteger)_offset count:(NSUInteger)_count;
- (void)appendData:(NSString *)_data;
- (void)insertData:(NSString *)_data offset:(NSUInteger)_offset;
- (void)deleteData:(NSUInteger)_offset count:(NSUInteger)_count;
- (void)replaceData:(NSUInteger)_offs count:(NSUInteger)_count with:(NSString *)_s;

@end /* DOMCharacterData */

@protocol DOMComment < DOMCharacterData >
@end /* DOMComment */

@protocol DOMText < DOMCharacterData >

- (id<NSObject,DOMText>)splitText:(NSUInteger)_offset;

/* DOM Level 3 */

- (BOOL)isWhitespaceInElementContent;
- (NSString *)wholeText;
- (id<NSObject,DOMText>)replaceWholeText:(NSString *)_content;

@end

@protocol DOMCDATASection < DOMText >
@end

@protocol DOMElement < DOMNode >

/* attributes */

- (NSString *)tagName;

/* lookup */

- (id<NSObject,DOMNodeList>)getElementsByTagName:(NSString *)_tagName;
- (id<NSObject,DOMNodeList>)getElementsByTagName:(NSString *)_tagName
  namespaceURI:(NSString *)_uri;

/* element attributes */

- (BOOL)hasAttribute:(NSString *)_attrName;
- (BOOL)hasAttribute:(NSString *)_localName namespaceURI:(NSString *)_ns;

- (void)setAttribute:(NSString *)_attrName value:(NSString *)_value;
- (void)setAttribute:(NSString *)_localName namespaceURI:(NSString *)_ns
  value:(NSString *)_value;

- (NSString *)attribute:(NSString *)_attrName;
- (NSString *)attribute:(NSString *)_localName namespaceURI:(NSString *)_ns;
- (void)removeAttribute:(NSString *)_attrName;
- (void)removeAttribute:(NSString *)_attrName namespaceURI:(NSString *)_ns;

- (id<NSObject,DOMAttr>)setAttributeNode:(id<NSObject,DOMAttr>)_attrNode;
- (id<NSObject,DOMAttr>)removeAttributeNode:(id<NSObject,DOMAttr>)_attrNode;
- (id<NSObject,DOMAttr>)setAttributeNodeNS:(id<NSObject,DOMAttr>)_attrNode;
- (id<NSObject,DOMAttr>)removeAttributeNodeNS:(id<NSObject,DOMAttr>)_attrNode;

@end /* DOMElement */

@protocol DOMDocumentType < DOMNode >
@end /* DOMDocumentType */

@protocol DOMProcessingInstruction < DOMNode >

- (NSString *)target;
- (NSString *)data;

@end /* DOMProcessingInstruction */

@protocol DOMEntityReference < DOMNode >
@end

@class NGDOMImplementation;

@protocol DOMDocument < DOMNode >

- (id<NSObject,DOMDocumentType>)doctype;
- (NGDOMImplementation *)implementation;
- (id<NSObject,DOMElement>)documentElement;

- (id<NSObject,DOMNodeList>)getElementsByTagName:(NSString *)_tagName;
- (id<NSObject,DOMNodeList>)getElementsByTagName:(NSString *)_tagName
  namespaceURI:(NSString *)_uri;
- (id<NSObject,DOMElement>)getElementById:(NSString *)_eid;

/* creation */

- (id<NSObject,DOMElement>)createElement:(NSString *)_tagName;
- (id<NSObject,DOMElement>)createElement:(NSString *)_tagName
  namespaceURI:(NSString *)_uri;

- (id<NSObject,DOMDocumentFragment>)createDocumentFragment;
- (id<NSObject,DOMText>)createTextNode:(NSString *)_data;
- (id<NSObject,DOMComment>)createComment:(NSString *)_data;
- (id<NSObject,DOMCDATASection>)createCDATASection:(NSString *)_data;

- (id<NSObject,DOMProcessingInstruction>)
  createProcessingInstruction:(NSString *)_target data:(NSString *)_data;

- (id<NSObject,DOMAttr>)createAttribute:(NSString *)_name;
- (id<NSObject,DOMAttr>)createAttribute:(NSString *)_name
  namespaceURI:(NSString *)_uri;

- (id<NSObject,DOMEntityReference>)createEntityReference:(NSString *)_name;

@end /* DOMDocument */

#endif /* __DOM_DOMProtocols_H__ */
