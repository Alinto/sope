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

#import <Foundation/NSExpression.h>
#include "common.h"

@implementation NSExpression(EOCoreData)

- (NSPredicate *)asPredicate {
  return nil;
}
- (NSExpression *)asExpression {
  return self;
}

/* key/value archiving */

- (id)initWithKeyValueUnarchiver:(EOKeyValueUnarchiver *)_unarchiver {
  id tmp;

  [self release]; self = nil;
  
  if ((tmp = [_unarchiver decodeObjectForKey:@"constantValue"]) != nil)
    return [[NSExpression expressionForConstantValue:tmp] retain];

  if ((tmp = [_unarchiver decodeObjectForKey:@"keyPath"]) != nil)
    return [[NSExpression expressionForKeyPath:tmp] retain];
  
  if ((tmp = [_unarchiver decodeObjectForKey:@"variable"]) != nil)
    return [[NSExpression expressionForVariable:tmp] retain];
  
  if ((tmp = [_unarchiver decodeObjectForKey:@"function"]) != nil) {
    NSArray *args;
    
    args = [_unarchiver decodeObjectForKey:@"arguments"];
    return [[NSExpression expressionForFunction:tmp arguments:args] retain];
  }
  
  return [[NSExpression expressionForEvaluatedObject] retain];
}

- (void)encodeWithKeyValueArchiver:(EOKeyValueArchiver *)_archiver {
  switch ([self expressionType]) {
  case NSConstantValueExpressionType:
    [_archiver encodeObject:[self constantValue] forKey:@"constantValue"];
    return;
  case NSEvaluatedObjectExpressionType:
    /* encode no marker */
    return;
  case NSVariableExpressionType:
    [_archiver encodeObject:[self variable] forKey:@"variable"];
    return;
  case NSKeyPathExpressionType:
    [_archiver encodeObject:[self keyPath] forKey:@"keyPath"];
    return;
  case NSFunctionExpressionType:
    [_archiver encodeObject:[self function]  forKey:@"function"];
    [_archiver encodeObject:[self arguments] forKey:@"arguments"];
    return;
    
  default:
      NSLog(@"WARNING(%s): could not encode NSExpression: %@!",
	    __PRETTY_FUNCTION__, self);
  }
}

@end /* NSPredicate(EOCoreData) */
