/*
  Copyright (C) 2000-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess

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

#include "WOWrapperTemplateBuilder.h"
#include "WODParser.h"
#include "WOHTMLParser.h"
#include "WOCompoundElement.h"
#include "WOChildComponentReference.h"
#include <NGObjWeb/WOAssociation.h>
#include "common.h"

/*
  .wo components need to know at parsing time whether we are dealing
  with a component or a dynamic element, the .wod or the .html does
  not contain this information.
  
  What to do ... ?? Always checking the class isn't very nice either ..
*/

@interface _WODFileEntry : NSObject
{
@public
  NSString     *componentName;
  NSDictionary *associations;
  Class        componentClass;
  signed char  isDynamicElement;
}

- (BOOL)isDynamicElement;
- (Class)componentClass;

@end

@interface WODynamicElement(UsedPrivates)
- (id)initWithElementName:(NSString *)_element
  attributes:(NSDictionary *)_attributes
  contentElements:(NSArray *)_subElements
  componentDefinition:(id)_cdef;
+ (BOOL)isDynamicElement;
@end

static Class AssocClass = Nil;
static Class StrClass   = Nil;
static Class ValAssoc   = Nil;

@implementation WOWrapperTemplateBuilder

static BOOL debugOn              = NO;
static BOOL logExtraAssociations = NO;
static BOOL logScriptAdditions   = NO;
static NSStringEncoding parserEncoding;
static NSDictionary *defaultAssocMap = nil;

+ (int)version {
  return [super version] + 0 /* v2 */;
}

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  
  AssocClass = [WOAssociation class];
  StrClass   = [NSString      class];

  if (ValAssoc == Nil)
    ValAssoc = NSClassFromString(@"WOValueAssociation");
  
  // TODO: improve extensibility of this (remember WOxElemBuilder)
  defaultAssocMap = [[ud dictionaryForKey:@"WOxAssociationClassMapping"] copy];
  
  if ([ud boolForKey:@"WOParsersUseUTF8"]) {
    parserEncoding = NSUTF8StringEncoding;
    NSLog(@"Note: using UTF-8 as wrapper template parser encoding.");
  }
  else
    parserEncoding = [NSString defaultCStringEncoding];
}

- (void)dealloc {
  [self->lastException  release];
  [self->definitions    release];
  [self->componentNames release];
  [self->iTemplate      release];
  [super dealloc];
}

/* parsing */

- (BOOL)_parseDeclarationsFile:(NSData *)_decl {
  NSDictionary *defs;
  WODParser *parser;
   
  parser = [WODParser alloc]; /* keep gcc happy */
  parser = [[parser initWithHandler:(id)self] autorelease];
  defs = [parser parseDeclarationData:_decl];
  return defs ? YES : NO;
}

- (WOElement *)parseWithHTMLData:(NSData *)_html
  declarationData:(NSData *)_decl
{
  WOHTMLParser *parser;
  NSArray      *topLevel    = nil;
  NSException  *exception   = nil;
  WOElement    *rootElement;
  
  /* parse declarations file */
  if (![self _parseDeclarationsFile:_decl])
    return nil;
  
  /* parse HTML file */
  parser = [WOHTMLParser alloc]; /* keep gcc happy */
  parser = [[parser initWithHandler:(id)self] autorelease];
  if ((topLevel = [parser parseHTMLData:_html]) == nil)
    exception = [parser parsingException];
  
  /* setup root element */
  
  if ([topLevel count] == 1) {
    rootElement = [[topLevel objectAtIndex:0] retain];
  }
  else if ([topLevel count] > 1) {
    static Class CompoundElemClass = Nil;
    if (CompoundElemClass == Nil)
      CompoundElemClass = NSClassFromString(@"WOCompoundElement");
    
    rootElement =
      [[CompoundElemClass allocForCount:[topLevel count] zone:[self zone]]
                          initWithChildren:topLevel];
  }
  else /* no topLevel element */
    rootElement = nil;
  
  if (exception) [exception raise];
  return rootElement;
}

- (void)reset {
  [self->definitions    removeAllObjects];
  [self->componentNames removeAllObjects];
  [self->iTemplate release]; self->iTemplate = nil;
}

- (NSData *)rewriteData:(NSData *)_data 
  fromEncoding:(NSStringEncoding)_from
  toEncoding:(NSStringEncoding)_to
{
  NSString *s;
  NSData   *d;
  
  if ((s = [[NSString alloc] initWithData:_data encoding:_from]) == nil) {
    [self errorWithFormat:@"template file has incorrect encoding!"];
    return _data;
  }
  if ((d = [s dataUsingEncoding:_to]) == nil) {
    [self errorWithFormat:
            @"could not represent template file in parser encoding!"];
    return _data;
  }
  return d;
}

- (NSException *)_handleBuildException:(NSException *)_exc atURL:(NSURL *)_url{
  NSException *newException;
  NSDictionary *userInfo;
  NSMutableDictionary *newUserInfo;

  [self reset];

  if ((userInfo = [_exc userInfo]) != nil) {
    newUserInfo = [[NSMutableDictionary alloc] initWithCapacity:
                                                 [userInfo count] + 1];
    [newUserInfo addEntriesFromDictionary:userInfo];
    [newUserInfo setObject:_url forKey:@"templateURL"];
  }
  else {
    newUserInfo = (NSMutableDictionary *)
      [[NSDictionary alloc] initWithObjectsAndKeys:_url, @"templateURL", nil];
  }
  newException = [NSException exceptionWithName:[_exc name]
                              reason:[_exc reason]
                              userInfo:newUserInfo];
  return newException;
}

- (NSStringEncoding)encodingForString:(NSString *)_enc {
  NSStringEncoding encoding;

  encoding = 0;
    
  if ([_enc isEqualToString:@"NSASCIIStringEncoding"])
    encoding = NSASCIIStringEncoding;
  else if ([_enc isEqualToString:@"NSNEXTSTEPStringEncoding"])
    encoding = NSNEXTSTEPStringEncoding;
  else if ([_enc isEqualToString:@"NSUTF8StringEncoding"])
    encoding = NSUTF8StringEncoding;
  else if ([_enc isEqualToString:@"NSISOLatin1StringEncoding"])
    encoding = NSISOLatin1StringEncoding;
  else if ([_enc isEqualToString:@"NSISOLatin2StringEncoding"])
    encoding = NSISOLatin2StringEncoding;
  else if ([_enc isEqualToString:@"NSUnicodeStringEncoding"])
    encoding = NSUnicodeStringEncoding;
  else if ([_enc length] == 0)
    ; // keep platform encoding
#if LIB_FOUNDATION_LIBRARY
  else if ([_enc isEqualToString:@"NSISOLatin9StringEncoding"])
    encoding = NSISOLatin9StringEncoding;
  else if ([_enc isEqualToString:@"NSWinLatin1StringEncoding"])
    encoding = NSWinLatin1StringEncoding;
#endif
#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY
  else
    encoding = [NSString stringEncodingForEncodingNamed:_enc];
#endif
  return encoding;
}

- (WOTemplate *)buildTemplateAtURL:(NSURL *)_url {
  static NSData *emptyData = nil;
  NSFileManager *fm;
  WOTemplate    *template;
  WOElement     *rootElement;
  BOOL          withLanguage;
  NSData        *wodFile     = nil;
  NSData        *htmlFile    = nil;
  NSDictionary  *wooFile     = nil;
  NSString      *tmpPath;
  NSString      *path, *name;
  NSStringEncoding encoding;
  WOComponentScript *script;
  id tmp;
  
  NSAssert(self->iTemplate == nil, @"parsing in progress !!!");
  [self reset];
  [self->lastException release]; self->lastException = nil;
  
  if (_url == nil)
    return nil;
  
  if (![_url isFileURL]) {
    [self logWithFormat:@"can only process wrappers at file-URLs: %@", _url];
    return nil;
  }

  /* setup local and common objects */
  
  if (emptyData == nil)
    emptyData = [[NSData alloc] init];
  
  if (self->definitions == nil)
    self->definitions = [[NSMutableDictionary alloc] initWithCapacity:64];

  /* process pathes */
  
  fm   = [NSFileManager defaultManager];
  path = [_url path];
  
  tmpPath      = [path lastPathComponent];
  withLanguage = [[tmpPath pathExtension] isEqualToString:@"lproj"];
  
  /*
    TODO: can this code handle ".wo" templates without a wrapper? Eg if I place
          Main.html and Main.wod directly into the bundle resources directory?
    TODO: can this code handle static names for contained files? (eg 
          template.wod instead of Main.wod) This way we could avoid renaming
	  the individual files if the wrapper name changes.
  */
  if (withLanguage) {
    /* eg /a/b/c/a.wo/English.lproj/a.html */
    tmpPath = [path stringByDeletingLastPathComponent];
    name = [[tmpPath lastPathComponent] stringByDeletingPathExtension];
  }
  else if ([path hasSuffix:@".html"]) {
    /* 
       If we pass in the .html, this basically means that the .html and .wod
       are not inside a wrapper but in some arbitary directory.
       This is used in OGo to support FHS location in a Unix-like way (the
       templates live in /usr/share/ogo/templates/xyz.html and xyz.wod).
    */
    name = [[path lastPathComponent] stringByDeletingPathExtension];
    path = [path stringByDeletingLastPathComponent];
    if (debugOn) [self logWithFormat:@"CHECK: %@", path];
  }
  else {
    /* eg /a/b/c/a.wo/a.html */
    name = [[path lastPathComponent] stringByDeletingPathExtension];
  }
  
  tmpPath = [name stringByAppendingPathExtension:@"wod"];
  tmpPath = [path stringByAppendingPathComponent:tmpPath];
  wodFile = [NSData dataWithContentsOfFile:tmpPath];
  if (debugOn)
    [self logWithFormat:@"CHECK: %@ + %@ => %@", path, name, tmpPath];
  
  tmpPath = [name stringByAppendingPathExtension:@"html"];
  tmpPath = [path stringByAppendingPathComponent:tmpPath];
  htmlFile = [NSData dataWithContentsOfFile:tmpPath];

  tmpPath = [name stringByAppendingPathExtension:@"woo"];
  tmpPath = [path stringByAppendingPathComponent:tmpPath];
  if ([fm fileExistsAtPath:tmpPath])
    wooFile = [NSDictionary dictionaryWithContentsOfFile:tmpPath];
  
  /* process language specific pathes */
  
  script = nil;
  if (wodFile == nil) { /* no .wod, no script (cannot be bound ...) */
    if (withLanguage) {
      tmpPath = [name stringByAppendingPathExtension:@"wod"];
      tmpPath = [[path stringByDeletingLastPathComponent]
                       stringByAppendingPathComponent:tmpPath];
      
      if ((wodFile = [NSData dataWithContentsOfFile:tmpPath]) == nil) {
        wodFile = emptyData;
        [self logWithFormat:
		@"%s:%i:\n"
	        @"  could not load wod file of component '%@'\n"
                @"  URL:      '%@'\n"
	        @"  tmp-path: '%@'\n"
                @"  path:     '%@'",
	        __PRETTY_FUNCTION__, __LINE__, 
	        name, [_url absoluteString], tmpPath, path];
      }
    }
    else {
      wodFile = emptyData;
      [self logWithFormat:
              @"%s:%i:\n  could not load wod file of %@\n"
              @"  path=%@, not with lang.",
              __PRETTY_FUNCTION__, __LINE__, name, path];
    }
  }
  else {
    /* check for script */
    NSFileManager *fm = [NSFileManager defaultManager];
    
    tmpPath = [name stringByAppendingPathExtension:@"js"];
    tmpPath = [path stringByAppendingPathComponent:tmpPath];
    
    if ([fm fileExistsAtPath:tmpPath])
      script = [[WOComponentScript alloc] initWithContentsOfFile:tmpPath];
  }
  if (htmlFile == nil) {
    [self logWithFormat:@"%s:\n  could not load html file of component %@.",
            __PRETTY_FUNCTION__, name];
    return nil;
  }
  
  /* process string encoding */
  
  encoding = parserEncoding;
  if ((tmp = [wooFile objectForKey:@"encoding"]) != nil) {
    // TODO: move to an NSString category, isn't there a method for this in
    //       Foundation?!
    if ((encoding = [self encodingForString:tmp]) == 0) {
      [self errorWithFormat:
              @"(%s): cannot deal with template encoding: '%@'",
              __PRETTY_FUNCTION__, tmp];
      encoding = parserEncoding;
    }
    
    if (encoding != parserEncoding) {
      // TODO: HACK and slow, the parsers should be able to deal with Unicode
      // TODO: in case this works, remove the log
      [self logWithFormat:
              @"Note: rewriting template NSData for parser encoding (%@=>%@).",
              [NSString localizedNameOfStringEncoding:encoding],
              [NSString localizedNameOfStringEncoding:parserEncoding]];
      
      htmlFile = [self rewriteData:htmlFile 
                       fromEncoding:encoding toEncoding:parserEncoding];
      wodFile  = [self rewriteData:wodFile
                       fromEncoding:encoding toEncoding:parserEncoding];
    }
  }
  
  /* instantiate template */
  
  self->iTemplate = [[WOTemplate alloc] initWithURL:_url rootElement:nil];
  
  rootElement = nil;
  NS_DURING
    rootElement = [self parseWithHTMLData:htmlFile declarationData:wodFile];
  NS_HANDLER
    [[self _handleBuildException:localException atURL:_url] raise];
  NS_ENDHANDLER;
  
  [self->iTemplate setRootElement:rootElement];
  [rootElement release];
  template = self->iTemplate;
  self->iTemplate = nil;
  
  [self reset];
  
  if ((tmp = [wooFile objectForKey:@"variables"]))
    [template setKeyValueArchivedTemplateVariables:tmp];
  
  if (script) {
    if (logScriptAdditions) {
      [self logWithFormat:@"adding script %@ to template: '%@'", 
              script, template];
    }
    [template setComponentScript:script];
    [script release];
  }
  
  return template;
}

/* creating associations from WO/hash tag attributes */

- (NSString *)namespaceURIForPrefix:(NSString *)_prefix {
  unsigned int len;
  
  if ((len = [_prefix length]) == 0)
    return nil;

  switch (len) {
  case 2:
    if ([_prefix isEqualToString:@"so"])
      return @"http://www.skyrix.com/od/so-lookup";
    break;
  case 3:
    if ([_prefix isEqualToString:@"var"])
      return @"http://www.skyrix.com/od/binding";
    break;
  case 4:
    if ([_prefix isEqualToString:@"rsrc"])
      return @"OGo:url";
    break;
  case 5:
    if ([_prefix isEqualToString:@"const"])
      return @"http://www.skyrix.com/od/constant";
    if ([_prefix isEqualToString:@"label"])
      return @"OGo:label";
    break;
  }
  [self errorWithFormat:@"found no namespace for prefix: '%@'", _prefix];
  return nil;
}

- (Class)associationClassForNamespaceURI:(NSString *)_uri {
  if (_uri == nil)
    return ValAssoc;
  
  // TODO: WOxElemBuilder caches the classes
  return NSClassFromString([defaultAssocMap objectForKey:_uri]);
}

- (void)addAttributes:(NSDictionary *)_attrs
  toAssociations:(NSMutableDictionary *)assocs
{
  NSEnumerator *e;
  NSString *key;
  unsigned count;
  
  if (_attrs == nil)
    return;
  if ((count = [_attrs count]) == 0)
    return;
  if (count == 1 && [_attrs objectForKey:@"NAME"] != nil)
    return;
  
  e = [_attrs keyEnumerator];
  while ((key = [e nextObject]) != nil) {
    BOOL doRelease;
    id value;
    
    if ([key isEqualToString:@"NAME"]) /* <WEBOBJECT NAME="">, not in assocs */
      continue;
    
    value = [_attrs objectForKey:key];
    if (![value isKindOfClass:AssocClass]) {
      NSRange  r;
      NSString *uri, *name;
      Class clazz;
      
      r    = [key rangeOfString:@":"];
      uri  = (r.length > 0)
	? [key substringToIndex:r.location] : (NSString *)nil;
      uri  = [self namespaceURIForPrefix:uri];
      name = (r.length > 0) 
        ? [key substringFromIndex:(r.location + r.length)] 
        : key;
      
      if ((clazz = [self associationClassForNamespaceURI:uri]) == nil) {
        [self logWithFormat:@"ERROR: could not process tag attribute: %@",key];
        continue;
      }
      
      value = [[clazz alloc] initWithString:value];
      key   = name;
      doRelease = YES;
    }
    else
      doRelease = NO;
    
    [assocs setObject:value forKey:key];
    if (doRelease) [value release];
  }
}

/* HTML parser callbacks */

- (NSString *)_uniqueComponentNameForDefinitionWithName:(NSString *)_element {
  NSString *cname;
  int      i = 0;
  
  if (self->componentNames == nil)
    self->componentNames = [[NSMutableSet alloc] init];
  
  cname = _element;
  while ([self->componentNames containsObject:cname]) {
    cname = [NSString stringWithFormat:@"%@%i", _element, i];
    i++;
    if (i > 200) break;
  }
  
  NSAssert3(i < 200,
	    @"more than 200 components for definition named %@ "
	    @"(last name %@) (names=%@) ??",
	    _element, cname, self->componentNames);
  
  [self->componentNames addObject:cname];
  return cname;
}

- (WOElement *)componentWithName:(NSString *)_element
  attributes:(NSDictionary *)_attributes // not the associations !
  contentElements:(NSArray *)_subElements
{
  /*
    Setup a new child component reference.
    
    Note: it could be a hash-reference, like <#Frame>, in this case we need to
          derive the associations from the attributes.
  */
  static Class ChildRefClass = Nil;
  _WODFileEntry      *def;
  WOChildComponentReference *element = nil;
  NSString     *cname = nil;
  NSDictionary *assoc;
  
  if ((def = [self->definitions objectForKey:_element]) != nil)
    assoc = def->associations;
  else {
    assoc = [NSMutableDictionary dictionaryWithCapacity:4];
    [self addAttributes:_attributes
	  toAssociations:(NSMutableDictionary *)assoc];
  }
  
  if (ChildRefClass == Nil)
    ChildRefClass = NSClassFromString(@"WOChildComponentReference");
  
  cname = [self _uniqueComponentNameForDefinitionWithName:_element];
  
  /* add subcomponent info */
  [self->iTemplate
       addSubcomponentWithKey:cname
       name:(def != nil ? def->componentName : _element)
       bindings:assoc];
  
  /* add subcomponent reference */
  element = [[ChildRefClass alloc]
                            initWithName:cname
                            associations:nil
                            contentElements:_subElements];
  if (element == nil) {
    [self errorWithFormat:
	    @"could not instantiate child component reference: %@", _element];
  }
  
  return element;
}

- (WOElement *)dynamicElementWithName:(NSString *)_element
  attributes:(NSDictionary *)_attributes // not the associations !
  contentElements:(NSArray *)_subElements
{
  _WODFileEntry *def;
  Class               elementClass;
  NSMutableDictionary *assoc = nil;
  WODynamicElement    *element;
  
  if ((def = [self->definitions objectForKey:_element]) == nil) {
    /* 
       If there is no definition with the name, try to treat it as a
       classname, eg:
         <#WOString var:value="abc" />
         <WEBOBJECT NAME="WOString" var:value="abc"></WEBOBJECT>
    */
    if ((elementClass = NSClassFromString(_element)) == nil) {
      /* ok, we also do not have a matching class */
      
      [self errorWithFormat:
              @"did not find definition of dynamic element '%@'",
              _element];
      return [[NSClassFromString(@"WONoContentElement") alloc]
               initWithElementName:_element
               attributes:_attributes
               contentElements:_subElements
               componentDefinition:nil];
    }
    
    /* setup fake WOD entry */
    def = [[[_WODFileEntry alloc] init] autorelease];
    def->componentName  = [_element copy];
    def->associations   = [[NSDictionary alloc] init];
    def->componentClass = elementClass;
  }
  
  if (![def isDynamicElement]) {
    /* definition describes a component */
    return [self componentWithName:_element
                 attributes:_attributes
                 contentElements:_subElements];
  }
  
  elementClass = [def componentClass];
  NSAssert1(elementClass, @"got no class for element %@", def);
  
  assoc = [def->associations mutableCopy];
  [self addAttributes:_attributes toAssociations:assoc];
  
  /* create element */
  
  element = [[elementClass alloc]
                           initWithName:_element
                           associations:assoc
                           contentElements:_subElements];
  if (element == nil) {
    [self errorWithFormat:@"could not instantiate dynamic element of class %@",
            NSStringFromClass(elementClass)];
  }
  if ([assoc isNotEmpty]) {
    if (logExtraAssociations)
      [self logWithFormat:@"remaining definition attributes: %@", assoc];
    [element setExtraAttributes:assoc];
  }
  [assoc release]; assoc = nil;

  return element;
}

/* WOTemplate(HTMLParser) */

- (BOOL)parser:(id)_parser willParseHTMLData:(NSData *)_data {
  return YES;
}

- (void)parser:(id)_parser finishedParsingHTMLData:(NSData *)_data
  elements:(NSArray *)_elements
{
}

- (void)parser:(id)_parser failedParsingHTMLData:(NSData *)_data
  exception:(NSException *)_exception
{
}

/* WOTemplate(WODParser) */

- (BOOL)parser:(id)_parser willParseDeclarationData:(NSData *)_data {
  return YES;
}
- (void)parser:(id)_parser finishedParsingDeclarationData:(NSData *)_data
  declarations:(NSDictionary *)_decls
{
}
- (void)parser:(id)_parser failedParsingDeclarationData:(NSData *)_data
  exception:(NSException *)_exception
{
  [_exception raise];
}

- (id)parser:(id)_parser makeAssociationWithValue:(id)_value {
  return [AssocClass associationWithValue:_value];
}
- (id)parser:(id)_parser makeAssociationWithKeyPath:(NSString *)_keyPath {
  NSCAssert([_keyPath isKindOfClass:StrClass],
            @"invalid keypath property (expected string)");
  return [AssocClass associationWithKeyPath:_keyPath];
}
- (id)parser:(id)_parser makeDefinitionForComponentNamed:(NSString *)_cname
  associations:(id)_entry
  elementName:(NSString *)_elemName
{
  _WODFileEntry *def;
  
  def = [[[_WODFileEntry alloc] init] autorelease];
  def->componentName = [_cname copy];
  def->associations  = [_entry retain];
  
  [self->definitions setObject:def forKey:_elemName];
  
  return def;
}

@end /* WOWrapperTemplateBuilder */

@implementation _WODFileEntry

- (id)init {
  self->isDynamicElement = -1;
  return self;
}

- (void)dealloc {
  [self->componentName release];
  [self->associations  release];
  [super dealloc];
}

/* accessors */

- (NSString *)componentName {
  return self->componentName;
}
- (NSDictionary *)bindings {
  return self->associations;
}

- (Class)componentClass {
  if (self->componentClass == nil)
    self->componentClass = NSClassFromString(self->componentName);
  
  return self->componentClass;
}

- (BOOL)isDynamicElement {
  if (self->isDynamicElement == -1) {
    self->isDynamicElement = 
      [[self componentClass] isDynamicElement] ? 1 : 0;
  }
  return (self->isDynamicElement == 0) ? NO : YES;
}

@end /* _WODFileEntry */
