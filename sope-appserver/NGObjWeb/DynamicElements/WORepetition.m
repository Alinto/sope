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

#include <NGObjWeb/WODynamicElement.h>
#include "WOElement+private.h"
#include <NGExtensions/NSString+misc.h>
#include "decommon.h"

@interface WORepetition : WODynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  WOElement *template;
#if DEBUG
  NSString  *repName;
#endif
}

@end /* WORepetition */

@interface _WOComplexRepetition : WORepetition
{
  WOAssociation *list;       // array of objects to iterate through
  WOAssociation *item;       // current item in the array
  WOAssociation *index;      // current index
  WOAssociation *identifier; // unique id for element
  WOAssociation *count;      // number of times the contents will be repeated
  
  // non-WO
  WOAssociation *startIndex;
  WOAssociation *separator;  // string inserted between repetitions
}

@end

@interface _WOSimpleRepetition : WORepetition
{
  WOAssociation *list; // array of objects to iterate through
  WOAssociation *item; // current item in the array
}

@end

@interface _WOTemporaryRepetition : NSObject
@end

//#define PROF_REPETITION_CLUSTER 1

static int descriptiveIDs  = -1;
static int debugTakeValues = -1;

#if PROF_REPETITION_CLUSTER
static int complexCount = 0;
static int simpleCount = 0;
#endif

@implementation _WOTemporaryRepetition

static inline Class _classForConfig(NSDictionary *_config) {
  Class repClass = Nil;
  unsigned c;

  switch ((c = [_config count])) {
    case 0:
      repClass = [_WOSimpleRepetition class];
      break;
    case 1:
      if ([_config objectForKey:@"list"])
        repClass = [_WOSimpleRepetition class];
      else if ([_config objectForKey:@"item"])
        repClass = [_WOSimpleRepetition class];
      break;
    case 2:
      if ([_config objectForKey:@"list"] &&
          [_config objectForKey:@"item"])
        repClass = [_WOSimpleRepetition class];
      break;
    default:
      repClass = [_WOComplexRepetition class];
      break;
  }
  
  if (repClass == Nil)
    repClass = [_WOComplexRepetition class];

  return repClass;
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_template
{
  Class repClass = Nil;

  repClass = _classForConfig(_config);
  
  return [[repClass alloc]
                    initWithName:_name
                    associations:_config
                    template:_template];
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  contentElements:(NSArray *)_contents
{
  Class repClass = Nil;
  
  repClass = _classForConfig(_config);
  
  return [[repClass alloc]
                    initWithName:_name
                    associations:_config
                    contentElements:_contents];
}

@end /* _WOTemporaryRepetition */

@implementation WORepetition

+ (int)version {
  return [super version] + 1 /* v3 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);

  if (debugTakeValues == -1) {
    debugTakeValues = 
      [[NSUserDefaults standardUserDefaults] boolForKey:@"WODebugTakeValues"]
      ? 1 : 0;
    
    if (debugTakeValues) NSLog(@"WORepetition: WODebugTakeValues on.");
  }
}

+ (id)allocWithZone:(NSZone *)zone {
  static Class WORepetitionClass = Nil;
  static _WOTemporaryRepetition *temporaryRepetition = nil;
  
  if (WORepetitionClass == Nil)
    WORepetitionClass = [WORepetition class];
  if (temporaryRepetition == nil)
    temporaryRepetition = [_WOTemporaryRepetition allocWithZone:zone];
  
  return (self == WORepetitionClass)
    ? (id)temporaryRepetition
    : (id)NSAllocateObject(self, 0, zone);
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if (descriptiveIDs == -1) {
    descriptiveIDs = [[[NSUserDefaults standardUserDefaults]
                                       objectForKey:@"WODescriptiveElementIDs"]
                                       boolValue] ? 1 : 0;
  }
  
#if DEBUG
  self->repName = _name ? [_name copy] : (id)@"R";
#endif
  
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->template = RETAIN(_c);
  }
  return self;
}

- (void)dealloc {
  [self->template release];
#if DEBUG
  [self->repName release];
#endif
  [super dealloc];
}

@end /* WORepetition */

@implementation _WOComplexRepetition

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
#if PROF_REPETITION_CLUSTER
    complexCount++;

    if (complexCount % 10 == 0) {
      NSLog(@"REPETITION CLUSTER: %i simple, %i complex",
            simpleCount, complexCount);
    }
#endif
    self->list       = OWGetProperty(_config, @"list");
    self->item       = OWGetProperty(_config, @"item");
    self->index      = OWGetProperty(_config, @"index");
    self->identifier = OWGetProperty(_config, @"identifier");
    self->count      = OWGetProperty(_config, @"count");
    self->startIndex = OWGetProperty(_config, @"startIndex");
    self->separator  = OWGetProperty(_config, @"separator");
  }
  return self;
}

- (void)dealloc {
  [self->separator  release];
  [self->list       release];
  [self->item       release];
  [self->index      release];
  [self->identifier release];
  [self->count      release];
  [self->startIndex release];
  [super dealloc];
}

/* accessors */

- (id)template {
  return self->template;
}

/* OWResponder */

static inline void
_applyIdentifier(_WOComplexRepetition *self,
                 WOComponent *sComponent,
                 NSString *_idx)
{
  NSArray *array;
  unsigned count;

#if DEBUG
  NSCAssert(self->identifier, @"this method is only to be called on objects "
            @"with a specified 'identifier' association !");
#endif

  array = [self->list valueInComponent:sComponent];
  count = [array count];

  if (count > 0) {
    unsigned cnt;

    /* find subelement for unique id */
    
    for (cnt = 0; cnt < count; cnt++) {
      NSString *ident;
      
      if (self->index)
        [self->index setUnsignedIntValue:cnt inComponent:sComponent];

      if (self->item) {
        [self->item setValue:[array objectAtIndex:cnt]
                    inComponent:sComponent];
      }

      ident = [self->identifier stringValueInComponent:sComponent];

      if ([ident isEqualToString:_idx]) {
        /* found subelement with unique id */
        return;
      }
    }
    
    [sComponent logWithFormat:
                  @"WORepetition: array did change, "
                  @"unique-id isn't contained."];
    [self->item  setValue:nil          inComponent:sComponent];
    [self->index setUnsignedIntValue:0 inComponent:sComponent];
  }
}

static inline void
_applyIndex(_WOComplexRepetition *self, WOComponent *sComponent, unsigned _idx)
{
  NSArray *array;
  
  array = [self->list valueInComponent:sComponent];

  if (self->index)
    [self->index setUnsignedIntValue:_idx inComponent:sComponent];

  if (self->item) {
    unsigned count = [array count];

    if (_idx < count) {
      [self->item setValue:[array objectAtIndex:_idx]
                  inComponent:sComponent];
    }
    else {
      [sComponent logWithFormat:
                    @"WORepetition: array did change, index is invalid."];
      [self->item setValue:nil inComponent:sComponent];
    }
  }
}

- (void)takeValuesFromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  // iterate ..
  WOComponent *sComponent;
  NSArray     *array;
  unsigned    aCount;
  unsigned    goCount;

#if DEBUG
  if (descriptiveIDs)
    [_ctx appendElementIDComponent:self->repName];
#endif
  
  sComponent = [_ctx component];
  array      = [self->list valueInContext:_ctx];
  aCount     = [array count];
  
  goCount    = self->count
    ? [self->count unsignedIntValueInComponent:sComponent]
    : aCount;
  
  if (goCount > 0) {
    unsigned startIdx, goUntil;
    unsigned cnt;
    
    startIdx =
      [self->startIndex unsignedIntValueInComponent:sComponent];
    
    if (self->identifier == nil) {
      if (startIdx == 0)
        [_ctx appendZeroElementIDComponent];
      else
        [_ctx appendIntElementIDComponent:startIdx];
    }
    
    if (self->list) {
      goUntil = (aCount > (startIdx + goCount))
        ? startIdx + goCount
        : aCount;
    }
    else
      goUntil = startIdx + goCount;

#if DEBUG
    if (debugTakeValues) {
      [sComponent debugWithFormat:
                    @"%@: name=%@ id='%@' start walking rep (%i-%i) ..",
                    NSStringFromClass([self class]),
                    self->repName,
                    [_ctx elementID],
                    startIdx, goUntil];
    }
#endif
    
    for (cnt = startIdx; cnt < goUntil; cnt++) {
      _applyIndex(self, sComponent, cnt);
      
      if (self->identifier) {
        NSString *s;
        
        s = [self->identifier stringValueInComponent:sComponent];
        [_ctx appendElementIDComponent:s];
      }

      if (debugTakeValues) {
        [[_ctx component] debugWithFormat:@"%@<%@>: "
                                          @"let template take values ..",
                                            [_ctx elementID],
                                            NSStringFromClass([self class])];
      }
      
      [self->template takeValuesFromRequest:_request inContext:_ctx];
      
      if (self->identifier == nil)
        [_ctx incrementLastElementIDComponent];
      else
        [_ctx deleteLastElementIDComponent];
    }
    
    if (self->identifier == nil)
      [_ctx deleteLastElementIDComponent]; // Repetition Index
  }
  else if (debugTakeValues) {
    [[_ctx component] debugWithFormat:
                        @"%@<%@>: takevalues -> no contents to walk ! ..",
                        [_ctx elementID], NSStringFromClass([self class])];
  }
  
#if DEBUG
  if (descriptiveIDs)
    [_ctx deleteLastElementIDComponent];
#endif
}

- (id)invokeActionForRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  WOComponent *sComponent;
  id result = nil;
  id idxId;
  
  sComponent = [_ctx component];

#if DEBUG
  if (descriptiveIDs) {
    if (![[_ctx currentElementID] isEqualToString:self->repName]) {
      [[_ctx session] logWithFormat:@"%s: %@ missing repetition ID 'R' !",
                                      __PRETTY_FUNCTION__, self];
      return nil;
    }
    [_ctx consumeElementID]; // consume 'R'
    [_ctx appendElementIDComponent:self->repName];
  }
#endif
  
  if ((idxId  = [_ctx currentElementID])) {
    [_ctx consumeElementID]; // consume index-id
    
    /* this updates the element-id path */
    [_ctx appendElementIDComponent:idxId];
    
    if (self->identifier)
      _applyIdentifier(self, sComponent, idxId);
    else
      _applyIndex(self, sComponent, [idxId intValue]);
    
    result = [self->template invokeActionForRequest:_request inContext:_ctx];

    [_ctx deleteLastElementIDComponent];
  }
  else {
    [[_ctx session]
           logWithFormat:@"%s: %@: MISSING INDEX ID in URL !",
             __PRETTY_FUNCTION__,
             self];
  }

#if DEBUG
  if (descriptiveIDs)
    [_ctx deleteLastElementIDComponent];
#endif
  
  return result;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSAutoreleasePool *pool;
  WOComponent *sComponent;
  NSArray     *array;
  unsigned    aCount, goCount, startIdx;
  BOOL        doRender;

#if DEBUG
  if (descriptiveIDs)
    [_ctx appendElementIDComponent:self->repName];
#endif
  
  pool       = [[NSAutoreleasePool alloc] init];
  

  doRender   = ![_ctx isRenderingDisabled];
  sComponent = [_ctx component];
  array      = [[self->list valueInContext:_ctx] retain];
  aCount     = [array count];
  startIdx   = [self->startIndex unsignedIntValueInComponent:sComponent];

  goCount    = self->count
    ? [self->count unsignedIntValueInComponent:sComponent]
    : aCount;
  
  if (goCount > 0) {
    unsigned cnt, goUntil;

#if HTML_DEBUG
    // append debugging info
    if (doRender)
      WOResponse_AddString(_response,
                          [NSString stringWithFormat:
                                    @"<!-- WORep. count=%d arraySize=%d -->\n",
                                    goCount, [array count]]);
#endif

    if (self->identifier == nil) {
      if (startIdx == 0)
        [_ctx appendZeroElementIDComponent];
      else
        [_ctx appendIntElementIDComponent:startIdx];
    }

    if (self->list) {
      goUntil = (aCount > (startIdx + goCount))
        ? startIdx + goCount
        : aCount;
    }
    else
      goUntil = startIdx + goCount;
    
    for (cnt = startIdx; cnt < goUntil; cnt++) {
      id ident = nil;
      id lItem;
      
      if ((cnt != startIdx) && (self->separator != nil) && doRender) {
        WOResponse_AddString(_response,
                             [self->separator stringValueInComponent:
                                                sComponent]);
      }
      
      if (self->index)
        [self->index setUnsignedIntValue:cnt inComponent:sComponent];

      lItem = [array objectAtIndex:cnt];
      
      if (self->item) {
        [self->item setValue:lItem inComponent:sComponent];
      }
      else {
        if (!self->index && self->list) {
          [_ctx pushCursor:lItem];
        }
      }

      /* get identifier used for action-links */
      
      if (self->identifier) {
        /* use a unique id for subelement detection */
        ident = [self->identifier stringValueInComponent:sComponent];
        ident = [ident stringByEscapingURL];
        [_ctx appendElementIDComponent:ident];
      }

#if HTML_DEBUG
      /* append debugging info */
      if (doRender)
        WOResponse_AddString(_response, [NSString stringWithFormat:
                                        @"  <!-- iteration=%d -->\n", cnt]);
#endif

      /* append child elements */
      
      [self->template appendToResponse:_response inContext:_ctx];

      /* cleanup */

      if (self->identifier)
        [_ctx deleteLastElementIDComponent];
      else
        [_ctx incrementLastElementIDComponent];
    }

    if (self->identifier == nil)
      [_ctx deleteLastElementIDComponent]; /* repetition index */

    if (!self->item && !self->index &&self->list)
      [_ctx popCursor];

    //if (self->index) [self->index setUnsignedIntValue:0];
    //if (self->item)  [self->item  setValue:nil];
  }
#if HTML_DEBUG
  else {
    if (doRender)
      WOResponse_AddCString(_response, "<!-- repetition with no contents -->");
  }
#endif
  [array release];
  [pool release];
  
#if DEBUG
  if (descriptiveIDs)
    [_ctx deleteLastElementIDComponent];
#endif
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = [NSMutableString stringWithCapacity:32];

  if (self->list)       [str appendFormat:@" list=%@",     self->list];
  if (self->item)       [str appendFormat:@" item=%@",     self->item];
  if (self->index)      [str appendFormat:@" index=%@",    self->index];
  if (self->identifier) [str appendFormat:@" id=%@",       self->identifier];
  if (self->count)      [str appendFormat:@" count=%@",    self->count];
  if (self->template)   [str appendFormat:@" template=%@", self->template];

  return str;
}

@end /* _WOComplexRepetition */

@implementation _WOSimpleRepetition

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
#if PROF_REPETITION_CLUSTER
    simpleCount++;

    if (simpleCount % 10 == 0) {
      NSLog(@"REPETITION CLUSTER: %i simple, %i complex",
            simpleCount, complexCount);
    }
#endif
    self->list = OWGetProperty(_config, @"list");
    self->item = OWGetProperty(_config, @"item");
  }
  return self;
}

- (void)dealloc {
  [self->list release];
  [self->item release];
  [super dealloc];
}

/* processing */

static inline void
_sapplyIndex(_WOSimpleRepetition *self, WOComponent *sComponent, NSArray *array, unsigned _idx)
{
  if (self->item) {
    unsigned count = [array count];

    if (_idx < count) {
      [self->item setValue:[array objectAtIndex:_idx]
                  inComponent:sComponent];
    }
    else {
      [sComponent logWithFormat:
                    @"WORepetition: array did change, index is invalid."];
      [self->item setValue:nil inComponent:sComponent];
    }
  }
}

- (void)takeValuesFromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  // iterate ..
  WOComponent *sComponent;
  NSArray     *array;
  unsigned    aCount;
  unsigned    goCount;

#if DEBUG
  if (descriptiveIDs)
    [_ctx appendElementIDComponent:self->repName];
#endif
  
  sComponent = [_ctx component];
  array      = [self->list valueInContext:_ctx];
  goCount    = aCount = [array count];
  
  if (goCount > 0) {
    unsigned cnt;
    
    [_ctx appendZeroElementIDComponent];
    
#if DEBUG
    if (debugTakeValues) {
      NSLog(@"%s: name=%@ id='%@' start walking rep (count=%i) ..",
	    __PRETTY_FUNCTION__, self->repName, [_ctx elementID], aCount);
    }
#endif
    
    for (cnt = 0; cnt < aCount; cnt++) {
      _sapplyIndex(self, sComponent, array, cnt);
      
#if DEBUG
      if (debugTakeValues) {
	NSLog(@"%s:    %@<%@>: idx[%i] let template take values ..",
	      __PRETTY_FUNCTION__,
	      [_ctx elementID], NSStringFromClass([self class]), cnt);
      }
#endif
      
      [self->template takeValuesFromRequest:_request inContext:_ctx];
      
      [_ctx incrementLastElementIDComponent];
    }
    
    [_ctx deleteLastElementIDComponent]; // Repetition Index
  }
#if DEBUG
  else if (debugTakeValues) {
    NSLog(@"%s: %@<%@>: takevalues -> no contents to walk:\n"
	  @"  component: %@\n"
	  @"  list:      %@\n"
	  @"  count:     %i",
	  __PRETTY_FUNCTION__,
	  [_ctx elementID], NSStringFromClass([self class]),
	  sComponent, array, goCount);
  }
#endif
  
#if DEBUG
  if (descriptiveIDs)
    [_ctx deleteLastElementIDComponent];
#endif
}

- (id)invokeActionForRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  WOComponent *sComponent;
  id result = nil;
  id idxId;
  
  sComponent = [_ctx component];
  
#if DEBUG
  if (descriptiveIDs) {
    if (![[_ctx currentElementID] isEqualToString:self->repName]) {
      [[_ctx session]
             logWithFormat:@"%s: %@ missing repetition ID 'R' !",
               __PRETTY_FUNCTION__, self];
      return nil;
    }
    [_ctx consumeElementID]; // consume 'R'
    [_ctx appendElementIDComponent:self->repName];
  }
#endif
  
  if ((idxId  = [_ctx currentElementID])) {
    int idx;
    
    idx = [idxId intValue];
    [_ctx consumeElementID]; // consume index-id
    
    /* this updates the element-id path */
    [_ctx appendElementIDComponent:idxId];
    
    _sapplyIndex(self, sComponent, 
		 [self->list valueInContext:_ctx], idx);
    
    result = [self->template invokeActionForRequest:_request inContext:_ctx];

    [_ctx deleteLastElementIDComponent];
  }
  else {
    [[_ctx session]
           logWithFormat:@"%s: %@: MISSING INDEX ID in URL !",
             __PRETTY_FUNCTION__,
             self];
  }

#if DEBUG
  if (descriptiveIDs)
    [_ctx deleteLastElementIDComponent];
#endif
  
  return result;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSAutoreleasePool *pool;
  WOComponent *sComponent;
  NSArray     *array;
  unsigned    aCount;

#if DEBUG
  if (descriptiveIDs)
    [_ctx appendElementIDComponent:self->repName];
#endif
  
  pool       = [[NSAutoreleasePool alloc] init];
  
  sComponent = [_ctx component];
  array      = [[self->list valueInContext:_ctx] retain];
  aCount     = [array count];

  if (aCount > 0) {
    unsigned cnt;

#if HTML_DEBUG
    // append debugging info
    WOResponse_AddString(_response,
                         [NSString stringWithFormat:
                                     @"<!-- WORep. count=%d arraySize=%d -->\n",
                                     goCount, [array count]]);
#endif

    [_ctx appendZeroElementIDComponent];
    
    for (cnt = 0; cnt < aCount; cnt++) {
      if (self->item) {
        [self->item setValue:[array objectAtIndex:cnt]
                    inComponent:sComponent];
      }
      else {
        [_ctx pushCursor:[array objectAtIndex:cnt]];
      }
      
#if HTML_DEBUG
      // append debugging info
      WOResponse_AddString(_response, [NSString stringWithFormat:
                                         @"  <!-- iteration=%d -->\n", cnt]);
#endif
      
      /* append child elements */
      
      [self->template appendToResponse:_response inContext:_ctx];

      /* cleanup */
      [self->item setValue:nil inComponent:sComponent];
      
      [_ctx incrementLastElementIDComponent];
      
      if (self->item == nil)
        [_ctx popCursor];
    }

    [_ctx deleteLastElementIDComponent]; /* repetition index */
    
    //if (self->item)  [self->item  setValue:nil];
  }
#if HTML_DEBUG
  else {
    WOResponse_AddCString(_response, "<!-- repetition with no contents -->");
  }
#endif
  
  [array release];
  [pool release];
  
#if DEBUG
  if (descriptiveIDs)
    [_ctx deleteLastElementIDComponent];
#endif
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;
  
  str = [NSMutableString stringWithCapacity:24];
  if (self->list)     [str appendFormat:@" list=%@",     self->list];
  if (self->item)     [str appendFormat:@" item=%@",     self->item];
  if (self->template) [str appendFormat:@" template=%@", self->template];
  return str;
}

@end /* _WOSimpleRepetition */
