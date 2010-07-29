/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#include <NGObjWeb/WOContext.h>
#include "NSObject+WO.h"
#include "WOComponent+private.h"
#include "WOContext+private.h"
#include "WOApplication+private.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOSession.h>
#include <Foundation/NSNull.h>
#include "WOElementID.h"
#include "common.h"
#include <time.h>


@interface WOContext(Privates5)
- (NSArray *)_componentStack;
@end

@interface WOComponent(Cursors)
- (void)pushCursor:(id)_obj;
- (id)popCursor;
- (id)cursor;
@end

static Class WOAppClass = Nil;

@implementation WOContext

+ (int)version {
  return 9;
}

static Class    WOContextClass       = Nil;
static Class    MutableStrClass      = Nil;
static int      contextCount         = 0;
static int      logComponents        = -1;
static int      relativeURLs         = -1;
static BOOL     debugOn              = NO;
static int      debugCursor          = -1;
static BOOL     debugComponentAwake  = NO;
static BOOL     testNSURLs           = NO;
static BOOL     newCURLStyle         = NO;
static NSString *WOApplicationSuffix = nil;
static NSURL    *redirectURL         = nil;

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;
  NSString       *cn;
  NSString       *url;

  if (didInit) return;

  didInit = YES;

  ud = [NSUserDefaults standardUserDefaults];

  if (WOAppClass == Nil)
    WOAppClass = [WOApplication class];
  if (MutableStrClass == Nil)
    MutableStrClass = [NSMutableString class];
  
  cn             = [ud stringForKey:@"WOContextClass"];
  WOContextClass = NSClassFromString(cn);
  NSAssert1(WOContextClass != Nil,
            @"Couldn't instantiate WOContextClass (%@)!", cn);

  logComponents = [[ud objectForKey:@"WOLogComponents"] boolValue] ? 1 : 0;
  relativeURLs  = [[ud objectForKey:@"WOUseRelativeURLs"] boolValue]? 1 : 0;
  debugCursor         = [ud boolForKey:@"WODebugCursor"] ? 1 : 0;
  debugComponentAwake = [ud boolForKey:@"WODebugComponentAwake"];
  WOApplicationSuffix = [[ud stringForKey:@"WOApplicationSuffix"] copy];
  url                 = [ud stringForKey:@"WOApplicationRedirectURL"];
  if (url != nil)
    redirectURL       = [NSURL URLWithString: url];
}

+ (id)contextWithRequest:(WORequest *)_r {
  return [[(WOContext *)[WOContextClass alloc] initWithRequest:_r] autorelease];
}

- (id)initWithRequest:(WORequest *)_request {
  if ((self = [super init])) {
    char buf[24];
    self->qpJoin = @"&amp;";
    
    sprintf(buf, "%03x%08x%08x", ++contextCount, (int)time(NULL),
	    (unsigned int)(unsigned long)self);
    self->ctxId = [[NSString alloc] initWithCString:buf];
    
    /* per default close tags in XML style */
    self->wcFlags.xmlStyleEmptyElements = 1;
    self->wcFlags.allowEmptyAttributes  = 0;
    
    self->elementID = [[WOElementID alloc] init];
    self->awakeComponents = [[NSMutableSet alloc] initWithCapacity:64];
    
    self->request  = [_request retain];
    self->response = [[WOResponse responseWithRequest:_request] retain];

    if (_request && [_request isFragmentIDInRequest]) {
      [self setFragmentID:[_request fragmentID]];
      [self disableRendering];
    }
  }
  return self;
}

+ (id)context {
  return [[[self alloc] init] autorelease];
}
- (id)init {
  return [self initWithRequest:nil];
}

/* components */

- (void)_addAwakeComponent:(WOComponent *)_component {
  if (_component == nil)
    return;

  if ([self->awakeComponents containsObject:_component])
    return;

  /* wake up component */
  if (debugComponentAwake)
    [self logWithFormat:@"mark component awake: %@", _component];
  
  [self->awakeComponents addObject:_component];
}

- (void)_awakeComponent:(WOComponent *)_component {
  if (_component == nil)
    return;

  if ([self->awakeComponents containsObject:_component])
    return;

  /* wake up component */
  if (debugComponentAwake)
    [self logWithFormat:@"awake component: %@", _component];
    
  [_component _awakeWithContext:self];

  [self _addAwakeComponent:_component];
  
  if (debugComponentAwake)
    [self logWithFormat:@"woke up component: %@", _component];
}

- (void)sleepComponents {
  NSEnumerator *e;
  WOComponent  *component;
  BOOL sendSleepToPage;

  if (debugComponentAwake) {
    [self logWithFormat:@"sleep %d components ...", 
	    [self->awakeComponents count]];
  }
  
  sendSleepToPage = YES;
  e = [self->awakeComponents objectEnumerator];
  while ((component = [e nextObject])) {
    if (debugComponentAwake)
      [self logWithFormat:@"  sleep component: %@", component];
    [component _sleepWithContext:self];
    if (component == self->page) sendSleepToPage = NO;
  }
  if (sendSleepToPage && (self->page != nil)) {
    if (debugComponentAwake)
      [self logWithFormat:@"  sleep page: %@", self->page];
    [self->page _sleepWithContext:self];
  }
  
  if (debugComponentAwake) {
    [self logWithFormat:@"done sleep %d components.", 
	    [self->awakeComponents count]];
  }
  [self->awakeComponents removeAllObjects];
}

#if WITH_DEALLOC_OBSERVERS
- (void)addDeallocObserver:(id)_observer {
  if (_observer == NULL) return;
  
  /* check array */
  if (self->deallocObservers == NULL) {
    self->deallocObservers        = calloc(8, sizeof(id));
    self->deallocObserverCount    = 0;
    self->deallocObserverCapacity = 8;
  }

  /* check capacity */
  if (self->deallocObserverCapacity == self->deallocObserverCount) {
    /* need to increase array */
    id *newa;
    
    newa = calloc(self->deallocObserverCapacity * 2, sizeof(id));
    memcpy(newa, self->deallocObservers, 
	   sizeof(id) * self->deallocObserverCount);
    free(self->deallocObservers);
    self->deallocObservers = newa;
    self->deallocObserverCapacity *= 2;
  }
  
  /* register */
  self->deallocObservers[self->deallocObserverCount] = _observer;
  self->deallocObserverCount++;
}
- (void)removeDeallocObserver:(id)_observer {
  /* the observer currently will only grow (this should be OK for WOContext) */
  register int i;
  if (_observer == NULL) return;
  
  for (i = self->deallocObserverCount - 1; i >= 0; i++) {
    if ((self->deallocObservers[i]) == _observer)
      self->deallocObservers[i] = NULL;
  }
}
#endif

- (void)dealloc {
  [self sleepComponents];
  
#if WITH_DEALLOC_OBSERVERS
  if (self->deallocObservers) {
    register int i;
    
#if DEBUG
    printf("%s: dealloc observer capacity: %i\n",
           __PRETTY_FUNCTION__, self->deallocObserverCapacity);
#endif
    
    /* GC!! process in reverse order ... */
    for (i = self->deallocObserverCount - 1; i >= 0; i++)
      [self->deallocObservers[i] _objectWillDealloc:self];
    
    free(self->deallocObservers);
    self->deallocObservers = NULL;
  }
#endif

  [self->activeUser            release];
  [self->rootURL               release];
  [self->objectPermissionCache release];
  [self->traversalStack        release];
  [self->clientObject          release];
  [self->objectDispatcher      release];
  [self->soRequestType         release];
  [self->pathInfo              release];
  
  [[NSNotificationCenter defaultCenter]
                         postNotificationName:@"WOContextWillDeallocate"
                         object:self->ctxId];
  
  { /* release component stack */
    int i;
    for (i = (self->componentStackCount - 1); i >= 0; i--) {
      [self->componentStack[i] release]; self->componentStack[i] = nil;
      [self->contentStack[i]   release]; self->contentStack[i]   = nil;
    }
  }
  
  [self->urlPrefix         release];
  [self->elementID         release];
  [self->reqElementID      release];
  [self->fragmentID        release];
  [self->activeFormElement release];
  [self->page              release];
  [self->awakeComponents   release];
  [self->appURL            release];
  [self->baseURL           release];
  [self->session           release];
  [self->variables         release];
  [self->request           release];
  [self->response          release];
  [self->ctxId             release];
  [super dealloc];
}

/* session */

- (void)setSession:(WOSession *)_session {
  ASSIGN(self->session, _session);
}
- (void)setNewSession:(WOSession *)_session {
  [self setSession:_session];
  self->wcFlags.hasNewSession = 1;
}

- (id)session {
  /* in WO4 -session creates a new session if none is associated */
  
  if (self->session == nil) {
    [[self application] _initializeSessionInContext:self];
    
    if (self->session == nil) {
      [self logWithFormat:@"%s: missing session for context ..",
              __PRETTY_FUNCTION__];
    }
  }
  
  return self->session;
}

- (NSString *)contextID {
  NSAssert(self->ctxId, @"context without id !");
#if 0
  // in WO4 -contextID returns nil if there is no associated session
  return self->session ? self->ctxId : nil;
#else
  /*
    IMHO the above isn't true, otherwise session cannot be automagically
    generated!
    
    TODO: well, we might want to generate component URLs which work without
          a session - at least in theory the ID tree should be stable even
          without a session (and if proper uids are used for dynamic content).
          eg this would be quite useful for SOPE.
  */
  return self->ctxId;
#endif
}

- (WORequest *)request {
  return self->request;
}
- (WOResponse *)response {
  return self->response;
}

- (BOOL)hasSession {
  return (self->session != nil) ? YES : NO;
}
- (BOOL)hasNewSession {
  if (!self->wcFlags.hasNewSession)
    return NO;
  return [self hasSession];
}

- (BOOL)savePageRequired {
  return self->wcFlags.savePageRequired ? YES : NO;
}

/* cursors */

- (void)pushCursor:(id)_obj {
  if (debugCursor == -1) {
    debugCursor = [[NSUserDefaults standardUserDefaults]
                                   boolForKey:@"WODebugCursor"]
      ? 1 : 0;
  }
  
  if (debugCursor) [self logWithFormat:@"enter cursor: %@", _obj];
  [[self component] pushCursor:_obj];
}

- (id)popCursor {
  if (debugCursor) [self logWithFormat:@"leave cursor ..."];
  return [[self component] popCursor];
}

- (id)cursor {
  return [(id <WOPageGenerationContext>)[self component] cursor];
}

/* components */

- (id)component {
  return (self->componentStackCount > 0)
    ? self->componentStack[self->componentStackCount - 1]
    : nil;
}

- (void)setPage:(WOComponent *)_page {
  [_page ensureAwakeInContext:self];
  ASSIGN(self->page, _page);
}
- (id)page {
  return self->page;
}

void WOContext_enterComponent
(WOContext *self, WOComponent *_component, WOElement *_content)
{
  WOComponent *parent = nil;
#if DEBUG
  NSCAssert(_component, @"missing component to enter ...");
#endif
  
  if (logComponents) {
    [self->application logWithFormat:@"enter component %@ (content=%@) ..",
                         [_component name], _content];
  }
  
  parent = self->componentStackCount > 0
    ? self->componentStack[self->componentStackCount - 1]
    : nil;
  
  NSCAssert2(self->componentStackCount < NGObjWeb_MAX_COMPONENT_NESTING_DEPTH,
             @"exceeded maximum component nesting depth (%i):\n%@",
             NGObjWeb_MAX_COMPONENT_NESTING_DEPTH,
             [self _componentStack]);
  self->componentStack[(int)self->componentStackCount] = [_component retain];
  self->contentStack[(int)self->componentStackCount]   = [_content   retain];
  self->componentStackCount++;
  
  [self _awakeComponent:_component];
  
  if (parent) {
    if ([_component synchronizesVariablesWithBindings])
      WOComponent_syncFromParent(_component, parent);
  }
}
void WOContext_leaveComponent(WOContext *self, WOComponent *_component) {
  WOComponent *parent = nil;

  BEGIN_PROFILE;

  parent = (self->componentStackCount > 1)
    ? self->componentStack[self->componentStackCount - 2]
    : nil;
  
  if (parent) {
    if ([_component synchronizesVariablesWithBindings])
      WOComponent_syncToParent(_component, parent);
  }

  PROFILE_CHECKPOINT("after sync");
  
  /* remove last object */
  self->componentStackCount--;
  NSCAssert(self->componentStackCount >= 0,
            @"tried to pop component from empty component stack !");
  [self->componentStack[(int)self->componentStackCount] release];
  self->componentStack[(int)self->componentStackCount] = nil;
  [self->contentStack[(int)self->componentStackCount] release];
  self->contentStack[(int)self->componentStackCount] = nil;
  
  if (logComponents)
    [self->application logWithFormat:@"left component %@.", [_component name]];

  END_PROFILE;
}

- (void)enterComponent:(WOComponent *)_comp content:(WOElement *)_content {
  WOContext_enterComponent(self, _comp, _content);
}
- (void)leaveComponent:(WOComponent *)_component {
  BEGIN_PROFILE;
  WOContext_leaveComponent(self, _component);
  END_PROFILE;
}

- (WOComponent *)parentComponent {
  return (self->componentStackCount > 1)
    ? self->componentStack[(int)self->componentStackCount - 2]
    : nil;
}

- (WODynamicElement *)componentContent {
  return (self->componentStackCount > 0)
    ? self->contentStack[(int)self->componentStackCount - 1]
    : nil;
}

- (unsigned)componentStackCount {
  return self->componentStackCount;
}
- (NSArray *)_componentStack {
  return [NSArray arrayWithObjects:self->componentStack
                  count:self->componentStackCount];
}

/* URLs */

- (NSURL *)serverURL {
  WORequest *rq;
  NSString  *serverURL;
  NSURL     *url;
  NSString  *host;
    
  if ((rq = [self request]) == nil) {
    [self logWithFormat:@"missing request in -baseURL call .."];
    return nil;
  }
  
  if (redirectURL != nil) {
    // Use URL from user defaults (WOApplicationRedirectURL)
    return redirectURL;
  }
  
  if ((serverURL = [rq headerForKey:@"x-webobjects-server-url"]) == nil) {
    if ((host = [rq headerForKey:@"host"]))
      serverURL = [@"http://" stringByAppendingString:host];
  }
  else {
    // TODO: fix that (host is also broken for example with SOUP)
    /* sometimes the port is broken in the server URL ... */
    if ([serverURL hasSuffix:@":0"]) { // bad bad bad
      if ((host = [rq headerForKey:@"host"])) {
        NSString *scheme;
        scheme    = [serverURL hasPrefix:@"https://"] ? @"https://":@"http://";
        serverURL = [scheme stringByAppendingString:host];
      }
    }
  }
  
  if ([serverURL length] == 0) {
    [self errorWithFormat:@"could not find x-webobjects-server-url header !"];
    return nil;
  }
  
  if ((url = [NSURL URLWithString:serverURL]) == nil) {
    [self logWithFormat:@"could not construct NSURL from string '%@'",
            serverURL];
    return nil;
  }
  return url;
}

- (NSURL *)baseURL {
  WORequest *rq;
  NSURL     *serverURL;

  if (self->baseURL) 
    return self->baseURL;
    
  if ((rq = [self request]) == nil) {
    [self logWithFormat:@"missing request in -baseURL call .."];
    return nil;
  }
    
  serverURL = [self serverURL];
  self->baseURL =
    [[NSURL URLWithString:[rq uri] relativeToURL:serverURL] retain];
    
  if (self->baseURL == nil) {
    [self logWithFormat:
	    @"could not construct NSURL for uri '%@' and base '%@' ...",
	    [rq uri], serverURL];
  }
  return self->baseURL;
}

- (NSURL *)applicationURL {
  NSString *s;
  
  if (self->appURL != nil)
    return self->appURL;

  // TODO: we should ensure that the suffix (.woa) is in the URL
  
  s = [self->request adaptorPrefix];
  if ([s length] > 0) {
    s = [[[s stringByAppendingString:@"/"]
             stringByAppendingString:[self->request applicationName]]
             stringByAppendingString:@"/"];
  }
  else
    s = [[self->request applicationName] stringByAppendingString:@"/"];
  
  self->appURL =
    [[NSURL URLWithString:s relativeToURL:[self serverURL]] retain];
  return self->appURL;
}
- (NSURL *)urlForKey:(NSString *)_key {
  _key = [_key stringByAppendingString:@"/"];
  return [NSURL URLWithString:_key relativeToURL:[self applicationURL]];
}

/* forms */

- (void)setInForm:(BOOL)_form {
  self->wcFlags.inForm = _form ? 1 : 0;
}
- (BOOL)isInForm {
  return self->wcFlags.inForm ? YES : NO;
}

- (void)addActiveFormElement:(WOElement *)_formElement {
  if (self->activeFormElement) {
    [[self component] debugWithFormat:@"active form element already set !"];
    return;
  }
  
  ASSIGN(self->activeFormElement, _formElement);
  [self setRequestSenderID:[self elementID]];
}
- (WOElement *)activeFormElement {
  return self->activeFormElement;
}

/* context variables (transient) */

- (void)setObject:(id)_obj forKey:(NSString *)_key {
  if (self->variables == nil) {
    self->variables =
      [[NSMutableDictionary allocWithZone:[self zone]]
                            initWithCapacity:16];
  }

  if (_obj)
    [self->variables setObject:_obj forKey:_key];
  else
    [self->variables removeObjectForKey:_key];
}
- (id)objectForKey:(NSString *)_key {
  return [self->variables objectForKey:_key];
}
- (void)removeObjectForKey:(NSString *)_key {
  [self->variables removeObjectForKey:_key];
}

- (NSDictionary *)variableDictionary {
  return self->variables;
}

- (void)takeValue:(id)_value forKey:(NSString *)_key {
  if (WOSetKVCValueUsingMethod(self, _key, _value))
    // method is used
    return;
  else if (WOGetKVCGetMethod(self, _key) == NULL) {
    if (_value == nil)
      _value = [NSNull null];
    
    if (self->variables == nil) {
      self->variables =
        [[NSMutableDictionary allocWithZone:[self zone]]
                              initWithCapacity:16];
    }
    [self->variables setObject:_value forKey:_key];
    return;
  }
  else {
    // only a 'get' method is defined for _key !
    [self handleTakeValue:_value forUnboundKey:_key];
  }
}
- (id)valueForKey:(NSString *)_key {
  id value;
  
  if ((value = WOGetKVCValueUsingMethod(self, _key)))
    return value;
  value = [self->variables objectForKey:_key];
  return value;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [self retain];
}

/* description */

- (NSString *)description {
  NSString *sid = nil;
  WOApplication *app = [self application];

  if ([self hasSession])
    sid = [[self session] sessionID];
  
  return [NSString stringWithFormat:
                     @"<0x%p[%@]: %@ app=%@ sn=%@ eid=%@ rqeid=%@>",
                     self, NSStringFromClass([self class]),
                     [self  contextID],
                     [app name],
		     sid != nil ? sid : (NSString *)@"none",
                     [self  elementID],
                     [self  senderID]];
}

/* ElementIDs */

- (NSString *)elementID {
  return [self->elementID elementID];
}
- (void)appendElementIDComponent:(NSString *)_eid {
  [self->elementID appendElementIDComponent:_eid];
}
- (void)appendZeroElementIDComponent {
  [self->elementID appendZeroElementIDComponent];
}
- (void)deleteAllElementIDComponents {
  [self->elementID deleteAllElementIDComponents];
}
- (void)deleteLastElementIDComponent {
  [self->elementID deleteLastElementIDComponent];
}
- (void)incrementLastElementIDComponent {
  [self->elementID incrementLastElementIDComponent];
}
- (void)appendIntElementIDComponent:(int)_eid {
  [self->elementID appendIntElementIDComponent:_eid];
}

/* the following can be later moved to WOElementID */

- (id)currentElementID {
  return [self->reqElementID currentElementID];
}
- (id)consumeElementID {
  return [self->reqElementID consumeElementID];
}

/* URLs */

- (void)_generateCompleteURLs {
  /* described in Apple TIL article 70101 */
}

- (void)setQueryPathSeparator:(NSString *)_sp {
  ASSIGNCOPY(self->qpJoin, _sp);
}
- (NSString *)queryPathSeparator {
  return self->qpJoin;
}

- (void)setGenerateXMLStyleEmptyElements:(BOOL)_flag {
  self->wcFlags.xmlStyleEmptyElements = _flag ? 1 : 0;
}
- (BOOL)generateXMLStyleEmptyElements {
  return self->wcFlags.xmlStyleEmptyElements ? YES : NO;
}

- (void)setGenerateEmptyAttributes:(BOOL)_flag {
  self->wcFlags.allowEmptyAttributes = _flag ? 1 : 0;
}
- (BOOL)generateEmptyAttributes {
  return self->wcFlags.allowEmptyAttributes ? YES : NO;
}

- (NSString *)queryStringFromDictionary:(NSDictionary *)_queryDict {
  NSEnumerator    *keys;
  NSString        *key;
  BOOL            isFirst;
  NSMutableString *qs;
  
  qs   = [MutableStrClass stringWithCapacity:256];
  keys = [_queryDict keyEnumerator];
  for (isFirst = YES; (key = [keys nextObject]) != nil; ) {
    id value;
    
    value = [_queryDict objectForKey:key];

    /* check for multi-value parameter */

    if ([value isKindOfClass:[NSArray class]]) {
      NSArray  *a = value;
      unsigned i, count;
      
      for (i = 0, count = [a count]; i < count; i++) {
	value = [a objectAtIndex:i];
	
	if (isFirst) isFirst = NO;
	else [qs appendString:self->qpJoin];

	// TODO: code duplication ...
	value = ![value isNotNull] ? (NSString *)nil : [value stringValue];
	key   = [key   stringByEscapingURL];
	value = [value stringByEscapingURL];
    
	[qs appendString:key];
	if (value != nil) {
	  [qs appendString:@"="];
	  [qs appendString:value];
	}
      }
      continue;
    }

    /* regular, single-value parameter */
    
    if (isFirst) isFirst = NO;
    else [qs appendString:self->qpJoin];
    
    value = ![value isNotNull] ? (NSString *)nil : [value stringValue];
    key   = [key   stringByEscapingURL];
    value = [value stringByEscapingURL];
    
    [qs appendString:key];
    if (value != nil) {
      [qs appendString:@"="];
      [qs appendString:value];
    }
  }
  
  return qs;
}

- (NSString *)directActionURLForActionNamed:(NSString *)_actionName
  queryDictionary:(NSDictionary *)_queryDict
{
  NSMutableString *url;
  NSString        *qs;

  url = [MutableStrClass stringWithCapacity:256];
  
  if (!testNSURLs)
     [url appendString:@"/"];
  
  [url appendString:_actionName];
  
  /* add query parameters */
  
  qs = [self queryStringFromDictionary:_queryDict];
    
  return [self urlWithRequestHandlerKey:
                 [WOAppClass directActionRequestHandlerKey]
               path:url queryString:qs];
}

- (NSString *)componentActionURL {
  // TODO: add a -cComponentActionURL 
  //       (without NSString for use with appendContentCString:)
  // Profiling:
  //   26% -urlWithRequestHandler...
  //   21% -elementID (was 40% !! :-)
  //   ~20% mutable string ops
  
  /* 
     This makes the request handler save the page in the session at the
     end of the request (only necessary if the page generates URLs which
     refer the context).
  */
  self->wcFlags.savePageRequired = 1;
  
  if (newCURLStyle) {
    // TODO: who uses that? Its not enabled per default
    // TODO: what does this do?
    NSMutableString *qs;
    NSString *p;
  
    qs = [MutableStrClass stringWithCapacity:64];
  
    [qs appendString:WORequestValueSenderID];
    [qs appendString:@"="];
    [qs appendString:[self elementID]];
    [qs appendString:self->qpJoin];
    [qs appendString:WORequestValueSessionID];
    [qs appendString:@"="];
    [qs appendString:[[self session] sessionID]];
    [qs appendString:self->qpJoin];
    [qs appendString:WORequestValueContextID];
    [qs appendString:@"="];
    [qs appendString:[self contextID]];
  
    p = [[self page] componentActionURLForContext:self];

    if (testNSURLs) {
      if ([p hasPrefix:@"/"]) p = [p substringFromIndex:1];
    }
  
    return [self urlWithRequestHandlerKey:
		   [WOAppClass componentRequestHandlerKey]
		 path:p
		 queryString:qs];
  }
  else {
    /* old style URLs ... */
    static NSMutableString *url = nil; // THREAD
    static IMP addStr = NULL;
    NSString *s;
    NSString *coRqhKey;

    coRqhKey = [WOAppClass componentRequestHandlerKey];

    /* 
       Optimization: use relative URL if the request already was a component
                     action (with a valid session)
    */
    if (!self->wcFlags.hasNewSession) {
      if ([[self->request requestHandlerKey] isEqualToString:coRqhKey])
	return [self->elementID elementID];
    }
    
    if (url == nil) {
      url = [[MutableStrClass alloc] initWithCapacity:256];
      addStr = [url methodForSelector:@selector(appendString:)];
      addStr(url, @selector(appendString:), @"/");
    }
    else
      [url setString:@"/"];
    
    /*
      Note: component actions *always* require sessions to be able to locate
      the request component !
    */
    addStr(url, @selector(appendString:), [[self session] sessionID]);
    addStr(url, @selector(appendString:), @"/");
    addStr(url, @selector(appendString:), [self->elementID elementID]);
  
    s = [self urlWithRequestHandlerKey:coRqhKey
	      path:url queryString:nil];
    return s;
  }
}

- (NSString *)urlWithRequestHandlerKey:(NSString *)_key
  path:(NSString *)_path
  queryString:(NSString *)_query
{
  if (testNSURLs) { /* use NSURLs for processing */
    NSURL *rqUrl;
    
    if ([_path hasPrefix:@"/"]) {
#if DEBUG
      [self warnWithFormat:@"got absolute path '%@'", _path];
#endif
      _path = [_path substringFromIndex:1];
    }
    
    if (_key == nil) _key = [WOAppClass componentRequestHandlerKey];
    rqUrl = [self urlForKey:_key];
  
    if ([_query length] > 0) {
      NSMutableString *s;
    
      s = [_path mutableCopy];
      [s appendString:@"?"];
      [s appendString:_query];
      rqUrl = [NSURL URLWithString:s relativeToURL:rqUrl];
      [s release];
    }
    else
      rqUrl = [NSURL URLWithString:_path relativeToURL:rqUrl];
    
    //[self logWithFormat:@"constructed component URL: %@", rqUrl];
    
    return [rqUrl stringValueRelativeToURL:[self baseURL]];
  }
  else {
    NSMutableString *url;
    NSString *tmp;
    IMP addStr;
  
    if (_key == nil) _key = [WOAppClass componentRequestHandlerKey];
  
    url = [MutableStrClass stringWithCapacity:256];
    addStr = [url methodForSelector:@selector(appendString:)];

    /* static part */
    if (self->urlPrefix == nil) {
      if (!relativeURLs) {
	if ((tmp = [self->request headerForKey:@"x-webobjects-server-url"])) {
	  if ([tmp hasSuffix:@":0"] && [tmp length] > 2) // TODO: BAD BAD BAD
	    tmp = [tmp substringToIndex:([tmp length] - 2)];
	  addStr(url, @selector(appendString:), tmp);
	}
	else if ((tmp = [self->request headerForKey:@"host"])) {
	  addStr(url, @selector(appendString:), @"http://");
	  addStr(url, @selector(appendString:), tmp);
	}
      }

      addStr(url, @selector(appendString:), [self->request adaptorPrefix]);
      addStr(url, @selector(appendString:), @"/");
      tmp = [[self request] applicationName];
      if ([tmp length] == 0)
        tmp = [(WOApplication *)[self application] name];
      if ([tmp length] > 0) {
	addStr(url, @selector(appendString:), tmp);
	if (WOApplicationSuffix)
	  addStr(url, @selector(appendString:), WOApplicationSuffix);
	addStr(url, @selector(appendString:), @"/");
      }
      
      /* cache prefix */
      self->urlPrefix = [url copy];
      if (debugOn) [self debugWithFormat:@"URL prefix: '%@'", self->urlPrefix];
    }
    else {
      /* prefix is cached :-) */
      addStr(url, @selector(appendString:), self->urlPrefix);
    }
  
    /* variable part */
    addStr(url, @selector(appendString:), _key);
    if (_path) 
      addStr(url, @selector(appendString:), _path);
    if ([_query length] > 0) {
      addStr(url, @selector(appendString:), @"?");
      addStr(url, @selector(appendString:), _query);
    }
    return url;
  }
}
- (NSString *)completeURLWithRequestHandlerKey:(NSString *)_key
  path:(NSString *)_path queryString:(NSString *)_query
  isSecure:(BOOL)_isSecure port:(int)_port
{
  NSMutableString *url = [MutableStrClass stringWithCapacity:256];
  [url appendString:_isSecure ? @"https://" : @"http://"];
  [url appendString:[[self request] headerForKey:@"host"]];
  if (_port > 0) {
    if (!(_isSecure && _port == 443) && !(!_isSecure && _port == 80))
      [url appendFormat:@":%i", _port];
  }
  [url appendString:[self urlWithRequestHandlerKey:_key
                          path:_path
                          queryString:_query]];
  return url;
}

- (void)setRequestSenderID:(NSString *)_rid {
  WOElementID *eid;
  
  eid = [[WOElementID alloc] initWithString:_rid];
  [self->reqElementID release];
  self->reqElementID = eid;
}
- (NSString *)senderID {
#if 1
  return [self->reqElementID elementID];
#else
  NSMutableString *eid;
  IMP addStr;
  int i;
  
  eid = [MutableStrClass stringWithCapacity:(self->reqElementIdCount * 4) + 1];
  addStr = [eid methodForSelector:@selector(appendString:)];
  for (i = 0; i < self->reqElementIdCount; i++) {
    if (i != 0) addStr(eid, @selector(appendString:), @".");
    addStr(eid, @selector(appendString:), [self->reqElementId[i] stringValue]);
  }
  return eid;
#endif
}

/* languages for resource lookup (non-WO) */

- (NSArray *)resourceLookupLanguages {
  return [self hasSession] 
    ? [[self session] languages]
    : [[self request] browserLanguages];
}

/* fragments */

- (void)setFragmentID:(NSString *)_fragmentID {
  ASSIGNCOPY(self->fragmentID, _fragmentID);
}
- (NSString *)fragmentID {
  return self->fragmentID;
}

- (void)enableRendering {
  self->wcFlags.isRenderingDisabled = NO;
}
- (void)disableRendering {
  self->wcFlags.isRenderingDisabled = YES;
}
- (BOOL)isRenderingDisabled {
  return self->wcFlags.isRenderingDisabled; 
}

/* DeprecatedMethodsInWO4 */

- (id)application {
  if (self->application == nil)
    self->application = [WOAppClass application];

  if (self->application == nil) {
    [self logWithFormat:
	    @"%s: missing application for context %@", 
	    __PRETTY_FUNCTION__, self];
  }
  
  return self->application;
}

- (void)setDistributionEnabled:(BOOL)_flag {
  IS_DEPRECATED;
  [[self session] setDistributionEnabled:_flag];
}
- (BOOL)isDistributionEnabled {
  IS_DEPRECATED;
  return [[self session] isDistributionEnabled];
}

- (NSString *)url {
  return [self componentActionURL];
}

- (NSString *)urlSessionPrefix {
  NSMutableString *url;
  NSString *tmp;

  url = [MutableStrClass stringWithCapacity:128];
  
  [url appendString:[[self request] adaptorPrefix]];
  [url appendString:@"/"];
  tmp = [[self request] applicationName];
  [url appendString:
	 tmp ? tmp : [(WOApplication *)[self application] name]];

#if DEBUG
  if ([url length] == 0) {
    [self warnWithFormat:@"(%s): could not determine session URL prefix !",
            __PRETTY_FUNCTION__];
  }
#endif
  
  return url;
}

@end /* WOContext */


@implementation WOComponent(Cursors)

- (void)pushCursor:(id)_obj {
  if (debugCursor)
    [self logWithFormat:@"enter cursor: %@", _obj];
  
  if (!self->cycleContext)
    self->cycleContext = [[NSMutableArray alloc] initWithCapacity:8];
  
  /* add to cursor stack */
  [self->cycleContext addObject:(_obj != nil ? _obj : (id)[NSNull null])];
  
  /* set active cursor */
  [self setObject:_obj forKey:@"_"];
}

- (id)popCursor {
  NSMutableArray *ctxStack;
  id old;
  
  /* retrieve last context */
  old  = [[self objectForKey:@"_"] retain];
  [self setObject:nil forKey:@"_"];
  
  /* restore old ctx */
  if ((ctxStack = self->cycleContext) != nil) {
    unsigned count;
    
    if ((count = [ctxStack count]) > 0) {
      [ctxStack removeObjectAtIndex:(count - 1)];
      count--;
      
      if (count > 0) {
        id obj;
        
        obj = [ctxStack objectAtIndex:(count - 1)];
      
        if (![obj isNotNull]) obj = nil;
        [self setObject:obj forKey:@"_"];
      }      
    }
  }
#if DEBUG
  else {
    [self warnWithFormat:@"-popCursor called without cycle ctx !"];
  }
#endif
  
  if (debugCursor) {
    [self logWithFormat:@"leave cursor: %@ (restored=%@)",
            old, [self cursor]];
  }
  
  return [old autorelease];
}

- (id)cursor {
  NSMutableArray *ctxStack;
  
  // TODO: why do we check for _ODCycleCtx, if we query '_' ?
  
  if ((ctxStack = self->cycleContext) == nil)
    /* no cycle context setup for component ... */
    return self;
  if ([ctxStack count] == 0)
    /* nothing contained in cycle context ... */
    return self;
  
  return [self objectForKey:@"_"];
}

@end /* WOComponent(Cursors) */
