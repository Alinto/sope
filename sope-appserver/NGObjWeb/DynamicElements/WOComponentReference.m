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

#include "WOComponentReference.h"
#include "WOElement+private.h"
#include "WOContext+private.h"
#include "WOComponent+private.h"
#include "decommon.h"

@interface WOContext(ComponentStackCount)
- (unsigned)componentStackCount;
@end

@implementation WOComponentReference

static int   profileComponents = -1;
static BOOL  coreOnRecursion   = NO;
static BOOL  debugOn           = NO;
static Class NSDateClass = Nil;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  profileComponents = [[ud objectForKey:@"WOProfileComponents"]
			   boolValue] ? 1 : 0;
  coreOnRecursion = [ud boolForKey:@"WOCoreOnRecursiveSubcomponents"];
  NSDateClass = [NSDate class];
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->containsForm    = YES;
    self->activeComponent = OWGetProperty(_config, @"component");
    self->bindings        = [_config copyWithZone:[self zone]];
    [(NSMutableDictionary *)_config removeAllObjects];
    
    self->template = [_c retain];
  }
  return self;
}

- (void)dealloc {
  [self->template        release];
  [self->bindings        release];
  [self->activeComponent release];
  [self->child           release];
  [super dealloc];
}

/* accessors */

- (WOComponent *)childComponent {
  return self->child; // THREAD
}

static inline void
_updateComponent(WOComponentReference *self, WOContext *_ctx)
{
  /*
    Note: this is rather dangerous. We keep a processing state - the 'child'
          ivar containing the component - inside the dynamic element. Yet
          elements are supposed to be stateless.
          
          As long as we are single-threaded this should not be a problem, but
          keep in mind that this element is NOT reentrant.
  */
  // THREAD
  WOComponent *newChild;
  
  if (self->activeComponent == nil)
    return;

  newChild = [self->activeComponent valueInComponent:[_ctx component]];
#if 0
  if (newChild == nil) {
    [[_ctx component] logWithFormat:
                        @"missing child (got nil) "
                        @"(element=%@, association=%@, component=%@).",
                        self, self->activeComponent,
                        [[_ctx component] name]];
  }
#endif
    
  if (newChild != self->child) { // THREAD
#if 0
    NSLog(@"switched component %@ => %@ ...",
          [self->child name], [newChild name]);
#endif
    ASSIGN(self->child, newChild);
    [newChild setParent:[_ctx component]];
    [newChild setBindings:self->bindings];
  }
}

/* handling requests */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOComponent *parent;

  parent = [_ctx component];
  
  _updateComponent(self, _ctx);

  if (self->child != nil) {
    [_ctx enterComponent:self->child content:self->template];
    [self->child takeValuesFromRequest:_req inContext:_ctx];
    [_ctx leaveComponent:self->child];
  }
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOComponent *parent;
  id result    = nil;

  parent = [_ctx component];

  _updateComponent(self, _ctx);

  if (self->child != nil) {
    [_ctx enterComponent:self->child content:self->template];
    result = [self->child invokeActionForRequest:_req inContext:_ctx];
    [_ctx leaveComponent:self->child];
  }
  
  return result;
}

/* generate response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *parent;
  
  parent = [_ctx component];
  
  _updateComponent(self, _ctx);
  
  if (self->child == parent) {
    [self warnWithFormat:@"recursive call of component: %@", parent];
    if (coreOnRecursion)
      abort();
  }
  
  if (self->child != nil) {
    NSTimeInterval st = 0.0;

    if (profileComponents)
      st = [[NSDateClass date] timeIntervalSince1970];
    
    [_ctx enterComponent:self->child content:self->template];
    [self->child appendToResponse:_response inContext:_ctx];
    [_ctx leaveComponent:self->child];

    if (profileComponents) {
      NSTimeInterval diff;
      int i;
      diff = [[NSDateClass date] timeIntervalSince1970] - st;
      for (i = [_ctx componentStackCount]; i >= 0; i--)
        printf("  ");
      printf("[%s %s]: %0.3fs\n",
             [[child name] cString], 
#if APPLE_RUNTIME || NeXT_RUNTIME
	     sel_getName(_cmd), 
#else
	     sel_get_name(_cmd), 
#endif
	     diff);
    }
  }
  else if (debugOn) {
    [self debugWithFormat:@"missing component for reference: %@",
	    self->activeComponent];
    if (![_ctx isRenderingDisabled]) {
      [_response appendContentHTMLString:@"[missing component for reference: "];
      [_response appendContentHTMLString:[self->activeComponent description]];
      [_response appendContentHTMLString:@"]"];
    }
  }
}

/* description */

- (NSString *)description {
  NSMutableString *desc;
  
  desc = [NSMutableString stringWithCapacity:64];
  [desc appendFormat:@"<%@[0x%p]:", NSStringFromClass([self class]), self];
  
  if (self->child != nil) {
    [desc appendFormat:@" child=%@[0x%p] childName=%@",
            NSStringFromClass([self->child class]),
            self->child, [self->child name]];
  }
  
  [desc appendString:@">"];
  return desc;
}

@end /* WOComponentReference */
