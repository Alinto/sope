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

#include "WOChildComponentReference.h"
#include "WOComponent+private.h"
#include "WOContext+private.h"
#include <NGObjWeb/WOSession.h>
#include <NGObjWeb/WOResponse.h>
#include "common.h"

@interface WOContext(ComponentStackCount)
- (unsigned)componentStackCount;
@end

@implementation WOChildComponentReference

static int profileComponents = -1;
static Class NSDateClass = Nil;

+ (int)version {
  return 2;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);

  if (profileComponents == -1) {
    profileComponents = [[[NSUserDefaults standardUserDefaults]
                                          objectForKey:@"WOProfileComponents"]
                                          boolValue] ? 1 : 0;
  }
  if (NSDateClass == Nil)
    NSDateClass = [NSDate class];
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_associations
  template:(WOElement *)_template
{
  self = [super initWithName:_name associations:nil template:_template];
  if (self) {
    self->childName = [_name copyWithZone:[self zone]];
    self->template  = RETAIN(_template);
  }
  return self;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  RELEASE(self->childName);
  RELEASE(self->template);
  [super dealloc];
}
#endif

/* accessors */

- (NSString *)childName {
  return self->childName;
}

- (id)template {
  return self->template;
}

/* responder */

- (void)takeValuesFromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  WOComponent *parent, *child;
  NSTimeInterval st = 0.0;
  
  if ((parent = [_ctx component]) == nil) {
    [self warnWithFormat:
            @"%s: did not find parent component of child %@",
            __PRETTY_FUNCTION__, self->childName];
    return;
  }
  if ((child = [parent childComponentWithName:self->childName]) == nil) {
    [self warnWithFormat:
            @"did not find child component %@ of parent %@",
            self->childName, [parent name]];
    return;
  }
  
  if (profileComponents)
    st = [[NSDateClass date] timeIntervalSince1970];

  WOContext_enterComponent(_ctx, child, self->template);
  [child takeValuesFromRequest:_request inContext:_ctx];
  WOContext_leaveComponent(_ctx, child);
  
  if (profileComponents) {
    NSTimeInterval diff;
    int i;
    diff = [[NSDateClass date] timeIntervalSince1970] - st;
    for (i = [_ctx componentStackCount]; i >= 0; i--)
      printf("  ");
    printf("[%s %s]: %0.3fs\n",
           [[child name] cString], sel_get_name(_cmd), diff);
  }
}

- (id)invokeActionForRequest:(WORequest *)_request inContext:(WOContext *)_ctx {
  WOComponent    *parent, *child;
  id             result = nil;
  NSTimeInterval st = 0.0;

  if ((parent = [_ctx component]) == nil) {
    [[_ctx session]
           warnWithFormat:@"did not find parent component of child %@",
             self->childName];
    return nil;
  }
  if ((child = [parent childComponentWithName:self->childName]) == nil) {
    [[_ctx session]
           warnWithFormat:
             @"did not find child component %@ of parent %@",
             self->childName, [parent name]];
    return nil;
  }
  
  if (profileComponents)
    st = [[NSDateClass date] timeIntervalSince1970];
  
  WOContext_enterComponent(_ctx, child, self->template);
  result = [child invokeActionForRequest:_request inContext:_ctx];
  WOContext_leaveComponent(_ctx, child);

  if (profileComponents) {
    NSTimeInterval diff;
    int i;
    diff = [[NSDateClass date] timeIntervalSince1970] - st;
    for (i = [_ctx componentStackCount]; i >= 0; i--)
      printf("  ");
    printf("[%s %s]: %0.3fs\n",
           [[child name] cString], sel_get_name(_cmd), diff);
  }

  return result;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *parent, *child;
  NSTimeInterval st = 0.0;
  
  if ((parent = [_ctx component]) == nil) {
    [self warnWithFormat:
            @"%s: did not find parent component of child %@",
            __PRETTY_FUNCTION__, self->childName];
    return;
  }
  if ((child = [parent childComponentWithName:self->childName]) == nil) {
    [self warnWithFormat:
            @"did not find child component %@ of parent %@",
            self->childName, [parent name]];
    if ([_ctx isRenderingDisabled]) return;
    [_response appendContentString:@"<pre>[missing component: "];
    [_response appendContentHTMLString:self->childName];
    [_response appendContentString:@"]</pre>"];
    return;
  }
  
  if (profileComponents)
    st = [[NSDateClass date] timeIntervalSince1970];
  
  WOContext_enterComponent(_ctx, child, self->template);
  [child appendToResponse:_response inContext:_ctx];
  WOContext_leaveComponent(_ctx, child);
  
  if (profileComponents) {
    NSTimeInterval diff;
    int i;
    diff = [[NSDateClass date] timeIntervalSince1970] - st;
    for (i = [_ctx componentStackCount]; i >= 0; i--)
      printf("  ");
    printf("[%s %s]: %0.3fs\n",
           [[child name] cString], sel_get_name(_cmd), diff);
  }
}

@end /* WOChildComponentReference */
