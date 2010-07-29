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

#include "WOInput.h"
#include "decommon.h"
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSDateFormatter.h>

@interface WOText : WOInput
{
  // inherited: name
  // inherited: value
  // inherited: disabled
@protected
  // non WO:
  WOAssociation *rows;
  WOAssociation *cols;
  WOAssociation *numberformat; // string
  WOAssociation *dateformat;   // string
  WOAssociation *formatter;
}

@end /* WOText */

@interface NSObject(UsedKeyPath)
- (NSString *)keyPath;
@end

@implementation WOText

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{

  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->rows         = OWGetProperty(_config, @"rows");
    self->cols         = OWGetProperty(_config, @"cols");
    self->formatter    = OWGetProperty(_config, @"formatter");
    self->numberformat = OWGetProperty(_config, @"numberformat");
    self->dateformat   = OWGetProperty(_config, @"dateformat");
    
    if (self->formatter == nil) {
      if ([_config objectForKey:@"formatterClass"] != nil) {
        id className;

        className = OWGetProperty(_config, @"formatterClass");
        className = [className autorelease];
        
        className = [className valueInComponent:nil];
        className = NSClassFromString(className);
        className = [[className alloc] init];

        self->formatter = [WOAssociation associationWithValue:className];
        self->formatter = [self->formatter retain];
        [className release];
      }
    }

    // check formats
    {
      int num = 0;
      if (self->formatter)    num++;
      if (self->numberformat) num++;
      if (self->dateformat)   num++;
      if (num > 1)
        NSLog(@"WARNING: more than one formats specified in element %@", self);
    }
  }
  return self;
}

- (void)dealloc {
  [self->numberformat release];
  [self->dateformat   release];
  [self->formatter    release];
  [self->rows         release];
  [self->cols         release];
  [super dealloc];
}

/* formatter */

static inline NSFormatter *_getFormatter(WOText *self, WOContext *_ctx) {
  NSFormatter *fmt = nil;
  
  if (self->numberformat != nil) {
    fmt = [[[NSNumberFormatter alloc] init] autorelease];
    [(NSNumberFormatter *)fmt setFormat:
        [self->numberformat valueInComponent:[_ctx component]]];
  }
  else if (self->dateformat != nil) {
    fmt = [[NSDateFormatter alloc]
                            initWithDateFormat:
                              [self->dateformat valueInComponent:
                                                  [_ctx component]]
                            allowNaturalLanguage:NO];
    fmt = [fmt autorelease];
  }
  else if (self->formatter) {
    fmt = [self->formatter valueInComponent:[_ctx component]];
  }

  return fmt;
}

/* handle requests */

- (id)parseFormValue:(id)_value inContext:(WOContext *)_ctx {
  NSFormatter *fmt;
  NSException *formatException = nil;
  NSString    *keyPath         = nil;
  NSString *errorText = nil;
  id       object     = nil;

  fmt = _getFormatter(self, _ctx);
  if (fmt == nil)
    return [super parseFormValue:_value inContext:_ctx];

  //fmt = [self->formatter valueInComponent:[_ctx component]];

  if ([fmt getObjectValue:&object forString:[_value stringValue]
             errorDescription:&errorText]) {

      return object;
  }

      
  if ([self->value respondsToSelector:@selector(keyPath)])
    keyPath = [(id)self->value keyPath];

  formatException = [NSException exceptionWithName:@"WOValidationException"
                                     reason:errorText
                                     userInfo:nil];
  
  [[_ctx component] validationFailedWithException:formatException
		    value:_value
		    keyPath:keyPath];
  return nil;
}

/* generate response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  NSFormatter *fmt;
  id          v;
  unsigned    r;
  unsigned    c;
  
  if ([_ctx isRenderingDisabled]) return;

  sComponent = [_ctx component];
  v  = [self->value valueInComponent:sComponent];
  r  = [self->rows  unsignedIntValueInComponent:sComponent];
  c  = [self->cols  unsignedIntValueInComponent:sComponent];
  
  fmt = _getFormatter(self, _ctx);
  if (fmt) {
    NSString *formattedObj = nil;

    formattedObj = [fmt editingStringForObjectValue:v];
    v = formattedObj;
  }
  else
    v = [v stringValue];
  
  WOResponse_AddCString(_response, "<textarea name=\"");
  [_response appendContentHTMLAttributeValue:OWFormElementName(self, _ctx)];
  WOResponse_AddChar(_response, '"');
  if (r > 0) {
    WOResponse_AddCString(_response, " rows=\"");
    WOResponse_AddUInt(_response, r);
    WOResponse_AddChar(_response, '"');
  }
  if (c > 0) {
    WOResponse_AddCString(_response, " cols=\"");
    WOResponse_AddUInt(_response, c);
    WOResponse_AddChar(_response, '"');
  }

  if ([self->disabled boolValueInComponent:sComponent])
    WOResponse_AddCString(_response, " disabled=\"disabled\"");
  
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  if (self->otherTagString) {
    NSString *s;

    s = [self->otherTagString stringValueInComponent:[_ctx component]];
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response, s);
  }
  WOResponse_AddChar(_response, '>');

  if ([v length] > 0) {
    BOOL     removeCR = NO;
    NSString *ua;
    
    ua = [[_ctx request] headerForKey:@"user-agent"];
    
    if ([ua rangeOfString:@"Opera"].length > 0)
      removeCR = YES;
    
    if (removeCR)
      v = [v stringByReplacingString:@"\r" withString:@""];
    
    [_response appendContentHTMLString:v];
  }
  
  WOResponse_AddCString(_response, "</textarea>");
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = nil;
  
  str = [NSMutableString stringWithCapacity:64];
  [str appendString:[super associationDescription]];
  
  if (self->rows)       [str appendFormat:@" rows=%@", self->rows];
  if (self->cols)       [str appendFormat:@" cols=%@", self->cols];
  if (self->formatter)  [str appendFormat:@" formatter=%@", self->formatter];
  if (self->dateformat) [str appendFormat:@" dateformat=%@", self->dateformat];
  if (self->numberformat)
    [str appendFormat:@" numberformat=%@", self->numberformat];
  
  return str;
}

@end /* WOText */
