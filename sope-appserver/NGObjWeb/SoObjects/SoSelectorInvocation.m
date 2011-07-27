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

#include "SoSelectorInvocation.h"
#include "SoClassSecurityInfo.h"
#include "NSException+HTTP.h"
#include "WOContext+SoObjects.h"
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOContext.h>
#include <DOM/EDOM.h>
#include "common.h"

#if (defined(__GNU_LIBOBJC__) && (__GNU_LIBOBJC__ == 20100911)) || defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
#  define sel_get_any_uid   sel_getUid
#  define sel_register_name sel_registerName
#endif

@implementation SoSelectorInvocation

static BOOL debugOn = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;

  debugOn = [ud boolForKey:@"SoSelectorInvocationDebugEnabled"];
  if (debugOn) NSLog(@"Note: SOPE selector invocation debug is enabled.");
  
  /* per default selector invocations are public */
  [[self soClassSecurityInfo] declareObjectPublic];
}

- (id)init {
  if ((self = [super init]) != nil) {
    [self setDoesAddContextParameter:YES];
  }
  return self;
}

- (id)initWithSelectorNamed:(NSString *)_sel addContextParameter:(BOOL)_wc {
  if ((self = [self init])) {
    [self addSelectorNamed:_sel];
    [self setDoesAddContextParameter:_wc];
  }
  return self;
}

- (void)dealloc {
  [self->argumentSpecifications release];
  [self->object release];
  [super dealloc];
}

/* containment */

- (void)detachFromContainer {
}
- (id)container {
  return nil;
}
- (NSString *)nameInContainer {
  return nil;
}

/* configuration */

- (void)addSelectorNamed:(NSString *)_name {
  unsigned len;
  
  if ((len = [_name length]) == 0) 
    return;
  if (self->sel != NULL) {
    [self logWithFormat:@"not yet ready for operator overloading (%@).",
	    _name];
    return;
  }
  
  /* count arguments (do we have something like this as a string method?) */
  
  self->argCount = 0;
  while (len > 0) {
    len--;
    
    if ([_name characterAtIndex:len] == ':')
      self->argCount++;
  }
  
  if ((self->sel = NSSelectorFromString(_name)) == NULL) {
    /* this can happen if the product bundle is not yet loaded ... */
#if GNU_RUNTIME
    const char *sname = [_name cString];
    if ((self->sel = sel_get_any_uid(sname)) == NULL)
      self->sel = sel_register_name(sname);
#else
    /* TODO: not tested against this ObjC runtime */
    [self warnWithFormat:@"(%s): not tested against this ObjC runtime, "
            @"product bundle loading may be broken.", __PRETTY_FUNCTION__];
#endif
  }
  if (self->sel == NULL)
    [self warnWithFormat:@"did not find selector: %@", _name];
}

- (void)setDoesAddContextParameter:(BOOL)_flag {
  self->flags.addContextParameter = _flag ? 1 : 0;
}
- (BOOL)doesAddContextParameter {
  return self->flags.addContextParameter ? YES : NO;
}

- (void)setArgumentSpecifications:(NSDictionary *)_specs {
  ASSIGNCOPY(self->argumentSpecifications, _specs);
}
- (NSDictionary *)argumentSpecifications {
  return self->argumentSpecifications;
}

/* error objects */

- (NSException *)unsupportedSelectorError:(SEL)_sel {
  return [NSException exceptionWithHTTPStatus:500 /* Server Error */
		      reason:@"tried to call unsupported selector"];
}

- (NSException *)noSelectorForArgumentCountError:(unsigned)_callArgCount {
  NSString *s;

  s = [NSString stringWithFormat:
		  @"incorrect argument count for SOPE method: "
		  @"required %i for %@, got %i", 
		  self->argCount, NSStringFromSelector(self->sel), 
		  _callArgCount];
  return [NSException exceptionWithHTTPStatus:400 /* Bad Request */
		      reason:s];
}

/* arguments */

- (NSArray *)extractSOAPArgumentsFromContext:(id)_ctx specification:(id)_spec {
  /* spec is supposed to be an array of DOM query pathes ... */
  NSMutableArray *args;
  unsigned       i, count;
  id             soapEnvelope;
  
  // TODO: I guess that should be improved a bit in the dispatcher
  if ((soapEnvelope = [_ctx valueForKey:@"SOAPEnvelope"]) == nil) {
    // TODO: generate some kind of fault? (NSException?)
    [self errorWithFormat:@"no SOAP envelope available in context!"];
    return nil;
  }
  
  /* for each positional selector argument we have a query path */
  count = [_spec count];
  args  = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    NSString *qppath;
    id value;
    
    qppath = [_spec objectAtIndex:i];
    value  = [qppath isNotNull] ? [soapEnvelope lookupQueryPath:qppath] : nil;
    
    [args addObject:(value != nil ? value : (id)[NSNull null])];
  }
  return args;
}

- (NSArray *)extractArgumentsFromContext:(id)_ctx
  forRequestType:(NSString *)_type
  specification:(id)_spec 
{
  if ([_type isEqualToString:@"SOAP"])
    return [self extractSOAPArgumentsFromContext:_ctx specification:_spec];
  
  [self errorWithFormat:
          @"cannot extract parameters for request type: '%@'", _type];
  return nil;
}

/* invocation */

- (BOOL)isCallable {
  return YES;
}
- (id)clientObject {
  return self->object;
}

- (id)primaryCallSelector:(SEL)_sel withArguments:(NSArray *)_args {
  unsigned     i, callArgCount;
  NSInvocation *inv;
  id result;
  
  if (self->object == nil || _sel == NULL)
    return nil;
  
  if (![self->object respondsToSelector:_sel]) {
    [self logWithFormat:
	    @"Object does not support selector %@, probably broken "
	    @"product.plist file.",
	    NSStringFromSelector(_sel)];
    return [self unsupportedSelectorError:_sel];
  }
  
  callArgCount = [_args count];
  
  /* use primitives if possible */
  
  if (callArgCount == 0)
    return [self->object performSelector:_sel];
  if (callArgCount == 1) {
    return [self->object performSelector:_sel
		withObject:[_args objectAtIndex:0]];
  }
  if (callArgCount == 2) {
    return [self->object performSelector:_sel 
		withObject:[_args objectAtIndex:0] 
		withObject:[_args objectAtIndex:1]];
  }
  
  /* construct NSInvocation */

  // TODO: do security audit, can this lead to "issues"? (should not)
  
  inv = [NSInvocation invocationWithMethodSignature:
			[self->object methodSignatureForSelector:_sel]];
  [inv setSelector:_sel];
  [inv setTarget:self->object];
  
  for (i = 0; i < callArgCount; i++) {
    id arg;
    
    arg = [_args objectAtIndex:i];
    [inv setArgument:&arg atIndex:(i + 2)];
  }
  
  NS_DURING {
    [inv invoke];
    [inv getReturnValue:&result];
  }
  NS_HANDLER
    result = [[localException retain] autorelease];
  NS_ENDHANDLER;
  return result;
}

- (SEL)selectorForNumberOfArguments:(unsigned)_argcount {
#if 1
  // for now, we require an exact match
  return self->argCount == _argcount ? self->sel : NULL;
#else
  // we fill up missing args with nil/NSNull (TODO: prior validation!)
  return self->argCount >= _argcount ? self->sel : NULL;
#endif
}

- (id)callOnObject:(id)_client inContext:(id)_ctx {
  /* call method for keyword arguments or other stuff */
  NSArray      *args;
  NSDictionary *argspec;
  SEL          selector;
  
  /* do not rebind, this breaks if client!=lookup */
  if (self->object == nil) {
    /* bind on demand */
    return [[self bindToObject:_client inContext:_ctx]
	          callOnObject:_client inContext:_ctx];
  }

  /* process arguments */
  
  args    = nil;
  argspec = [self->argumentSpecifications objectForKey:[_ctx soRequestType]];
  if (argspec == nil) {
    /* no argument extractors defined */
    if (debugOn) {
      [self debugWithFormat:@"no arg type spec for type: '%@'",
	      [_ctx soRequestType]];
    }
    if ([self doesAddContextParameter])
      args = [NSArray arrayWithObject:(_ctx ? _ctx : (id)[NSNull null])];
  }
  else {
    args = [self extractArgumentsFromContext:_ctx
		 forRequestType:[_ctx soRequestType]
		 specification:argspec];
    if (debugOn) [self debugWithFormat:@"extracted args %@", args];
    if ([self doesAddContextParameter]) {
      if (args != nil)
	args = [args arrayByAddingObject:(_ctx != nil?_ctx:(id)[NSNull null])];
      else
	args = [NSArray arrayWithObject: (_ctx != nil?_ctx:(id)[NSNull null])];
    }
  }
  
  /* find selector */
  
  selector = [self selectorForNumberOfArguments:[args count]];
  if (selector == NULL) {
    [self warnWithFormat:@"missing selector for invocation!"];
    return [self noSelectorForArgumentCountError:[args count]];
  }
  
  // TODO: check whether this is really a "context invocation"
  // TODO: check number of arguments

  /* invoke */
  
  /* if prebound, call on the bound object, not on the client ! */
  return [self primaryCallSelector:self->sel withArguments:args];
}

- (id)callOnObject:(id)_client 
  withPositionalParameters:(NSArray *)_args
  inContext:(id)_ctx
{
  /* call method for positional parameters */
  SEL      selector;
  unsigned callArgCount;
  
  if (self->object == nil) {
    /* bind on demand */
    return [[self bindToObject:_client inContext:_ctx]
	          callOnObject:_client 
	          withPositionalParameters:_args inContext:_ctx];
  }
  
  callArgCount = [_args count];
  if ([self doesAddContextParameter]) callArgCount++;
  
  if ((selector = [self selectorForNumberOfArguments:callArgCount]) == NULL) {
    [self warnWithFormat:@"missing selector for invocation (args=%d)!",
            callArgCount];
    return [self noSelectorForArgumentCountError:callArgCount];
  }
  
  // TODO:
  //   step A: fill up missing arguments (support default values?!)
  //   step B: validate arguments!
  
  if ([self doesAddContextParameter])
    _args = [_args arrayByAddingObject:_ctx ? _ctx : (id)[NSNull null]];
  
  if (debugOn) {
    [self debugWithFormat:@"call on %@ with args(%i) %@ context %@",
	    _client, [_args count], _args, _client];
  }
  return [self primaryCallSelector:self->sel withArguments:_args];
}

/* binding */

- (BOOL)isBound {
  return self->object == nil ? NO : YES;
}

- (id)bindToObject:(id)_object inContext:(id)_ctx {
  SoSelectorInvocation *inv;
  
  if (_object == nil) return nil;
  
  inv = [SoSelectorInvocation alloc];
  inv->sel      = self->sel;
  inv->argCount = self->argCount;
  inv->flags    = self->flags;
  inv->object   = [_object retain];
  inv->method   = [_object methodForSelector:inv->sel];
  inv->argumentSpecifications = [self->argumentSpecifications copy];
  return [inv autorelease];
}

/* delivering as content (can happen in DAV !) */

- (void)appendToResponse:(WOResponse *)_r inContext:(WOContext *)_ctx {
  [_r appendContentString:@"Compiled SOPE method: "];
  
  if (self->sel)
    [_r appendContentHTMLString:NSStringFromSelector(self->sel)];
  else
    [_r appendContentHTMLString:@"missing selector!"];

  if (self->object) {
    [_r appendContentHTMLString:@" (method is bound to object of class "];
    [_r appendContentHTMLString:NSStringFromClass([self->object class])];
    [_r appendContentHTMLString:@")"];
  }
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  if (self->sel) {
    [ms appendFormat:@" sel=%@", NSStringFromSelector(self->sel)];
    [ms appendFormat:@"(%i args)", self->argCount];
  }
  if (self->object) {
    [ms appendFormat:@" bound(0x%p,%@)", 
          self->object, NSStringFromClass([self->object class])];
  }

  if ([self doesAddContextParameter])
    [ms appendFormat:@" ctx-arg"];
  
  if ([self->argumentSpecifications count] > 0) {
    id tmp;
    
    tmp = [self->argumentSpecifications allKeys];
    tmp = [tmp componentsJoinedByString:@","];
    [ms appendFormat:@" arg-handlers=%@",tmp];
  }
  
  [ms appendString:@">"];
  return ms;
}

@end /* SoSelectorInvocation */
