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

#include "SoSubContext.h"
#include "WOElementID.h"
#include "WOContext+SoObjects.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include "common.h"

@implementation SoSubContext

+ (int)version {
  return [super version] + 0 /* v8 */;
}
+ (void)initialize {
  NSAssert2([super version] == 8,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)initWithParentContext:(WOContext *)_parent {
  if ((self = [super init])) {
    self->parentContext = [_parent retain];

    self->qpJoin = @"&";
    
    self->elementID = [[WOElementID alloc] init];
    self->request   = [[_parent request]  retain];
    self->response  = [[_parent response] retain];
    
    self->traversalStack = [[_parent objectTraversalStack] mutableCopy];
    self->clientObject   = [[_parent clientObject] retain];
    
    self->soRequestType = @"INTERNAL";
  }
  return self;
}
- (id)init {
  return [self initWithParentContext:[[WOApplication application] context]];
}

- (void)dealloc {
  [self->parentContext release];
  [super dealloc];
}

/* accessors */

- (WOContext *)parentContext {
  return self->parentContext;
}
- (WOContext *)rootContext {
  return [[self parentContext] rootContext];
}

/* overrides */

- (NSString *)contextID {
  /* a subcontext currently has no ID */
  /*
    NOTE: a subcontext may *NOT* have the same ID as the parent-context,
          otherwise havoc is done in component activation
  */
  return nil;
}

- (void)setSession:(WOSession *)_session {
  [self logWithFormat:@"ignoring -setSession:%@ on sub-context", _session];
}
- (id)session {
  return [[self parentContext] session];
}

- (BOOL)hasSession {
  return [[self parentContext] hasSession];
}
- (BOOL)savePageRequired {
  return [[self parentContext] savePageRequired];
}

- (void)setPage:(WOComponent *)_page {
  [self logWithFormat:@"ignoring -setPage:%@ on sub-context", _page];
}
- (id)page {
  return [[self parentContext] page];
}

- (NSURL *)serverURL {
  return [[self parentContext] serverURL];
}
- (NSURL *)baseURL {
  return [[self parentContext] baseURL];
}
- (NSURL *)applicationURL {
  return [[self parentContext] applicationURL];
}
- (NSURL *)urlForKey:(NSString *)_key {
  return [[self parentContext] urlForKey:_key];
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<0x%p[%@]: parent=0x%p>",
                     self, NSStringFromClass([self class]),
                     [self parentContext]];
}

@end /* SoSubContext */
