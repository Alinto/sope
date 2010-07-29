/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id: NGObjectMappingContext.m 6 2004-08-20 17:57:50Z helge $

#include "NGObjectMappingContext.h"
#include "common.h"

#define MAX_CONTEXT_DEPTH 16

@implementation NGObjectMappingContext

- (id)init {
  self->objForHandle =
    (void *)[self methodForSelector:@selector(objectForHandle:)];
  self->handleForObj =
    (void *)[self methodForSelector:@selector(handleForObject:)];
  return self;
}

/* mappings */

- (void *)handleForObject:(id)_object {
#if LIB_FOUNDATION_LIBRARY
  return [self subclassResponsibility:_cmd];
#else
  [self doesNotRecognizeSelector:_cmd];
  return NULL;
#endif
}
- (id)objectForHandle:(void *)_handle {
#if LIB_FOUNDATION_LIBRARY
  return [self subclassResponsibility:_cmd];
#else
  [self doesNotRecognizeSelector:_cmd];
  return nil;
#endif
}

- (void)forgetObject:(id)_object {
}
- (void)forgetHandle:(void *)_handle {
}

/* context stack */

static NGObjectMappingContext **ctxs; // THREAD
static unsigned currentContextDepth = 0;

+ (id)activeObjectMappingContext { // THREAD
  return currentContextDepth > 0
    ? ctxs[currentContextDepth - 1]
    : nil;
}

- (void)pushContext { // THREAD
  if (ctxs == NULL) ctxs = calloc(MAX_CONTEXT_DEPTH, sizeof(id));
  ctxs[currentContextDepth] = [self retain];
  currentContextDepth++;

#if DEBUG_CTX_STACK
  if (currentContextDepth == 1)
    printf("PUSHED first 0x%p\n", self);
  else
    printf("PUSHED[%i]: 0x%p, prev 0x%p", 
           currentContextDepth, self, ctxs[currentContextDepth - 2]);
  
  NSAssert([[self class] activeObjectMappingContext] == self,
           @"failed to push self as active mapping context !");
#endif
}
- (id)popContext { // THREAD
  NSAssert(currentContextDepth > 0,
           @"no context is active !");
  NSAssert2(ctxs[currentContextDepth - 1] == self,
            @"current context is not the active context (%@ vs %@) !",
            ctxs[currentContextDepth - 1], self);
  
#if DEBUG_CTX_STACK
  if (currentContextDepth == 1)
    printf("POP first 0x%p\n", self);
  else
    printf("POP[%i]: 0x%p, activate 0x%p", 
           currentContextDepth, self, ctxs[currentContextDepth - 2]);
#endif
  currentContextDepth--;
  ctxs[currentContextDepth] = nil;
  return [self autorelease];
}

- (void)collectGarbage {
}

/* NSCoding */

- (id)initWithCoder:(NSCoder *)_coder {
  id ctx;
  
  /* if an context is active, use that */
  if ((ctx = [[self class] activeObjectMappingContext])) {
    [self release];
    return [ctx retain];
  }
  
  /* otherwise init a new context ... */
  return [self init];
}
- (void)encodeWithCoder:(NSCoder *)_coder {
  /* no ivars to encode ... */
}

@end /* NGObjectMappingContext */

id NGObjectMapping_GetObjectForHandle(void *_handle) {
  register NGObjectMappingContext *ctx;
  
  if (currentContextDepth < 1) return nil;
  ctx = ctxs[currentContextDepth - 1];
  
  return ctx->objForHandle(ctx, @selector(objectForHandle:), _handle);
}
void *NGObjectMapping_GetHandleForObject(id _object) {
  register NGObjectMappingContext *ctx;
  
  if (currentContextDepth < 1) return nil;
  ctx = ctxs[currentContextDepth - 1];
  
  return ctx->handleForObj(ctx, @selector(handleForObject:), _object);
}
