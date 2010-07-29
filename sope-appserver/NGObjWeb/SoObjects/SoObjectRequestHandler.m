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

#include "SoObjectRequestHandler.h"
#include "SoObject.h"
#include "SoObjectMethodDispatcher.h"
#include "SoSecurityManager.h"
#include "SoDefaultRenderer.h"
#include "WOContext+SoObjects.h"
#include "WORequest+So.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOElement.h>
#include <NGObjWeb/WOTemplate.h>
#include <NGObjWeb/WEClientCapabilities.h>
#include <NGExtensions/NGRuleContext.h>
#include <NGExtensions/NSString+Ext.h>
#include "WOComponent+private.h"
#include "common.h"

@interface NSObject(ObjectDispatcher)
- (id)dispatcherForContext:(WOContext *)_ctx;
- (WOResponse *)preprocessCredentialsInContext:(WOContext *)_ctx;
- (void)_sleepWithContext:(WOContext *)_ctx;
@end

@interface NSObject(SoOFS)
- (NSString *)storagePath;
@end

@implementation SoObjectRequestHandler

static NGLogger *debugLogger = nil;
static NGLogger *logger      = nil;
static BOOL debugRulesOn     = NO;
static BOOL disableZLHack    = NO;

static Class WOTemplateClass = Nil;
static NSString *rapidTurnAroundPath = nil;

static NSString *redirectURISafetySuffix = nil;

+ (int)version {
  return [super version] + 0 /* 2 */;
}
+ (void)initialize {
  static BOOL     didInit = NO;
  NSUserDefaults  *ud;
  NGLoggerManager *lm;

  if (didInit) return;

  didInit = YES;
  NSAssert2([super version] == 2,
	    @"invalid superclass (%@) version %i !",
	    NSStringFromClass([self superclass]), [super version]);

  lm          = [NGLoggerManager defaultLoggerManager];
  logger      = [lm loggerForClass:self];
  debugLogger = [lm loggerForDefaultKey:@"SoObjectRequestHandlerDebugEnabled"];

  ud            = [NSUserDefaults standardUserDefaults];
  debugRulesOn  = [ud boolForKey:@"SoObjectRequestHandlerRulesDebugEnabled"];
  disableZLHack = [ud boolForKey:@"DisableZideLookHack"];

  WOTemplateClass     = [WOTemplate class];
  rapidTurnAroundPath = [[ud stringForKey:@"WOProjectDirectory"] copy];    
  
  redirectURISafetySuffix = 
    [[ud stringForKey:@"WORedirectURISafetySuffix"] copy];
}

- (id)init {
  if ((self = [super init])) {
    self->dispatcherRules =
      [[NGRuleContext ruleContextWithModelInUserDefault:
                        @"SoRequestDispatcherRules"] retain];
    if (debugRulesOn) [self->dispatcherRules setDebugEnabled:YES];
  }
  return self;
}
- (void)dealloc {
  [self->dispatcherRules release];
  [self->rootObject      release];
  [super dealloc];
}

/* type the request */

- (BOOL)isObjectPublishingContext:(WOContext *)_ctx {
  /* 
     Find out, whether we should do acquisition and dynamic method publishing.
     This is only appropriate for HEAD/GET/POST requests from non-WebDAV
     clients ?
  */
  id value;
  
  value = [self->dispatcherRules valueForKey:@"useAcquisition"];
  if (debugRulesOn) [self debugWithFormat:@"acquision: %@", value];
  return [value boolValue];
}

/* request path acquisition */

- (BOOL)enableZideLookHack {
  /* Temporary Hack for ZideLook */
  return disableZLHack ? NO : YES;
}

- (BOOL)skipApplicationName {
  /* is the application name path of a URI part of the traversal path ? */
  return NO;
}

- (NSString *)hackZideLookURI:(NSString *)m {
  if ([m hasPrefix:@"H_chste_Ebene_der_Pers_nlichen_Ordner"]) {
    m = [m stringByReplacingString:@"H_chste_Ebene_der_Pers_nlichen_Ordner"
	   withString:@"helge"];
  }
  else if ([m hasPrefix:@"Suchpfad"]) {
    m = [m stringByReplacingString:@"Suchpfad"
	   withString:@"helge"];
  }
  else if ([m hasPrefix:@"public"]) {
    /* Evolution query on "/public" */
    ; // keep it completly
  }
  else if ([self skipApplicationName]) {
    /* cut of appname */
    NSRange r;
    r = [m rangeOfString:@"/"];
    m = [m substringFromIndex:(r.location + r.length)];
  }
  return m;
}
- (NSString *)hackZideLookName:(NSString *)_p {
  if ([_p isEqualToString:@"Gel_schte_Objekte"])
    return @"Trash";
  return _p;
}

- (NSMutableArray *)addSpecialFormValuesInRequest:(WORequest *)_rq
  toTraversalPath:(NSMutableArray *)_traversalPath
{
  NSArray  *keys;
  unsigned i, count;
  
  keys = [_rq formValueKeys];
  if ((count = [keys count]) == 0)
    return _traversalPath;
  
  for (i = 0; i < count; i++) {
    NSString *key;
    unsigned klen;
    NSString *m;
    
    key  = [keys objectAtIndex:i];
    klen = [key length];
    if (klen != 3 && klen < 7)
      continue;
    
    /* calculate method name */
    
    m = nil;
    if (klen == 3 && [key isEqualToString:@"Cmd"]) {
      /* 
	 Check for ASP style ?Cmd query parameter (required in ZideStore),
	 the value is the additional path we need to add.

	 TODO: ?Cmd should only lookup using the SoClass, this would avoid
               conflicts with content hierarchies.
      */
      m = [_rq formValueForKey:key]; // need to unescape somehow ?
    }
    else if (klen == 7 && [key isEqualToString:@":method"]) {
      /* 
	 check for ":method" form value, the value is the additional path we 
	 need to add
      */
      m = [_rq formValueForKey:key]; // need to unescape somehow ?
    }
    else if ([key hasSuffix:@":method"]) {
      /*
	Check for XXX:method form-keys, the value is ignored and the
	XXX is added to the path. This is useful for binding actions
	to submit buttons, since the value of a submit button is 
	displayed as it's label in the browser
      */
      klen = klen - 7;
      m = [key substringToIndex:klen];
    }
    
    /* check calculated method */
    
    if (m == nil)
      continue;
    else if ([m length] == 0) {
      [self debugWithFormat:@"empty '%@' query parameter !", key];
      continue;
    }
    
    /* add to path */
    [_traversalPath addObject:m];
  }
  return _traversalPath;
}

- (NSArray *)traversalPathFromRequest:(WORequest *)_rq {
  static NSArray *rqKeys = nil; /* cache of request handlers */
  NSMutableArray *traversalPath;
  unsigned i, count;
  NSString *m;
  NSArray  *a;
  
  if (rqKeys == nil)
    /* cache set of registered request handlers */
    rqKeys = [[[WOApplication application] registeredRequestHandlerKeys] copy];

  /* check request handler keys */
  
  m = [_rq requestHandlerKey];
  if ([rqKeys containsObject:m]) {
    /* 
       If the request-handler-key parsed by WORequest is valid, we'll consider
       it a "usual" NGObjWeb query. Note that the appname is *not* processed !
       Example:
         /MyApp/wo/...   => match
         /MyApp/bla/...  => fail
         /blah/wa/...    => match
    */
    a = [_rq requestHandlerPathArray];
  }
  else {
    /* TODO: more options, eg allow the appname to be part of the path */
    NSRange r;

    /* get URI, cut of leading slash */
    m = [_rq uri];
    m = [m substringFromIndex:1];
    
    if ([self enableZideLookHack]) 
      m = [self hackZideLookURI:m];
    else if ([self skipApplicationName]) {
      /* cut of application name */
      r = [m rangeOfString:@"/"];
      m = [m substringFromIndex:(r.location + r.length)];
    }
    
    /* cut of query parameters */
    r = [m rangeOfString:@"?"];
    if (r.length > 0)
      m = [m substringToIndex:r.location];
    
    /* split into path components */
    a = [m componentsSeparatedByString:@"/"];
  }
  
  count = [a count];
  traversalPath = [NSMutableArray arrayWithCapacity:(count + 1)];
  for (i = 0; i < count; i++) {
    NSString *p;
    
    p = [a objectAtIndex:i];
    
    if ([p hasPrefix:@"_range"])
      /* a ZideLook range query, further handled by WebDAV dispatcher */
      continue;
    
    p = [p stringByUnescapingURL];
    
    if ([self enableZideLookHack])
      p = [self hackZideLookName:p];
    
    if ([p isNotEmpty])
      [traversalPath addObject:p];
  }
  
  traversalPath = [self addSpecialFormValuesInRequest:_rq
			toTraversalPath:traversalPath];
  
  return traversalPath;
}

- (id)rootObjectForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  id object;
  
  if (self->rootObject != nil)
    return self->rootObject;
    
  if ((object = [_ctx application]) == nil)
    object = [WOApplication application];
  
#if 0
  /* 
    If we resolve in this location, we won't be able to resolve
    application names like "Control_Panel".
    
    TODO: explain better!
  */
  if ([object respondsToSelector:@selector(rootObjectInContext:)])
    object = [object rootObjectInContext:_ctx];
#endif
  
  return object;
}

- (id)lookupObjectForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  NSAutoreleasePool *pool;
  NSArray     *traversalPath;
  id currentObject;
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    NSException *error = nil;
    id   root;
    BOOL doAcquire;
    
    /* build traversal path */
    
    traversalPath = [self traversalPathFromRequest:_rq];
    if (traversalPath != nil)
      [_ctx setSoRequestTraversalPath:traversalPath];
    
    /* setup root object */
    
    root = [self rootObjectForRequest:_rq inContext:_ctx];
    
    doAcquire = self->doesNoRequestPathAcquisition
      ? NO
      : [self isObjectPublishingContext:_ctx];

    [self debugWithFormat:@"traverse (%@): %@ %@", 
            [_rq uri], 
            [traversalPath componentsJoinedByString:@" => "],
            doAcquire ? @"[acquires]" : @"(no acquisition)"];
    
    currentObject = [root traversePathArray:traversalPath
			  inContext:_ctx
			  error:&error
			  acquire:doAcquire];
    if (error != nil)
      currentObject = error;
    
    /* retain result */
    currentObject = [currentObject retain];
  }
  [pool release];
  return [currentObject autorelease];
}

/* object invocation */

- (id)dispatcherForObject:(id)_object inContext:(WOContext *)_ctx {
  NSString *dpClass, *rqType;
  id dispatcher = nil;
  
  /* ask object for dispatcher */
  
  if ([_object respondsToSelector:@selector(dispatcherForContext:)]) {
    if ((dispatcher = [_object dispatcherForContext:_ctx]))
      return dispatcher;
  }
  
  if (debugRulesOn) {
    [self debugWithFormat:@"select dispatcher using rules: %@", 
            self->dispatcherRules];
  }
  
  /* query */
  dpClass = [self->dispatcherRules valueForKey:@"dispatcher"];
  rqType  = [self->dispatcherRules valueForKey:@"requestType"];
  if (debugRulesOn) {
    [self debugWithFormat:@"selected dispatcher: %@", dpClass];
    [self debugWithFormat:@"selected rq-type:    %@", rqType];
  }
  
  /* create dispatcher */
  
  if (rqType != nil) [_ctx setSoRequestType:rqType];
  if ((dispatcher = NSClassFromString(dpClass)) == nil) {
    [self errorWithFormat:@"did not find dispatcher class '%@'", dpClass];
    return nil;
  }
  
  if ((dispatcher = [[dispatcher alloc] initWithObject:_object]))
    [_ctx setObjectDispatcher:dispatcher];
  
  return [dispatcher autorelease];
}

/* object rendering */

- (WOResponse *)renderObject:(id)_object inContext:(WOContext *)_ctx {
  SoDefaultRenderer *renderer;
  NSException  *error;
  NSEnumerator *e;
  id container;
  
  [self debugWithFormat:@"render in ctx: %@", _ctx];

  if ([_object isKindOfClass:[WOResponse class]])
    /* already rendered ... */
    return _object;
  
  /* check whether a container on the traversal stack provides a renderer */
  
  renderer = nil;
  e = [[_ctx objectTraversalStack] reverseObjectEnumerator];
  while ((container = [e nextObject]) != nil) {
    if (![container respondsToSelector:
		      @selector(rendererForObject:inContext:)]) {
      /* does not provide a renderer factory ... */
      continue;
    }
    
    if ((renderer = [container rendererForObject:_object inContext:_ctx])) {
      /* the container provided an own renderer for the object */
      [self debugWithFormat:@"use container renderer: %@", renderer];
      break;
    }
  }
  
  /* if we didn't find a renderer, determine using rules */
  
  if (renderer == nil) {
    NSString *rendererClass;
    
    rendererClass = [self->dispatcherRules valueForKey:@"renderer"];
    if (rendererClass) {
      Class clazz;
      
      if ((clazz = NSClassFromString(rendererClass)) == Nil) {
        [self errorWithFormat:@"did not find class of selected renderer %@", 
                rendererClass];
      }
      else if ((renderer = [clazz sharedRenderer]) == nil) {
        [self errorWithFormat:@"could not get renderer of class %@", 
                rendererClass];
      }
      else if (![renderer canRenderObject:_object inContext:_ctx]) {
        [self debugWithFormat:@"renderer %@ rejected rendering of object %@", 
                renderer, _object];
        renderer = [SoDefaultRenderer sharedRenderer];
      }
    }
    
    if (renderer != nil)
      [self debugWithFormat:@"use rule-selected renderer: %@", renderer];
  }
  
  if (renderer == nil)
    [self debugWithFormat:@"found no renderer for object: %@", _object];
  
  if ((error = [renderer renderObject:_object inContext:_ctx])) {
    if (renderer != [SoDefaultRenderer sharedRenderer]) {
      NSException *e2;
      
      e2 = [(SoDefaultRenderer *)[SoDefaultRenderer sharedRenderer] 
                                 renderObject:error inContext:_ctx];
      if (e2) {
        [self errorWithFormat:
                @"default renderer could not render error %@: %@", error, e2];
        return nil;
      }
    }
    else {
      [self errorWithFormat:@"default renderer returned error: %@", error];
      return nil;
    }
  }
  return [_ctx response];
}

- (BOOL)doesRejectFavicon {
  return NO;
}

- (WOResponse *)handleRequest:(WORequest *)_rq
  inContext:(WOContext *)_ctx
  session:(WOSession *)_sn
  application:(WOApplication *)app
{
  /* split up this big method */
  WOResponse *r;
  id   object;
  id   authenticator;
  BOOL doDispatch;
  
  if (debugLogger) {
    [self debugWithFormat:@"request 0x%p: %@ %@ (ctx=0x%p)", _rq, 
            [_rq method], [_rq uri], _ctx];
    if (_sn) [self debugWithFormat:@"session 0x%p: %@", _sn, _sn];
  }
  
  /* first check safety marker */
  
  if ([[_rq uri] hasSuffix:redirectURISafetySuffix]) {
    [self errorWithFormat:
	    @"stopping processing because redirect safety suffix was "
	    @"reached:\n  uri=%@\n  suffix=%@\n",
	    [_rq uri], redirectURISafetySuffix];
    
    r = [_ctx response];
    [r setStatus:403 /* Forbidden */];
    [r appendContentString:
	 @"Request forbidden, a server side safety limit was reached."];
    return r;
  }
  
  /* setup rule context */
  
  [self->dispatcherRules reset];
  [self->dispatcherRules takeValue:_rq           forKey:@"request"];
  [self->dispatcherRules takeValue:[_rq headers] forKey:@"headers"];
  [self->dispatcherRules takeValue:[_rq method]  forKey:@"method"];
  [self->dispatcherRules takeValue:_ctx          forKey:@"context"];
  
  /* preprocess authentication credentials with global auth handler */
  
  if ((authenticator = [app authenticatorInContext:_ctx])) {
    [_ctx setObject:authenticator forKey:@"SoAuthenticator"];
    
    /* give authenticator the chance to reject invalid credentials */
    
    if ((r = [authenticator preprocessCredentialsInContext:_ctx])) {
      [self->dispatcherRules reset];
      return r;
    }
    
    [self debugWithFormat:@"authenticator allowed request."];
  }
  else {
    [self warnWithFormat:@"no authenticator available."];
  }
  
  /* lookup object */
  
  doDispatch = YES;
  object = [self lookupObjectForRequest:_rq inContext:_ctx];
  
  if (object != nil) {
    [self->dispatcherRules 
         takeValue:[_ctx clientObject] forKey:@"clientObject"];
    [self->dispatcherRules takeValue:object forKey:@"object"];
  }
  else {
    r = [_ctx response];
    [r setStatus:404 /* not found */];
    [r setHeader:@"text/html" forKey:@"content-type"];
    [r appendContentString:@"object not found: "];
    [r appendContentHTMLString:
	 [[_ctx soRequestTraversalPath] componentsJoinedByString:@" => "]];
    doDispatch = NO;
    object = r;
  }
  
  /* dispatch object */
  
  if ([object isKindOfClass:[NSException class]]) {
    /* exceptions are not called ... */
    [self debugWithFormat:@"not calling exception: %@", object];
    doDispatch = NO;
  }
  
  if (doDispatch) {
    id dispatcher;
    
    dispatcher = [self dispatcherForObject:object inContext:_ctx];
    [self debugWithFormat:@"dispatcher: %@", dispatcher];
    
    [self debugWithFormat:@"dispatch object: %@", object];
    object = [dispatcher dispatchInContext:_ctx];

    if (object) [self->dispatcherRules takeValue:object forKey:@"result"];
  }
  
  /* render result */
  
  if (object == nil) {
    [self debugWithFormat:@"got an empty result !"];
    r = [_ctx response];
    [r setStatus:500];
    [r appendContentString:@"the called object returned no result"];
  }
  else if ([object isKindOfClass:[WOResponse class]]) {
    r = object;
    [self debugWithFormat:
            @"got response: 0x%p (status=%i,len=%@,type=%@)", 
            r, [r status], 
            [r headerForKey:@"content-length"],
            [r headerForKey:@"content-type"]];
  }
  else {
    if (debugLogger) {
      if ([object isKindOfClass:[NSData class]]) {
        [self debugWithFormat:@"render data 0x%p[len=%i]",
	        object, [object length]];
      }
      else
        [self debugWithFormat:@"render object: %@", object];
    }
    
    [self->dispatcherRules takeValue:object forKey:@"result"];
    r = [self renderObject:object inContext:_ctx];
    
    if (debugLogger) {
      [self debugWithFormat:
	            @"made response: 0x%p (status=%i,len=%@,type=%@)", 
              r, [r status], 
              [r headerForKey:@"content-length"],
              [r headerForKey:@"content-type"]];
    }
  }
  
  /* add header with primary key of new objects (for ZideLook) */
  if (r != nil) {
    id key;
    
    if ((key = [_ctx objectForKey:@"SxNewObjectID"])) {
      key = [NSString stringWithFormat:@"%@", key];
      [r setHeader:key forKey:@"x-skyrix-newname"];
      [self logWithFormat:@"added new key header to response: '%@'", key];
    }
  }

  /* rapid turnaround */
  if (rapidTurnAroundPath != nil) {
    WOComponent *page;
    NSString *_path = nil;

    if ((page = [_ctx page])) {
      WOElement *template;
          
      template = [page _woComponentTemplate];
      if ([template isKindOfClass:WOTemplateClass])
        _path = [[(WOTemplate *)template url] path];
    }
    else {
      // TODO: ZNeK: explain!
      //       I guess we need some generic method to retrieve a template path?
      if ([object isKindOfClass:NSClassFromString(@"OFSBaseObject")])
        _path = [object storagePath];
    }
    if (_path != nil)
      [r setHeader:_path forKey:@"x-sope-template-path"];
  }
  
  /* sleep traversal stack */
  {
    NSEnumerator *e;
    id obj;
    
    e = [[_ctx objectTraversalStack] reverseObjectEnumerator];
    while ((obj = [e nextObject])) {
      if (![obj isNotNull])
	continue;
      
      if ([obj respondsToSelector:@selector(_sleepWithContext:)])
	[obj _sleepWithContext:_ctx];
      else if ([obj respondsToSelector:@selector(sleep)])
	[obj sleep];
    }
  }
  
  [self->dispatcherRules reset];
  
  return r;
}

@end /* SoObjectRequestHandler */


@implementation WOCoreApplication(RendererSelection)

- (id)rendererForObject:(id)_object inContext:(WOContext *)_ctx {
  return nil;
}

@end /* WOCoreApplication(RendererSelection) */


@implementation SoObjectRequestHandler(Logging)

- (NSString *)loggingPrefix {
  return @"[object-handler]";
}
- (BOOL)isDebuggingEnabled {
  return debugLogger ? YES : NO;
}
- (id)logger {
  return logger;
}
- (id)debugLogger {
  return debugLogger;
}

@end /* SoObjectRequestHandler(Logging) */
