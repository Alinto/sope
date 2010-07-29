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
#include <DOM/DOMElement.h>
#include <DOM/DOMNodeWalker.h>
#include <DOM/DOMProcessingInstruction.h>
#include <DOM/DOMElement.h>
#include <DOM/DOMAttribute.h>
#include <DOM/DOMEntityReference.h>
#include "DOMSaxBuilder.h"
#include "DOMNode+QueryPath.h"
#include "common.h"

//#define PROF_DEALLOC 1

@implementation NGDOMDocument

+ (id)documentFromData:(NSData *)_data {
  id builder;
  
  builder = [[[DOMSaxBuilder alloc] init] autorelease];
  return [builder buildFromData:_data];
}
+ (id)documentFromString:(NSString *)_string {
  return [self documentFromData:
                 [_string dataUsingEncoding:NSISOLatin1StringEncoding]];
}
+ (id)documentFromURI:(NSString *)_uri {
  id builder;
  
  builder = [[[DOMSaxBuilder alloc] init] autorelease];
  return [builder buildFromContentsOfFile:_uri];
}

- (id)initWithName:(NSString *)_qname
  namespaceURI:(NSString *)_uri
  documentType:(id)_doctype
  dom:(NGDOMImplementation *)_dom
{
  self->dom     = [_dom   retain];
  self->qname   = [_qname copy];
  self->uri     = [_uri   copy];
  self->doctype = [_doctype retain];
  return self;
}

- (void)dealloc {
#if PROF_DEALLOC
  NSDate *start = [NSDate date];
#endif

  [self->errors   release];
  [self->warnings release];
  [self->dom      release];
  [self->qname    release];
  [self->uri      release];
  [self->doctype  release];
  [super dealloc];

#if PROF_DEALLOC
  printf("%s: %.3fs\n", __PRETTY_FUNCTION__,
         [NSDate timeIntervalSinceDate:start]);
#endif
}

/* errors/warnings */

- (void)addErrors:(NSArray *)_errors {
  if (self->errors == nil)
    self->errors = [_errors copy];
  else {
    NSArray *tmp;

    tmp = self->errors;
    self->errors = [[tmp arrayByAddingObjectsFromArray:_errors] copy];
    [tmp release];
  }
}
- (void)addWarnings:(NSArray *)_errors {
  if (self->warnings == nil)
    self->warnings = [_errors copy];
  else {
    NSArray *tmp;

    tmp = self->warnings;
    self->warnings = [[tmp arrayByAddingObjectsFromArray:_errors] copy];
    [tmp release];
  }
}

/* attributes */

- (id<NSObject,DOMDocumentType>)doctype {
  return self->doctype;
}
- (NGDOMImplementation *)implementation {
  return self->dom;
}

- (id<NSObject,DOMElement>)documentElement {
  id children;
  unsigned i, count;
  
  if ((children = [self childNodes]) == nil)
    return nil;
  
  for (i = 0, count = [children count]; i < count; i++) {
    id node;

    node = [children objectAtIndex:i];
    if ([node nodeType] == DOM_ELEMENT_NODE)
      return node;
  }
  return nil;
}

/* node */

- (BOOL)_isValidChildNode:(id)_node {
  switch ([_node nodeType]) {
    case DOM_ELEMENT_NODE:
    case DOM_PROCESSING_INSTRUCTION_NODE:
    case DOM_COMMENT_NODE:
    case DOM_DOCUMENT_TYPE_NODE:
      return YES;
      
    default:
      return NO;
  }
}

- (DOMNodeType)nodeType {
  return DOM_DOCUMENT_NODE;
}

- (id<NSObject,DOMNamedNodeMap>)attributes {
  return nil;
}

- (IDOMDocument)ownerDocument {
  return nil;
}

- (id<NSObject,DOMNode>)parentNode {
  /* document cannot be nested */
  return nil;
}
- (id<NSObject,DOMNode>)nextSibling {
  /* document cannot be nested */
  return nil;
}
- (id<NSObject,DOMNode>)previousSibling {
  /* document cannot be nested */
  return nil;
}

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
  NSMutableArray          *array;
  NGDOMNodePreorderWalker *walker;
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
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (id<NSObject,DOMElement>)getElementById:(NSString *)_eid {
  /*
    Introduced in DOM2
    
    Note: The DOM implementation must have information that says which
    attributes are of type ID. Attributes with the name "ID" are not of
    type ID unless so defined.
    Implementations that do not know whether attributes are of type ID
    or not are expected to return null.
  */
  return nil;
}

/* factory */

- (Class)domElementClass {
  return [self->dom domElementClass];
}
- (Class)domElementNSClass {
  return [self->dom domElementNSClass];
}
- (Class)domDocumentFragmentClass {
  return [self->dom domDocumentFragmentClass];
}
- (Class)domTextNodeClass {
  return [self->dom domTextNodeClass];
}
- (Class)domCommentClass {
  return [self->dom domCommentClass];
}
- (Class)domCDATAClass {
  return [self->dom domCDATAClass];
}
- (Class)domProcessingInstructionClass {
  return [self->dom domProcessingInstructionClass];
}
- (Class)domAttributeClass {
  return [self->dom domAttributeClass];
}
- (Class)domAttributeNSClass {
  return [self->dom domAttributeNSClass];
}
- (Class)domEntityReferenceClass {
  return [self->dom domEntityReferenceClass];
}

- (id<NSObject,DOMElement>)createElement:(NSString *)_tagName {
  id elem;
  elem = [[[self domElementClass] 
	         alloc] 
	         initWithTagName:_tagName];
  return [elem autorelease];
}
- (id<NSObject,DOMElement>)createElement:(NSString *)_tagName
  namespaceURI:(NSString *)_uri
{
  id elem;
  elem = [[[self domElementNSClass] 
	         alloc] 
	         initWithTagName:_tagName namespaceURI:_uri];
  return [elem autorelease];
}

- (id<NSObject,DOMDocumentFragment>)createDocumentFragment {
  id elem;
  elem = [[[self domDocumentFragmentClass] alloc] init];
  return [elem autorelease];
}

- (id<NSObject,DOMText>)createTextNode:(NSString *)_data {
  id elem;
  elem = [[[self domTextNodeClass] alloc] initWithString:_data];
  return [elem autorelease];
}
- (id<NSObject,DOMComment>)createComment:(NSString *)_data {
  id elem;
  elem = [[[self domCommentClass] alloc] initWithString:_data];
  return [elem autorelease];
}
- (id<NSObject,DOMCDATASection>)createCDATASection:(NSString *)_data {
  id elem;
  elem = [[[self domCDATAClass] alloc] initWithString:_data];
  return [elem autorelease];
}

- (id<NSObject,DOMProcessingInstruction>)createProcessingInstruction:
    (NSString *)_target data:(NSString *)_data 
{
  id elem;
  elem = [[[self domProcessingInstructionClass] 
	         alloc] 
	         initWithTarget:_target data:_data];
  return [elem autorelease];
}

- (id<NSObject,DOMAttr>)createAttribute:(NSString *)_name {
  id elem;
  elem = [[[self domAttributeClass] 
	         alloc]
	         initWithName:_name];
  return [elem autorelease];
}
- (id<NSObject,DOMAttr>)createAttribute:(NSString *)_name
  namespaceURI:(NSString *)_uri
{
  id elem;
  elem = [[[self domAttributeNSClass] 
	         alloc]
	         initWithName:_name namespaceURI:_uri];
  return [elem autorelease];
}

- (id<NSObject,DOMEntityReference>)createEntityReference:(NSString *)_name {
  id elem;
  elem = [[[self domEntityReferenceClass] alloc] initWithName:_name];
  return [elem autorelease];
}

/* QPValues */

- (NSException *)setQueryPathValue:(id)_value {
  return [NSException exceptionWithName:@"QueryPathEvalException"
                      reason:@"cannot set query-path value on DOMDocument !"
                      userInfo:nil];
}
- (id)queryPathValue {
  return [self documentElement];
}

/* Key/Value Coding */

- (id)valueForKey:(NSString *)_key {
  if ([_key hasPrefix:@"/"])
    return [self lookupQueryPath:_key];
  
  return [super valueForKey:_key];
}

@end /* NGDOMDocument */
