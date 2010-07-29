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

#ifndef __WOxElemBuilder_H__
#define __WOxElemBuilder_H__

#import <Foundation/NSObject.h>
#include <DOM/DOMProtocols.h>

@class NSString, NSArray, NSMutableDictionary, NSMutableArray;
@class WOElement, WOAssociation, WOComponent, WOResourceManager;
@class WOComponentScript, WOComponentScriptPart;

/*
  Abstract class to build NGObjWeb WOElement templates from
  XML DOM structures.
  
  Template builders can be stacked in a processing queue, so that
  unknown elements are produced by the "nextBuilder". When processing
  is done using a stack, the first stack builder is called the
  "templateBuilder" and used to keep global state (eg the template
  builder must be used to create further elements if the same element
  set is required).
  
  WOxElemBuilder stacks are not thread-safe since the template builder
  stores subcomponent creation info in an instance variable.
*/

@interface WOxElemBuilder : NSObject
{
@protected
  WOxElemBuilder      *nextBuilder;
  NSMutableArray      *subcomponentInfos;
  NSMutableDictionary *nsToAssoc;
  NSMutableArray      *scriptParts;
  WOComponentScript   *script;
}

+ (WOxElemBuilder *)createBuilderQueue:(NSArray *)_classNames;
+ (WOxElemBuilder *)createBuilderQueueV:(NSString *)_className, ...;

/* building a template from a DOM structure */

- (WOElement *)buildTemplateFromDocument:(id<DOMDocument>)_document;

/* node-type build dispatcher method ... */

- (WOElement *)buildNode:(id<DOMNode>)_node templateBuilder:(id)_bld;
- (NSArray *)buildNodes:(id<DOMNodeList>)_node templateBuilder:(id)_bld;

/* building parts of a DOM ... */

- (WOElement *)buildDocument:(id<DOMDocument>)_node templateBuilder:(id)_bld;
- (WOElement *)buildElement:(id<DOMElement>)_node   templateBuilder:(id)_bld;

- (WOElement *)buildCharacterData:(id<DOMCharacterData>)_node
  templateBuilder:(id)_builder;
- (WOElement *)buildText:(id<DOMText>)_node
  templateBuilder:(id)_builder;
- (WOElement *)buildCDATASection:(id<DOMCDATASection>)_node
  templateBuilder:(id)_builder;
- (WOElement *)buildComment:(id<DOMComment>)_node
  templateBuilder:(id)_builder;

/* association callbacks */

- (WOAssociation *)associationForValue:(id)_value;
- (WOAssociation *)associationForKeyPath:(NSString *)_path;
- (WOAssociation *)associationForJavaScript:(NSString *)_js;

// this one uses the attribute namespace to determine the association class
- (WOAssociation *)associationForAttribute:(id<DOMAttr>)_attribute;
// map the attribute names to dict keys and use the method above for the value
// "_name" attributes are mapped to "?name" query keys
- (NSMutableDictionary *)associationsForAttributes:(id<DOMNamedNodeMap>)_attrs;

- (void)registerAssociationClass:(Class)_class forNamespaceURI:(NSString *)_ns;
- (Class)associationClassForNamespaceURI:(NSString *)_ns;

/* creating unique IDs */

- (NSString *)uniqueIDForNode:(id)_node;
  
/* logging */

#if 0
- (void)logWithFormat:(NSString *)_format, ...;
- (void)debugWithFormat:(NSString *)_format, ...;
#endif

/* managing builder queues */

- (void)setNextBuilder:(WOxElemBuilder *)_builder;
- (WOxElemBuilder *)nextBuilder;

/* component script parts */

- (WOComponentScript *)componentScript;
- (void)addComponentScriptPart:(WOComponentScriptPart *)_part;
- (void)addComponentScript:(NSString *)_script line:(unsigned)_line;

/* subcomponent registry, created during parsing ... */

- (void)registerSubComponentWithId:(NSString *)_cid
  componentName:(NSString *)_name
  bindings:(NSMutableDictionary *)_bindings;

- (NSArray *)subcomponentInfos;

- (void)reset;

/* support methods for subclasses */

- (id<DOMElement>)lookupUniqueTag:(NSString *)_name
  inElement:(id<DOMElement>)_elem;

- (WOElement *)elementForRawString:(NSString *)_rawstr;
- (WOElement *)elementForElementsAndStrings:(NSArray *)_elements;

- (WOElement *)wrapElement:(WOElement *)_element 
  inCondition:(WOAssociation *)_condition
  negate:(BOOL)_flag;

- (WOElement *)wrapElements:(NSArray *)_sub inElementOfClass:(Class)_class;

- (WOElement *)wrapChildrenOfElement:(id<DOMElement>)_tag
  inElementOfClass:(Class)_class
  templateBuilder:(id)_b;

@end


@interface WOxElemBuilderComponentInfo : NSObject
{
  NSString            *cid;
  NSString            *pageName;
  NSMutableDictionary *bindings;
}

- (id)initWithComponentId:(NSString *)_cid
  componentName:(NSString *)_name
  bindings:(NSMutableDictionary *)_bindings;

/* accessors */

- (NSString *)componentId;
- (NSString *)pageName;
- (NSMutableDictionary *)bindings;

/* create the component ... */

- (id)instantiateWithResourceManager:(WOResourceManager *)_rm
  languages:(NSArray *)_languages;

@end

/*
  Specialized superclass for builders which directly map DOM elements
  to NGObjWeb dynamic elements (which is usually the case ...).

  The classes returned must conform to the WOxTagClassInit protocol and
  can use the _builder argument to continue building for child nodes
  of the given DOM element.
*/

@interface NSObject(WOxTagClassInit)

- (id)initWithElement:(id<DOMElement>)_element
  templateBuilder:(WOxElemBuilder *)_builder;

@end

@interface WOxTagClassElemBuilder : WOxElemBuilder

- (WOElement *)buildNextElement:(id<DOMElement>)_elem templateBuilder:(id)_b;
- (Class)classForElement:(id<DOMElement>)_element;

@end

#endif /* WOxElemBuilder */
