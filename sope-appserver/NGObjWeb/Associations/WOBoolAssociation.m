/*
  Copyright (C) 2017 Inverse inc.

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

#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOComponent.h>

#import "WOBoolAssociation.h"

@implementation WOBoolAssociation

- (id) initWithString: (NSString *) _string
{
  return [self initWithValue: _string];
}

- (id) initWithValue: (id) _value
{
  if ((self = [super init])) {
    self->value = [_value retain];
  }
  return self;
}

- (void) dealloc
{
  [self->value release];
  [super dealloc];
}

- (id) valueInComponent: (WOComponent *) _component
{
  return [self boolValueInComponent: _component]? [NSNumber numberWithBool: YES] : nil;
}

- (BOOL) boolValueInComponent: (WOComponent *) _component
{
  SEL selector;

  selector = NSSelectorFromString(value);
  if ([_component respondsToSelector: selector])
      return [_component performSelector: selector]? YES : NO;

  return NO;
}

- (BOOL) isValueConstant
{
  return NO;
}

- (BOOL) isValueSettable
{
  return NO;
}

@end
