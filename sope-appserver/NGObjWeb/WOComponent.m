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

#include <NGObjWeb/WOComponent.h>
#include "WOComponent+private.h"
#include "NSObject+WO.h"
#include <NGObjWeb/WODynamicElement.h>
#include "WOContext+private.h"
#include "WOElement+private.h"
#include <NGObjWeb/WOComponentDefinition.h>
#include <NGObjWeb/WOResourceManager.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOResponse.h>
#include "WOComponentFault.h"
#include "common.h"
#include <NGExtensions/NGBundleManager.h>
#import <EOControl/EOControl.h>
#ifdef MULLE_EO_CONTROL
#import <EOControl/EOKeyValueUnarchiver.h>
#endif
#include <NGExtensions/NSString+Ext.h>

@interface WOContext(ComponentStackCount)
- (unsigned)componentStackCount;
@end

#if APPLE_FOUNDATION_LIBRARY || NeXT_Foundation_LIBRARY
@interface NSObject(Miss)
- (id)notImplemented:(SEL)cmd;
@end
#endif

#if !LIB_FOUNDATION_LIBRARY
#  define NG_USE_KVC_FALLBACK 1
#endif

@implementation WOComponent

static Class NSDateClass      = Nil;
static Class WOComponentClass = Nil;

static NGLogger *perfLogger                    = nil;

static BOOL  debugOn                           = NO;
static BOOL  debugComponentAwake               = NO;
static BOOL  debugTemplates                    = NO;
static BOOL  debugTakeValues                   = NO;
static BOOL  abortOnAwakeComponentInCtxDealloc = NO;
static BOOL  abortOnMissingCtx                 = NO;
static BOOL  wakeupPageOnCreation              = NO;

+ (int)version {
  // TODO: is really v4 for baseURL/cycleContext ivar changes
  return [super version] + 0 /* v2 */;
}
+ (void)initialize {
  NSUserDefaults  *ud;
  NGLoggerManager *lm;
  static BOOL didInit = NO;

  if (didInit) return;
  didInit = YES;
  
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);

  ud = [NSUserDefaults standardUserDefaults];
  lm = [NGLoggerManager defaultLoggerManager];
  
  WOComponentClass    = [WOComponent class];
  NSDateClass         = [NSDate class];
  perfLogger          = [lm loggerForDefaultKey:@"WOProfileElements"];
  debugOn             = [WOApplication isDebuggingEnabled];
  debugComponentAwake = [ud boolForKey:@"WODebugComponentAwake"];
  
  if ((debugTakeValues = [ud boolForKey:@"WODebugTakeValues"]))
    NSLog(@"WOComponent: WODebugTakeValues on.");
  
  abortOnAwakeComponentInCtxDealloc = 
    [ud boolForKey:@"WOCoreOnAwakeComponentInCtxDealloc"];
}

- (id)init {
  if ((self = [super init])) {
    NSNotificationCenter  *nc;
    WOComponentDefinition *cdef;
    
    if ((cdef = (id)self->wocVariables)) { 
      // HACK CD, see WOComponentDefinition
      self->wocVariables = nil;
    }
    
    if (self->wocName == nil)
      self->wocName = [NSStringFromClass([self class]) copy];
    
    [self setCachingEnabled:[[self application] isCachingEnabled]];
    
    /* finish initialization */
    
    if (cdef) {
      [cdef _finishInitializingComponent:self];
      [cdef release]; cdef = nil;
    }
#if !APPLE_FOUNDATION_LIBRARY && !NeXT_Foundation_LIBRARY
    else {
      /* this is triggered by Publisher on MacOSX */
      [self debugWithFormat:
	      @"Note: got no component definition according to HACK CD"];
    }
#endif
    
    /* add to notification center */
    
    nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self selector:@selector(_sessionWillDealloc:)
        name:@"WOSessionWillDeallocate" object:nil];
    
    [nc addObserver:self selector:@selector(_contextWillDealloc:)
        name:@"WOContextWillDeallocate" object:nil];
  }
  return self;
}
- (id)initWithContext:(WOContext *)_ctx {
  [self _setContext:_ctx];
  if ((self = [self init])) {
    if (self->context != nil)
      [self ensureAwakeInContext:self->context];
    else {
      [self warnWithFormat:
              @"no context given to -initWithContext: ..."];
    }
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  [[self->subcomponents allValues]
                        makeObjectsPerformSelector:@selector(setParent:)
                        withObject:nil];
  [self->subcomponents release];
  
  [self->wocClientObject release];
  [self->wocBindings   release];
  [self->wocVariables  release];
  [self->wocName       release];
  [self->wocBaseURL    release];
  [super dealloc];
}

static inline void _setExtraVar(WOComponent *self, NSString *_key, id _obj) {
  if (_obj) {
    if (self->wocVariables == nil)
      self->wocVariables = [[NSMutableDictionary alloc] initWithCapacity:16];
    
    [self->wocVariables setObject:_obj forKey:_key];
  }
  else
    [self->wocVariables removeObjectForKey:_key];
}
static inline id _getExtraVar(WOComponent *self, NSString *_key) {
  return [self->wocVariables objectForKey:_key];
}

/* observers */

- (void)_sessionWillDealloc:(NSNotification *)_notification {
#if DEBUG
  NSAssert(_notification, @"missing valid session arg ...");
#endif

  if (self->session == nil) {
    /* component isn't interested in session anymore anyway ... */
    return;
  }
  if (self->session != [_notification object])
    /* not the component's context ... */
    return;
  
#if DEBUG && 0
  [self debugWithFormat:@"resetting sn/ctx because session will dealloc .."];
#endif
  
  if (self->componentFlags.isAwake) {
    [self warnWithFormat:
            @"session will dealloc, but component 0x%p is awake (ctx=%@) !",
            self, self->context];
    [self _sleepWithContext:self->context];
  }
  
  self->session = nil;
  [self _setContext:nil];
}
- (void)_contextWillDealloc:(NSNotification *)_notification {
#if DEBUG
  NSAssert(_notification, @"missing valid notification arg ...");
#endif
  
  if (self->context == nil)
    /* component isn't interested in context anyway ... */
    return;
  if (![[self->context contextID] isEqualToString:[_notification object]])
    /* not the component's context ... */
    return;
  
#if DEBUG && 0
  [self debugWithFormat:@"resetting sn/ctx because context will dealloc .."];
#endif
  
  if (self->componentFlags.isAwake) {
    /*
      Note: this is not necessarily a problem, no specific reason to log
            the event?!
    */
    [self debugWithFormat:
            @"context %@ will dealloc, but component is awake in ctx %@!",
            [_notification object], [self->context contextID]];
    if (abortOnAwakeComponentInCtxDealloc)
      abort();
    
    [self _sleepWithContext:nil];
  }
  
  [self _setContext:nil];
  self->session = nil;
}

/* awake & sleep */

- (void)awake {
}
- (void)sleep {
  if (debugOn) {
    if (self->componentFlags.isAwake) {
      [self warnWithFormat:
              @"component should not be awake if sleep is called !"];
    }
    if (self->context == nil) {
      [self warnWithFormat:
              @"context should not be nil if sleep is called !"];
    }
  }
  
  self->componentFlags.isAwake = 0;
  [self _setContext:nil];
  self->application = nil;
  self->session     = nil;
}

- (void)ensureAwakeInContext:(WOContext *)_ctx {
#if DEBUG
  NSAssert1(_ctx, @"missing context for awake (component=%@) ...", self);
#endif
  
  if (debugComponentAwake) 
    [self debugWithFormat:@"0x%p ensureAwakeInContext:0x%p", self, _ctx];
  
  /* sanity check */

  if (self->componentFlags.isAwake) {
    if (self->context == _ctx) {
      if (debugComponentAwake) 
	[self debugWithFormat:@"0x%p already awake:0x%p", self, _ctx];
      return;
    }
  }
  
  /* setup globals */
  
  if (self->context     == nil) [self _setContext:_ctx];
  if (self->application == nil) self->application = [_ctx application];
  
  if ((self->session == nil) && [_ctx hasSession])
    self->session = [_ctx session];
  
  self->componentFlags.isAwake = 1;
  [_ctx _addAwakeComponent:self]; /* ensure that sleep is called */
  
  /* awake subcomponents */
  {
    NSEnumerator *children;
    WOComponent  *child;
    
    children = [self->subcomponents objectEnumerator];
    while ((child = [children nextObject]) != nil)
      [child _awakeWithContext:_ctx];
  }
  
  [self awake];
}

- (void)_awakeWithContext:(WOContext *)_ctx {
  if (self->componentFlags.isAwake)
    return;
  
  [self ensureAwakeInContext:_ctx];
}
- (void)_sleepWithContext:(WOContext *)_ctx {
  if (debugComponentAwake) 
    [self debugWithFormat:@"0x%p _sleepWithContext:0x%p", self, _ctx];
  
  if (_ctx != self->context) {
    if ((self->context != nil) && (_ctx != nil)) {
      /* component is active in different context ... */
      [self warnWithFormat:
              @"sleep context mismatch (own=0x%p vs given=0x%p)",
              self->context, _ctx];
      return;
    }
  }
  
  if (self->componentFlags.isAwake) {
    /* 
       Sleep all child components, this is necessary to ensure some ordering
       in the sleep calls. All awake components are put to sleep in any case
       by the WOContext destructor.
    */
    NSEnumerator *children;
    WOComponent *child;
    
    children = [self->subcomponents objectEnumerator];
    self->componentFlags.isAwake = 0;
    
    while ((child = [children nextObject]))
      [child _sleepWithContext:_ctx];
    
    [self sleep];
  }
  [self _setContext:nil];
  self->application = nil;
  self->session     = nil;
}

/* accessors */

- (NSString *)name {
  return self->wocName;
}
- (NSString *)frameworkName {
  NSBundle *cbundle;
  
  cbundle = [NGBundle bundleForClass:[self class]];
  if (cbundle == [NSBundle mainBundle])
    return nil;
  
  return [cbundle bundleName];
}
- (NSString *)path {
  NSArray *languages = nil;
  
#if 0 // the component might not yet be awake !
  languages = [[self context] resourceLookupLanguages];
#endif
  
  return [[self resourceManager]
                pathToComponentNamed:[self name]
                inFramework:[self frameworkName]
                languages:languages];
}
- (void)setBaseURL:(NSURL *)_url {
  ASSIGNCOPY(self->wocBaseURL, _url);
}
- (NSURL *)baseURL {
  NSURL *url;
  
  if (self->wocBaseURL)
    return self->wocBaseURL;
  
  url = [(WOApplication *)[self application] baseURL];
  self->wocBaseURL = 
    [[NSURL URLWithString:@"WebServerResources" relativeToURL:url] copy];
  return self->wocBaseURL;
}

- (NSString *)componentActionURLForContext:(WOContext *)_ctx {
  return [@"/" stringByAppendingString:[self name]];
}

- (id)application {
  if (self->application == nil)
    return (self->application = [WOApplication application]);
  return self->application;
}

- (id)existingSession {
  if (self->session != nil)
    return self->session;
  
  if ([[self context] hasSession])
    return [self session];

  return nil;
}
- (id)session {
  if (self->session == nil) {
    if ((self->session = [[self context] session]) == nil) {
      [self debugWithFormat:@"could not get session object from context %@",
              self->context];
    }
  }
  
  if (self->session == nil)
    [self warnWithFormat:@"missing session for component!"];
  
  return self->session;
}

- (void)_setContext:(WOContext *)_ctx {
  self->context = _ctx;
}
- (WOContext *)context {
  if (self->context != nil)
    return self->context;
  
  [self debugWithFormat:
          @"missing context in component 0x%p (component%s)",
          self,
          self->componentFlags.isAwake ? " is awake" : " is not awake"];
  if (abortOnMissingCtx) {
    [self errorWithFormat:@"aborting, because ctx is missing !"];
    abort();
  }
  
  if (self->application == nil)
    self->application = [WOApplication application];
  [self _setContext:[self->application context]];
  
  if (self->context == nil)
    [self warnWithFormat:@"could not determine context object!"];
  
  return self->context;
}

- (BOOL)hasSession {
  return [[self context] hasSession];
}

- (void)setCachingEnabled:(BOOL)_flag {
  self->componentFlags.reloadTemplates = _flag ? 0 : 1;
}
- (BOOL)isCachingEnabled {
  return (!self->componentFlags.reloadTemplates) ? YES : NO;
}

- (id)pageWithName:(NSString *)_name {
  NSArray           *languages;
  WOResourceManager *rm;
  WOComponent       *component;
  
  languages = [[self context] resourceLookupLanguages];
  rm        = [self resourceManager];

  /* 
     Note: this API is somewhat broken since the component expects the
           -initWithContext: message for initialization yet we pass no
           context ...
  */
  component = [rm pageWithName:_name languages:languages];
  
  // Note: should we call ensureAwakeInContext or is this to early ?
  //       probably the component should be woken up if it enters the ctx.
  //       If we create a page but never render it, we may get a warning 
  //       that a context will dealloc but the page is active (yet not awake)
  // Note: awake is not the same like "has context"! A component can have a
  //       context without being awake - maybe we need an additional method
  //       to hook up a component but the awake list
  if (wakeupPageOnCreation)
    [component ensureAwakeInContext:[self context]];
  return component;
}

- (NSString *)stringForKey:(NSString *)_key
  inTableNamed:(NSString *)_tableName
  withDefaultValue:(NSString *)_default
{
  NSArray *langs;
  IS_DEPRECATED;
  
  langs = [[self context] resourceLookupLanguages];
  
  return [[[self application]
                 resourceManager]
                 stringForKey:_key
                 inTableNamed:_tableName
                 withDefaultValue:_default
                 languages:langs];
}

- (void)setName:(NSString *)_name {
  if (![_name isNotNull])
    [self warnWithFormat:@"setting 'nil' name on component!"];
  
  ASSIGNCOPY(self->wocName, _name);
}

- (void)setBindings:(NSDictionary *)_bindings {
  // this is _very_ private and used by WOComponentReference
  ASSIGNCOPY(self->wocBindings, _bindings);
}
- (NSDictionary *)_bindings {
  // private method
  return self->wocBindings;
}

- (void)setSubComponents:(NSDictionary *)_dictionary {
  ASSIGNCOPY(self->subcomponents, _dictionary);
}
- (NSDictionary *)_subComponents {
  // private method
  return self->subcomponents;
}

- (void)setParent:(WOComponent *)_parent {
  self->parentComponent = _parent;
}
- (id)parent {
  return self->parentComponent;
}

/* language change */

- (void)languageArrayDidChange {
}

/* element name */

- (NSString *)elementID {
  return [self name];
}

/* resources */

- (id<WOActionResults>)redirectToLocation:(id)_loc {
  WOContext  *ctx = [self context];
  WOResponse *r;
  NSString   *target;

  if (_loc == nil)
    return nil;
  
  if ((r = [ctx response]) == nil)
    r = [[[WOResponse alloc] init] autorelease];
  
  if ([_loc isKindOfClass:[NSURL class]])
    target = [_loc absoluteString];
  else {
    _loc = [_loc stringValue];
    if ([_loc isAbsoluteURL])
      target = _loc;
    else if ([_loc isAbsolutePath])
      target = _loc;
    else {
      target = [[ctx request] uri];
      
      // TODO: check whether the algorithm is correct
      if (![target hasSuffix:@"/"])
	target = [target stringByDeletingLastPathComponent];
      target = [target stringByAppendingPathComponent:_loc];
    }
  }
  
  if (target == nil)
    return nil;
  [r setStatus:302 /* moved */];
  [r setHeader:target forKey:@"location"];
  return r;
}

- (void)setResourceManager:(WOResourceManager *)_rm {
  _setExtraVar(self, @"__worm", _rm);
}
- (WOResourceManager *)resourceManager {
  WOResourceManager *rm;
  WOComponent *p;
  
  if ((rm = _getExtraVar(self, @"__worm")))
    return rm;
  
  /* ask parent component ... */
  if ((p = [self parent])) {
    NSAssert2(p != self, @"parent component == component !!! (%@ vs %@)",
              p, self);
    if ((rm = [p resourceManager]))
      return rm;
  }
  
  /* ask application ... */
  return [[self application] resourceManager];
}

- (NSString *)pathForResourceNamed:(NSString *)_name ofType:(NSString *)_ext {
  NSFileManager *fm;
  NSEnumerator  *languages;
  NSString      *language;
  BOOL          isDirectory = NO;
  NSString      *cpath;
  
  if (_ext) _name = [_name stringByAppendingPathExtension:_ext];

  if ((cpath = [self path]) == nil) {
    [self warnWithFormat:@"no path set in component %@", [self name]];
    return nil;
  }
  
  fm = [NSFileManager defaultManager];
  if (![fm fileExistsAtPath:cpath isDirectory:&isDirectory]) {
    [self warnWithFormat:@"component directory %@ does not exist !", cpath];
    return nil;
  }
  if (!isDirectory) {
    [self warnWithFormat:@"component path %@ is not a directory !", cpath];
    return nil;
  }
  
  /* check in language projects */

  languages = [self hasSession]
    ? [[(WOSession *)[self session] languages] objectEnumerator]
    : [[[[self context] request] browserLanguages] objectEnumerator];
  
  while ((language = [languages nextObject]) != nil) {
    language = [language stringByAppendingPathExtension:@"lproj"];
    language = [cpath stringByAppendingPathComponent:language];
    language = [language stringByAppendingPathExtension:_name];
    
    if ([fm fileExistsAtPath:language])
      return language;
  }
  
  /* check in component */
  cpath = [cpath stringByAppendingPathComponent:_name];
  if ([fm fileExistsAtPath:cpath])
    return cpath;

  return nil;
}

/* template */

+ (WOElement *)templateWithHTMLString:(NSString *)_html
  declarationString:(NSString *)_wod
  languages:(NSArray *)_languages
{
  return [self notImplemented:_cmd];
}
- (WOElement *)templateWithHTMLString:(NSString *)_html
  declarationString:(NSString *)_wod
{
  IS_DEPRECATED;
  return [[self class] templateWithHTMLString:_html
		       declarationString:_wod
		       languages:[(WOSession *)[self session] languages]];
}

- (WOElement *)templateWithName:(NSString *)_name {
  WOResourceManager *resourceManager;
  NSArray           *languages;
  WOElement         *tmpl;
  
  if ((resourceManager = [self resourceManager]) == nil) {
    [self errorWithFormat:@"%s: could not determine resource manager !",
            __PRETTY_FUNCTION__];
    return nil;
  }
  
  languages = [[self context] resourceLookupLanguages];
  tmpl      = [resourceManager templateWithName:_name languages:languages];

  if (debugTemplates) [self debugWithFormat:@"found template: %@", tmpl];
  return tmpl;
}

- (void)setTemplate:(id)_template {
  /*
    WO has private API for this:
      - (void)setTemplate:(WOElement *)template;
    As mentioned in the OmniGroup WO mailing list ...
  */
  _setExtraVar(self, @"__wotemplate", _template);
}
- (WOElement *)_woComponentTemplate {
  WOElement *element;
  
  // TODO: move to ivar?
  if ((element = _getExtraVar(self, @"__wotemplate")) != nil)
    return element;
  
  return [self templateWithName:[self name]];
}

/* child components */

- (WOComponent *)childComponentWithName:(NSString *)_name {
  id child;
  
  child = [self->subcomponents objectForKey:_name];
  if ([child isComponentFault]) {
    NSMutableDictionary *tmp;
    
    child = [child resolveWithParent:self];
    if (child == nil) {
      [self warnWithFormat:@"Could not resolve component fault: %@", _name];
      return nil;
    }
    
    tmp = [self->subcomponents mutableCopy];
    [tmp setObject:child forKey:_name];
    [self->subcomponents release]; self->subcomponents = nil;
    self->subcomponents = [tmp copy];
    [tmp release]; tmp = nil;
  }
  return child;
}

- (BOOL)synchronizesVariablesWithBindings {
  return [self isStateless] ? NO : YES;
}

- (void)setValue:(id)_value forBinding:(NSString *)_name {
  WOComponent      *parent;
  WOContext        *ctx;
  WODynamicElement *content;
  
  ctx     = [self context];
  parent  = [ctx parentComponent];
  content = [ctx componentContent];
  
  if (parent == nil) {
    parent = [self parent];
    [self warnWithFormat:@"tried to set value of binding '%@' in component "
            @"'%@' without parent component (parent is '%@') !",
            _name, [self name], [parent name]];
  }
  
  [[self    retain] autorelease];
  [[content retain] autorelease];
  
  WOContext_leaveComponent(ctx, self);
  [[self->wocBindings objectForKey:_name] setValue:_value inComponent:parent];
  WOContext_enterComponent(ctx, self, content);
}
- (id)valueForBinding:(NSString *)_name {
  WOComponent      *parent;
  WOContext        *ctx;
  WODynamicElement *content;
  id value;
  
  ctx     = [self context];
  parent  = [ctx parentComponent];
  content = [ctx componentContent];
  
  if (parent == nil) {
    parent = [self parent];
    [self warnWithFormat:@"tried to retrieve value of binding '%@' in"
            @" component '%@' without parent component (parent is '%@') !",
            _name, [self name], [parent name]];
  }
  
  [[self    retain] autorelease];
  [[content retain] autorelease];
  
  WOContext_leaveComponent(ctx, self);
  value = [[self->wocBindings objectForKey:_name] valueInComponent:parent];
  WOContext_enterComponent(ctx, self, content);
  
  return value;
}

- (BOOL)hasBinding:(NSString *)_name {
  return ([self->wocBindings objectForKey:_name] != nil) ? YES : NO;
}

- (BOOL)canSetValueForBinding:(NSString *)_name {
  WOAssociation *binding;

  if ((binding = [self->wocBindings objectForKey:_name]) == nil)
    return NO;
  
  return [binding isValueSettable];
}
- (BOOL)canGetValueForBinding:(NSString *)_name {
  WOAssociation *binding;

  if ((binding = [self->wocBindings objectForKey:_name]) == nil)
    return NO;

  return YES;
}

- (id)performParentAction:(NSString *)_name {
  WOContext        *ctx;
  WOComponent      *parent;
  WODynamicElement *content;
  SEL              action;
  id               result   = nil;

  ctx     = [self context];
  parent  = [ctx parentComponent];
  content = [ctx componentContent];
  action  = NSSelectorFromString(_name);
  
  if (parent == nil)  return nil;
  if (action == NULL) return nil;
  
  NSAssert(parent != self, @"parent component equals current component");

  if (![parent respondsToSelector:action]) {
    [self debugWithFormat:@"parent %@ doesn't respond to %@",
            [parent name], _name];
    return nil;
  }

  self = [self retain];
  NS_DURING {
    WOContext_leaveComponent(ctx, self);
    *(&result) = [parent performSelector:action];
    WOContext_enterComponent(ctx, self, content);
  }
  NS_HANDLER {
    [self release];
    [localException raise];
  }
  NS_ENDHANDLER;
  
  [self release];
  return result;
}

/* OWResponder */

- (BOOL)shouldTakeValuesFromRequest:(WORequest *)_rq inContext:(WOContext*)_c {
  if (debugTakeValues)
    [self debugWithFormat:@"%s: default says no.", __PRETTY_FUNCTION__];
  return NO;
}

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOElement *template = nil;
  
  if (debugTakeValues) 
    [self debugWithFormat:@"take values from rq 0x%p", _req];
  
  NSAssert1(self->componentFlags.isAwake,
            @"component %@ is not awake !", self);
  
  [self _setContext:_ctx];
  template = [self _woComponentTemplate];
  
  if (template == nil) {
    if (debugTakeValues) 
      [self debugWithFormat:@"cannot take values, component has no template!"];
    return;
  }
  
  if (template->takeValues) {
    template->takeValues(template,
			 @selector(takeValuesFromRequest:inContext:),
			 _req, _ctx);
  }
  else
    [template takeValuesFromRequest:_req inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOElement *template = nil;
  id result = nil;
  
  NSAssert1(self->componentFlags.isAwake, @"component %@ is not awake!", self);

  [self _setContext:_ctx];
  template = [self _woComponentTemplate];
  result = [template invokeActionForRequest:_req inContext:_ctx];
  return result;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOElement *template = nil;
  NSTimeInterval st = 0.0;
  
  NSAssert1(self->componentFlags.isAwake,
            @"component %@ is not awake !", self);
  if (debugOn) {
    if (self->context != _ctx) {
      [self debugWithFormat:@"%s: component ctx != ctx (%@ vs %@)",
              __PRETTY_FUNCTION__, self->context, _ctx];
    }
  }
  
  [self _setContext:_ctx];
  
  if ((template = [self _woComponentTemplate]) == nil) {
    if (debugOn) {
      [self debugWithFormat:@"component has no template (rm=%@).",
              [self resourceManager]];
    }
    return;
  }
  
  if (perfLogger)
    st = [[NSDateClass date] timeIntervalSince1970];
    
  if (template->appendResponse) {
    template->appendResponse(template,
                             @selector(appendToResponse:inContext:),
                             _response, _ctx);
  }
  else
    [template appendToResponse:_response inContext:_ctx];

  if (perfLogger) {
    NSTimeInterval diff;
    int i;
    diff = [[NSDateClass date] timeIntervalSince1970] - st;
#if 1
    for (i = [_ctx componentStackCount]; i >= 0; i--)
      printf("  ");
#endif
    [perfLogger logWithFormat:@"Template %@ (comp %@): %0.3fs\n",
                  [_ctx elementID],
                  [self name],
                  diff];
  }
}
  
/* WOActionResults */

- (WOResponse *)generateResponse {
  WOResponse *response = nil;
  WOContext  *ctx = nil;
  NSString   *ctxID;
  
  ctx      = [self context];
  ctxID    = [ctx  contextID];
  response = [WOResponse responseWithRequest:[ctx request]];
  
  if (ctxID == nil) {
    [self debugWithFormat:@"missing ctx-id for context %@", ctx];
    ctxID = @"noctx";
  }
  
  [ctx deleteAllElementIDComponents];
  [ctx appendElementIDComponent:ctxID];
  
  WOContext_enterComponent(ctx, self, nil);
  [self appendToResponse:response inContext:ctx];
  WOContext_leaveComponent(ctx, self);
  
  [ctx deleteLastElementIDComponent];

  ctx = nil;

#if 0
  if ([[[ctx request] method] isEqualToString:@"HEAD"])
    [response setContent:[NSData data]];
#endif
  
  /* HTTP/1.1 caching directive, prevents browser from caching dynamic pages */
  if ([[ctx application] isPageRefreshOnBacktrackEnabled])
    [response disableClientCaching];
  
  return response;
}

/* coding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  BOOL doesReloadTemplates = self->componentFlags.reloadTemplates;

  [_coder encodeObject:self->wocBindings];
  [_coder encodeObject:self->wocName];
  [_coder encodeConditionalObject:self->parentComponent];
  [_coder encodeObject:self->subcomponents];
  [_coder encodeObject:self->wocVariables];
  [_coder encodeConditionalObject:self->session];
  [_coder encodeValueOfObjCType:@encode(BOOL) at:&doesReloadTemplates];
}
- (id)initWithCoder:(NSCoder *)_decoder {
  if ((self = [super init])) {
    BOOL doesReloadTemplates = YES;

    self->wocBindings     = [[_decoder decodeObject] retain];
    self->wocName         = [[_decoder decodeObject] retain];
    self->parentComponent = [_decoder decodeObject]; // non-retained
    self->subcomponents   = [[_decoder decodeObject] retain];
    self->wocVariables    = [[_decoder decodeObject] retain];
    self->session         = [_decoder decodeObject]; // non-retained
    
    [_decoder decodeValueOfObjCType:@encode(BOOL) at:&doesReloadTemplates];
    [self setCachingEnabled:!doesReloadTemplates];
  }
  return self;
}

/* component variables */

- (BOOL)isStateless {
  return NO;
}
- (void)reset {
  [self->wocVariables removeAllObjects];
}

- (void)setObject:(id)_obj forKey:(NSString *)_key {
  _setExtraVar(self, _key, _obj);
}
- (id)objectForKey:(NSString *)_key {
  return _getExtraVar(self, _key);
}
- (NSDictionary *)variableDictionary {
  return self->wocVariables;
}

- (BOOL)logComponentVariableCreations {
  /* only if we have a subclass, we can store values in ivars ... */
  return (self->isa != WOComponentClass) ? YES : NO;
}

#if !NG_USE_KVC_FALLBACK /* only override on libFoundation */

- (void)takeValue:(id)_value forKey:(NSString *)_key {
  if (WOSetKVCValueUsingMethod(self, _key, _value)) {
    // method is used
    return;
  }
  if (WOGetKVCGetMethod(self, _key) == NULL) {
    if (_value == nil) {
#if 0
      [self debugWithFormat:
              @"storing <nil> value in component variable %@", _key];
#endif
      
      if ([self->wocVariables objectForKey:_key])
        [self setObject:nil forKey:_key];
      
      return;
    }
#if DEBUG
    if ([self logComponentVariableCreations]) {
      /* only if we have a subclass, we can store values in ivars ... */
      if (![[self->wocVariables objectForKey:_key] isNotNull]) {
        [self debugWithFormat:
                @"Created component variable (class=%@): '%@'.",
                NSStringFromClass(self->isa), _key];
      }
    }
#endif
    
    [self setObject:_value forKey:_key];
    return;
  }

  [self debugWithFormat:
          @"value %@ could not set via method or KVC "
          @"(self responds to %@: %s).",
	        _key, _key,
          [self respondsToSelector:NSSelectorFromString(_key)] ? "yes" : "no"];
#if 0
  return NO;
#endif
}
- (id)valueForKey:(NSString *)_key {
  id value;
  
  if ((value = WOGetKVCValueUsingMethod(self, _key)))
    return value;

#if DEBUG && 0
  [self debugWithFormat:@"KVC: accessed the component variable %@", _key];
#endif
  if ((value = [self objectForKey:_key]) != nil)
    return value;
  
  return nil;
}

#else /* use fallback methods on other Foundation libraries */

- (void)setValue:(id)_value forUndefinedKey:(NSString *)_key {
  // Note: this is not used on libFoundation, insufficient KVC implementation

#if DEBUG && 0
  [self logWithFormat:@"KVC: set the component variable %@: %@",_key,_value];
#endif
  
  if (_value == nil) {
#if 0
    [self debugWithFormat:
	    @"storing <nil> value in component variable %@", _key];
#endif
    
    if ([self->wocVariables objectForKey:_key] !=  nil)
      [self setObject:nil forKey:_key];
      
    return;
  }
  
#if DEBUG
  if ([self logComponentVariableCreations]) {
    /* only if we have a subclass, we can store values in ivars ... */
    if (![[self->wocVariables objectForKey:_key] isNotNull]) {
      [self debugWithFormat:@"Created component variable (class=%@): '%@'.", 
	            NSStringFromClass(self->isa), _key];
    }
  }
#endif
  [self setObject:_value forKey:_key];
}

- (id)valueForUndefinedKey:(NSString *)_key {
  // Note: this is not used on libFoundation, insufficient KVC implementation
#if DEBUG && 0
  [self debugWithFormat:@"KVC: accessed the component variable %@", _key];
#endif
  
  return [self objectForKey:_key];
}

- (void)handleTakeValue:(id)_value forUnboundKey:(NSString *)_key {
  // deprecated: pre-Panther method
  [self setValue:_value forUndefinedKey:_key];
}
- (id)handleQueryWithUnboundKey:(NSString *)_key {
  // deprecated: pre-Panther method
  return [self valueForUndefinedKey:_key];
}

- (void)unableToSetNilForKey:(NSString *)_key {
  // TODO: should we call setValue:NSNull forKey?
  [self errorWithFormat:@"unable to set 'nil' for key: '%@'", _key];
}

#endif /* KVC */

- (void)validationFailedWithException:(NSException *)_exception
  value:(id)_value keyPath:(NSString *)_keyPath
{
  [self warnWithFormat:
          @"formatter failed for value %@ (keyPath=%@): %@",
          _value, _keyPath, [_exception reason]];
}

/* logging */

- (BOOL)isEventLoggingEnabled {
  return YES;
}

- (BOOL)isDebuggingEnabled {
  return debugOn;
}
- (NSString *)loggingPrefix {
  NSString *n;
  
  n = [self name];
  if ([n length] == 0)
    return @"<component without name>";
  
  return n;
}

/* woo/plist unarchiving */

- (id)unarchiver:(EOKeyValueUnarchiver *)_archiver 
  objectForReference:(id)_keyPath
{
  /* 
     This is used when a .woo file is unarchived. Eg datasources contain
     bindings in the archive:
     
       editingContext = session.defaultEditingContext;
     
     The binding will evaluate against the component during loading.
  */
  return [self valueForKeyPath:_keyPath];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  // TODO: find out who triggers this
  return [self retain];
}

/* description */

- (NSString *)description {
  NSMutableString *str;
  id tmp;
  
  str = [NSMutableString stringWithCapacity:128];
  [str appendFormat:@"<0x%p[%@]: name=%@", self,
         NSStringFromClass([self class]), [self name]];

  if (self->parentComponent)
    [str appendFormat:@" parent=%@", [self->parentComponent name]];
  if (self->subcomponents)
    [str appendFormat:@" #subs=%i", [self->subcomponents count]];
  
  if (self->componentFlags.isAwake)
    [str appendFormat:@" awake=0x%p", self->context];
  else if (self->context == nil)
    [str appendString:@" no-ctx"];
  
  if ((tmp = _getExtraVar(self, @"__worm")))
    [str appendFormat:@" rm=%@", tmp];
  
  [str appendString:@">"];
  return str;
}

/* Statistics */

- (NSString *)descriptionForResponse:(WOResponse *)_response
  inContext:(WOContext *)_context
{
  return [self name];
}

/* AdvancedBindingAccessors */

- (void)setUnsignedIntValue:(unsigned)_value forBinding:(NSString *)_name {
  [self setValue:[NSNumber numberWithUnsignedInt:_value] forBinding:_name];
}
- (unsigned)unsignedIntValueForBinding:(NSString *)_name {
  return [[self valueForBinding:_name] unsignedIntValue];
}

- (void)setIntValue:(int)_value forBinding:(NSString *)_name {
  [self setValue:[NSNumber numberWithInt:_value] forBinding:_name];
}
- (int)intValueForBinding:(NSString *)_name {
  return [[self valueForBinding:_name] intValue];
}

- (void)setBoolValue:(BOOL)_value forBinding:(NSString *)_name {
  [self setValue:[NSNumber numberWithBool:_value] forBinding:_name];
}
- (BOOL)boolValueForBinding:(NSString *)_name {
  return [[self valueForBinding:_name] boolValue];
}

#if !NG_USE_KVC_FALLBACK
- (id)handleQueryWithUnboundKey:(NSString *)_key {
  [self logWithFormat:@"query for unbound key: %@", _key];
  return [super handleQueryWithUnboundKey:_key];
}
#endif

@end /* WOComponent */
