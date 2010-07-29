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

#include "DOMPYXOutputter.h"
#include "DOMDocument.h"
#include "DOMElement.h"
#include "common.h"

@interface NGDOMPYXOutputter(Privates)
- (void)outputNode:(id)_node to:(id)_target;
- (void)outputNodeList:(id)_nodeList to:(id)_target;
@end

@implementation NGDOMPYXOutputter

- (void)write:(NSString *)s to:(id)_target {
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
  [self write:@"A"                  to:_target];
  [self write:[_attrNode name]      to:_target];
  [self write:@" "                  to:_target];
  [self write:[_attrNode nodeValue] to:_target];
  [self write:@"\n"                 to:_target];
}

- (void)outputAttributeNodes:(id<DOMNamedNodeMap>)_nodes
  ofNode:(id<DOMNode>)_node
  to:(id)_target
{
  unsigned i, count;
  
  if ((count = [_nodes length]) == 0)
    return;
  
  for (i = 0; i < count; i++) {
    [self outputAttributeNode:[_nodes objectAtIndex:i]
          ofNode:_node
          to:_target];
  }
}

- (void)outputTextNode:(id<DOMText>)_node to:(id)_target {
  NSString *s;
  unsigned len;
  
  s = [_node data];
  if ((len = [s length]) == 0)
    return;
  
  if ([s rangeOfString:@"\n"].length != 0) {
    s = [[s componentsSeparatedByString:@"\n"]
            componentsJoinedByString:@"\\n"];
  }
  
  [self write:@"-"  to:_target];
  [self write:s     to:_target];
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
  NSString *tagName;
  NSString *ns;
  
  /* needs to declare namespaces !!! */
  tagName = [_node tagName];
  if ([[_node prefix] length] > 0) {
    NSString *p = [_node prefix];
    
    p       = [p stringByAppendingString:@":"];
    tagName = [p stringByAppendingString:tagName];

    ns = [NSString stringWithFormat:@" xmlns:%@=\"%@\"",
                     [_node prefix],
                     [_node namespaceURI]];
  }
  else if ([[_node namespaceURI] length] > 0) {
    ns = [NSString stringWithFormat:@" xmlns=\"%@\"", [_node namespaceURI]];
  }
  else
    ns = nil;

  [self write:@"("    to:_target];
  [self write:tagName to:_target];
  [self write:@"\n"   to:_target];
    
  [self outputAttributeNodes:[_node attributes] ofNode:_node to:_target];
  
  if ([_node hasChildNodes])
    [self outputNodeList:[_node childNodes] to:_target];
    
  [self write:@")"    to:_target];
  [self write:tagName to:_target];
  [self write:@"\n"   to:_target];
}

- (void)outputCDATA:(id<DOMCharacterData>)_node to:(id)_target {
  NSString *s;

  s = [_node data];
  
  if ([s rangeOfString:@"\n"].length != 0) {
    /* escape newlines */
    s = [[s componentsSeparatedByString:@"\n"]
            componentsJoinedByString:@"\\n"];
  }
  
  [self write:@"-"  to:_target];
  [self write:s     to:_target];
  [self write:@"\n" to:_target];
}

- (void)outputPI:(id<DOMProcessingInstruction>)_node to:(id)_target {
  [self write:@"?"           to:_target];
  [self write:[_node target] to:_target];
  [self write:@" "           to:_target];
  [self write:[_node data]   to:_target];
  [self write:@"\n"          to:_target];
}

- (void)outputNode:(id)_node to:(id)_target {
  switch ([_node nodeType]) {
    case DOM_ELEMENT_NODE:
      [self outputElementNode:_node to:_target];
      break;
    case DOM_CDATA_SECTION_NODE:
      [self outputCDATA:_node to:_target];
      break;
    case DOM_PROCESSING_INSTRUCTION_NODE:
      [self outputPI:_node to:_target];
      break;
    case DOM_TEXT_NODE:
      [self outputTextNode:_node to:_target];
      break;
    case DOM_COMMENT_NODE:
      [self outputCommentNode:_node to:_target];
      break;
      
    default:
      NSLog(@"cannot output node %@", _node);
      break;
  }
}
- (void)outputNodeList:(id)_nodeList to:(id)_target {
  id       children;
  unsigned i, count;
  
  children = _nodeList;
  
  for (i = 0, count = [children count]; i < count; i++)
    [self outputNode:[children objectAtIndex:i] to:_target];
}

- (void)outputDocument:(id)_document to:(id)_target {
  if (![_document hasChildNodes])
    return;

  NS_DURING
    [self outputNodeList:[_document childNodes] to:_target];
  NS_HANDLER
#ifndef __APPLE__
    fprintf(stderr, "%s\n", [[localException description] cString]);
#else
    fprintf(stderr, "%s\n", [[localException description] UTF8String]);
#endif
#if DEBUG
    abort();
#endif
  NS_ENDHANDLER;
}

@end /* DOMPYXOutputter */
