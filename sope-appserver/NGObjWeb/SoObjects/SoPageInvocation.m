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

#include "SoPageInvocation.h"
#include "SoClassSecurityInfo.h"
#include "SoProduct.h"
#include "WOContext+SoObjects.h"
#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOSession.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResourceManager.h>
#include <NGObjWeb/WOApplication.h>
#include "common.h"

@interface WOComponent(UsedPrivates)
/* this is defined in WOPageRequestHandler */
- (id<WOActionResults>)performActionNamed:(NSString *)_actionName;
- (id<WOActionResults>)defaultAction;
- (void)setResourceManager:(WOResourceManager *)_rm;
@end

@interface WOContext(UsedPrivates)
- (void)setPage:(WOComponent *)_page;
@end

@implementation SoPageInvocation

static int debugOn = 0;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;
    
  debugOn = [ud boolForKey:@"SoPageInvocationDebugEnabled"] ? 1 : 0;
}

- (id)initWithPageName:(NSString *)_pageName {
  return [self initWithActionClassName:_pageName];
}
- (id)initWithPageName:(NSString *)_pageName actionName:(NSString *)_action {
  return [self initWithActionClassName:_pageName actionName:_action];
}
- (id)initWithPageName:(NSString *)_pageName actionName:(NSString *)_action
  product:(SoProduct *)_product
{
  if ((self = [self initWithPageName:_pageName actionName:_action]) != nil) {
    self->product = _product;
  }
  return self;
}

/* accessors */

- (NSString *)pageName {
  return [self actionClassName];
}
- (NSString *)defaultActionClassName {
  return @"Main";
}

/* containment */

- (void)detachFromContainer {
  self->product = nil;
}
- (id)container {
  return self->product;
}
- (NSString *)nameInContainer {
  /* could ask product */
  return nil;
}

/* calling */

- (void)_prepareContext:(id)_ctx withMethodObject:(id)_method {
  /* make page the "request" page */
  [_ctx setPage:_method];
}

- (void)_prepareMethod:(id)_method inContext:(id)_ctx {
  /* apply request parameters */
  WORequest *rq;
  
  rq = [(id <WOPageGenerationContext>)_ctx request];
  if ([_method shouldTakeValuesFromRequest:rq inContext:_ctx]) {
    [[_ctx application] takeValuesFromRequest:rq
			inContext:_ctx];
  }
}

/* page construction */

- (WOComponent *)instantiatePageInContext:(id)_ctx {
  // Careful: this must return a RETAINED object!
  WOResourceManager *rm;
  WOComponent *lPage;
  NSArray     *languages;
  
  if (debugOn) {
    [self debugWithFormat:@"instantiate page: %@", self->methodObject];
    if (self->product == nil)
      [self debugWithFormat:@"  no product is set."];
  }

  if (_ctx == nil) {
    [self debugWithFormat:
	    @"Note: got no explicit context for page instantiation, using "
	    @"application context."];
    _ctx = [[WOApplication application] context];
  }
  
  /* lookup available resource manager (product,component,app) */
  
  if ((rm = [self->product resourceManager]) == nil) {
    if ((rm = [[_ctx component] resourceManager]) == nil) {
      rm = [[_ctx application] resourceManager];
      if (debugOn) [self debugWithFormat:@"   app-rm: %@", rm];
    }
    else
      if (debugOn) [self debugWithFormat:@"   component-rm: %@", rm];
  }
  else
    if (debugOn) [self debugWithFormat:@"   product-rm: %@", rm];
  
  /* determine language */
  
  languages = [_ctx resourceLookupLanguages];

  /* instantiate */
  
  lPage = [rm pageWithName:[self pageName] languages:languages];
  [lPage ensureAwakeInContext:_ctx];
  [lPage setResourceManager:rm];
  
  if (debugOn) [self debugWithFormat:@"   page: %@", lPage];
  
  return [lPage retain];
}
- (id)instantiateMethodInContext:(id)_ctx {
  // Careful: this must return a RETAINED object!
  /* override default method */
  return [self instantiatePageInContext:_ctx];
}

/* binding */

- (id)bindToObject:(id)_object inContext:(id)_ctx {
  SoPageInvocation *inv;
  
  if (_object == nil) return nil;
  
  // TODO: clean up this section, a bit hackish
  inv = [[[self class] alloc] initWithActionClassName:self->actionClassName];
  inv = [inv autorelease];
  
  /* Note: product must be set _before_ instantiate! */
  inv->object       = [_object retain];
  inv->actionName   = [self->actionName copy];
  inv->product      = self->product; // non-owned (cannot be detached !!!)
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
  [_r appendContentString:@"native component method: "];
  [_r appendContentHTMLString:[self description]];
}

/* description */

- (void)appendAttributesToDescription:(NSMutableString *)_ms {
  [super appendAttributesToDescription:_ms];
  if (self->product) [_ms appendFormat:@" product=%@", self->product];
}

/* Logging */

- (NSString *)loggingPrefix {
  return [NSString stringWithFormat:@"[so-page 0x%p %@]", 
		     self, [self pageName]];
}
- (BOOL)isDebuggingEnabled {
  return debugOn ? YES : NO;
}

@end /* SoPageInvocation */
