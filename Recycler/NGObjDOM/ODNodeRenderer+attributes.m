/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#include <NGObjDOM/ODNodeRenderer+attributes.h>
#include <NGObjDOM/ODNodeRenderer.h>
#include <NGObjDOM/ODNamespaces.h>
#include <NGObjDOM/WOContext+Cursor.h>
#include "common.h"

@interface ODNodeRenderer(PrivateMethodes)
- (id)attributeNodeNamed:(NSString *)_attr ofNode:(id)_node inContext:(id)_ctx;
- (id)stringValueForAttributeNode:(id)_attrNode inContext:(id)_ctx;
@end

@interface NSObject(NGScriptEval)
- (id)evaluateScript:(NSString *)_script language:(NSString *)_lang;
@end

@implementation ODNodeRenderer(attributes)

static BOOL evalJSInHandler = NO;
static BOOL debugJS         = NO;
static BOOL logValues       = NO;

static void _categoryInitialize(void) {
  NSUserDefaults *ud;
  static BOOL didInit = NO;
  if (didInit) return;
  
  ud = [NSUserDefaults standardUserDefaults];
  evalJSInHandler = [ud boolForKey:@"ODEvalAttrValuesInExceptionHandler"];
  debugJS         = [ud boolForKey:@"ODDebugJSAttrEval"];
  logValues       = [ud boolForKey:@"ODLogAttrValues"];
  
  didInit = YES;
}

/* attributes */

- (BOOL)boolFor:(NSString *)_attr node:(id)_node ctx:(id)_ctx {
  id       attrNode;
  NSString *value;
  
  attrNode = [self attributeNodeNamed:_attr ofNode:_node inContext:_ctx];
  value    = [[self valueForAttributeNode:attrNode inContext:_ctx] stringValue];

  if (logValues)
    NSLog(@"%s: bool for attr %@ => '%@'", __PRETTY_FUNCTION__, _attr, value);
  
  if ([value isEqualToString:@"true"])
    return YES;
  if ([value isEqualToString:@"false"])
    return NO;
  
  return [value boolValue];
}

- (int)intFor:(NSString *)_attr node:(id)_node ctx:(id)_ctx {
  id attrNode = [self attributeNodeNamed:_attr ofNode:_node inContext:_ctx];
  
  return [[self valueForAttributeNode:attrNode inContext:_ctx] intValue];
}

- (id)valueFor:(NSString *)_attr node:(id)_node ctx:(id)_ctx {
  id attrNode;
  
  attrNode = [self attributeNodeNamed:_attr ofNode:_node inContext:_ctx];
  
  return [self valueForAttributeNode:attrNode inContext:_ctx];
}

- (NSString *)stringFor:(NSString *)_attr node:(id)_node ctx:(id)_ctx {
  id attrNode;
  
  attrNode = [self attributeNodeNamed:_attr ofNode:_node inContext:_ctx];
  
  return [self stringValueForAttributeNode:attrNode inContext:_ctx];
}

- (void)setValue:(id)_value for:(NSString *)_attr node:(id)_node ctx:(id)_ctx {
  id attrNode = nil;
  id<DOMNamedNodeMap> attrs;

  NSAssert2((_attr != nil),
            @"%s: Cannot set '%@' (The attributeName is nil!)",
            __PRETTY_FUNCTION__, _value);

  NSAssert3(((attrs = [_node attributes]) != nil),
           @"%s: Cannot set '%@' for '%@' (There are no attributes!)",
           __PRETTY_FUNCTION__, _value, _attr);
  
  attrNode = [attrs namedItem:_attr namespaceURI:XMLNS_OD_BIND];
  
  NSAssert4((attrNode != nil),
            @"%s: Cannot set '%@' for '%@:%@' (There is not such attribute!)",
            __PRETTY_FUNCTION__, _value, XMLNS_OD_BIND, _attr);

  [[(id<WOPageGenerationContext>)_ctx cursor] 
    takeValue:_value forKeyPath:[attrNode value]];
}

- (void)setBool:(BOOL)_value for:(NSString *)_attr node:(id)_node ctx:(id)_ctx {
  [self setValue:[NSNumber numberWithBool:_value]
        for:_attr
        node:_node
        ctx:_ctx];
}

- (void)setInt:(int)_value for:(NSString *)_attr node:(id)_node ctx:(id)_ctx {
  [self setValue:[NSNumber numberWithInt:_value]
        for:_attr
        node:_node
        ctx:_ctx];  
}

- (void)setString:(NSString *)_value
  for:(NSString *)_attr node:(id)_node ctx:(id)_ctx
{
  [self setValue:[_value stringValue] for:_attr node:_node ctx:_ctx];
}

- (void)forceSetValue:(id)_value
  for:(NSString *)_attr node:(id)_node ctx:(id)_ctx
{
  if ([self isSettable:_attr node:_node ctx:_ctx])
    [self setValue:_value for:_attr node:_node ctx:_ctx];
  else
    [_node setAttribute:_attr namespaceURI:XMLNS_OD_CONST value:_value];
}

- (void)forceSetBool:(BOOL)_value for:(NSString *)_attr node:(id)_node ctx:(id)_ctx {
  [self forceSetValue:[NSNumber numberWithBool:_value]
        for:_attr
        node:_node
        ctx:_ctx];
}

- (void)forceSetInt:(int)_value
  for:(NSString *)_attr node:(id)_node ctx:(id)_ctx
{
  [self forceSetValue:[NSNumber numberWithInt:_value]
        for:_attr
        node:_node
        ctx:_ctx];  
}

- (void)forceSetString:(NSString *)_value
  for:(NSString *)_attr node:(id)_node ctx:(id)_ctx
{
  [self forceSetValue:[_value stringValue] for:_attr node:_node ctx:_ctx];
}


- (BOOL)hasAttribute:(NSString *)_attr node:(id)_node ctx:(id)_ctx {
  return ([self attributeNodeNamed:_attr ofNode:_node inContext:_ctx] != nil)
    ? YES
    : NO;
}

- (BOOL)isSettable:(NSString *)_attr node:(id)_node ctx:(id)_ctx {
  id attrNode = nil;
  id<DOMNamedNodeMap> attrs;
  
  if ((attrs = [_node attributes]) == nil)
    return NO;
  
  if (!(attrNode = [attrs namedItem:_attr namespaceURI:XMLNS_OD_BIND]))
    return NO;

  return ([[attrNode value] length] > 0) ? YES : NO;
}

- (NSString *)stringForInt:(int)_value {
  static NSString *strs[10] = {
    @"0", @"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9" };
  
  if (_value < 10 && _value >= 0)
    return strs[_value];
  
  return [NSString stringWithFormat:@"%i", _value];
}

/* evaluate associations (looks for 'special' namespaces) */

- (NSException *)handleEvalException:(NSException *)_exception
  onNode:(id)_attrNode inContext:(id)_ctx 
{
  [self logWithFormat:@"Eval Node %@ catched: %@", _attrNode, _exception];
  return nil;
}

- (id)valueForAttributeNode:(id)_attrNode inContext:(id)_ctx {
  NSString *nsuri;
  NSString *value;
  
  _categoryInitialize();
  
  if (_attrNode == nil) {
    return nil;
  }
  
  nsuri = [_attrNode namespaceURI];
  value = [_attrNode value];
  
  if (logValues) {
    [self logWithFormat:
	    @"%s:\n  value for attr %@\n  (ns=%@, value='%@', cursor=%@) ...",
	    __PRETTY_FUNCTION__, _attrNode, nsuri, value, 
	    [(id<WOPageGenerationContext>)_ctx cursor]];
  }
  
  if ([nsuri isEqualToString:XMLNS_OD_CONST]) {
    // do nothing ...
    if (logValues) [self logWithFormat:@"    constant value, pass through"];
  }
  else if ([nsuri isEqualToString:XMLNS_OD_BIND]) {
    if (logValues) {
      [self logWithFormat:@"    cursor: %@\n    valueForKeyPath:'%@'", 
	      [(id<WOPageGenerationContext>)_ctx cursor], value];
    }
    value = [[(id<WOPageGenerationContext>)_ctx cursor] valueForKeyPath:value];
  }
  else if ([nsuri isEqualToString:XMLNS_OD_ACTION]) {
    // TODO: is this ever used anywhere ? (hm, maybe in forms)
    // Note: the node-value gets used in the dispatch phase !
    if (logValues) [self logWithFormat:@"    componentAction: '%@'", value];
    value = [_ctx componentActionURL];
  }
  else if ([nsuri isEqualToString:XMLNS_OD_EVALJS]) {
    id cursor;
    
    if (logValues) [self logWithFormat:@"    JavaScript: '%@'", value];
    
    cursor = [(id<WOPageGenerationContext>)_ctx cursor];
    if ([cursor respondsToSelector:@selector(evaluateScript:language:)]) {
      if (debugJS)
	[self logWithFormat:@"\n  cursor %@\n  eval: '%@'", cursor, value];
      
      if (!evalJSInHandler) {
	value = [cursor evaluateScript:value language:@"javascript"];
      }
      else {
	NS_DURING
	  value = [cursor evaluateScript:value language:@"javascript"];
	NS_HANDLER
	  [[self handleEvalException:localException
		 onNode:_attrNode inContext:_ctx] raise];
	NS_ENDHANDLER;
      }
      
      if (debugJS) [self logWithFormat:@"  got: %@", value];
    }
    else {
      [self logWithFormat:
	      @"%s:\n  object %@ cannot evaluate JavaScript\n'%@' !!",
              __PRETTY_FUNCTION__, self, value];
    }
  }
  
  if (logValues) {
    [self logWithFormat:@"  return value: %@ (%@,0x%p)\n", 
 	    value ? value: @"<nil>", NSStringFromClass([value class]), value];
  }
  return value;
}

- (id)invokeValueForAttributeNode:(id)_attrNode inContext:(id)_ctx {
  NSString *nsuri;
  id result;

  result = nil;
  
  if ((nsuri = [_attrNode namespaceURI])) {
    if ([nsuri isEqualToString:XMLNS_OD_ACTION])
      result = [[_ctx component] valueForKeyPath:[_attrNode value]];
  }
  if (result == nil)
    result = [self valueForAttributeNode:_attrNode inContext:_ctx];
  
  if (![result conformsToProtocol:@protocol(WOActionResults)])
    return nil;
  
  return result;
}

@end /* ODNodeRenderer(attributes) */

@implementation ODNodeRenderer(PrivateMethodes)

- (id)attributeNodeNamed:(NSString *)_attr ofNode:(id)_node inContext:(id)_ctx{
  id attrNode;
  id<DOMNamedNodeMap> attrs;
  
  if ((attrs = [_node attributes]) == nil)
    return nil;
  
  attrNode = [attrs namedItem:_attr namespaceURI:XMLNS_OD_CONST];
  if (attrNode == nil)
    attrNode = [attrs namedItem:_attr namespaceURI:XMLNS_OD_BIND];
  if (attrNode == nil)
    attrNode = [attrs namedItem:_attr namespaceURI:XMLNS_XUL];
  if (attrNode == nil)
    attrNode = [attrs namedItem:_attr namespaceURI:XMLNS_XHTML];
  if (attrNode == nil)
    attrNode = [attrs namedItem:_attr namespaceURI:XMLNS_HTML40];
  if (attrNode == nil)
    attrNode = [attrs namedItem:_attr namespaceURI:XMLNS_OD_EVALJS];

  if (attrNode == nil)
    attrNode = [_node attributeNode:_attr namespaceURI:@"*"];
  
#if DEBUG && 0
  if (attrNode == nil) {
    NSLog(@"%s: found no attribute named %@ in node %@", __PRETTY_FUNCTION__,
          _attr, _node);
  }
#endif
  return attrNode;
}

- (id)stringValueForAttributeNode:(id)_attrNode inContext:(id)_ctx {
  if ([[_attrNode namespaceURI] isEqualToString:XMLNS_XUL]) {
    if ([[(id<DOMAttr>)_attrNode name] isEqualToString:@"src"]) {
      /* a URL */
      NSURL *url;
      id rm;
      
      if ((url = [NSURL URLWithString:[_attrNode value]])) {
        /* valid, regular URL */
        return [[_attrNode value] stringValue];
      }
      
      /* consider it a resource name */
      rm = [[_ctx component] resourceManager];
      return [rm urlForResourceNamed:[_attrNode value]
		 inFramework:nil
		 languages:[[_ctx session] languages]
		 request:[(WOContext *)_ctx request]];
    }

    if ([(NSString *)[(id<DOMAttr>)_attrNode name] hasPrefix:@"on"])
      return [[_ctx elementID] stringValue];
  }
  return [[self valueForAttributeNode:_attrNode inContext:_ctx] stringValue];
}

@end /* ODNodeRenderer(PrivateMethodes) */
