/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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
#include "WOElement+private.h"
#include "decommon.h"

@implementation WOInput

static BOOL takeValueDebugOn = YES;

+ (int)version {
  return [super version] + 0 /* v2 */;
}

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);

  if ((takeValueDebugOn = [ud boolForKey:@"WODebugTakeValues"]))
    NSLog(@"WOInput: WODebugTakeValues on.");
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_associations
  template:(WOElement *)_rootChild
{
  self = [super initWithName:_name associations:_associations
                template:_rootChild];
  if (self) {
    self->containsForm = YES;
    self->name     = OWGetProperty(_associations, @"name");
    self->value    = OWGetProperty(_associations, @"value");
    self->disabled = OWGetProperty(_associations, @"disabled");
    
    /* type is defined by the element itself ... */
    [(NSMutableDictionary *)_associations removeObjectForKey:@"type"];
    
    if ([_associations objectForKey:@"NAME"]) {
      [self warnWithFormat:@"found 'NAME' association in element %@, "
            @"'name' is probably the right thing.", _name];
    }
  }
  return self;
}

- (void)dealloc {
  [self->name     release];
  [self->value    release];
  [self->disabled release];
  [super dealloc];
}

/* form support */

NSString *OWFormElementName(WOInput *self, WOContext *_ctx) {
  NSString *name;
  
  if (self->name == nil)
    return [_ctx elementID];
  
  if ((name = [self->name stringValueInComponent:[_ctx component]]) != nil)
    return name;
  
  [[_ctx component]
         warnWithFormat:
               @"in element %@, 'name' attribute configured (%@),"
               @"but no name assigned (using elementID as name) !",
               self, self->name];
  return [_ctx elementID];
}

/* taking form values */

- (id)parseFormValue:(id)_value inContext:(WOContext *)_ctx {
  /* redefined in subclasses */
  return _value;
}

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  NSString *formName;
  id formValue = nil;
  
  if ([self->disabled boolValueInComponent:[_ctx component]])
    return;
  
  formName = OWFormElementName(self, _ctx);
  if ((formValue = [_req formValueForKey:formName]) == nil)
    // TODO: is this correct?
    return;
  
  if (takeValueDebugOn) {
    [self logWithFormat:
	    @"%s(%@): form=%@ ctx=%@ value=%@ ..", __PRETTY_FUNCTION__,
	    [_ctx elementID], formName, [_ctx contextID], formValue];
  }
  
  if ([self->value isValueSettable]) {
    formValue = [self parseFormValue:formValue inContext:_ctx];
    [self->value setStringValue:formValue inComponent:[_ctx component]];
  }
  else if (self->value != nil) {
    [self logWithFormat:
	    @"%s: form value is not settable: %@", __PRETTY_FUNCTION__,
            self->value];
  }
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;
  
  str = [NSMutableString stringWithCapacity:128];
  if (self->value != nil) [str appendFormat:@" value=%@",    self->value];
  if (self->name  != nil) [str appendFormat:@" name=%@",     self->name];
  
  if (self->disabled) [str appendFormat:@" disabled=%@", self->disabled];
  return str;
}

@end /* WOInput */
