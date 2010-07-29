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

#include <NGObjWeb/WOxElemBuilder.h>
#include <DOM/EDOM.h>
#include <SaxObjC/XMLNamespaces.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOElement.h>
#include <NGObjWeb/WOAssociation.h>
#include <NGObjWeb/WOComponentScript.h>
#include <NGObjWeb/WODynamicElement.h>
#include "WOComponentFault.h"
#include "common.h"

@interface WOElement(UsedPrivates)
- (id)initWithValue:(id)_value escapeHTML:(BOOL)_flag;
+ (id)allocForCount:(int)_count zone:(NSZone *)_zone;
- (id)initWithContentElements:(NSArray *)_elements;
@end

@interface WOAssociation(misc)
- (id)initWithScript:(NSString *)_script language:(NSString *)_lang;
@end

@implementation WOxElemBuilderComponentInfo

- (id)initWithComponentId:(NSString *)_cid
  componentName:(NSString *)_name
  bindings:(NSMutableDictionary *)_bindings
{
  self->cid      = [_cid copy];
  self->pageName = [_name copy];
  self->bindings = [_bindings retain];
  return self;
}
- (void)dealloc {
  [self->cid      release];
  [self->pageName release];
  [self->bindings release];
  [super dealloc];
}

/* accessors */

- (NSString *)componentId {
  return self->cid;
}

- (NSString *)pageName {
  return self->pageName;
}

- (NSMutableDictionary *)bindings {
  return self->bindings;
}

/* operations */

- (id)instantiateWithResourceManager:(WOResourceManager *)_rm
  languages:(NSArray *)_languages
{
  static Class FaultClass = Nil;
  WOComponentFault *fault;
  
  if (FaultClass == Nil)
    FaultClass = [WOComponentFault class];
  
  fault = [FaultClass alloc];
  NSAssert1(fault, @"couldn't allocated object of class '%@' ..", FaultClass);
  
  fault = [fault initWithResourceManager:_rm
                 pageName:self->pageName
                 languages:_languages
                 bindings:self->bindings];
  return (id)fault;
}

@end /* SxElementBuilderComponentInfo */

@implementation WOxElemBuilder

static Class         StrClass          = Nil;
static Class         AStrClass         = Nil;
static NSDictionary  *defaultAssocMap  = nil;
static Class         ValAssoc          = Nil;
static BOOL          logAssocMap       = NO;
static BOOL          logAssocCreation  = NO;
static BOOL          debugOn           = NO;
static NGLogger      *logger           = nil;
static Class         CompoundElemClass = Nil;
static NSNumber      *yesNum   = nil;
static WOAssociation *yesAssoc = nil;

+ (int)version {
  return 1;
}
+ (void)initialize {
  NSUserDefaults  *ud;
  NGLoggerManager *lm;
  static BOOL didInit = NO;

  if (didInit) return;
  didInit = YES;

  ud = [NSUserDefaults standardUserDefaults];
  lm = [NGLoggerManager defaultLoggerManager];

  logger = [lm loggerForClass:self];
  [logger setLogLevel:[WOApplication isDebuggingEnabled] ? NGLogLevelDebug
                                                         : NGLogLevelInfo];

  StrClass = NSClassFromString(@"_WOSimpleStaticString");
  if (StrClass == Nil)
    [logger errorWithFormat:@"missing class _WOSimpleStaticString !"];
  AStrClass = NSClassFromString(@"_WOSimpleStaticASCIIString");
  if (AStrClass == Nil)
    [logger errorWithFormat:@"missing class _WOSimpleStaticASCIIString !"];

  logAssocMap = [ud boolForKey:@"WOxElemBuilder_LogAssociationMapping"];
  logAssocCreation = 
    [ud boolForKey:@"WOxElemBuilder_LogAssociationCreation"];
  if (logAssocMap)
    [logger logWithFormat:@"association mapping is logged!"];
  if (logAssocCreation)
    [logger logWithFormat:@"association creation is logged!"];

  // TODO: improve extensibility of this (remember WOWrapperTemplateBuilder)
  defaultAssocMap = [[ud dictionaryForKey:@"WOxAssociationClassMapping"] copy];
  if (defaultAssocMap == nil)
    [logger warnWithFormat:
      @"WOxAssociationClassMapping default is not set!"];
  
  if (ValAssoc == Nil)
    ValAssoc = NSClassFromString(@"WOValueAssociation");
  
  CompoundElemClass = NSClassFromString(@"WOCompoundElement");

  if (yesNum   == nil) 
    yesNum = [[NSNumber numberWithBool:YES] retain];
  if (yesAssoc == nil)
    yesAssoc = [[WOAssociation associationWithValue:yesNum] retain];
}

+ (WOxElemBuilder *)createBuilderQueue:(NSArray *)_classNames {
  unsigned 	     i, count;
  WOxElemBuilder *first, *current = nil;
  NSMutableArray *missingBuilders = nil;
  
  if ((count = [_classNames count]) == 0)
    return nil;
  
  for (first = nil, i = 0; i < count; i++) {
    WOxElemBuilder *nx;
    NSString *cn;
    Class    clazz;
    
    cn = [_classNames objectAtIndex:i];
#if 0
    NSLog(@"builder class: %@", cn);
#endif
    
    if ((clazz = NSClassFromString(cn)) == Nil) {
      if (missingBuilders == nil) 
        missingBuilders = [NSMutableArray arrayWithCapacity:16];
      [missingBuilders addObject:cn];
      continue;
    }
    
    if ((nx = [[clazz alloc] init])) {
      if (first == nil) {
        first = current = nx;
        [nx autorelease];
      }
      else {
        [current setNextBuilder:nx];
        current = [nx autorelease];
      }
    }
    else {
      NSLog(@"%s: couldn't allocate builder (class=%@)", cn);
      continue;
    }
  }
  
  if (missingBuilders) {
    NSLog(@"WOxElemBuilder: could not locate builders: %@", 
          [missingBuilders componentsJoinedByString:@","]);
  }
  return first;
}

+ (WOxElemBuilder *)createBuilderQueueV:(NSString *)_className, ... {
  // TODO: reimplement using createBuilderQueue:
  va_list       ap;
  NSString      *cn;
  WOxElemBuilder *first, *current;
  
  if (_className == nil)
    return [[[self alloc] init] autorelease];
    
  first = [[[NSClassFromString(_className) alloc] init] autorelease];
    
  va_start(ap, _className);
  for (current = first; (cn = va_arg(ap, id)); ) {
    WOxElemBuilder *nx;

    nx = [[NSClassFromString(cn) alloc] init];
    [current setNextBuilder:nx];
    current = [nx autorelease];
  }
  va_end(ap);
    
  return first;
}

- (void)dealloc {
  [self->script            release];
  [self->subcomponentInfos release];
  [self->nsToAssoc         release];
  [self->nextBuilder       release];
  [super dealloc];
}

/* building an element (returns a retained object !!!) */

- (WOElement *)buildNode:(id<DOMNode>)_node templateBuilder:(id)_builder {
  if (_node == nil)
    return nil;

  switch ([_node nodeType]) {
    case DOM_ELEMENT_NODE:
      return [self buildElement:(id<DOMElement>)_node
                   templateBuilder:_builder];
    case DOM_TEXT_NODE:
      return [self buildText:(id<DOMText>)_node
                   templateBuilder:_builder];
    case DOM_CDATA_SECTION_NODE:
      return [self buildCDATASection:(id<DOMCDATASection>)_node
                   templateBuilder:_builder];
    case DOM_COMMENT_NODE:
      return [self buildComment:(id<DOMComment>)_node
                   templateBuilder:_builder];
    case DOM_DOCUMENT_NODE:
      return [self buildDocument:(id<DOMDocument>)_node
                   templateBuilder:_builder];
      
    default:
      if (self->nextBuilder)
        return [self->nextBuilder buildNode:_node templateBuilder:_builder];
      else {
        NSLog(@"unknown node type %i, node %@", [_node nodeType], _node);
        return nil;
      }
  }
}

- (NSArray *)buildNodes:(id<DOMNodeList>)_nodes templateBuilder:(id)_bld {
  // Note: returns a regular autoreleased array
  NSMutableArray *children;
  unsigned       i, count;
  
  if ((count = [_nodes length]) == 0)
    return nil;
  
  children = [[NSMutableArray alloc] initWithCapacity:(count + 1)];
  
  for (i = 0; i < count; i++) {
    WOElement *e;

    e = [_bld buildNode:[_nodes objectAtIndex:i] templateBuilder:_bld];
    if (e) {
      [children addObject:e];
      [e release];
    }
  }
  return children;
}

/* building methods specialized on type (return retained objects !!!) */

- (WOElement *)buildDocument:(id<DOMDocument>)_node templateBuilder:(id)_bld {
  return [self buildElement:[_node documentElement] templateBuilder:_bld];
}

- (WOElement *)buildElement:(id<DOMElement>)_node templateBuilder:(id)_bld {
  if (self->nextBuilder)
    return [self->nextBuilder buildElement:_node templateBuilder:_bld];

  [self logWithFormat:@"cannot build node %@ (template builder %@)",
          _node, _bld];
  return nil;
}

- (WOElement *)buildCharacterData:(id<DOMCharacterData>)_text
  templateBuilder:(id)_builder
{
  static Class ValClass = Nil;
  WOElement *textElement;
  unsigned len;
  BOOL     isASCII = NO;
  id       str;
  
  str = [_text data];
  if ((len = [str length]) == 0) return nil;
  
  /* 
     we use WOValueAssociation directly, because WOAssociation caches all
     values
  */
  if (ValClass == Nil)
    ValClass = NSClassFromString(@"WOValueAssociation");

#if 0
#  warning not using ASCII string !
  isASCII = NO;
#else
  if (len > 1) {
    // TODO(perf): improve on that
    /* not very efficient, but only used during template parsing ... */
    if ([str dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:NO])
      isASCII = YES;
    else
      isASCII = NO;
  }
  else {
    isASCII = ([str characterAtIndex:0] < 128) ? YES : NO;
  }
#endif
  
  str = [[ValClass alloc] initWithString:str];
  textElement = 
    [[(isASCII?AStrClass:StrClass) alloc] initWithValue:str escapeHTML:YES];
  [str release];
  return textElement;
}
- (WOElement *)buildText:(id<DOMText>)_node
  templateBuilder:(id)_builder
{
  return [self buildCharacterData:_node templateBuilder:_builder];
}
- (WOElement *)buildCDATASection:(id<DOMCDATASection>)_node
  templateBuilder:(id)_builder
{
  return [self buildCharacterData:_node templateBuilder:_builder];
}

- (WOElement *)buildComment:(id<DOMComment>)_node
  templateBuilder:(id)_builder
{
  /* comments aren't delivered ... */
  return nil;
}

/* building the whole template */

- (WOElement *)buildTemplateFromDocument:(id<DOMDocument>)_document {
  NSAutoreleasePool *pool;
  WOElement *result;
  
  pool   = [[NSAutoreleasePool alloc] init];
  result = [self buildNode:_document templateBuilder:self];
  [pool release];
  return result;
}

/* association callbacks */

- (WOAssociation *)associationForValue:(id)_value {
  return [WOAssociation associationWithValue:_value];
}

- (WOAssociation *)associationForKeyPath:(NSString *)_path {
  return [WOAssociation associationWithKeyPath:_path];
}

- (WOAssociation *)associationForJavaScript:(NSString *)_js {
  WOAssociation *assoc;
  
  assoc = [NSClassFromString(@"WOScriptAssociation") alloc];
  assoc = [(id)assoc initWithScript:_js language:@"javascript"];
  return [assoc autorelease];
}

- (WOAssociation *)associationForAttribute:(id<DOMAttr>)_attribute {
  NSString      *nsuri;
  NSString      *value;
  WOAssociation *assoc;
  Class c;
  
  nsuri = [_attribute namespaceURI];
  value = [_attribute nodeValue];
  
  c = [self associationClassForNamespaceURI:[_attribute namespaceURI]];
  if (c == Nil) {
    [self warnWithFormat:
	    @"found no association class for attribute %@ (namespace=%@)",
	    _attribute, [_attribute namespaceURI]];
    return nil;
  }
  if (logAssocMap) {
    [self logWithFormat:@"use class %@ for namespaceURI %@ (attribute %@)",
            c, [_attribute namespaceURI], [_attribute name]];
  }
  
  assoc = [[c alloc] initWithString:value];
  if (logAssocCreation) {
    [self logWithFormat:@"created assoc %@ for attribute %@", 
            assoc, [_attribute name]];
  }
  
  return [assoc autorelease];
}

- (NSMutableDictionary *)associationsForAttributes:(id<DOMNamedNodeMap>)_attrs{
  NSMutableDictionary *assocs;
  int i, count;
  
  if ((count = [_attrs length]) == 0)
    return nil;
  
  assocs = [NSMutableDictionary dictionaryWithCapacity:(count + 1)];

  for (i = 0; i < count; i++) {
    id<DOMAttr>   attr;
    WOAssociation *assoc;

    attr = [_attrs objectAtIndex:i];
    
    if ((assoc = [self associationForAttribute:attr])) {
      NSString *key;
      
      key = [attr name];
      if ([key characterAtIndex:0] == '_')
        key = [@"?" stringByAppendingString:[key substringFromIndex:1]];
      
      [assocs setObject:assoc forKey:key];
    }
  }
  return assocs;
}

- (void)_ensureDefaultAssocMappings {
  NSEnumerator *e;
  NSString     *ns;
  
  if (self->nsToAssoc) 
    return;
  
  self->nsToAssoc = [[NSMutableDictionary alloc] initWithCapacity:8];
  e = [defaultAssocMap keyEnumerator];
  while ((ns = [e nextObject]) != nil) {
    NSString *className;
    Class    clazz;
    
    className = [defaultAssocMap objectForKey:ns];
    clazz = NSClassFromString(className);
    
    if (clazz == Nil) {
      [self warnWithFormat:@"did not find association class: '%@'",
 	      className];
      continue;
    }
    
    /* register */
    [self->nsToAssoc setObject:clazz forKey:ns];
  }
}
- (void)registerAssociationClass:(Class)_class forNamespaceURI:(NSString *)_ns{
  if (_ns    == nil) return;
  if (_class == Nil) return;
  
  [self _ensureDefaultAssocMappings];
  [self->nsToAssoc setObject:_class forKey:_ns];
}
- (Class)associationClassForNamespaceURI:(NSString *)_ns {
  Class c;
  
  [self _ensureDefaultAssocMappings];
  
  if ((c = [self->nsToAssoc objectForKey:_ns]) == Nil)
    /* if we have no class mapped for a namespace, we treat it as a value */
    c = ValAssoc;
  
  if (debugOn)
    [self debugWithFormat:@"using class %@ for namespace %@", c, _ns];
  return c;
}

/* creating unique IDs */

- (NSString *)uniqueIDForNode:(id)_node {
  NSMutableArray  *nodePath;
  NSMutableString *uid;
  NSEnumerator    *topDown;
  id   node, parent;
  BOOL isFirst;

  if (_node == nil) return nil;

  nodePath = [NSMutableArray arrayWithCapacity:16];

  /* collect all parent nodes in bottom-up form */

  for (node = _node; node; node = [node parentNode])
    [nodePath addObject:node];

  /* generate ID */

  uid     = [NSMutableString stringWithCapacity:64];
  topDown = [nodePath reverseObjectEnumerator];
  isFirst = YES;
  parent  = nil;

  for (isFirst = YES; (node = [topDown nextObject]); parent = node) {
    if (!isFirst) {
      NSArray  *children;
      unsigned i, count;

      [uid appendString:@"."];

      /* determine index of _node */

      children = (NSArray *)[parent childNodes];
      for (i = 0, count = [children count]; i < count; i++) {
        if ([children objectAtIndex:i] == node)
          break;
      }
      [uid appendFormat:@"%d", i];
    }
    else {
      [uid appendString:@"R"];
      isFirst = NO;
    }
  }

  return [[uid copy] autorelease];
}

/* logging */

+ (id)logger {
  return logger;
}
- (id)logger {
  return logger;
}

- (void)logWithFormat:(NSString *)_format, ... {
  NSString *value = nil;
  va_list  ap;

  va_start(ap, _format);
  value = [[NSString alloc] initWithFormat:_format arguments:ap];
  va_end(ap);

  NSLog(@"|%@| %@", self, value);
  [value release];
}
- (void)debugWithFormat:(NSString *)_format, ... {
  static char showDebug = 2;
  NSString *value = nil;
  va_list  ap;
  
  if (showDebug == 2) {
    showDebug = [WOApplication isDebuggingEnabled] ? 1 : 0;
  }
  
  if (showDebug) {
    va_start(ap, _format);
    value = [[NSString alloc] initWithFormat:_format arguments:ap];
    va_end(ap);
    
    NSLog(@"|%@|D %@", self, value);
    [value release];
  }
}

/* managing builder queues */

- (void)setNextBuilder:(WOxElemBuilder *)_builder {
  ASSIGN(self->nextBuilder, _builder);
}
- (WOxElemBuilder *)nextBuilder {
  return self->nextBuilder;
}

/* component script parts */

- (void)addComponentScriptPart:(WOComponentScriptPart *)_part {
  if (self->script == nil)
    self->script = [[WOComponentScript alloc] init];
  
  [self->script addScriptPart:_part];
}
- (void)addComponentScript:(NSString *)_script line:(unsigned)_line {
  WOComponentScriptPart *part;
  
  part = [[WOComponentScriptPart alloc] initWithURL:nil startLine:_line
					script:_script];
  [self addComponentScriptPart:part];
  RELEASE(part);
}

- (WOComponentScript *)componentScript {
  return self->script;
}

/* subcomponent registry, created during parsing ... */

- (void)registerSubComponentWithId:(NSString *)_cid
  componentName:(NSString *)_name
  bindings:(NSMutableDictionary *)_bindings
{
  WOxElemBuilderComponentInfo *info;
  
  info = [[WOxElemBuilderComponentInfo alloc] initWithComponentId:_cid
    componentName:_name
    bindings:_bindings];
    
  if (self->subcomponentInfos == nil)
    self->subcomponentInfos = [[NSMutableArray alloc] initWithCapacity:16];
  [self->subcomponentInfos addObject:info];
  [info release]; info = nil;
}

- (NSArray *)subcomponentInfos {
  return self->subcomponentInfos;
}

- (void)reset {
  [self->subcomponentInfos removeAllObjects];
  [self->script release]; self->script = nil;
}

/* support methods for subclasses */

- (id<DOMElement>)lookupUniqueTag:(NSString *)_name
  inElement:(id<DOMElement>)_elem
{
  id<DOMNodeList> list;
  
  if ((list = [_elem getElementsByTagName:_name]) == nil)
    return nil;
  if ([list length] == 0)
    return nil;
  if ([list length] > 1) {
    [self warnWithFormat:
	    @"more than once occurence of tag %@ in element: %@", 
	    _name, _elem];
  }
  return [list objectAtIndex:0];
}

- (WOElement *)elementForRawString:(NSString *)_rawstr {
  /* Note: returns a retained element! */
  WOAssociation *a;
  
  if (_rawstr == nil) return nil;
  a = [WOAssociation associationWithValue:_rawstr];
  return [[StrClass alloc] initWithValue:a escapeHTML:NO];
}

- (WOElement *)elementForElementsAndStrings:(NSArray *)_elements {
  /* Note: returns a retained element! */
  NSMutableArray *ma;
  WOElement *element;
  unsigned  i, count;
  
  if ((count = [_elements count]) == 0)
    return nil;
  
  ma = [[NSMutableArray alloc] initWithCapacity:count];
  for (i = 0; i < count; i++) {
    id elem;
    
    elem = [_elements objectAtIndex:i];
    if ([elem isKindOfClass:[WOElement class]]) {
      [ma addObject:elem];
      continue;
    }
    
    if ((elem = [self elementForRawString:[elem stringValue]]))
      [ma addObject:elem];
  }
  if ((count = [ma count]) == 0)
    element = nil;
  else if (count == 1) {
    element = [[ma objectAtIndex:0] retain];
  }
  else {
    element = [[CompoundElemClass allocForCount:count zone:NULL]
		initWithContentElements:ma];
  }
  [ma release];
  return element;
}

- (WOElement *)wrapElement:(WOElement *)_element 
  inCondition:(WOAssociation *)_condition
  negate:(BOOL)_flag
{
  // NOTE: *releases* _element parameter!
  //       returns retained conditional
  static Class WOConditionalClass = Nil;
  static NSString *key = @"condition";
  NSMutableDictionary *assocs;
  WOElement *element;
  NSArray   *children;

  if (WOConditionalClass == Nil)
    WOConditionalClass = NSClassFromString(@"WOConditional");
  
  if (_element == nil)
    return nil;
  if (_condition == nil)
    return _element;
  
  if (_flag) {
    assocs = [[NSMutableDictionary alloc] 
	       initWithObjectsAndKeys:_condition, key,
	       yesAssoc, @"negate", nil];
  }
  else {
    assocs = [[NSMutableDictionary alloc] initWithObjects:&_condition
					  forKeys:&key count:1];
  }
  children = [[NSArray alloc] initWithObjects:&_element count:1];
  element = [[WOConditionalClass alloc] initWithName:nil
                                        associations:assocs
                                        contentElements:children];
  [children release];
  [_element release];
  [assocs   release];
  return element;
}

- (WOElement *)wrapElements:(NSArray *)_sub inElementOfClass:(Class)_class {
  WOElement *element;
  
  if (_sub == nil)
    return nil;
  
  element = [[_class alloc] initWithName:nil
                            associations:nil
                            contentElements:_sub];
  return element;
}

- (WOElement *)wrapChildrenOfElement:(id<DOMElement>)_tag
  inElementOfClass:(Class)_class
  templateBuilder:(id)_b
{
  NSArray *children;
  
  children = [_tag hasChildNodes]
    ? [_b buildNodes:[_tag childNodes] templateBuilder:_b]
    : (NSArray *)nil;
  [children autorelease];
  
  return [self wrapElements:children inElementOfClass:_class];
}

@end /* WOxElemBuilder */
