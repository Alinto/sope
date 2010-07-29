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

#include <NGObjWeb/WOElement.h>
#include "WOElement+private.h"
#include <NGObjWeb/WOComponent.h>
#include "common.h"

@implementation WOElement

+ (int)version {
  return 2;
}

static id numStrings[100];

+ (void)initialize {
  static BOOL didInitialize = NO;

  if (!didInitialize) {
    int cnt;
    
    didInitialize = YES;
    
    for (cnt = 0; cnt < 100; cnt++) {
      char buf[8];

      sprintf(buf, "%i", cnt);
      numStrings[cnt] = [[NSString alloc] initWithCString:buf];
    }
  }
}

- (id)init {
  if ((self = [super init])) {
#if !NO_METHOD_CACHING
    self->takeValues = (OWTakeValuesMethod)
      [self methodForSelector:@selector(takeValuesFromRequest:inContext:)];
    self->appendResponse = (OWAppendResponseMethod)
      [self methodForSelector:@selector(appendToResponse:inContext:)];
#else
#  warning methods are not cached !
#endif
  }
  return self;
}

/* element IDs */

- (NSString *)stringForInt:(int)_i {
  NSString *s = nil;
  
  if ((_i < 100) && (_i >= 0)) {
    // MT flaw, should be locked
    s = numStrings[_i];
    if (s == nil) {
      char buf[16];
      sprintf(buf, "%i", _i);
      s = [NSString stringWithCString:buf];
      numStrings[_i] = RETAIN(s);
    }
  }
  else {
    char buf[16];
    sprintf(buf, "%i", _i);
    s = [NSString stringWithCString:buf];
  }
  return s;
}

- (NSString *)elementID {
  return nil;
}

/* OWResponder */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
}

- (id)invokeActionForRequest:(WORequest *)_request inContext:(WOContext *)_ctx {
  return nil;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
}

/* forms */

+ (BOOL)isDynamicElement {
  return NO;
}

// description

- (NSString *)indentString:(int)_indent {
  switch (_indent) {
    case  0: return @"";
    case  2: return @"  ";
    case  4: return @"    ";
    case  6: return @"      ";
    case  8: return @"        ";
    case 10: return @"          ";
    case 12: return @"            ";
    case 14: return @"              ";

    default: {
      int cnt;
      NSMutableString *str = [[NSMutableString alloc] init];
      for (cnt = 0; cnt < _indent; cnt++)
        [str appendString:@" "];
      return AUTORELEASE(str);
    }
  }
}

- (NSString *)elementTreeWithIndent:(int)_indent {
  NSMutableString *str = [[NSMutableString alloc] init];

  [str appendString:[self indentString:_indent]];
  [str appendString:[self description]];
  [str appendString:@"\n"];

  return AUTORELEASE(str);
}

- (NSString *)elementTree {
  return [self elementTreeWithIndent:2];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@[0x%p]>",
                     NSStringFromClass([self class]), self];
}

/* QueryString */

- (NSString *)queryStringForQueryDictionary:(NSDictionary *)_queryDict
  andQueryParameters:(NSDictionary *)_paras
  inContext:(WOContext *)_ctx
{
  NSMutableString *str;
  NSEnumerator    *keys;
  NSString        *key;
  NSString        *value;
  BOOL            isFirst;
  WOComponent     *sComponent;
  NSArray         *paraKeys;

  if ((_queryDict == nil) && (_paras == nil))
    return nil;

  str = [NSMutableString stringWithCapacity:128];
  sComponent = [_ctx component];
  
  isFirst = YES;
  paraKeys = [_paras allKeys];
  
  /* ?style parameters */
  
  keys = [_paras keyEnumerator];
  while ((key = [keys nextObject]) != nil) {
    value = [[_paras objectForKey:key] stringValueInComponent:sComponent];
    value = value != nil ? [value stringByEscapingURL] : (NSString *)@"";
    key   = key   != nil ? [key   stringByEscapingURL] : (NSString *)@"";
    
    if (isFirst) isFirst = NO;
    else [str appendString:@"&"];
    
    [str appendString:key];
    [str appendString:@"="];
    [str appendString:value];
  }
  
  keys = [_queryDict keyEnumerator];
  while ((key = [keys nextObject]) != nil) {
    if([paraKeys containsObject:key])
      /* overridden by a query parameter (?abc=abc) */
      continue;
    
    value = [_queryDict objectForKey:key];
    if ([value isKindOfClass:[NSArray class]]) {
      /* if we bind the queryDictionary to request.formValues */
      NSArray  *values;
      unsigned i, count;

      values = (NSArray *)value;
      for (i = 0, count = [values count]; i < count; i++) {
	value = [values objectAtIndex:i];
        value = [value stringValue];
        value = value ? [value stringByEscapingURL] : (NSString *)@"";
        key   = key   ? [key   stringByEscapingURL] : (NSString *)@"";
        
        if (isFirst) isFirst = NO;
        else [str appendString:@"&"];
	
        [str appendString:key];
        [str appendString:@"="];
        [str appendString:value];
      }
    }
    else {
      value = [value stringValue];
      value = value ? [value stringByEscapingURL] : (NSString *)@"";
      key   = key   ? [key   stringByEscapingURL] : (NSString *)@"";
      
      if (isFirst) isFirst = NO;
      else [str appendString:@"&"];
        
      [str appendString:key];
      [str appendString:@"="];
      [str appendString:value];
    }
  }
  
  return [str isNotEmpty] ? str : (NSMutableString *)nil;
}

@end /* WOElement */

NGObjWeb_DECLARE id OWGetProperty(NSDictionary *_set, NSString *_name) {
  register id propValue;
  
  if ((propValue = [_set objectForKey:_name]) != nil) {
    propValue = [propValue retain];
    [(NSMutableDictionary *)_set removeObjectForKey:_name];
  }
  return propValue;
}
