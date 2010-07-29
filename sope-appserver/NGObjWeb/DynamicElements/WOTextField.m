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

/*
  Usage:

    PhoneNumber: WOTextField {
      size               = 30;
      formatter          = session.phoneNumberFormatter;
      formatErrorString  = errorString;
      formatFailedAction = "handleFormattingError";
    };

  The textfield calls the -validationFailed:.. method of the associated
  component if a formatter could not format a value.
*/

@interface WOTextField : WOInput
{
  // inherited: name
  // inherited: value
  // inherited: disabled
@protected
  WOAssociation *numberformat; // string
  WOAssociation *dateformat;   // string
  WOAssociation *formatter;    // WO4
  
  // non WO:
  WOAssociation *size;
}

@end /* WOTextField */

@interface NSObject(UsedKeyPath)
- (NSString *)keyPath;
@end

@implementation WOTextField

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->size         = OWGetProperty(_config, @"size");
    self->formatter    = OWGetProperty(_config, @"formatter");
    self->numberformat = OWGetProperty(_config, @"numberformat");
    self->dateformat   = OWGetProperty(_config, @"dateformat");

    if (self->formatter == nil) {
      if ([_config objectForKey:@"formatterClass"]) {
        id className;
	
        className = [OWGetProperty(_config, @"formatterClass") autorelease];
        className = [className valueInComponent:nil];
        className = NSClassFromString(className);
        className = [[className alloc] init];

        self->formatter = 
	  [[WOAssociation associationWithValue:className] retain];
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
  [self->size         release];
  [super dealloc];
}

/* formatter */

static inline NSFormatter *_getFormatter(WOTextField *self, WOContext *_ctx) {
  // TODO: a DUP to WOText?
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
  else if (self->formatter != nil) {
    fmt = [self->formatter valueInComponent:[_ctx component]];
  }

  return fmt;
}

/* handle requests */

- (id)parseFormValue:(id)_value inContext:(WOContext *)_ctx {
  // TODO: a DUP to WOText?
  NSException *formatException = nil;
  NSString    *keyPath         = nil;
  NSFormatter *fmt;
  NSString    *errorText = nil;
  id          object     = nil;

  if ((fmt = _getFormatter(self, _ctx)) == nil)
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
  NSFormatter *fmt;
  id       obj;
  unsigned s;

  if ([_ctx isRenderingDisabled]) return;

  obj = [self->value valueInComponent:[_ctx component]];
  s   = [self->size  unsignedIntValueInComponent:[_ctx component]];

  if ((fmt = _getFormatter(self, _ctx)) != nil) {
    NSString *formattedObj;

    formattedObj = [fmt editingStringForObjectValue:obj];

#if 0
    if (formattedObj == nil) {
      NSLog(@"WARNING: formatter %@ returned nil string for object %@",
            fmt, obj);
    }
#endif
    obj = formattedObj;
  }
  
  WOResponse_AddCString(_response, "<input type=\"text\" name=\"");
  [_response appendContentHTMLAttributeValue:OWFormElementName(self, _ctx)];
  WOResponse_AddCString(_response, "\" value=\"");
  [_response appendContentHTMLAttributeValue:[obj stringValue]];
  WOResponse_AddChar(_response, '"');
  if (s > 0) {
    WOResponse_AddCString(_response, " size=\"");
    WOResponse_AddUInt(_response, s);
    WOResponse_AddChar(_response, '"');
  }

  if (self->disabled != nil) {
    if ([self->disabled boolValueInComponent:[_ctx component]])
      WOResponse_AddCString(_response, " disabled=\"disabled\"");
  }
  
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  if (self->otherTagString) {
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response,
                         [self->otherTagString stringValueInComponent:
                              [_ctx component]]);
  }
  WOResponse_AddEmptyCloseParens(_response, _ctx);
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;
  
  str = [NSMutableString stringWithCapacity:128];
  [str appendString:[super associationDescription]];

  if (self->size)       [str appendFormat:@" size=%@",      self->size];
  if (self->formatter)  [str appendFormat:@" formatter=%@", self->formatter];
  if (self->dateformat) [str appendFormat:@" dateformat=%@", self->dateformat];
  if (self->numberformat)
    [str appendFormat:@" numberformat=%@", self->numberformat];

  return str;
}

@end /* WOTextField */
