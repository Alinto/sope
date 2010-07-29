/*
  Copyright (C) 2002-2009 SKYRIX Software AG

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

#include "SoActionInvocation.h"
#include "SoClassSecurityInfo.h"
#include "SoProduct.h"
#include "WOContext+SoObjects.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WODirectAction.h>
#include <NGObjWeb/WOResponse.h>
#include <DOM/EDOM.h>
#include "common.h"

@implementation SoActionInvocation

static int debugOn = 0;

+ (void)initialize {
  static BOOL didInit = NO;
  if (!didInit) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    didInit = YES;
    
    debugOn = [ud boolForKey:@"SoPageInvocationDebugEnabled"] ? 1 : 0;
  }
}

- (id)initWithActionClassName:(NSString *)_cn actionName:(NSString *)_action {
  if ((self = [super init])) {
    self->actionClassName = [_cn     copy];
    self->actionName      = [_action copy];
  }
  return self;
}
- (id)initWithActionClassName:(NSString *)_cn {
  return [self initWithActionClassName:_cn actionName:nil];
}
- (id)init {
  return [self initWithActionClassName:nil actionName:nil];
}

- (void)dealloc {
  [self->argumentSpecifications release];
  [self->methodObject           release];
  [self->object                 release];
  [self->actionClassName        release];
  [self->actionName             release];
  [super dealloc];
}

/* accessors */

- (NSString *)defaultActionClassName {
  return @"DirectAction";
}
- (NSString *)actionClassName {
  return [self->actionClassName isNotNull] 
    ? self->actionClassName 
    : [self defaultActionClassName];
}
- (NSString *)actionName {
  return self->actionName;
}

- (void)setArgumentSpecifications:(NSDictionary *)_specs {
  ASSIGNCOPY(self->argumentSpecifications, _specs);
}
- (NSDictionary *)argumentSpecifications {
  return self->argumentSpecifications;
}

/* argument processing */

- (NSDictionary *)extractSOAPArgumentsFromContext:(id)_ctx 
  specification:(id)_spec 
{
  /* 
     spec is supposed to be a dictionary with the KVC keys as the 
     keys and DOM query pathes as the values.
  */
  NSMutableDictionary *args;
  NSEnumerator *keys;
  NSString     *key;
  id           soapEnvelope;
  
  // TODO: I guess that should be improved a bit in the dispatcher
  if ((soapEnvelope = [_ctx valueForKey:@"SOAPEnvelope"]) == nil) {
    // TODO: generate some kind of fault? (NSException?)
    [self errorWithFormat:@"no SOAP envelope available in context!"];
    return nil;
  }
  
  /* for each key argument we have a query path */
  
  args = [NSMutableDictionary dictionaryWithCapacity:8];
  keys = [_spec keyEnumerator];
  while ((key = [keys nextObject]) != nil) {
    NSString *qppath;
    id value;
    
    qppath = [_spec valueForKey:key];
    value  = [qppath isNotNull] ? [soapEnvelope lookupQueryPath:qppath] : nil;
    
    [args setObject:(value != nil ? value : (id)[NSNull null]) forKey:key];
  }
  return args;
}

- (NSDictionary *)extractArgumentsFromContext:(id)_ctx
  forRequestType:(NSString *)_type
  specification:(id)_spec 
{
  if ([_type isEqualToString:@"SOAP"])
    return [self extractSOAPArgumentsFromContext:_ctx specification:_spec];

  // TODO: would be cool to have that for REPORTs as well
  
  [self errorWithFormat:
          @"cannot extract parameters for request type: '%@'", _type];
  return nil;
}

/* page construction */

- (id)instantiateMethodInContext:(id)_ctx {
  // Careful: this must return a RETAINED object!
  Class clazz;
  id lMethod;
  
  if (debugOn)
    [self debugWithFormat:@"instantiate method: %@", self->methodObject];
  
  if (_ctx == nil) {
    [self debugWithFormat:
	    @"Note: got no explicit context for method instantiation, using "
	    @"application context."];
    _ctx = [[WOApplication application] context];
  }
  
  /* find class */
  
  if ((clazz = NSClassFromString([self actionClassName])) == Nil) {
    [self errorWithFormat:@"did not find action class: %@",
            [self actionClassName]];
    return  nil;
  }
  
  /* instantiate */

  if ([clazz instancesRespondToSelector:@selector(initWithContext:)])
    lMethod = [[clazz alloc] initWithContext:_ctx];
  else if ([clazz instancesRespondToSelector:@selector(initWithRequest:)]) {
    lMethod = [[clazz alloc] initWithRequest:
                 [(id<WOPageGenerationContext>)_ctx request]];
  }
  else
    lMethod = [[clazz alloc] init];
  
  if (debugOn) [self debugWithFormat:@"   page: %@", lMethod];
  
  return lMethod;
}

/* invocation */

- (BOOL)isCallable {
  return YES;
}
- (id)clientObject {
  return self->object;
}

- (void)_prepareContext:(id)_ctx withMethodObject:(id)_method {
  /* for subclasses (set page in context in page invocation) */
}
- (void)_prepareMethod:(id)_method inContext:(id)_ctx {
  /* for subclasses (triggers takeValues phase in page invocation) */
}

- (void)_applyArgumentsOnMethod:(id)_method inContext:(id)_ctx {
  NSDictionary *argspec;
  NSDictionary *args;
  
  argspec = [self->argumentSpecifications objectForKey:[_ctx soRequestType]];
  if (argspec == nil)
    return;
  
  args = [self extractArgumentsFromContext:_ctx
	       forRequestType:[_ctx soRequestType]
	       specification:argspec];
  if (debugOn) [self debugWithFormat:@"extracted args %@", args];
  
  if (args != nil) [_method takeValuesFromDictionary:args];
}

- (void)_applyPositionalArguments:(NSArray *)_args onMethod:(id)_method
  inContext:(id)_ctx
{
  NSArray *info;
  unsigned i, argCount, infoCount;
  
  info      = [self->argumentSpecifications objectForKey:@"positionalKeys"];
  infoCount = [info  count];
  argCount  = [_args count];
  if ((info == nil) && (argCount > 0)) {
    [self warnWithFormat:
            @"found no argument specification for positional keys!"];
    return;
  }
  
  /* copy available arguments to key */
  
  for (i = 0; i < argCount; i++) {
    if (i >= infoCount) {
      [self warnWithFormat:
              @"could not apply argument %d (no key info)", (i + 1)];
      continue;
    }
    
    [_method takeValue:[_args objectAtIndex:i] forKey:[info objectAtIndex:i]];
  }
  
  /* fill up missing arguments */
  
  for (i = argCount; i < infoCount; i++)
    [_method takeValue:nil forKey:[info objectAtIndex:i]];
}

/* calling the method */

- (id)callOnObject:(id)_client 
  withPositionalParametersWhenNotNil:(NSArray *)_positionalArgs
  inContext:(id)_ctx
{
  /* method used for both, positional and key arguments */
  id method;
  id result = nil;
  
  if (self->object != _client) {
    /* rebind */
    return [[self bindToObject:_client inContext:_ctx]
                  callOnObject:_client inContext:_ctx];
  }
  
  if ([(method = self->methodObject) retain] == nil) {
    // Note: instantiateMethodInContext: returns a retained object
    method = [self instantiateMethodInContext:_ctx];
  }
  
  if (method == nil) {
    [self logWithFormat:@"found no method named '%@' for call !", 
            [self actionClassName]];
    return nil;
  }
  
  /* make page the "request" page */
  
  [self _prepareContext:_ctx withMethodObject:method];
  
  /* set client object in page */
  
  if ([method respondsToSelector:@selector(setClientObject:)])
    [method setClientObject:_client];
  
  if ([_positionalArgs isNotNull]) {
    [self _applyPositionalArguments:_positionalArgs onMethod:method
	  inContext:_ctx];
  }
  else {
    /* TODO: what should be done first?, take values or args? */
    [self _prepareMethod:method          inContext:_ctx];
    [self _applyArgumentsOnMethod:method inContext:_ctx];
  }
  
  /* call action */
  
  if (self->actionName != nil) {
    if (debugOn) {
      [self debugWithFormat:@"  performing action %@ on page: %@", 
	      self->actionName, method];
    }
    result = [method performActionNamed:self->actionName];
  }
  else {
    if (debugOn) {
      [self debugWithFormat:@"  performing default action on page: %@", 
	      method];
    }
    result = [method defaultAction];
  }
  
  result = [result retain];
  [method release]; method = nil;
  return [result autorelease];
}

- (id)callOnObject:(id)_client inContext:(id)_ctx {
  return [self callOnObject:_client
               withPositionalParametersWhenNotNil:nil /* not positional */
               inContext:_ctx];
}
- (id)callOnObject:(id)_client 
  withPositionalParameters:(NSArray *)_args
  inContext:(id)_ctx
{
  if (_args == nil) _args = [NSArray array];
  return [self callOnObject:_client
               withPositionalParametersWhenNotNil:_args
               inContext:_ctx];
}

/* bindings */

- (BOOL)isBound {
  return self->object != nil ? YES : NO;
}

- (id)bindToObject:(id)_object inContext:(id)_ctx {
  SoActionInvocation *inv;
  
  if (_object == nil) return nil;
  
  // TODO: clean up this section, a bit hackish
  inv = [[[self class] alloc] initWithActionClassName:self->actionClassName];
  inv = [inv autorelease];
  
  inv->object       = [_object retain];
  inv->actionName   = [self->actionName copy];
  inv->argumentSpecifications = [self->argumentSpecifications copy];

  // Note: instantiateMethodInContext: returns a retained object!
  inv->methodObject = [inv instantiateMethodInContext:_ctx];
  if (inv->methodObject == nil) {
    [self errorWithFormat:@"did not find method '%@'", [self actionClassName]];
    return nil;
  }
  
  return inv;
}

/* delivering as content (can happen in DAV !) */

- (void)appendToResponse:(WOResponse *)_r inContext:(WOContext *)_ctx {
  [_r appendContentString:@"native action method: "];
  [_r appendContentHTMLString:[self description]];
}

/* key/value coding */

- (id)valueForUndefinedKey:(NSString *)_key {
  if (debugOn) [self debugWithFormat:@"return nil for KVC key: '%@'", _key];
  return nil;
}

/* description */

- (void)appendAttributesToDescription:(NSMutableString *)ms {
  NSString *tmp;
  
  if ((tmp = [self actionClassName])) [ms appendFormat:@" class=%@", tmp];
  if (self->actionName) [ms appendFormat:@" action=%@", self->actionName];
  
  if (self->object) [ms appendString:@" bound"];
  if (self->methodObject) [ms appendString:@" instantiated"];
  
  if ([self->argumentSpecifications count] > 0) {
    id tmp;
    
    tmp = [self->argumentSpecifications allKeys];
    tmp = [tmp componentsJoinedByString:@","];
    [ms appendFormat:@" arg-handlers=%@",tmp];
  }
}
- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [self appendAttributesToDescription:ms];
  [ms appendString:@">"];
  return ms;
}

/* Logging */

- (NSString *)loggingPrefix {
  return [NSString stringWithFormat:@"[so-action 0x%p %@]", 
		     self, self->actionClassName];
}
- (BOOL)isDebuggingEnabled {
  return debugOn ? YES : NO;
}

@end /* SoActionInvocation */
