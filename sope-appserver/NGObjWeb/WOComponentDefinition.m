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

#include <NGObjWeb/WOComponentDefinition.h>
#include "WOComponent+private.h"
#include "WOComponentFault.h"
#include "WONoContentElement.h"
#include <NGObjWeb/WOAssociation.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOElement.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOResourceManager.h>
#include "common.h"
#import <EOControl/EOControl.h>
#ifdef MULLE_EO_CONTROL
#import <EOControl/EOKeyValueUnarchiver.h>
#endif

#include <NGObjWeb/WOTemplateBuilder.h>

static Class    StrClass    = Nil;
static Class    DictClass   = Nil;
static Class    AssocClass  = Nil;
static Class    NumberClass = Nil;
static Class    DateClass   = Nil;
static NSNumber *yesNum     = nil;
static NSNumber *noNum      = nil;

@interface WOComponent(UsedPrivates)
- (void)setBaseURL:(id)_url;
@end

@interface WOComponentDefinition(PrivateMethods)

- (BOOL)load;

@end

#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOSession.h>

/*
  TODO:
  
  WO's instantiation method is 
    - componentInstanceInContext:forComponentReference:
  with the primary being
    - _componentInstanceInContext:forComponentReference:
  
  Maybe we should change to that. Currently this flow is a bit broken because
  the resourcemanager sits in the middle, though I'm pretty sure that some
  older WO used WOResourceManager just like we do in the moment.
*/

@implementation WOComponent(InfoSetup)

- (Class)componentFaultClass {
  return [WOComponentFault class];
}

- (NSMutableDictionary *)instantiateChildComponentsInTemplate:(WOTemplate *)_t
  languages:(NSArray *)_languages
{
  NSMutableDictionary *childComponents = nil;
  WOResourceManager *_rm;
  WOTemplate *tmpl;
  NSEnumerator *keys;
  NSString     *key;
  
  if ((tmpl = _t) == nil)
    return nil;
  
  _rm = [[WOApplication application] resourceManager];
  
  if ([tmpl hasSubcomponentInfos] == 0)
    return nil;
  
  keys = [tmpl infoKeyEnumerator];
  while ((key = [keys nextObject])) {
    WOSubcomponentInfo *childInfo = nil;
    WOComponentFault   *child     = nil;
      
    childInfo = [tmpl subcomponentInfoForKey:key];
    
    child = [[WOComponentFault alloc]
              initWithResourceManager:nil //_rm
              pageName:[childInfo componentName]
              languages:_languages
              bindings:[childInfo bindings]];

    if (child != nil) {
      if (childComponents == nil)
        childComponents = [NSMutableDictionary dictionaryWithCapacity:16];
        
      [childComponents setObject:child forKey:key];
      [child release];
    }
    else {
      [self errorWithFormat:
              @"(%s): Could not instantiate child fault %@, component: '%@'",
              __PRETTY_FUNCTION__, key, [childInfo componentName]];
    }
  }
  return childComponents;
}

- (id)initWithName:(NSString *)_cname
  template:(WOTemplate *)_template
  inContext:(WOContext *)_ctx
{
  // Note: the _template can be nil and will then get looked up dynamically!
  [self setName:_cname];
  if ((self = [self initWithContext:_ctx])) {
    NSMutableDictionary *childComponents;
    NSArray             *langs;

    langs = [[self context] resourceLookupLanguages];
    
    childComponents = [self instantiateChildComponentsInTemplate:_template
			                      languages:langs];
    [self setSubComponents:childComponents];
    [self setTemplate:_template];
  }
  return self;
}

- (id)initWithComponentDefinition:(WOComponentDefinition *)_cdef 
  inContext:(WOContext *)_ctx
{
  /* 
     HACK HACK HACK CD: 
     We reuse the wocVariables ivar to pass over the component definition to 
     the component which will then call -_finishInitializingComponent: on the
     definition for applying the .woo.
     
     Sideeffects: if a component subclass uses extra vars prior calling
     WOComponent -init, it will run into "issues".
  */
  NSAssert(self->wocVariables == nil,
	   @"extra variables dict is already set! cannot transfer component "
	   @"definition in that variable (use the HACK)");
  self->wocVariables = (id)[_cdef retain];
  
  return [self initWithName:[_cdef componentName]
	       template:[_cdef template]
	       inContext:_ctx];
}

@end /* WOComponent(InfoSetup) */

@implementation WOComponentDefinition

static BOOL debugOn     = NO;
static BOOL profLoading = NO;
static BOOL enableClassLessComponents = NO;
static BOOL enableWOOFiles            = NO;
static NSArray *woxExtensions = nil;

+ (int)version {
  return 4;
}

+ (void)initialize {
  static BOOL isInitialized = NO;
  NSUserDefaults *ud;
  if (isInitialized) return;
  isInitialized = YES;
  ud = [NSUserDefaults standardUserDefaults];
    
  StrClass    = [NSString      class];
  DictClass   = [NSMutableDictionary class];
  AssocClass  = [WOAssociation class];
  NumberClass = [NSNumber      class];
  DateClass   = [NSDate        class];
    
  yesNum = [[NumberClass numberWithBool:YES] retain];
  noNum  = [[NumberClass numberWithBool:NO]  retain];
  
  profLoading = [[ud objectForKey:@"WOProfileLoading"] boolValue];
  enableClassLessComponents = 
    [ud boolForKey:@"WOEnableComponentsWithoutClasses"];
  enableWOOFiles = [ud boolForKey:@"WOComponentLoadWOOFiles"];
  debugOn        = [ud boolForKey:@"WODebugComponentDefinition"];
  woxExtensions  = [[ud arrayForKey:@"WOxFileExtensions"] copy];
}

- (id)initWithName:(NSString *)_name
  path:(NSString *)_path
  baseURL:(NSURL *)_baseUrl
  frameworkName:(NSString *)_frameworkName
{
  /* 
     this method is usually called by WOResourceManager
     (_definitionWithName:...) 
  */
  if ((self = [super init])) {
    /*
      'name'    is the name of the component
      'path'    contains a string or a NSURL with the location of the directory
                containing the component - TODO: explain who calculates that!
      'baseURL' contains a URL like /AppName/FrameworkName/Component/Eng.lProj
                (the external URL of the component, not sure whether this is
		 actually used somewhere)
    */
    NSZone *z = [self zone];
    
    self->name          = [_name          copyWithZone:z];
    self->path          = [_path          copyWithZone:z];
    self->baseUrl       = [_baseUrl       copyWithZone:z];
    self->frameworkName = [_frameworkName copyWithZone:z];
  
    if (debugOn) {
      [self debugWithFormat:
	      @"init: '%@' path='%@'\n  URL='%@'\n  framework='%@'",
	      self->name, self->path, [self->baseUrl absoluteString], 
	      self->frameworkName];
    }
    
    if (![self load]) { /* TODO: is this really required? */
      [self release];
      return nil;
    }
  }
  return self;
}

- (id)init {
  [self errorWithFormat:@"called -init on WOComponentDefinition!"];
  [self release];
  return nil;
}

- (void)dealloc {
  [self->template      release];
  [self->name          release];
  [self->path          release];
  [self->baseUrl       release];
  [self->frameworkName release];
  [super dealloc];
}

/* accessors */

- (Class)componentClassForScript:(WOComponentScript *)_script {
  return Nil;
}

- (void)setComponentClass:(Class)_class {
  self->componentClass = _class;
}
- (Class)componentClass {
  if (self->componentClass == Nil)
    self->componentClass = NSClassFromString(self->name);
  
  if (self->componentClass != Nil)
    return self->componentClass;

  if (self->name == nil)
    return Nil;
  
  if ([self->name isAbsolutePath])
	;
  else if ([self->name rangeOfString:@"."].length > 0)
	;
  else if (enableClassLessComponents)
	;
  else {
    [self logWithFormat:@"Note: did not find component class with name '%@'",
	    self->name];
  }
  return Nil;
}
- (NSString *)componentName {
  return self->name;
}

- (WOTemplate *)template {
  return self->template;
}

- (NSString *)path {
  return self->path;
}

- (NSURL *)baseURL {
  return self->baseUrl;
}
- (NSString *)frameworkName {
  return self->frameworkName;
}

/* caching */

- (void)touch {
  self->lastTouch = [DateClass timeIntervalSinceReferenceDate];
}

- (NSTimeInterval)lastTouch {
  return self->lastTouch;
}

/* instantiation */

- (BOOL)_checkComponentClassValidity:(Class)cClass {
#if 0
  /* this make no sense, need -isSubclassOfClass: ..,
     class instances are never isKindOfClass:WOElement ... 
  */
  {
    static Class WOElementClass = Nil;
    if (WOElementClass == Nil) WOElementClass = [WOElement class];
    if (![cClass isKindOfClass:WOElementClass] && cClass != nil) {
      [self warnWithFormat:@"(%s:%i): "
              @"component class %@ is not a subclass of WOElement !",
              __PRETTY_FUNCTION__, __LINE__,
              NSStringFromClass(cClass)];
      return NO;
    }
  }
#endif
  return YES;
}
- (BOOL)_checkComponentValidity:(id)component class:(Class)cClass {
  if (![component isKindOfClass:cClass] && component != nil) {
    [self warnWithFormat:@"(%s:%i): component %@ is not a subclass of "
            @"component class %@ !",
            __PRETTY_FUNCTION__, __LINE__,
            component, NSStringFromClass(cClass)];
    return NO;
  }
  return YES;
}

- (void)_applyWOOVariables:(NSDictionary *)_vars
  onComponent:(WOComponent *)_component 
{
  EOKeyValueUnarchiver *unarchiver;
  NSAutoreleasePool    *pool;
  NSEnumerator *keys;
  NSString     *key;
  
  pool = [[NSAutoreleasePool alloc] init];
  
  unarchiver = 
    [[[EOKeyValueUnarchiver alloc] initWithDictionary:_vars] autorelease];
  [unarchiver setDelegate:_component];
  
  keys = [_vars keyEnumerator];
  while ((key = [keys nextObject]) != nil) {
    id object;
    
    object = [unarchiver decodeObjectForKey:key];
    [_component takeValue:object forKey:key];
    
#if DEBUG_WOO
    [self logWithFormat:@"unarchived %@: %@", key, object];
#endif
  }
  [unarchiver finishInitializationOfObjects];
  [unarchiver awakeObjects];

  [pool release];
}

- (void)_applyWOOVariablesOnComponent:(WOComponent *)_component {
  /* 
     Note: we still need this, as components are not required to load the
           template at all!
  */
  NSString     *wooPath;
  NSDictionary *woo;

  wooPath = [[_component path] stringByAppendingPathExtension:@"woo"];
  if (![[NSFileManager defaultManager] fileExistsAtPath:wooPath])
    return;
  
  if ((woo = [NSDictionary dictionaryWithContentsOfFile:wooPath]) == nil) {
    [self errorWithFormat:@"could not load .woo-file: '%@'", wooPath];
    return;
  }
  
  [self _applyWOOVariables:[woo objectForKey:@"variables"]
        onComponent:_component];
}

- (void)_finishInitializingComponent:(WOComponent *)_component {
  if (self->baseUrl != nil)
    [_component setBaseURL:self->baseUrl];

  if (enableWOOFiles) {
    if (self->template != nil) {
      [self _applyWOOVariables:
              [self->template keyValueArchivedTemplateVariables]
            onComponent:_component];
    }
    else
      [self _applyWOOVariablesOnComponent:_component];
  }
}

- (WOComponent *)instantiateWithResourceManager:(WOResourceManager *)_rm
  languages:(NSArray *)_languages
{
  WOComponent       *component = nil;
  Class             cClass;
  WOComponentScript *script;
  
  cClass = ((script = [self->template componentScript]) != nil) 
    ? NSClassFromString(@"WOScriptedComponent")
    : [self componentClass];
  
  if (cClass == nil) {
    NSString *tmpPath;

    if (enableClassLessComponents) {
      [self debugWithFormat:@"Note: missing class for component: '%@'",
	      [self componentName]];
    }
    else {
      [self logWithFormat:@"Note: missing class for component: '%@'",
	      [self componentName]];
    }
    
    tmpPath = [self->name stringByAppendingPathExtension:@"html"];
    tmpPath = [self->path stringByAppendingPathComponent:tmpPath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:tmpPath]) {
      cClass = [WOComponent class];
    }
    else {
      [self debugWithFormat:@"Note: did not find .html template at path: '%@'",
	      tmpPath];
    }
  }
  
  if (![self _checkComponentClassValidity:cClass]) {
    [self logWithFormat:@"Component Class '%@' is not valid.", cClass];
    return nil;
  }
  
  /* instantiate object (this will call _finishInitializingComponent) */
  
  component = [[cClass alloc] initWithComponentDefinition:self
			      inContext:[[WOApplication application] context]];
  component = [component autorelease];
  if (component == nil)
    return nil;
  
  /* check validity */
  
  if (debugOn)
    [self _checkComponentValidity:component class:cClass];

  if (debugOn) {
    if (![component isKindOfClass:cClass]) {
      [self warnWithFormat:
              @"(%s:%i): component '%@' is not a subclass of "
              @"component class '%@' !",
              __PRETTY_FUNCTION__, __LINE__,
              component, NSStringFromClass(cClass)];
    }
  }
  return component;
}

/* templates */

- (WOTemplateBuilder *)templateBuilderForPath:(NSString *)_path {
  NSString *ext;
  
  if ([_path length] == 0)
    return nil;
  
  ext = [_path pathExtension];
  if ([woxExtensions containsObject:ext]) {
    static WOTemplateBuilder *woxBuilder = nil;
    if (woxBuilder == nil)
      woxBuilder = [[NSClassFromString(@"WOxTemplateBuilder") alloc] init];
    return woxBuilder;
  }
  
  {
    static WOTemplateBuilder *woBuilder = nil;
    if (woBuilder == nil) {
      woBuilder =
        [[NSClassFromString(@"WOWrapperTemplateBuilder") alloc] init];
    }
    return woBuilder;
  }
}

- (WOTemplateBuilder *)templateBuilderForURL:(NSURL *)_url {
  if ([_url isFileURL])
    return [self templateBuilderForPath:[_url path]];
  
  [self logWithFormat:@"only supports file URLs: %@", _url];
  return nil;
}

- (BOOL)load {
  WOTemplateBuilder *builder;
  NSURL *url;

  if (self->path == nil)
    /* a pathless component (a component without a template file) */
    return YES;
  
  /*
    Note: the URL can either point directly to the .wo or .wox file entry or
          it can point to a .lproj inside a .wo (eg Main.wo/English.lproj)
    Note: actually the WOTemplateBuilder only supports file URLs in the moment,
          it just checks the path extension to select the proper builder.
  */
  url = [self->path isKindOfClass:[NSURL class]]
    ? (id)self->path
    : [[[NSURL alloc] initFileURLWithPath:self->path] autorelease];
  
  if (debugOn) [self debugWithFormat:@"url: %@", [url absoluteString]];
  
  // TODO: maybe we should move the builder selection to the resource-manager
  builder = [self templateBuilderForURL:url];
  if (debugOn) [self debugWithFormat:@"builder: %@", builder];
  
  self->template = [builder buildTemplateAtURL:url];
  if (debugOn) [self debugWithFormat:@"template: %@", self->template];
  
  return self->template ? YES : NO;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

/* description */

- (NSString *)description {
  NSMutableString *ms = [NSMutableString stringWithCapacity:64];

  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  if (self->name)    [ms appendFormat:@" name=%@", self->name];
  if (self->path)    [ms appendFormat:@" path=%@", self->path];
  if (self->baseUrl) [ms appendFormat:@" base=%@", self->baseUrl];
  if (self->frameworkName) 
    [ms appendFormat:@" framework=%@", self->frameworkName];
  
  if (!self->template) [ms appendString:@" no-template"];
  [ms appendString:@">"];
  return ms;
}

@end /* WOComponentDefinition */
