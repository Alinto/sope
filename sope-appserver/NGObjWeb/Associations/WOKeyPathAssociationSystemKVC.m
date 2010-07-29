/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#include "WOKeyPathAssociation.h"
#include <NGObjWeb/WOComponent.h>
#include "NSObject+WO.h"
#include "common.h"

/*
  WOKeyPathAssociationSystemKVC
  
  This is an WOKeyPathAssociation subclass which uses the KVC methods
  provided in the Foundation library. This is much less performant, but
  much more compatible with WebObjects.
  
  This could be further optimized by doing method caching, using shared
  objects, etc. Yet if you need speed, you should use the default association.
*/

@interface WOKeyPathAssociationSystemKVC : WOKeyPathAssociation
{
  NSString *keyPathString;
  BOOL     hasCaretPrefix;
}

@end

@implementation WOKeyPathAssociationSystemKVC

static NSNumber *yesNum = nil;
static NSNumber *noNum  = nil;

+ (int)version {
  return [super version] + 0; /* v2 */
}
+ (void)initialize {
  if (yesNum == nil) yesNum = [[NSNumber numberWithBool:YES] retain];
  if (noNum  == nil) noNum  = [[NSNumber numberWithBool:NO]  retain];
}

- (id)initWithKeyPath:(NSString *)_keyPath {
  if ((self = [super initWithKeyPath:_keyPath])) {
    self->hasCaretPrefix = 
      (([_keyPath length] > 1) && [_keyPath hasPrefix:@"^"]) ? YES : NO;
    
    if (self->hasCaretPrefix)
      self->keyPathString = [[_keyPath substringFromIndex:1] copy];
    else
      self->keyPathString = [_keyPath copy];
  }
  return self;
}

- (void)dealloc {
  [self->keyPathString release];
  [super dealloc];
}

/* accessors */

- (NSString *)keyPath {
  return self->keyPathString;
}

/* value */

- (void)setValue:(id)_value inComponent:(WOComponent *)_component {
  if (self->hasCaretPrefix)
    [_component setValue:_value forBinding:self->keyPathString];
  else
    [_component takeValue:_value forKeyPath:self->keyPathString];
}
- (id)valueInComponent:(WOComponent *)_component {
  return (self->hasCaretPrefix)
    ? [_component valueForBinding:self->keyPathString]
    : [_component valueForKeyPath:self->keyPathString];
}

- (BOOL)isValueConstant {
  return NO;
}
- (BOOL)isValueSettable {
  return YES;
}

/* special values */

- (void)setUnsignedIntValue:(unsigned int)_v inComponent:(WOComponent *)_wo {
  [self setValue:[NSNumber numberWithUnsignedInt:_v] inComponent:_wo];
}
- (unsigned int)unsignedIntValueInComponent:(WOComponent *)_component {
  return [[self valueInComponent:_component] unsignedIntValue];
}

- (void)setIntValue:(int)_value inComponent:(WOComponent *)_wo {
  [self setValue:[NSNumber numberWithInt:_value] inComponent:_wo];
}
- (int)intValueInComponent:(WOComponent *)_component {
  return [[self valueInComponent:_component] intValue];
}

- (void)setBoolValue:(BOOL)_value inComponent:(WOComponent *)_wo {
  [self setValue:(_value ? yesNum : noNum) inComponent:_wo];
}
- (BOOL)boolValueInComponent:(WOComponent *)_component {
  /* some optimizations, very likely that same objects are used for YES|NO */
  id o;
  
  if ((o = [self valueInComponent:_component]) == nil)
    return NO;
  if (o == yesNum) return YES;
  if (o == noNum)  return NO;
  return [o boolValue];
}

- (void)setStringValue:(NSString *)_value inComponent:(WOComponent *)_wo {
  [self setValue:_value inComponent:_wo];
}
- (NSString *)stringValueInComponent:(WOComponent *)_component {
  return [[self valueInComponent:_component] stringValue];
}

@end /* WOKeyPathAssociationSystemKVC */
