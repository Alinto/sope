/*
  Copyright (C) 2000-2009 SKYRIX Software AG

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

#include "DOMXMLOutputter.h"
#include "DOMDocument.h"
#include "DOMElement.h"
#include "common.h"

@interface DOMXMLOutputter(Privates)
- (void)outputNode:(id<DOMNode>)_node to:(id)_target;
- (void)outputNodeList:(id<DOMNodeList>)_nodeList to:(id)_target;
@end

@interface DOMXMLOutputter(PrefixStack)
- (NSString *)topPrefix;
- (NSString *)topNamespace;
- (void)pushPrefix:(NSString *)_prefix namespace:(NSString *)_namespace;
- (void)popPrefixAndNamespace;
- (BOOL)isTagValidInStack:(id)_node;
- (NSArray *)newAttributePrefixesAndNamespaces:(NSArray *)_attrs;
@end /* DOMXMLOutputter(PrefixStack) */


@implementation DOMXMLOutputter

- (id)init {
  if ((self = [super init])) {
    self->stack = [[NSMutableArray alloc] initWithCapacity:32];
  }
  return self;
}

- (void)dealloc {
  [self->stack release];
  [super dealloc];
}

- (void)indentOn:(id)_target {
  int i;
  
  for (i = 0; i < (self->indent * 4); i++) {
    if (_target)
      [_target appendString:@" "];
    else
      fputc(' ', stdout);
  }
}

- (void)write:(NSString *)s to:(id)_target {
  if (_target)
    [_target appendString:s];
  else
#ifndef __APPLE__
    printf("%s", [s cString]);
#else
    printf("%s", [s UTF8String]);
#endif
}
- (BOOL)currentElementPreservesWhitespace {
  return NO;
}

- (void)outputAttributeNode:(id<DOMAttr>)_attrNode
  ofNode:(id<DOMNode>)_node
  to:(id)_target
{
  if ([[_attrNode prefix] length] > 0) {
    [self write:[_attrNode prefix] to:_target];
    [self write:@":"               to:_target];
  }
  [self write:[_attrNode name] to:_target];
  
  if ([_attrNode hasChildNodes]) {
    id children;
    unsigned i, count;

    [self write:@"=\"" to:_target];

    children = [_attrNode childNodes];
    for (i = 0, count = [children count]; i < count; i++) {
      id child;
      
      child = [children objectAtIndex:i];
      
      if ([child nodeType] == DOM_TEXT_NODE)
        [self write:[(id<DOMText>)child data] to:_target];
      else
        NSLog(@"WARNING: unsupported attribute value node %@", child);
    }
    
    [self write:@"\"" to:_target];
  }
  else
    NSLog(@"WARNING: attribute %@ has no content !", _attrNode);
}

- (void)outputAttributeNodes:(id<DOMNamedNodeMap>)_nodes
  list:(NSArray *)_list to:(id)_target
{
  unsigned i, count, count2;
  
  if ((count = [_nodes length]) == 0)
    return;

  // append required prefix and namespaces
  for (i = 0, count2 = [_list count]; i < count2; i = i + 2) {
    [self write:@" xmlns:" to:_target];
    [self write:[_list objectAtIndex:i]   to:_target];
    [self write:@"=\""     to:_target];
    [self write:[_list objectAtIndex:i+1] to:_target];
    [self write:@"\""      to:_target];
  }
  
  for (i = 0; i < count; i++) {
    id<DOMAttr> attrNode;
    
    attrNode = [_nodes objectAtIndex:i];
    
    [self write:@" " to:_target];
    [self outputAttributeNode:attrNode ofNode:nil to:_target];
  }
}

- (void)outputTextNode:(id<DOMText>)_node to:(id)_target {
  NSString *s;
  unsigned len;

  s = [_node data];
  if ((len = [s length]) == 0)
    return;
  
  if (![self currentElementPreservesWhitespace]) {
    unsigned i;
    
    for (i = 0; i < len; i++) {
      if (!isspace([s characterAtIndex:i]))
        break;
    }
    if (i == len)
      /* only whitespace */
      return;
    
    [self indentOn:_target];
  }
  
  [self write:[_node data] to:_target];
  
  if (![self currentElementPreservesWhitespace])
    [self write:@"\n" to:_target];
}
- (void)outputCommentNode:(id<DOMComment>)_node to:(id)_target {
  [self write:@"<!-- "     to:_target];
  [self write:[_node data] to:_target];
  [self write:@" -->"      to:_target];
  
  if (![self currentElementPreservesWhitespace])
    [self write:@"\n" to:_target];
}

- (void)outputElementNode:(id<DOMElement>)_node to:(id)_target {
  NSArray  *list;  // new attribute prefixes and namespaces
  NSString *tagName;
  NSString *ns = nil;
  NSString *tagURI;
  NSString *tagPrefix;
  BOOL     isNodeValid;
  unsigned i, count;
  
  // getting new attributes prefixes and namespaces
  list = (NSArray *)[_node attributes];
  list = [self newAttributePrefixesAndNamespaces:list];

  // push new attribute prefixes and namespaces to stack
  for (i = 0, count = [list count]; i < count; i = i + 2) {
    [self pushPrefix:[list objectAtIndex:i]
          namespace:[list objectAtIndex:i+1]];
  }
  
  tagURI       = [_node namespaceURI];
  tagPrefix    = [_node prefix];
  isNodeValid  = [self isTagValidInStack:_node];
  if (!isNodeValid) [self pushPrefix:tagPrefix namespace:tagURI];

  /* needs to declare namespaces !!! */
  tagName = [_node tagName];
  if ([[_node prefix] length] > 0) {
    NSString *p;

    if (!isNodeValid) {
      ns = [NSString stringWithFormat:@" xmlns:%@=\"%@\"",
                     tagPrefix,
                     tagURI];
    }
    p       = [_node prefix];
    p       = [p stringByAppendingString:@":"];
    tagName = [p stringByAppendingString:tagName];
  }
  else if ([tagURI length] > 0) {
    id   parent;
    BOOL addNS;

    addNS = YES;
    if ((parent = [_node parentNode])) {
      if ([parent nodeType] == DOM_ELEMENT_NODE) {
        if ([[parent namespaceURI] isEqualToString:tagURI]) {
          if ([[parent prefix] length] == 0)
            addNS = NO;
        }
      }
    }
    else
      addNS = YES;
    
    if (addNS)
      ns = [NSString stringWithFormat:@" xmlns=\"%@\"", [_node namespaceURI]];
    else
      ns = nil;
  }
  else
    ns = nil;
  
  if ([_node hasChildNodes]) {
    [self indentOn:_target];
    [self write:@"<"    to:_target];
    [self write:tagName to:_target];
    if (ns) [self write:ns to:_target];
    
    [self outputAttributeNodes:[_node attributes] list:list to:_target];
    [self write:@">\n"  to:_target];

    self->indent++;
    [self outputNodeList:[_node childNodes] to:_target];
    self->indent--;

    [self indentOn:_target];
    [self write:@"</"   to:_target];
    [self write:tagName to:_target];
    [self write:@">\n"  to:_target];
  }
  else {
    [self indentOn:_target];
    [self write:@"<"    to:_target];
    [self write:tagName to:_target];
    [self outputAttributeNodes:[_node attributes] list:list to:_target];
    [self write:@"/>\n" to:_target];
  }
  // pop attributes prefixes and namespaces from stack
  for (i = 0; i < count; i = i + 2) {
    [self popPrefixAndNamespace];
  }
  if (!isNodeValid) [self popPrefixAndNamespace];
}

- (void)outputCDATA:(id<DOMCharacterData>)_node to:(id)_target {
  [self write:@"<![CDATA[" to:_target];
  [self outputNodeList:[_node childNodes] to:_target];
  [self write:@"]]>" to:_target];
}

- (void)outputPI:(id<DOMProcessingInstruction>)_node to:(id)_target {
  [self indentOn:_target];
  [self write:@"<?"          to:_target];
  [self write:[_node target] to:_target];
  [self write:@" "           to:_target];
  [self write:[_node data]   to:_target];
  [self write:@"?>\n"        to:_target];
}

- (void)outputNode:(id<DOMNode>)_node to:(id)_target {
  switch ([_node nodeType]) {
    case DOM_ELEMENT_NODE:
      [self outputElementNode:(id)_node to:_target];
      break;
    case DOM_CDATA_SECTION_NODE:
      [self outputCDATA:(id)_node to:_target];
      break;
    case DOM_PROCESSING_INSTRUCTION_NODE:
      [self outputPI:(id)_node to:_target];
      break;
    case DOM_TEXT_NODE:
      [self outputTextNode:(id)_node to:_target];
      break;
    case DOM_COMMENT_NODE:
      [self outputCommentNode:(id)_node to:_target];
      break;
      
    default:
      NSLog(@"cannot output node '%@'", _node);
      break;
  }
}
- (void)outputNodeList:(id<DOMNodeList>)_nodeList to:(id)_target {
  id       children;
  unsigned i, count;
  
  children = _nodeList;
  
  for (i = 0, count = [children count]; i < count; i++)
    [self outputNode:[children objectAtIndex:i] to:_target];
}

- (void)outputDocument:(id)_document to:(id)_target {
  if (![_document hasChildNodes]) {
    NSLog(@"ERROR: document has no childnodes !");
    return;
  }
  
  [self write:@"<?xml version=\"1.0\"?>\n" to:_target];
  
  [self->stack removeAllObjects];
  [self outputNodeList:[_document childNodes] to:_target];
  
#if 0
  NS_DURING {
  }
  NS_HANDLER
    abort();
  NS_ENDHANDLER;
#endif
}

@end /* DOMXMLOutputter */


@implementation DOMXMLOutputter(PrefixStack)

- (void)_checkPrefixStack {
  NSAssert2(([self->stack count] % 2 == 0),
            @"%s: prefixStack is not valid (%@)!!!",
            __PRETTY_FUNCTION__,
            self->stack);
}

- (NSString *)topPrefix {
  [self _checkPrefixStack];
  if ([self->stack count] == 0) return nil;
  return [self->stack objectAtIndex:[self->stack count] -2];
}

- (NSString *)topNamespace {
  [self _checkPrefixStack];
  if ([self->stack count] == 0) return nil;
  return [self->stack lastObject];
}

- (void)pushPrefix:(NSString *)_prefix namespace:(NSString *)_namespace {
  [self _checkPrefixStack];
  [self->stack addObject:(_prefix)    ? _prefix    : (NSString *)@""];
  [self->stack addObject:(_namespace) ? _namespace : (NSString *)@""];
}

- (void)popPrefixAndNamespace {
  [self _checkPrefixStack];
  NSAssert1(([self->stack count] > 0), @"%s: prefixStack.count == 0",
            __PRETTY_FUNCTION__);
  [self->stack removeLastObject]; // namespace
  [self->stack removeLastObject]; // prefix
}

- (BOOL)isTagValidInStack:(id)_node {
  NSString *nodeNamespace;
  NSString *nodePrefix;
  int      i;

  nodePrefix    = [_node prefix];
  nodeNamespace = [_node namespaceURI];
  
  for (i = [self->stack count]; i >= 2; i = i - 2) {
    NSString *namespace;
    NSString *prefix;

    prefix    = [self->stack objectAtIndex:i-2];
    namespace = [self->stack objectAtIndex:i-1];
    if ([nodePrefix isEqualToString:prefix] &&
        [nodeNamespace isEqualToString:namespace])
      return YES;
  }
  return NO;
}

- (NSArray *)newAttributePrefixesAndNamespaces:(NSArray *)_attrs {
  NSMutableArray *result;
  int            i, j, count;

  count = [_attrs count];
  
  if (count == 0) return [NSArray array];

  result = [[NSMutableArray alloc] initWithCapacity:count];
  for (j = 0; j < count; j++) {
    id       attr;
    NSString *attrNamespace;
    NSString *attrPrefix;
    BOOL     didMatch = NO;

    attr          = [_attrs objectAtIndex:j];
    attrNamespace = [attr namespaceURI];
    attrPrefix    = [attr prefix];
    attrNamespace = (attrNamespace) ? attrNamespace : (NSString *)@"";
    attrPrefix    = (attrPrefix)    ? attrPrefix    : (NSString *)@"";

    if (([attrNamespace length] == 0 && [attrPrefix length] == 0)) continue;
    
    for (i = [self->stack count]; i >= 2; i = i - 2) {
      NSString *namespace;
      NSString *prefix;

      prefix    = [self->stack objectAtIndex:i-2];
      namespace = [self->stack objectAtIndex:i-1];
      if ([attrPrefix isEqualToString:prefix] &&
          [attrNamespace isEqualToString:namespace]) {
        didMatch = YES;
        break;
      }
    }
    if (didMatch == NO) {
      [result addObject:attrPrefix];
      [result addObject:attrNamespace];
    }
  }
  return [result autorelease];
}

@end /* DOMXMLOutputter(PrefixStack) */
