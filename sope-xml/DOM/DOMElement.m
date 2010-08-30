/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#include <DOM/DOMElement.h>
#include <DOM/DOMNamedNodeMap.h>
#include <DOM/DOMAttribute.h>
#include <DOM/DOMDocument.h>
#include <DOM/DOMNodeWalker.h>
#include "DOMNode+QueryPath.h"
#include "common.h"


@interface _DOMElementAttrNamedNodeMap : NSObject < DOMNamedNodeMap >
{
  NGDOMElement *element; /* non-retained */
}

- (id)initWithElement:(id)_element;

- (id)objectEnumerator;

- (void)invalidate;

@end /* _DOMElementAttrNamedNodeMap */

@interface NGDOMElement(Privates)
- (NSUInteger)_numberOfAttributes;
- (id)_attributeNodeAtIndex:(NSUInteger)_idx;
- (id)attributeNode:(NSString *)_localName;
- (id)attributeNode:(NSString *)_localName namespaceURI:(NSString *)_ns;
@end

static NSNull *null = nil;

@implementation NGDOMElement

- (id)initWithTagName:(NSString *)_tagName namespaceURI:(NSString *)_uri {
  if (null == nil)
    null = [[NSNull null] retain];
  
  if ((self = [super init])) {
    self->tagName      = [_tagName copy];
    self->namespaceURI = [_uri     copy];
  }
  return self;
}
- (id)initWithTagName:(NSString *)_tagName {
  return [self initWithTagName:_tagName namespaceURI:nil];
}

- (void)dealloc {
  [self->attributes makeObjectsPerformSelector:
                      @selector(_domNodeForgetParentNode:)
                    withObject:self];

  [self->attrNodeMap invalidate];
  [self->attrNodeMap    release];
  [self->keyToAttribute release];
  [self->attributes     release];
  [self->tagName        release];
  [self->namespaceURI   release];
  [self->prefix         release];
  [super dealloc];
}

/* attributes */

- (NSString *)tagName {
  return self->tagName;
}
- (NSString *)localName {
  return self->tagName;
}

- (void)setPrefix:(NSString *)_prefix {
  id old = self->prefix;
  self->prefix = [_prefix copy];
  [old release];
}
- (NSString *)prefix {
  return self->prefix;
}

- (NSString *)namespaceURI {
  return self->namespaceURI;
}

- (void)setLine:(NSUInteger)_line {
  self->line = _line;
}
- (NSUInteger)line {
  return self->line;
}

/* lookup */

- (void)_walk_getElementsByTagName:(id)_walker {
  id node;
  
  node = [_walker currentNode];
  if ([node nodeType] != DOM_ELEMENT_NODE)
    return;

  if (![[node tagName] isEqualToString:
          [(NSArray *)[_walker context] objectAtIndex:0]])
    /* tagname doesn't match */
    return;
  
  [[(NSArray *)[_walker context] objectAtIndex:1] addObject:node];
}
- (void)_walk_getElementsByTagNameAddAll:(id)_walker {
  id node;
  
  node = [_walker currentNode];
  if ([node nodeType] != DOM_ELEMENT_NODE)
    return;
  
  [(NSMutableArray *)[_walker context] addObject:node];
}
- (id<NSObject,DOMNodeList>)getElementsByTagName:(NSString *)_tagName {
  /* introduced in DOM2, should return a *live* list ! */
  NGDOMNodePreorderWalker *walker;
  NSMutableArray *array;
  SEL sel;
  id  ctx;
  
  if (![self hasChildNodes])
    return nil;

  if (_tagName == nil)
    return nil;

  array = [NSMutableArray arrayWithCapacity:4];
  
  if ([_tagName isEqualToString:@"*"]) {
    _tagName = nil;
    ctx = array;
    sel = @selector(_walk_getElementsByTagNameAddAll:);
  }
  else {
    ctx = [NSArray arrayWithObjects:_tagName, array, nil];
    sel = @selector(_walk_getElementsByTagName:);
  }
  
  walker = [[NGDOMNodePreorderWalker alloc]
	     initWithTarget:self selector:sel context:ctx];
  
  [walker walkNode:self];

  [walker release]; walker = nil;
  return [[array copy] autorelease];
}
- (id<NSObject,DOMNodeList>)getElementsByTagName:(NSString *)_tagName
  namespaceURI:(NSString *)_uri
{
  // TODO: implement
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

/* element attributes */

- (void)_ensureAttrs {
  if (self->attributes == nil)
    self->attributes = [[NSMutableArray alloc] init];
  if (self->keyToAttribute == nil)
    self->keyToAttribute = [[NSMutableDictionary alloc] init];
}

- (void)_attributeSetChanged {
}

- (NSUInteger)_numberOfAttributes {
  return [self->attributes count];
}
- (id)_attributeNodeAtIndex:(NSUInteger)_idx {
  if (_idx >= [self->attributes count])
    return nil;
  return [self->attributes objectAtIndex:_idx];
}

- (id)_keyForAttribute:(id<DOMAttr>)_attrNode {
  return [_attrNode name];
}
- (id)_nskeyForLocalName:(NSString *)attrName namespaceURI:(NSString *)nsURI {
  id key;
  
  if (attrName == nil)
    return nil;
  
  if (nsURI) {
    id objs[2];

    objs[0] = attrName;
    objs[1] = nsURI;
    key = [NSArray arrayWithObjects:objs count:2];
  }
  else
    key = attrName;
  
  return key;
}
- (id)_nskeyForAttribute:(id<DOMAttr>)_attrNode {
  NSString *attrName;
  
  if ((attrName = [_attrNode name]) == nil) {
    NSLog(@"WARNING: attribute %@ has no valid attribute name !", _attrNode);
    return nil;
  }
  
  return [self _nskeyForLocalName:attrName
               namespaceURI:[_attrNode namespaceURI]];
}

- (BOOL)hasAttribute:(NSString *)_attrName {
  return [self hasAttribute:_attrName namespaceURI:[self namespaceURI]];
}

- (void)setAttribute:(NSString *)_attrName value:(NSString *)_value {
  [self setAttribute:_attrName namespaceURI:[self namespaceURI] value:_value];

#if 0 // ms: ??
  id node;
  
  NSAssert1(_attrName, @"invalid attribute name '%@'", _attrName);

  if ((node = [self->keyToAttribute objectForKey:_attrName]) == nil) {
    /* create new node */
    node = [[self ownerDocument] createAttribute:_attrName];
  }
  NSAssert(node, @"couldn't find/create node for attribute");

  node = [self setAttributeNode:node];
  
  [node setValue:_value];
#endif
}
- (id)attributeNode:(NSString *)_attrName {
  return [self attributeNode:_attrName namespaceURI:[self namespaceURI]];
}
- (NSString *)attribute:(NSString *)_attrName {
  return [[self attributeNode:_attrName] value];
}

- (BOOL)hasAttribute:(NSString *)_localName namespaceURI:(NSString *)_ns {
  id objs[2];
  id key;

  if ([_ns isEqualToString:@"*"]) {
    /* match any namespace */
    NSEnumerator *e;
    id attr;
    
    if ((attr = [self->keyToAttribute objectForKey:_localName]))
      return YES;
    
    e = [self->keyToAttribute keyEnumerator];
    while ((key = [e nextObject])) {
      if ([key isKindOfClass:[NSArray class]]) {
        if ([[key objectAtIndex:0] isEqualToString:_localName])
          return YES;
      }
    }
    return NO;
  }
  
  objs[0] = _localName;
  objs[1] = _ns ? _ns : (NSString *)null;
  key = [NSArray arrayWithObjects:objs count:2];
  
  return [self->keyToAttribute objectForKey:key] ? YES : NO;
}

- (void)setAttribute:(NSString *)_localName namespaceURI:(NSString *)_ns
  value:(NSString *)_value
{
  id key;
  id node;
  
  key = [self _nskeyForLocalName:_localName namespaceURI:_ns];
  NSAssert2(key, @"invalid (ns-)attribute name localName='%@', uri='%@'",
            _localName, _ns);
  
  if ((node = [self->keyToAttribute objectForKey:key]) == nil) {
    /* create new node */
    node = [[self ownerDocument] createAttribute:_localName namespaceURI:_ns];
  }
  NSAssert(node, @"couldn't find/create node for attribute");

  node = [self setAttributeNodeNS:node];
  
  [node setValue:_value];
}
- (id)attributeNode:(NSString *)_localName namespaceURI:(NSString *)_ns {
  id objs[2];
  id key;
  
  if ([_ns isEqualToString:@"*"]) {
    /* match any namespace */
    NSEnumerator *e;
    id attr;
    
    if ((attr = [self->keyToAttribute objectForKey:_localName]))
      return attr;
    
    e = [self->keyToAttribute keyEnumerator];
    while ((key = [e nextObject])) {
      if ([key isKindOfClass:[NSArray class]]) {
        if ([[key objectAtIndex:0] isEqualToString:_localName])
          return [self->keyToAttribute objectForKey:key];
      }
    }
    return nil;
  }
  
  objs[0] = _localName;
  objs[1] = _ns ? _ns : (NSString *)null;
  key = [NSArray arrayWithObjects:objs count:2];

  return [self->keyToAttribute objectForKey:key];
}
- (NSString *)attribute:(NSString *)_localName namespaceURI:(NSString *)_ns {
  return [[self attributeNode:_localName namespaceURI:_ns] value];
}

- (id<NSObject, DOMAttr>)setAttributeNodeNS:(id<NSObject, DOMAttr>)_attrNode {
  id key, oldNode;
  
  if (_attrNode == nil)
    /* invalid node parameters */
    return nil;
  
  if ((key = [self _nskeyForAttribute:_attrNode]) == nil)
    /* couldn't get key */
    return nil;
  
  [self _ensureAttrs];
  
  /* check if the key is already added */
  
  if ((oldNode = [self->keyToAttribute objectForKey:key])) {
    if (oldNode == _attrNode) {
      /* already contained */
      // NSLog(@"node is already set !");
      return _attrNode;
    }
    
    /* replace existing node */
    [self->attributes replaceObjectAtIndex:
                        [self->attributes indexOfObject:oldNode]
                      withObject:_attrNode];
    [self->keyToAttribute setObject:_attrNode forKey:key];
    
    [(id)_attrNode _domNodeRegisterParentNode:self];
    [self _attributeSetChanged];

    return _attrNode;
  }
  else {
    /* add node */

    NSAssert(self->keyToAttribute, @"missing keyToAttribute");
    NSAssert(self->attributes,     @"missing attrs");
    
    [self->keyToAttribute setObject:_attrNode forKey:key];
    [self->attributes     addObject:_attrNode];
    
    [(id)_attrNode _domNodeRegisterParentNode:self];
    [self _attributeSetChanged];

    // NSLog(@"added attr %@, elem %@", _attrNode, self);
    
    return _attrNode;
  }
}

- (void)removeAttribute:(NSString *)_attr namespaceURI:(NSString *)_uri {
  id node;
  id key;
  
  key = [self _nskeyForLocalName:_attr namespaceURI:_uri];
  NSAssert2(key, @"invalid (ns-)attribute name '%@', '%@'", _attr, _uri);

  node = [self->keyToAttribute objectForKey:key];
  
  [self removeAttributeNodeNS:node];
}
- (id<NSObject,DOMAttr>)removeAttributeNodeNS:(id<NSObject,DOMAttr>)_attrNode {
  id key, oldNode;
  
  if (_attrNode == nil)
    /* invalid node parameters */
    return nil;
  
  if (self->attributes == nil)
    /* no attributes are set up */
    return nil;
  
  if ((key = [self _nskeyForAttribute:_attrNode]) == nil)
    /* couldn't get key for node */
    return nil;

  if ((oldNode = [self->keyToAttribute objectForKey:key])) {
    /* the node's key exists */
    if (oldNode != _attrNode) {
      /* the node has the same key, but isn't the same */
      return nil;
    }

    /* ok, found the node, let's remove ! */
    [[_attrNode retain] autorelease];
    [self->keyToAttribute removeObjectForKey:key];
    [self->attributes removeObjectIdenticalTo:_attrNode];
    
    [(id)_attrNode _domNodeForgetParentNode:self];
    [self _attributeSetChanged];
    
    return _attrNode;
  }
  else
    /* no such attribute is stored */
    return nil;
}

- (id<NSObject,DOMAttr>)setAttributeNode:(id<NSObject,DOMAttr>)_attrNode {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}
- (id<NSObject,DOMAttr>)removeAttributeNode:(id<NSObject,DOMAttr>)_attrNode {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}
- (void)removeAttribute:(NSString *)_attr {
  id node;
  
  NSAssert1(_attr, @"invalid attribute name '%@'", _attr);

  node = [self->keyToAttribute objectForKey:_attr];
  
  [self removeAttributeNode:node];
}

/* node */

- (BOOL)_isValidChildNode:(id)_node {
  switch ([_node nodeType]) {
    case DOM_ELEMENT_NODE:
    case DOM_TEXT_NODE:
    case DOM_COMMENT_NODE:
    case DOM_PROCESSING_INSTRUCTION_NODE:
    case DOM_CDATA_SECTION_NODE:
    case DOM_ENTITY_REFERENCE_NODE:
      return YES;
      
    default:
      return NO;
  }
}

- (DOMNodeType)nodeType {
  return DOM_ELEMENT_NODE;
}

- (id<NSObject,DOMNamedNodeMap>)attributes {
  /* returns a named-node-map */
  if (self->attrNodeMap == nil) {
    self->attrNodeMap =
      [[_DOMElementAttrNamedNodeMap alloc] initWithElement:self];
  }
  return self->attrNodeMap;
}

/* parent node */

- (void)_domNodeRegisterParentNode:(id)_parent {
  self->parent = _parent;
}
- (void)_domNodeForgetParentNode:(id)_parent {
  if (_parent == self->parent)
    /* the node's parent was deallocated */
    self->parent = nil;
}
- (id<NSObject,DOMNode>)parentNode {
  return self->parent;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<0x%p[%@]: name=%@ parent=%@ #attrs=%i #children=%i>",
                     self, NSStringFromClass([self class]),
                     [self nodeName],
                     [[self parentNode] nodeName],
                     [self _numberOfAttributes],
                     [self hasChildNodes] ? [[self childNodes] length] : 0];
}

/* QPValues */

- (NSException *)setQueryPathValue:(id)_value {
  return [NSException exceptionWithName:@"QueryPathEvalException"
                      reason:@"cannot set query-path value on DOMElement !"
                      userInfo:nil];
}
- (id)queryPathValue {
  return [self childNodes];
}

/* key/value coding */

- (id)valueForKey:(NSString *)_key {
  if ([_key hasPrefix:@"/"])
    return [self lookupQueryPath:[_key substringFromIndex:1]];
  
  if ([_key hasPrefix:@"@"]) {
    return [[self attributes] namedItem:[_key substringFromIndex:1]
			      namespaceURI:@"*"];
  }
  
  return [super valueForKey:_key];
}

@end /* NGDOMElement */



@implementation _DOMElementAttrNamedNodeMap

- (id)initWithElement:(id)_element {
  self->element = _element;
  return self;
}

- (void)invalidate {
  self->element = nil;
}

static inline void _checkValid(_DOMElementAttrNamedNodeMap *self) {
  if (self->element == nil) {
    NSCAssert(self->element,
              @"named node map is invalid (element was deallocated) !");
  }
}

/* access */

static NSString *_XNSUri(NSString *_name) {
  NSRange r1;

  if (![_name hasPrefix:@"{"])
    return nil;
  
  r1 = [_name rangeOfString:@"}"];
  if (r1.length == 0)
    return nil;
  
  r1.length   = (r1.location - 2);
  r1.location = 1;
  return [_name substringWithRange:r1];
}
static NSString *_XNSLocalName(NSString *_name) {
  NSRange r;
  
  r = [_name rangeOfString:@"}"];
  return r.length == 0
    ? _name
    : [_name substringFromIndex:(r.location + r.length)];
}

- (NSUInteger)length {
  _checkValid(self);
  return [self->element _numberOfAttributes];
}
- (id)objectAtIndex:(NSUInteger)_idx {
  _checkValid(self);
  return [self->element _attributeNodeAtIndex:_idx];
}

- (IDOMNode)namedItem:(NSString *)_name {
  NSString *nsuri;
  _checkValid(self);
  
  if ((nsuri = _XNSUri(_name)))
    return [self namedItem:_XNSLocalName(_name) namespaceURI:nsuri];
  
  return [self->element attributeNode:_name];
}
- (IDOMNode)setNamedItem:(IDOMNode)_node {
  _checkValid(self);

  // TODO: is the cast correct?
  return [self->element setAttributeNode:(id<NSObject,DOMAttr>)_node];
}
- (IDOMNode)removeNamedItem:(NSString *)_name {
  NSString *nsuri;
  id node;
  
  _checkValid(self);
  if ((nsuri = _XNSUri(_name)))
    return [self removeNamedItem:_XNSLocalName(_name) namespaceURI:nsuri];
  
  if ((node = [self->element attributeNode:_name])) {
    node = [node retain];
    [self->element removeAttribute:_name];
    return [node autorelease];
  }
  else
    return nil;
}

/* DOM2 access */

- (IDOMNode)namedItem:(NSString *)_name namespaceURI:(NSString *)_uri {
  return [self->element attributeNode:_name namespaceURI:_uri];
}
- (IDOMNode)setNamedItemNS:(IDOMNode)_node {
  _checkValid(self);
  // TODO: is the cast correct?
  return [self->element setAttributeNodeNS:(id<NSObject,DOMAttr>)_node];
}
- (IDOMNode)removeNamedItem:(NSString *)_name namespaceURI:(NSString *)_uri {
  id node;

  _checkValid(self);
  if ((node = [self->element attributeNode:_name namespaceURI:_uri])) {
    node = [node retain];
    [self->element removeAttribute:_name namespaceURI:_uri];
    return [node autorelease];
  }
  else
    return nil;
}

/* mimic NSArray */

- (NSUInteger)count {
  _checkValid(self);
  return [self->element _numberOfAttributes];
}

- (id)objectEnumerator {
  NSMutableArray *ma;
  unsigned i, count;

  _checkValid(self);
  if ((count = [self->element _numberOfAttributes]) == 0)
    return nil;

  ma = [NSMutableArray arrayWithCapacity:count];
  
  for (i = 0; i < count; i++)
    [ma addObject:[self->element _attributeNodeAtIndex:i]];
  
  return [ma objectEnumerator];
}

/* mimic NSDictionary */

- (void)setObject:(id)_value forKey:(id)_key {
  _checkValid(self);
  [self takeValue:_value forKey:[_key stringValue]];
}
- (id)objectForKey:(id)_key {
  _checkValid(self);
  return [self valueForKey:[_key stringValue]];
}

/* KVC */

- (void)takeValue:(id)_value forKey:(NSString *)_key {
  id node;
  _checkValid(self);
  
  if ((node = [self->element attributeNode:_key namespaceURI:@"*"])) {
    [node setValue:[_value stringValue]];
  }
  else {
    [self->element setAttribute:_key namespaceURI:@"xhtml"
                   value:[_value stringValue]];
  }
}
- (id)valueForKey:(NSString *)_key {
  id v;
  _checkValid(self);
  
  if ((v = [self namedItem:_key]))
    return [v value];
  if ((v = [self namedItem:_key namespaceURI:@"*"]))
    return [v value];
  
  return nil;
}

/* JSSupport */

- (id)_jsprop_length {
  return [NSNumber numberWithInt:[self length]];
}

- (id)_jsfunc_item:(NSArray *)_args {
  unsigned count;
  
  if ((count = [_args count]) == 0) return nil;
  return [self objectAtIndex:[[_args objectAtIndex:0] intValue]];
}

- (id)_jsfunc_getNamedItem:(NSArray *)_args {
  unsigned count;
  
  if ((count = [_args count]) == 0) return nil;
  return [self namedItem:[[_args objectAtIndex:0] stringValue]];
}
- (id)_jsfunc_getNamedItemNS:(NSArray *)_args {
  unsigned count;
  
  if ((count = [_args count]) == 0) return nil;
  if (count == 1)
    return [self namedItem:[[_args objectAtIndex:0] stringValue]];
  else {
    return [self namedItem:[[_args objectAtIndex:1] stringValue]
                 namespaceURI:[[_args objectAtIndex:0] stringValue]];
  }
}

- (id)_jsfunc_setNamedItem:(NSArray *)_args {
  unsigned i, count;
  id last = nil;

  for (i = 0, count = [_args count]; i < count; i++)
    last = [self setNamedItem:[_args objectAtIndex:i]];
  return last;
}
- (id)_jsfunc_setNamedItemNS:(NSArray *)_args {
  unsigned i, count;
  id last = nil;

  for (i = 0, count = [_args count]; i < count; i++)
    last = [self setNamedItemNS:[_args objectAtIndex:i]];
  return last;
}

- (id)_jsfunc_removeNamedItem:(NSArray *)_args {
  unsigned count;
  
  if ((count = [_args count]) == 0) return nil;
  return [self namedItem:[[_args objectAtIndex:0] stringValue]];
}
- (id)_jsfunc_removeNamedItemNS:(NSArray *)_args {
  unsigned count;
  
  if ((count = [_args count]) == 0) return nil;
  if (count == 1)
    return [self removeNamedItem:[[_args objectAtIndex:0] stringValue]];
  else {
    return [self removeNamedItem:[[_args objectAtIndex:1] stringValue]
                 namespaceURI:[[_args objectAtIndex:0] stringValue]];
  }
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  NSEnumerator *e;
  id attr;
  
  ms = [NSMutableString stringWithCapacity:1024];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [ms appendFormat:@" element=%@", self->element];
  
  [ms appendString:@" attributes:\n"];
  e = [self objectEnumerator];
  while ((attr = [e nextObject]) != nil) {
    [ms appendString:[attr description]];
    [ms appendString:@"\n"];
  }
  
  [ms appendString:@">"];
  return ms;
}

@end /* _DOMElementAttrNamedNodeMap */
