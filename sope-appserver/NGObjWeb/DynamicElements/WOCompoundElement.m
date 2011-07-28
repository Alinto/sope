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

#include "WOCompoundElement.h"
#include "WOElement+private.h"
#include <NGObjWeb/WOContext.h>
#include "decommon.h"

#if APPLE_RUNTIME || NeXT_RUNTIME
#  include <objc/objc-class.h>
#endif

@interface WOContext(ComponentStackCount)
- (unsigned)componentStackCount;
@end

@implementation WOCompoundElement

#ifdef DEBUG
static int profElements = -1;
static int embedInPool  = -1;
static int logId        = -1;
static Class NSDateClass = Nil;
#endif
static int descriptiveIDs = -1;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

  if (descriptiveIDs == -1) {
    descriptiveIDs =
      [[ud objectForKey:@"WODescriptiveElementIDs"] boolValue] ? 1 : 0;
  }

#if DEBUG
  if (profElements == -1) {
    profElements = [[[NSUserDefaults standardUserDefaults]
                                     objectForKey:@"WOProfileElements"]
                                     boolValue] ? 1 : 0;
  }
  if (embedInPool == -1) {
    embedInPool = [[[NSUserDefaults standardUserDefaults]
                                    objectForKey:@"WOCompoundElementPool"]
                                    boolValue] ? 1 : 0;
    NSLog(@"WOCompoundElement: pool embedding is on.");
  }
  if (logId == -1) {
    logId = [[[NSUserDefaults standardUserDefaults]
                              objectForKey:@"WOCompoundElementLogID"]
                              boolValue] ? 1 : 0;
    NSLog(@"WOCompoundElement: id logging is on.");
  }
#endif
}

+ (id)allocForCount:(int)_count zone:(NSZone *)_zone {
  return NSAllocateObject(self, _count * sizeof(WOElement *), _zone);
}

- (id)initWithContentElements:(NSArray *)_children {
  WOElement *(*objAtIdx)(id, SEL, int);
  int i;
  
  if (_children == nil) {
    NSLog(@"%@: invalid argument ..", self);
    self = [self autorelease];
    return nil;
  }
  
  self = [super init];

  objAtIdx = (void *)[_children methodForSelector:
                                @selector(objectAtIndex:)];
  NSAssert1(objAtIdx != NULL,
            @"could not get -objectAtIndex: method of %@",
            _children);
  
  self->count = [_children count];
  for (i = (self->count - 1); i >= 0; i--) {
    register WOElement *child;
    
    child = objAtIdx(_children, @selector(objectAtIndex:), i);
    
    self->children[i] = [child retain];
  }
  return self;
}

- (id)initWithChildren:(NSArray *)_children {
  return [self initWithContentElements:_children];
}
- (id)init {
  return [self initWithContentElements:nil];
}

- (void)dealloc {
  int i;
  for (i = 0; i < self->count; i++) {
    [self->children[i] release];
    self->children[i] = nil;
  }
  [super dealloc];
}

/* accessors */

- (NSArray *)subelements {
  if (self->count == 0)
    return nil;

  return [NSArray arrayWithObjects:self->children count:self->count];
}

/* responder */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  void (*incId)(id, SEL);
  unsigned short i;

  incId = (void *)
    [_ctx methodForSelector:@selector(incrementLastElementIDComponent)];

  if (descriptiveIDs)
    [_ctx appendElementIDComponent:@"c0"];
  else
    [_ctx appendZeroElementIDComponent];
  
  for (i = 0; i < self->count; i++) {
    register WOElement *child = self->children[i];
    
    if (child->takeValues) {
      child->takeValues(child,
                        @selector(takeValuesFromRequest:inContext:),
                        _rq, _ctx);
    }
    else
      [child takeValuesFromRequest:_rq inContext:_ctx];
    
    if (descriptiveIDs) {
      [_ctx deleteLastElementIDComponent];
      [_ctx appendElementIDComponent:
              [NSString stringWithFormat:@"c%i", i]];
    }
    else
      incId(_ctx, @selector(incrementLastElementIDComponent));
  }
  [_ctx deleteLastElementIDComponent];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  id result = nil;
  id idxId;
  
  if ((idxId = [_ctx currentElementID])) {
    int idx = [idxId intValue];

    idx = (descriptiveIDs)
      ? [[idxId substringFromIndex:1] intValue]
      : [idxId intValue];
    
    [_ctx consumeElementID]; // consume index-id
    
    if ((idx < 0) || (idx >= self->count)) {
      [[_ctx session] logWithFormat:
                        @"%s: invalid element id, %i is out of range (0-%i) !",
                        __PRETTY_FUNCTION__,
                        idx, (self->count - 1)];
      return nil;
    }
    
    [_ctx appendElementIDComponent:idxId];
    result = [self->children[idx] invokeActionForRequest:_rq inContext:_ctx];
    [_ctx deleteLastElementIDComponent];
  }
  else {
    [[_ctx session]
           logWithFormat:@"%s: MISSING INDEX ID in URL: %@ !",
             __PRETTY_FUNCTION__,
             [_ctx senderID]];
  }
  return result;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  static int depth = 0;
  void (*incId)(id, SEL);
  unsigned short i;
#if DEBUG
#if USE_EXCEPTION_HANDLER
  static NSString *cName  = @"componentName";
  static NSString *elemId = @"elementID";
#endif
  NSTimeInterval st = 0.0;
  
  if (NSDateClass == Nil)
    NSDateClass = [NSDate class];
#endif

  depth++;
  
#if defined(DEBUG) && USE_EXCEPTION_HANDLER
  NS_DURING {
#endif

#ifdef DEBUG
    if (profElements)
      st = [[NSDateClass date] timeIntervalSince1970];
#endif
    
    incId = (void *)
      [_ctx methodForSelector:@selector(incrementLastElementIDComponent)];
    
    if (descriptiveIDs)
      [_ctx appendElementIDComponent:@"c0"];
    else
      [_ctx appendZeroElementIDComponent];
    
    for (i = 0; i < self->count; i++) {
      register WOElement *child = self->children[i];
#if DEBUG
      NSAutoreleasePool *pool = nil;
      NSTimeInterval st = 0.0;
      if (embedInPool) pool = [[NSAutoreleasePool alloc] init];
      if (profElements)
        st = [[NSDateClass date] timeIntervalSince1970];
#endif
      
      if (child->appendResponse) {
        child->appendResponse(child,
                              @selector(appendToResponse:inContext:),
                              _response, _ctx);
      }
      else
        [child appendToResponse:_response inContext:_ctx];
      
#if DEBUG
      if (profElements) {
        NSTimeInterval diff;
        int j;
        diff = [[NSDateClass date] timeIntervalSince1970] - st;
        if (diff > 0.0005) {
#if 1
          for (j = [_ctx componentStackCount] + depth; j >= 0; j--)
            printf("  ");
#endif
          printf("  Child of 0x%p: i[%i] %s <%s>: %0.3fs\n",
#if (defined(__GNU_LIBOBJC__) && (__GNU_LIBOBJC__ == 20100911)) || defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
				 self, i, [[_ctx elementID] cString], class_getName([child class]),
#else
                 self, i, [[_ctx elementID] cString], [child class]->name,
#endif
				 diff);
        }
      }
      if (logId) {
        NSLog(@"WOCompoundElement: pool will release ... (lastId=%@)",
              [_ctx elementID]);
      }
      [pool release];
#endif

      if (descriptiveIDs) {
        [_ctx deleteLastElementIDComponent];
        [_ctx appendElementIDComponent:
                [NSString stringWithFormat:@"c%i", i]];
      }
      else
        incId(_ctx, @selector(incrementLastElementIDComponent));
    }
    [_ctx deleteLastElementIDComponent];

#if DEBUG
    if (profElements) {
      NSTimeInterval diff;
      int i;
      diff = [[NSDateClass date] timeIntervalSince1970] - st;
#if 1
      for (i = [_ctx componentStackCount] + depth; i >= 0; i--)
        printf("  ");
#endif
      printf("CompoundElem0x%p(#%i) %s (component=%s): %0.3fs\n",
             self, self->count, [[_ctx elementID] cString],
             [[(WOComponent *)[_ctx component] name] cString],
             diff);
    }
#endif
    
#if defined(DEBUG) && USE_EXCEPTION_HANDLER
  }
  NS_HANDLER {
    NSMutableDictionary *ui;
    id tmp;
    
    ui = [[localException userInfo] mutableCopy];
    if (ui == nil) ui = [[NSMutableDictionary alloc] init];
    
    if ((tmp = [ui objectForKey:cName]) == nil)
      [ui setObject:[[_ctx component] name] forKey:cName];
    if ((tmp = [ui objectForKey:elemId]) == nil)
      [ui setObject:[_ctx elementID] forKey:elemId];

    [localException setUserInfo:ui];
    [ui release]; ui = nil;
    
    [localException raise];
  }
  NS_ENDHANDLER;
#endif

  depth--;
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = [NSMutableString stringWithCapacity:256];
  int i;

  [str appendString:@"children=\n"];
  for (i = 0; i < self->count; i++) {
    [str appendString:@"  "];
    [str appendString:[self->children[i] description]];
    [str appendString:@"\n"];
  }
  return str;
}

@end /* WOCompoundElement */

@implementation WOHTMLStaticGroup

/* this element was discovered in SSLContainer.h and may not be public */

@end /* WOHTMLStaticGroup */
