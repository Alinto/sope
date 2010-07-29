/*
  Copyright (C) 2005 SKYRIX Software AG

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

/*
  WOCopyValue / <var:copy-value/>
  
  Usage:
    SetupContext: WOCopyValue {
      currentDate = "currentItem.date";
      copyValues = {
        "displayGroup.queryMin.lastModified" = "currentItem.date";
        "displayGroup.queryMax.lastModified" = "currentItem.date";
      };
      finishValues = {
        "displayGroup.queryMin.lastModified" = nil;
        "displayGroup.queryMax.lastModified" = nil;
      };
      resetValues = NO;
    }

  Bindings:
    copyValues
    finishValues
    resetValues
    <extra>: are used as 'prepare' values
  
  The element has a template and can be used in a certain scope,
*/

@interface WOCopyValue : WODynamicElement // TODO: should be WOElement?
{
  WOAssociation **targets;
  WOAssociation **sources;
  unsigned      count;
  WOElement     *template;
  WOAssociation *copyValues;
  WOAssociation *finishValues;
  WOAssociation *resetValues;
}

@end

#include <NGObjWeb/WOAssociation.h>
#include <NGObjWeb/WOContext.h>
#include "common.h"

@implementation WOCopyValue

// TODO: cache NSString class, cache constant objects

static inline id valueForConstString(NSString *v) {
  unsigned len;
  unichar  c0;
  id vr;

  len = [v length];
  c0  = len > 6 ? [v characterAtIndex:6] : 0;
	  
  if ((len == 9  && c0 == 'n' && [v isEqualToString:@"const:nil"]) ||
      (len == 10 && c0 == 'n' && [v isEqualToString:@"const:null"])) {
    vr = [NSNull null];
  }
  else if ((len == 9  && c0 == 'y' && [v isEqualToString:@"const:yes"]) ||
	   (len == 10 && c0 == 't' && [v isEqualToString:@"const:true"])) {
    vr = [NSNumber numberWithBool:NO];
  }
  else if ((len == 8  && c0 == 'n' && [v isEqualToString:@"const:no"]) ||
	   (len == 11 && c0 == 'f' && [v isEqualToString:@"const:false"])) {
    vr = [NSNumber numberWithBool:NO];
  }
  else if (isdigit(c0) || (c0 == '-' && len > 7)) {
    vr = [v substringFromIndex:6];
    vr = ([vr rangeOfString:@"."].length > 0)
      ? [NSNumber numberWithDouble:[vr doubleValue]]
      : [NSNumber numberWithDouble:[vr intValue]];
  }
  else
    vr = [v substringFromIndex:6];

  return vr;
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    NSDictionary *statVals = nil;
    
    self->template = [_c retain];
    self->copyValues   = OWGetProperty(_config, @"copyValues");
    self->finishValues = OWGetProperty(_config, @"finishValues");
    self->resetValues  = OWGetProperty(_config, @"resetValues");

    /* fill static value array */
    
    if ([self->copyValues isValueConstant]) {
      statVals = [[self->copyValues valueInContext:nil] retain];
      [self->copyValues release];
      self->copyValues = nil;
    }
    
    if ((self->count = ([statVals count] + [_config count])) > 0) {
      NSEnumerator *e;
      NSString *key;
      unsigned i;
      
      self->targets = calloc(self->count + 2, sizeof(id));
      self->sources = calloc(self->count + 2, sizeof(id));
      i = 0;
      
      /* extra keys first (key is a string, value is an assoc) */

      e = [_config keyEnumerator];
      while ((key = [e nextObject]) != nil) {
	self->targets[i] = [[WOAssociation associationWithKeyPath:key] retain];
	self->sources[i] = [[_config objectForKey:key] retain];
	i++;
      }
      
      /* then static keys (key and value are strings) */
      
      e = [statVals keyEnumerator];
      while ((key = [e nextObject]) != nil) {
	NSString *v;
	
	v = [statVals objectForKey:key];
	self->targets[i] = [[WOAssociation associationWithKeyPath:key] retain];
	
	if ([v hasPrefix:@"const:"]) {
	  self->sources[i] =
	    [[WOAssociation associationWithValue:valueForConstString(v)]
	                    retain];
	}
	else {
	  self->sources[i] =
	    [[WOAssociation associationWithKeyPath:v] retain];
	}
	i++;
      }
    }
    
    [statVals release]; statVals = nil;
  }
  return self;
}

- (void)dealloc {
  unsigned i;
  
  [self->finishValues release];
  [self->resetValues  release];
  
  for (i = 0; i < self->count; i++) {
    [self->targets[i] release];
    [self->sources[i] release];
  }
  if (self->targets != NULL) free(self->targets);
  if (self->sources != NULL) free(self->sources);
  
  [self->template release];
  [super dealloc];
}

/* accessors */

- (id)template {
  return self->template;
}

/* copy */

- (void)copyValuesInDictionary:(NSDictionary *)_d inContext:(WOContext *)_ctx {
  NSEnumerator *e;
  NSString *key;
  id setCursor, getCursor;
  
  setCursor = [_ctx component];
  getCursor = setCursor;
  
  e = [_d keyEnumerator];
  while ((key = [e nextObject]) != nil) {
    id value;
    
    value = [_d objectForKey:key];
    if ([value isKindOfClass:[NSString class]]) {
      value = [(NSString *)value hasPrefix:@"const:"]
	? valueForConstString(value)
	: [getCursor valueForKeyPath:value];
    }
    
    [setCursor takeValue:value forKeyPath:key];
  }
}

- (void)copyValuesInContext:(WOContext *)_ctx {
  unsigned i;
  
  /* copy constant mappings */
  for (i = 0; i < self->count; i++) {
    [self->targets[i] setValue:[self->sources[i] valueInContext:_ctx]
	              inContext:_ctx];
  }
  
  /* copy dynamic mappings */
  if (self->copyValues != nil) {
    [self copyValuesInDictionary:[self->copyValues valueInContext:_ctx]
	  inContext:_ctx];
  }
}

- (void)resetValuesInContext:(WOContext *)_ctx {
  if (self->resetValues == nil && self->finishValues == nil)
    return;
  
  /* reset values to nil */
  
  if ([self->resetValues boolValueInContext:_ctx]) {
    unsigned i;
    
    for (i = 0; i < self->count; i++)
      [self->targets[i] setValue:nil inContext:_ctx];
  }
  
  /* apply post value copy */
  if (self->finishValues != nil) {
    [self copyValuesInDictionary:[self->finishValues valueInContext:_ctx]
	  inContext:_ctx];
  }
}

/* handling requests */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  [self copyValuesInContext:_ctx];
  [self->template takeValuesFromRequest:_rq inContext:_ctx];
  [self resetValuesInContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  id result;
  
  [self copyValuesInContext:_ctx];
  result = [[self->template invokeActionForRequest:_rq inContext:_ctx] retain];
  [self resetValuesInContext:_ctx];
  
  return [result autorelease];
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  [self copyValuesInContext:_ctx];
  [self->template appendToResponse:_response inContext:_ctx];
  [self resetValuesInContext:_ctx];
}

@end /* WOCopyValue */
