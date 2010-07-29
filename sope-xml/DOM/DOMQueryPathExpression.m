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

#include <DOM/DOMQueryPathExpression.h>
#include "DOMDocument.h"
#include "DOMAttribute.h"
#include "DOMNamedNodeMap.h"
#include "common.h"

@interface NSString(QP)
- (NSArray *)queryPathComponents;
@end

#define QUERY_CURRENT 1
#define QUERY_PARENT  2
#define QUERY_ROOT    3

/*
  QueryPathExpression classes:
    NSObject
      _DOMQPPredicateExpression
      _DOMQPPredicateQPExpression
      DOMQueryPathExpression
        _DOMQueryPathSequence
        _DOMQueryPathPredicates
        _DOMQueryPathAttribute
        _DOMQueryPathNodeQuery
        _DOMQueryPathChildNodes
        _DOMQueryPathKeyPath
*/

@interface DOMQueryPathExpression(Privates)

+ (id)makeQueryPathExpression:(NSString *)_expr;

- (id)_deepChildNodesWithName:(id)_name type:(int)_type node:(id)_domNode;
- (id)_flatChildNodesWithName:(id)_name type:(int)_type node:(id)_domNode;
- (id)_rootSearchNodeForNode:(id)_domNode;

- (id)evaluateWithNode:(id)_node      inContext:(id)_ctx;
- (id)evaluateWithNodeList:(id)_nodes inContext:(id)_ctx;

@end

@interface _DOMQPPredicateExpression : NSObject
- (BOOL)matchesNode:(id)_node inContext:(id)_ctx;
@end

@interface _DOMQPPredicateQPExpression : NSObject
{
  DOMQueryPathExpression *qpexpr;
}
- (id)initWithQueryPathExpression:(DOMQueryPathExpression *)_expr;
@end

@interface _DOMQueryPathSequence : DOMQueryPathExpression
{
  NSArray *queryPaths;
}
+ (id)sequenceWithArray:(NSArray *)_array;
@end

@interface _DOMQueryPathPredicates : DOMQueryPathExpression
{
  DOMQueryPathExpression *expr;
  NSArray *predicates;
}
- (id)initWithQueryPathExpression:(DOMQueryPathExpression *)_expr
  predicates:(NSArray *)_predicates;
@end

@interface _DOMQueryPathAttribute : DOMQueryPathExpression
{
  NSString *attrSpec;
  NSString *uri;
  struct {
    int getAll:1;
    int hasColon:1;
  } aflags;
}
- (id)initWithString:(NSString *)_spec;
@end

@interface _DOMQueryPathNodeQuery : DOMQueryPathExpression
{
  int  queryOp;
}
- (id)initWithQueryOp:(int)_op;
@end

@interface _DOMQueryPathChildNodes : DOMQueryPathExpression
{
  NSString *elementName;
  BOOL     deep;
  int      nodeType;
}
- (id)initWithName:(NSString *)_name deep:(BOOL)_flag type:(int)_type;
@end

@interface _DOMQueryPathKeyPath : DOMQueryPathExpression
{
  NSString *keyPath;
}
- (id)initWithKeyPath:(NSString *)_path;
@end

@implementation DOMQueryPathExpression

- (id)_deepChildNodesWithName:(id)_name type:(int)_type node:(id)_domNode {
  NSMutableArray *array;
  id       children;
  unsigned i, count;
  NSString *fname, *furi;
  
  if (![_domNode hasChildNodes])
    return [NSArray array];
  
  children = [_domNode childNodes];
  if ((count = [children count]) == 0)
    return [NSArray array];

  if (_name) {
    NSRange r;

    r = [_name rangeOfString:@"}"];
    if (r.length != 0) {
      fname = [_name substringFromIndex:(r.location + r.length)];
      furi  = [[_name substringToIndex:r.location] substringFromIndex:1];
    }
    else {
      fname = _name;
      furi  = nil;
    }
  }
  else {
    fname = nil;
    furi  = nil;
  }
  
  array = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    id child;
    
    if ((child = [children objectAtIndex:i]) == nil)
      continue;
    
    if (([child nodeType] == _type) || (_type == -1)) {

      if (_name == nil) {
        /* wildcard query */
        [array addObject:child];
      }
      else {
        NSString *nname;
        NSString *qname;
        
        qname = _name;
        nname = [child nodeName];

        if ([nname isEqualToString:_name]) {
          /* FQ name matches */
          [array addObject:child];
        }
        else if ([nname isEqualToString:fname]) {
          /* name matches */
          if (furi) {
            /* check URI */
            if ([[child namespaceURI] isEqualToString:furi])
              [array addObject:child];
          }
          else {
            [array addObject:child];
          }
        }
      }
    }
    
    [array addObjectsFromArray:
             [self _deepChildNodesWithName:_name type:_type node:child]];
  }
  return array;
}

- (id)_flatChildNodesWithName:(id)_name type:(int)_type node:(id)_domNode {
  NSMutableArray *array;
  id       children;
  unsigned i, count;
  
  if (![_domNode hasChildNodes])
    return [NSArray array];
  
  children = [_domNode childNodes];
  if ((count = [children count]) == 0)
    return [NSArray array];
  
  array = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    id child;
    
    child = [children objectAtIndex:i];

    if (([child nodeType] != _type) && (_type != -1))
      continue;
    
    if (_name) {
      if (![[child nodeName] isEqualToString:_name])
        continue;
    }
    
    if (child)
      [array addObject:child];
  }
  return [[array copy] autorelease];
}

- (id)_rootSearchNodeForNode:(id)_domNode {
  id root;
  
  switch ([_domNode nodeType]) {
    case DOM_DOCUMENT_NODE:
    case DOM_DOCUMENT_FRAGMENT_NODE:
      root = [(id<DOMDocument>)_domNode documentElement];
      if (root == nil) {
        NSLog(@"WARNING(%s): document node %@ has no root element !",
              __PRETTY_FUNCTION__, _domNode);
      }
      break;
      
    case DOM_COMMENT_NODE:
    case DOM_PROCESSING_INSTRUCTION_NODE:
    case DOM_ELEMENT_NODE:
      root = [_domNode ownerDocument];
      if (root == nil) {
        NSLog(@"WARNING(%s): node %@ has no owner document !",
              __PRETTY_FUNCTION__, _domNode);
      }
      root = [self _rootSearchNodeForNode:root];
      break;
      
    case DOM_ATTRIBUTE_NODE:
      root = [(id<DOMAttr>)_domNode ownerElement];
      if (root == nil) {
        NSLog(@"WARNING(%s): attribute node %@ has no owner element !",
              __PRETTY_FUNCTION__, _domNode);
      }
      root = [self _rootSearchNodeForNode:root];
      break;

    default:
      root = [self _rootSearchNodeForNode:[_domNode parentNode]];
      break;
  }
  return root;
}

+ (id)queryPathWithComponents:(NSArray *)_array {
  NSMutableArray *a;
  unsigned i, count;
  
  if ((count = [_array count]) == 0)
    return nil;
  
  if (count == 1)
    return [[self makeQueryPathExpression:[_array objectAtIndex:0]]
                  autorelease];
  
  a = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    DOMQueryPathExpression *c;
    
    if ((c = [self makeQueryPathExpression:[_array objectAtIndex:i]])) {
      [a addObject:c];
      [c release]; c = nil;
    }
    else {
      NSLog(@"%s: couldn't make query-path expression ..", 
	    __PRETTY_FUNCTION__);
    }
  }
  
  return [_DOMQueryPathSequence sequenceWithArray:a];
}

+ (NSArray *)queryPathComponentsOfString:(NSString *)_path {
  return [_path queryPathComponents];
}

+ (id)queryPathWithString:(NSString *)_string {
  return [self queryPathWithComponents:[_string queryPathComponents]];
}

+ (_DOMQPPredicateExpression *)parsePredicateExpression:(NSString *)_expr {
  DOMQueryPathExpression    *qpexpr;
  _DOMQPPredicateExpression *pred;
#if 0
  NSLog(@"%s: can't parse predicates yet '%@'",
        __PRETTY_FUNCTION__, _expr);
#endif

  _expr = [@"-" stringByAppendingString:_expr];
  
  qpexpr = [DOMQueryPathExpression queryPathWithString:_expr];
  //NSLog(@"Expr: %@", qpexpr);
  
  pred =
    [[_DOMQPPredicateQPExpression alloc] initWithQueryPathExpression:qpexpr];
  
  return [pred autorelease];
}

+ (NSArray *)parseNodeQueryDetailExpressions:(NSString *)_path {
  unsigned       i, len, s;
  NSMutableArray *predicates;
  
  if ([_path length] == 0) return nil;
  
  predicates = nil;
  for (i = 0, s = 0, len = [_path length]; i < len; i++) {
    unichar c;
    
    c = [_path characterAtIndex:i];
    
    if ((c == ']') && (s != 0)) {
      /* finished a predicate */
      NSString *ps;
      id predicate;
      
      ps = ((i - s) > 0)
        ? [_path substringWithRange:NSMakeRange(s, (i - s))]
        : (NSString *)@"";
      
      if ((predicate = [self parsePredicateExpression:ps])) {
        if (predicates == nil)
          predicates = [NSMutableArray arrayWithCapacity:4];
        [predicates addObject:predicate];
      }
      
      s = 0;
    }
    else if (c == '[') {
      /* start a predicate */

      if (s != 0) {
        NSLog(@"%s: syntax error, predicate not properly closed ('%@') !",
              __PRETTY_FUNCTION__, _path);
      }
      
      s = (i + 1);
    }
  }
  return predicates;
}

+ (id)makeQueryPathExpression:(NSString *)_path {
  DOMQueryPathExpression *result;
  BOOL     isDeep = NO;
  NSString *predicateString;
  NSRange  r;
  
  if (([_path rangeOfString:@")"].length) != 0) {
    //[self doesNotRecognizeSelector:_cmd];
    NSLog(@"%s: unsupported querypath '%@'", __PRETTY_FUNCTION__, _path);
  }

  if ([_path hasPrefix:@"-"]) {
    isDeep = NO;
    _path = [_path substringFromIndex:1];
  }
  else
    isDeep = YES;

  r = [_path rangeOfString:@"["];
  if (r.length != 0) {
    predicateString = [_path substringFromIndex:r.location];
    _path           = [_path substringToIndex:r.location];
  }
  else
    predicateString = nil;
  
  if ([_path length] == 0) {
    /* empty path, returns current node */
    result = [[_DOMQueryPathNodeQuery alloc] initWithQueryOp:QUERY_CURRENT];
  }
  else if ([_path isEqualToString:@"/"]) {
    /* lookup root element */
    result = [[_DOMQueryPathNodeQuery alloc] initWithQueryOp:QUERY_ROOT];
  }
  else if ([_path isEqualToString:@"."]) {
    /* lookup current element */
    result = [[_DOMQueryPathNodeQuery alloc] initWithQueryOp:QUERY_CURRENT];
  }
  else if ([_path isEqualToString:@".."]) {
    /* lookup parent element */
    result = [[_DOMQueryPathNodeQuery alloc] initWithQueryOp:QUERY_PARENT];
  }
  else if ([_path isEqualToString:@"*"]) {
    result =
      [[_DOMQueryPathChildNodes alloc] initWithName:nil
				       deep:isDeep
				       type:DOM_ELEMENT_NODE];
  }
  else if ([_path isEqualToString:@"#"]) {
    result =
      [[_DOMQueryPathChildNodes alloc] initWithName:nil
				       deep:isDeep
				       type:-1];
  }
  else if ([_path hasPrefix:@"!"]) {
    /* perform key-value call */
    _path  = [_path substringFromIndex:1];
    result = [[_DOMQueryPathKeyPath alloc] initWithKeyPath:_path];
  }
  else if ([_path hasPrefix:@"?"]) {
    /* lookup processing instruction */
    _path = [_path substringFromIndex:1]; // target of PI
    result = [[_DOMQueryPathChildNodes alloc] 
	       initWithName:_path
	       deep:isDeep
	       type:DOM_PROCESSING_INSTRUCTION_NODE];
  }
  else if ([_path hasPrefix:@"@"]) {
    /* lookup attribute */
    _path  = [_path substringFromIndex:1];
    result = [[_DOMQueryPathAttribute alloc] initWithString:_path];
  }
  else {
    /* deep lookup child element */
    result =
      [[_DOMQueryPathChildNodes alloc] 
                                initWithName:_path deep:isDeep
                                type:DOM_ELEMENT_NODE];
  }
  
  /* attach predicates ... */
  
  if (([predicateString length] > 0) && (result != nil)) {
    NSArray *predicates;
    
    if ((predicates = [self parseNodeQueryDetailExpressions:predicateString])){
#if 0
      NSLog(@"%s: can't yet handle predicates %@",
            __PRETTY_FUNCTION__, predicates);
#endif
      
      result = [result autorelease];
      result = [[_DOMQueryPathPredicates alloc]
                                         initWithQueryPathExpression:result
                                         predicates:predicates];
    }
  }
  
  return result;
}

- (id)evaluateWithNode:(id)_node inContext:(id)_ctx {
  /* override in subclasses ! */
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (id)evaluateWithNodeList:(id)_nodes inContext:(id)_ctx {
  unsigned       i, count;
  NSMutableArray *ma;
  NSArray        *results;
  
  if ((count = [_nodes count]) == 0)
    return _nodes;
  
  ma = [[NSMutableArray alloc] init];
  for (i = 0; i < count; i++) {
    id node;
    
    node = [_nodes objectAtIndex:i];
    node = [self evaluateWithNode:node inContext:_ctx];
    
    if (node)
      [ma addObject:node];
  }
  results = [ma copy];
  [ma release];
  return [results autorelease];
}

- (id)evaluateWithNode:(id)_node {
  return [self evaluateWithNode:_node inContext:nil];
}
- (id)evaluateWithNodeList:(id)_nodes {
  return [self evaluateWithNodeList:_nodes inContext:nil];
}

@end /* DOMQueryPathExpression */

@implementation _DOMQueryPathChildNodes

- (id)initWithName:(NSString *)_name deep:(BOOL)_flag type:(int)_type {
  self->elementName = [_name copy];
  self->deep        = _flag;
  self->nodeType    = _type;
  return self;
}

- (void)dealloc {
  [self->elementName release];
  [super dealloc];
}

- (id)evaluateWithNode:(id)_node inContext:(id)_ctx {
  id   result;
  BOOL _forceList = NO;
  
  result = self->deep
    ? [self _deepChildNodesWithName:self->elementName
            type:self->nodeType node:_node]
    : [self _flatChildNodesWithName:self->elementName
            type:self->nodeType node:_node];
  
  if (!_forceList) {
    if ([result count] == 0)
      result = nil;
    else if ([result count] == 1)
      result = [result objectAtIndex:0];
  }
  
  return result;
}

- (id)evaluateWithNodeList:(id)_nodes inContext:(id)_ctx {
  unsigned       i, count;
  NSMutableArray *ma;
  NSArray        *results;
  
  if ((count = [_nodes count]) == 0)
    return _nodes;
  
  ma = [[NSMutableArray alloc] init];
  for (i = 0; i < count; i++) {
    id node;

    node = [_nodes objectAtIndex:i];
    
    node = self->deep
      ? [self _deepChildNodesWithName:self->elementName
              type:self->nodeType node:node]
      : [self _flatChildNodesWithName:self->elementName
              type:self->nodeType node:node];
    
    [ma addObjectsFromArray:node];
  }
  results = [ma copy];
  [ma release];
  return [results autorelease];
}

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<%@[0x%p]:", NSStringFromClass([self class]), self];
  [ms appendFormat:@" element='%@'", self->elementName];
  [ms appendString:self->deep ? @" deep" : @" shallow"];
  [ms appendFormat:@" nodeType=%i", self->nodeType];
  [ms appendString:@">"];
  return ms;
}

@end /* _DOMQueryPathChildNodes */

@implementation _DOMQueryPathKeyPath

- (id)initWithKeyPath:(NSString *)_path {
  self->keyPath = [_path copy];
  return self;
}
- (void)dealloc {
  [self->keyPath release];
  [super dealloc];
}

- (id)evaluateWithNode:(id)_node inContext:(id)_ctx {
  return [_node valueForKeyPath:self->keyPath];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<0x%p[%@]: keypath='%@'>",
                     self, NSStringFromClass([self class]), self->keyPath];
}

@end /* _DOMQueryPathKeyPath */

@implementation _DOMQueryPathNodeQuery

- (id)initWithQueryOp:(int)_op {
  self->queryOp = _op;
  return self;
}

- (id)evaluateWithNode:(id)_node inContext:(id)_ctx {
  switch (self->queryOp) {
    case QUERY_ROOT:
      return [self _rootSearchNodeForNode:_node];
    case QUERY_PARENT:
      return [_node parentNode];
    case QUERY_CURRENT:
      return _node;
      
    default:
      [NSException raise:@"DOMQueryPathException"
                   format:@"unknown node operation %i on node %@",
                     self->queryOp, _node];
      return nil;
  }
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<0x%p[%@]: op=%i>",
                     self, NSStringFromClass([self class]), self->queryOp];
}

@end /* _DOMQueryPathNodeQuery */

@implementation _DOMQueryPathPredicates

- (id)initWithQueryPathExpression:(DOMQueryPathExpression *)_expr
  predicates:(NSArray *)_predicates
{
  self->expr       = [_expr retain];
  self->predicates = [_predicates copy];
  return self;
}

- (void)dealloc {
  [self->expr       release];
  [self->predicates release];
  [super dealloc];
}

- (id)evaluateWithNodeList:(id)_nodes inContext:(id)_ctx {
  NSArray *list;
  
  if ((list = [self->expr evaluateWithNodeList:_nodes inContext:_ctx]) &&
      [self->predicates count] > 0) {
    NSMutableArray *result;
    unsigned i, count;

    result = [NSMutableArray arrayWithCapacity:16];
    
    for (i = 0, count = [list count]; i < count; i++) {
      NSEnumerator *e;
      _DOMQPPredicateExpression *pred;
      id node;
      
      if ((node = [list objectAtIndex:i]) == nil)
        continue;
      
      e = [self->predicates objectEnumerator];
      while ((pred = [e nextObject])) {
        if (![pred matchesNode:node inContext:nil]) {
          node = nil;
          break;
        }
      }

      if (node) [result addObject:node];
    }
    
    list = [[result copy] autorelease];
  }
  return list;
}
- (id)evaluateWithNode:(id)_node inContext:(id)_ctx {
  NSLog(@"WARNING(%s): called -evaluateWithNode: ...", __PRETTY_FUNCTION__);
  return [self evaluateWithNodeList:[NSArray arrayWithObject:_node]
               inContext:_ctx];
}

@end /* _DOMQueryPathPredicates */

@implementation _DOMQueryPathSequence

- (id)initWithArray:(NSArray *)_array {
  self->queryPaths = [_array retain];
  return self;
}
+ (id)sequenceWithArray:(NSArray *)_array {
  return [[[self alloc] initWithArray:_array] autorelease];
}

- (void)dealloc {
  [self->queryPaths release];
  [super dealloc];
}

- (id)evaluateWithNode:(id)_node inContext:(id)_ctx {
  NSEnumerator          *e;
  DOMQueryPathExpression *queryPathComponent;
  id                    activeNode;

  activeNode = _node;
  e = [self->queryPaths objectEnumerator];
  while ((queryPathComponent = [e nextObject]) && (activeNode != nil)) {
    activeNode =
      [queryPathComponent evaluateWithNode:activeNode inContext:_ctx];
  }
  
  return activeNode;
}

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<%@[0x%p]: ", NSStringFromClass([self class]), self];
  [ms appendString:@"sequence="];
  [ms appendString:[self->queryPaths description]];
  [ms appendString:@">"];
  return ms;
}

@end /* _DOMQueryPathSequence */

@implementation _DOMQueryPathAttribute

- (id)initWithString:(NSString *)_spec {
  if ([_spec isEqualToString:@"*"]) {
    /* select all attributes */
    self->aflags.getAll = 1;
  }
  else if ([_spec hasPrefix:@"{"]) {
    /* fully qualified name */
    NSRange r;

    r = [_spec rangeOfString:@"}"];
    if (r.length == 0) {
      /* syntax error, missing closing '}' */
      self->attrSpec = [_spec copy];
    }
    else {
      self->attrSpec =
        [[_spec substringFromIndex:(r.location + r.length)] copy];
      self->uri =
        [[[_spec substringToIndex:r.location] substringFromIndex:1] copy];
    }
  }
  else {
    NSRange r;

    r = [_spec rangeOfString:@":"];
    if (r.length != 0) {
      /* found colon (namespaces), eg 'html:blah' */
      self->aflags.hasColon = 1;
      self->attrSpec =
        [[_spec substringFromIndex:(r.location + r.length)] copy];
      
      self->uri = [_spec substringToIndex:r.location];
      self->uri = ([self->uri length] > 1)
        ? [self->uri copy]
        : (id)@"*";
    }
    else {
      /* usual 'blah' */
      self->attrSpec = [_spec copy];
    }
  }  
  return self;
}

- (void)dealloc {
  [self->uri      release];
  [self->attrSpec release];
  [super dealloc];
}

- (id)evaluateWithNode:(id)_node inContext:(id)_ctx {
  /* lookup attribute element */
  id   attributes;
  id   result;
  BOOL _forceList = NO;
  
  attributes = [(id<DOMNode>)_node attributes];

#if DEBUG
  if (attributes == nil)
    NSLog(@"%s: node %@ has no attributes ..", __PRETTY_FUNCTION__, _node);
#endif
  
  if (self->aflags.getAll) {
    /* all attribute elements */
    result = attributes;
    _forceList = NO; // attributes behave already like a list  ..
  }
  else if (self->uri) {
    result = [attributes namedItem:self->attrSpec namespaceURI:self->uri];
  }
  else if (self->aflags.hasColon) {
    result = [attributes namedItem:self->attrSpec namespaceURI:self->uri];
    //result = [result value];
  }
  else {
    result = [attributes namedItem:self->attrSpec];
  }
  
  if (_forceList)
    result = [NSArray arrayWithObject:result];
  
  return result;
}

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<%@[0x%p]:", NSStringFromClass([self class]), self];
  [ms appendFormat:@" attrSpec='%@'", self->attrSpec];
  if (self->uri)
    [ms appendFormat:@" uri='%@'", self->uri];
  if (self->aflags.getAll)
    [ms appendString:@" getall"];
  if (self->aflags.hasColon)
    [ms appendString:@" colon"];
  [ms appendString:@">"];
  return ms;
}

@end /* _DOMQueryPathAttribute */

@implementation _DOMQPPredicateExpression

- (BOOL)matchesNode:(id)_node inContext:(id)_ctx {
  /* override in subclasses ! */
  [self doesNotRecognizeSelector:_cmd];
  return NO;
}

@end /* _DOMQPPredicateExpression */

@implementation _DOMQPPredicateQPExpression

- (id)initWithQueryPathExpression:(DOMQueryPathExpression *)_expr {
  self->qpexpr = [_expr retain];
  return self;
}
- (id)init {
  return [self initWithQueryPathExpression:nil];
}

- (void)dealloc {
  [self->qpexpr release];
  [super dealloc];
}

- (BOOL)matchesNode:(id)_node inContext:(id)_ctx {
  id nodeList;
  
  //NSLog(@"check match of node %@, qpexpr %@ ...", _node, qpexpr);
  
  nodeList = [NSArray arrayWithObject:_node];
  nodeList = [self->qpexpr evaluateWithNodeList:nodeList inContext:_ctx];
  
  return ([nodeList count] > 0) ? YES : NO;
}

@end /* _DOMQPPredicateQPExpression */
