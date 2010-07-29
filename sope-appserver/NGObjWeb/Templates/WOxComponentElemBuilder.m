/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#include <NGObjWeb/WOxElemBuilder.h>

/*
  This builder builds references to subcomponents. The subcomponent name is
  derived from the tagname.
  
  NOTE: this builder is a "final destination" for all bind(var) namespace
  tags !
  
  Sample:
    <var:Embed a="a"/>

  Supported tags:
    <var:script src=...>....</var:script> maps to a component script part ...
    <var:component className=... />       maps to WOSwitchComponent
    <var:* ..../>
*/

@interface WOxComponentElemBuilder : WOxElemBuilder
{
}

@end

#include <SaxObjC/XMLNamespaces.h>
#include <DOM/DOMProtocols.h>
#include <DOM/DOMText.h>
#include <NGObjWeb/WOAssociation.h>
#include <NGObjWeb/WOComponentScript.h>
#include "WOChildComponentReference.h"
#include "common.h"

@interface NSObject(LineInfo)
- (unsigned)line;
@end

@implementation WOxComponentElemBuilder

static NGLogger *debugLogger = nil;

+ (void)initialize {
  NGLoggerManager *lm;
  static BOOL didInit = NO;
  if (didInit)
    return;
  didInit     = YES;
  lm          = [NGLoggerManager defaultLoggerManager];
  debugLogger = [lm loggerForDefaultKey:@"WOxComponentElemBuilderDebugEnabled"];
}

/* extracting associations */

- (NSMutableDictionary *)associationsForAttributes:(id<DOMNamedNodeMap>)_attrs
  templateBuilder:(id)_b
{
  NSMutableDictionary *assocs;
  
  if ((assocs = [_b associationsForAttributes:_attrs]) == nil)
    return nil;
  
  // should we check the tag or do we always remove className ?
  if ([assocs objectForKey:@"className"])
    [assocs removeObjectForKey:@"className"];
  else if ([assocs objectForKey:@"value"])
    [assocs removeObjectForKey:@"value"];
  return assocs;
}

/* building elements */

- (WOElement *)buildComponentReferenceElement:(id<DOMElement>)_element
  templateBuilder:(id)_b 
{
  /*
    TODO: I don't think that this already works - it uses the 'value'
          binding but WOComponentReference expects 'component'
  */
  static Class LiveChildRefClass = Nil;
  NSMutableDictionary *assocs;
  NSArray             *children;
  NSString            *value;
  WOElement           *de;
  
  if (LiveChildRefClass == Nil)
    LiveChildRefClass = NSClassFromString(@"WOComponentReference");
  
  if (debugLogger)
    [debugLogger debugWithFormat:@"build component-reference: %@", _element];
  
  value = [_element attribute:@"value" namespaceURI:XMLNS_OD_BIND];
  if ([value length] == 0) return nil;
  
  /* construct child elements */
  
  children = [_element hasChildNodes]
    ? [_b buildNodes:[_element childNodes] templateBuilder:_b]
    : (NSArray *)nil;
  [children autorelease];
  
  /* build associations */
  
  assocs = [self associationsForAttributes:[_element attributes]
                 templateBuilder:_b];
  [assocs setObject:[WOAssociation associationWithKeyPath:value]
          forKey:@"component"];
  
  /* build element */
  
  if (debugLogger) {
    [debugLogger debugWithFormat:
                   @"create reference for keypath: '%@': children=%@, "
                   @"assocs=%@", 
                   value, children, assocs];
  }
  
  de = [[LiveChildRefClass alloc] 
                           initWithName:[_b uniqueIDForNode:_element]
                           associations:assocs
                           contentElements:children];
  if (debugLogger) [debugLogger debugWithFormat:@"built: %@", de];
  return de;
}

- (WOElement *)processScriptElement:(id<DOMElement>)_e templateBuilder:(id)_b {
  /* process a component related script */
  NSString *src;
  
  [self debugWithFormat:@"processing script element: %@", _e];
  
  /* first process src attribute ... */
  if ((src = [_e attribute:@"src" namespaceURI:XMLNS_OD_BIND])) {
    /* create script part for src ... */
    [self logWithFormat:@"create script part for src '%@', not implemented",
            src];
  }
    
  /* create script part for content ... */
  if ([_e hasChildNodes]) {
    WOComponentScriptPart *lscript;
    NSEnumerator      *e;
    id                subnode;
    NSMutableString   *content;
    unsigned          line;
    NSURL             *url;
      
    content = [[NSMutableString alloc] initWithCapacity:256];
      
    line = ([(NSObject *)_e respondsToSelector:@selector(line)])
      ? [(id)_e line] : 0;
    
    url = nil;
      
    e = [(NSArray *)[_e childNodes] objectEnumerator];
    while ((subnode = [e nextObject])) {
      [content appendString:[subnode textValue]];
    }
      
    lscript = [WOComponentScriptPart alloc];
    lscript = [lscript initWithURL:url startLine:line script:content];
    [content release];
      
    [_b addComponentScriptPart:lscript];
    [lscript release];
  }
  
  return nil;
}

- (WOElement *)buildElement:(id<DOMElement>)_element templateBuilder:(id)_b {
  static Class ChildRefClass = Nil;
  NSMutableDictionary *bindings;
  NSArray  *children;
  NSString *cid;
  NSString *tagName;
  NSString *compName;
  
  if (![[_element namespaceURI] isEqualToString:XMLNS_OD_BIND]) {
    if (debugLogger) {
      [self debugWithFormat:
              @"do not process element, not in bind namespace: %@", _element];
    }
    return nil;
  }
  
  tagName = [_element tagName];
  compName = nil;
  
  if ([tagName isEqualToString:@"script"])
    return [self processScriptElement:_element templateBuilder:_b];
  
  if ([tagName isEqualToString:@"component"]) {
    compName = [_element attribute:@"className" namespaceURI:XMLNS_OD_BIND];
    if ([compName length] == 0) {
      compName = [_element attribute:@"classname"
                           namespaceURI:XMLNS_OD_BIND];
    }
    if ([compName length] == 0)
      compName = [_element attribute:@"name" namespaceURI:XMLNS_OD_BIND];
    
    /* check whether we should use a "live" reference to a component object */
    
    if ([compName length] == 0) {
      NSString *value;
      
      value = [_element attribute:@"value" namespaceURI:XMLNS_OD_BIND];
      if ([value length] > 0) {
        return [self buildComponentReferenceElement:_element 
                     templateBuilder:_b];
      }
    }
    
    if ([compName length] == 0) {
      [self logWithFormat:
              @"missing 'name' or 'value' attribute in var:component: %@", 
              [_element attributes]];
      return nil;
    }
  }
  else {
    [self logWithFormat:@"Creating component %@ using tag. "
          @"<var:component name='%@'/> is preferred !", 
	  _element, _element];
  }
  
  if (debugLogger)
    [debugLogger debugWithFormat:@"creating static component reference: %@",
                   _element];

  if (ChildRefClass == Nil)
    ChildRefClass = NSClassFromString(@"WOChildComponentReference");
  
  cid = [_b uniqueIDForNode:_element];
  if (debugLogger)
    [debugLogger debugWithFormat:@"BUILD Component(%@): %@", cid, _element];
  
  /* construct child elements */
  
  children = [_element hasChildNodes]
    ? [_b buildNodes:[_element childNodes] templateBuilder:_b]
    : (NSArray *)nil;
  [children autorelease];
  
  if (compName == nil)
    compName = [_element tagName];

  bindings = [self associationsForAttributes:[_element attributes]
		   templateBuilder:_b];
  if (debugLogger)
    [debugLogger debugWithFormat:@"using bindings: %@", bindings];
  
  [_b registerSubComponentWithId:cid
      componentName:compName
      bindings:bindings];
  
  return [[ChildRefClass alloc]
                         initWithName:cid
                         associations:nil
                         contentElements:children];
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugLogger != nil;
}

@end /* WOxComponentElemBuilder */
