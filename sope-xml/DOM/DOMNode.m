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

#include <DOM/DOMNode.h>
#include <DOM/DOMDocument.h>
#include <DOM/DOMProcessingInstruction.h>
#include <DOM/DOMCharacterData.h>
#include <DOM/DOMElement.h>
#include <DOM/DOMAttribute.h>
#include "common.h"

NSString *DOMNodeName(id<DOMNode> _node) {
  switch ([_node nodeType]) {
    case DOM_ATTRIBUTE_NODE:
      return [(id<DOMAttr>)_node name];
    case DOM_CDATA_SECTION_NODE:
      return @"#cdata-section";
    case DOM_COMMENT_NODE:
      return @"#comment";
    case DOM_DOCUMENT_NODE:
      return @"#document";
    case DOM_DOCUMENT_FRAGMENT_NODE:
      return @"#document-fragment";
    case DOM_ELEMENT_NODE:
      return [(id<DOMElement>)_node tagName];
    case DOM_PROCESSING_INSTRUCTION_NODE:
      return [(id<DOMProcessingInstruction>)_node target];
    case DOM_TEXT_NODE:
      return @"#text";
      
    case DOM_DOCUMENT_TYPE_NODE:
    case DOM_ENTITY_NODE:
    case DOM_ENTITY_REFERENCE_NODE:
    case DOM_NOTATION_NODE:
    default:
      NSLog(@"ERROR: unknown node type %i !", [_node nodeType]);
      return nil;
  }
}

NSString *DOMNodeValue(id _node) {
  switch ([_node nodeType]) {
    case DOM_ATTRIBUTE_NODE:
      return [_node value];
      
    case DOM_CDATA_SECTION_NODE:
    case DOM_COMMENT_NODE:
    case DOM_TEXT_NODE:
      return [(id<DOMCharacterData>)_node data];

    case DOM_DOCUMENT_NODE:
    case DOM_DOCUMENT_FRAGMENT_NODE:
    case DOM_ELEMENT_NODE:
      return nil;
      
    case DOM_PROCESSING_INSTRUCTION_NODE:
      return [(id<DOMProcessingInstruction>)_node data];
      
    case DOM_DOCUMENT_TYPE_NODE:
    case DOM_ENTITY_NODE:
    case DOM_ENTITY_REFERENCE_NODE:
    case DOM_NOTATION_NODE:
    default:
      NSLog(@"ERROR: unknown node type %i !", [_node nodeType]);
      return nil;
  }
}

@implementation NGDOMNode

- (void)_domNodeRegisterParentNode:(id)_parent {
}
- (void)_domNodeForgetParentNode:(id)_parent {
}

/* owner */

- (IDOMDocument)ownerDocument {
  id node;

  for (node = [self parentNode]; node; node = [node parentNode]) {
    if ([node nodeType] == DOM_DOCUMENT_NODE)
      return node;
    if ([node nodeType] == DOM_DOCUMENT_FRAGMENT_NODE)
      return node;
  }
  
  return nil;
}

/* attributes */

- (DOMNodeType)nodeType {
  return DOM_UNKNOWN_NODE;
}

- (NSString *)nodeName {
  return DOMNodeName(self);
}
- (NSString *)nodeValue {
  return DOMNodeValue(self);
}

- (id)subclassResponsibility:(SEL)_sel {
  [self doesNotRecognizeSelector:_sel];
  return nil;
}

- (NSString *)localName {
  /* introduced in DOM level 2 */
  return [self subclassResponsibility:_cmd];
}
- (NSString *)namespaceURI {
  /* introduced in DOM level 2 */
  return [self subclassResponsibility:_cmd];
}

- (void)setPrefix:(NSString *)_prefix {
  /* introduced in DOM level 2 */
  [self subclassResponsibility:_cmd];
}
- (NSString *)prefix {
  /* introduced in DOM level 2 */
  return [self subclassResponsibility:_cmd];
}

/* element attributes */

- (id<NSObject,DOMNamedNodeMap>)attributes {
  /* returns a NamedNodeList */
  return [self subclassResponsibility:_cmd];
}

/* modification */

- (BOOL)_isValidChildNode:(id)_node {
  return NO;
}

- (id<NSObject,DOMNode>)removeChild:(id<NSObject,DOMNode>)_node {
  return nil;
}
- (id<NSObject,DOMNode>)appendChild:(id<NSObject,DOMNode>)_node {
  return nil;
}

/* navigation */

- (id<NSObject,DOMNode>)parentNode {
  return [self subclassResponsibility:_cmd];
}

- (id<NSObject,DOMNode>)previousSibling {
  NGDOMNode *parent;
  
  if ((parent = (NGDOMNode *)[self parentNode]) == nil) return nil;
  if (parent == nil) return nil;
  if (![parent respondsToSelector:@selector(_domNodeBeforeNode:)]) return nil;
  return [parent _domNodeBeforeNode:self];
}
- (id<NSObject,DOMNode>)nextSibling {
  NGDOMNode *parent;
  
  if ((parent = (NGDOMNode *)[self parentNode]) == nil) return nil;
  if (parent == nil) return nil;
  if (![parent respondsToSelector:@selector(_domNodeBeforeNode:)]) return nil;
  return [parent _domNodeAfterNode:self];
}

- (id<NSObject,DOMNodeList>)childNodes {
  return nil;
}
- (BOOL)hasChildNodes {
  return NO;
}
- (id<NSObject,DOMNode>)firstChild {
  return nil;
}
- (id<NSObject,DOMNode>)lastChild {
  return nil;
}

/* key/value coding */

- (id)valueForUndefinedKey:(NSString *)_key {
  /* default is to raise an exception, we just return nil */
  return nil;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<0x%p[%@]: name=%@ parent=%@ type=%i #children=%i>",
                     self, NSStringFromClass([self class]),
                     [self nodeName],
                     [[self parentNode] nodeName],
                     [self nodeType],
                     [self hasChildNodes] ? [[self childNodes] length] : 0];
}

@end /* NGDOMNode */

#include "DOMXMLOutputter.h"
#include "DOMCharacterData.h"

@implementation NGDOMNode(Additions)

- (NSString *)nodeTypeString {
  switch ([self nodeType]) {
    case DOM_ATTRIBUTE_NODE:              return @"attribute";
    case DOM_CDATA_SECTION_NODE:          return @"cdata-section";
    case DOM_COMMENT_NODE:                return @"comment";
    case DOM_DOCUMENT_NODE:               return @"document";
    case DOM_DOCUMENT_FRAGMENT_NODE:      return @"document-fragment";
    case DOM_ELEMENT_NODE:                return @"element";
    case DOM_PROCESSING_INSTRUCTION_NODE: return @"processing-instruction";
    case DOM_TEXT_NODE:                   return @"text";
    case DOM_DOCUMENT_TYPE_NODE:          return @"document-type";
    case DOM_ENTITY_NODE:                 return @"entity";
    case DOM_ENTITY_REFERENCE_NODE:       return @"entity-reference";
    case DOM_NOTATION_NODE:               return @"notation";
    default:
      return @"unknown";
  }
}

- (NSString *)xmlStringValue {
  DOMXMLOutputter *out;
  NSMutableString *s;
  NSString *r;

  s   = [[NSMutableString alloc] initWithCapacity:1024];
  out = [[DOMXMLOutputter alloc] init];

  [out outputNode:self to:s];
  [out release];
  
  r = [s copy];
  [s release];
  return [r autorelease];
}

- (NSData *)xmlDataValue {
  return [[self xmlStringValue] dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)textValue {
  NSMutableString *s;
  
  s = [NSMutableString stringWithCapacity:256];

  switch ([self nodeType]) {
    case DOM_ELEMENT_NODE:
    case DOM_DOCUMENT_NODE:
    case DOM_ATTRIBUTE_NODE:
      if ([self hasChildNodes]) {
        id children;
        unsigned i, count;
        
        children = [self childNodes];
        for (i = 0, count = [children count]; i < count; i++) {
          NSString *cs;

          cs = [[children objectAtIndex:i] textValue];
          if (cs) [s appendString:cs];
        }
      }
      break;
      
    case DOM_TEXT_NODE:
    case DOM_COMMENT_NODE:
    case DOM_CDATA_SECTION_NODE:
      [s appendString:[(id<DOMCharacterData>)self data]];
      break;
      
    default:
      return nil;
  }
  
  return [[s copy] autorelease];
}

@end /* NGDOMNode(Additions) */

@implementation NSArray(DOMNodeList)

- (unsigned)length {
  return [self count];
}

@end /* NSObject(DOMNodeList) */
