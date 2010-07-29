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

#include "DOMAttribute.h"
#include "DOMDocument.h"
#include "common.h"

@implementation NGDOMAttribute

- (id)initWithName:(NSString *)_name namespaceURI:(NSString *)_uri {
  if ((self = [super init])) {
    self->name         = [_name copy];
    self->namespaceURI = [_uri  copy];
  }
  return self;
}

- (id)initWithName:(NSString *)_name {
  return [self initWithName:_name namespaceURI:nil];
}

- (void)dealloc {
  [self->prefix release];
  [self->name   release];
  [self->namespaceURI release];
  [super dealloc];
}

/* element tracking */

- (void)_domNodeRegisterParentNode:(id)_element {
  self->element = _element;
}
- (void)_domNodeForgetParentNode:(id)_element {
  if (_element == self->element)
    self->element = nil;
}

/* attributes */

- (IDOMElement)ownerElement {
  return self->element;
}
- (IDOMDocument)ownerDocument {
  return [[self ownerElement] ownerDocument];
}

- (BOOL)specified {
  return self->isSpecified;
}

- (NSString *)name {
  return self->name;
}

- (NSString *)namespaceURI {
  return self->namespaceURI;
}

- (void)setPrefix:(NSString *)_prefix {
  id old = self->prefix;
  self->prefix = [_prefix copy];
  [old release];
}
- (NSString *)prefix {
  return self->prefix;
}

- (void)setValue:(NSString *)_value {
  id child;
  
  self->isSpecified = YES;

  /* remove all existing children */
  while ((child = [self lastChild]))
    [self removeChild:child];
  
  child = [[self ownerDocument] createTextNode:_value];
  NSAssert1(child, @"couldn't create text-node child for value '%@' !", _value);
  
  [self appendChild:child];
}

- (NSString *)_stringValueOfChildNode:(id)_node {
  return [_node nodeValue];
}
- (NSString *)value {
  id       children;
  unsigned count;
  
  if (![self hasChildNodes])
    return nil;
  
  children = [self childNodes];
  if ((count = [children count]) == 0)
    return nil;
  
  if (count == 1) {
    return [self _stringValueOfChildNode:[children objectAtIndex:0]];
  }
  else {
    unsigned i;
    NSMutableString *s;

    s = [NSMutableString stringWithCapacity:256];
    for (i = 0; i < count; i++) {
      [s appendString:
	   [self _stringValueOfChildNode:[children objectAtIndex:i]]];
    }
    return [[s copy] autorelease];
  }
}

/* node */

- (BOOL)_isValidChildNode:(id)_node {
  switch ([_node nodeType]) {
    case DOM_TEXT_NODE:
    case DOM_ENTITY_REFERENCE_NODE:
      return YES;
      
    default:
      return NO;
  }
}

- (DOMNodeType)nodeType {
  return DOM_ATTRIBUTE_NODE;
}

- (id<NSObject,DOMNamedNodeMap>)attributes {
  return nil;
}

- (id<NSObject,DOMNode>)parentNode {
  return nil;
}
- (id<NSObject,DOMNode>)nextSibling {
  return nil;
}
- (id<NSObject,DOMNode>)previousSibling {
  return nil;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<0x%p[%@]: {%@}%@%s '%@'>",
                     self, NSStringFromClass([self class]),
                     self->namespaceURI,
                     [self name],
                     [self specified] ? " specified" : "",
                     [self stringValue]];
}

/* ObjCValues */

- (NSString *)stringValue {
  return [self value];
}
- (int)intValue {
  return [[self stringValue] intValue];
}
- (double)doubleValue {
  return [[self stringValue] doubleValue];
}

/* QPValues */

- (NSException *)setQueryPathValue:(id)_value {
  [self setValue:[_value stringValue]];
  return nil;
}
- (id)queryPathValue {
  return [self value];
}

@end /* NGDOMAttribute */
