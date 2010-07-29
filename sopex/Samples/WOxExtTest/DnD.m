/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id: DnD.m 1 2004-08-20 11:17:52Z znek $

#import <NGObjWeb/WOComponent.h>

@interface DnD : WOComponent
@end

#include "common.h"

@implementation DnD

- (void)awake {
  [super awake];
  [self setObject:nil forKey:@"lastDropOn"];
}

- (NSArray *)oneList {
  return [NSArray arrayWithObject:@"one"];
}
- (NSArray *)twoList {
  return [NSArray arrayWithObject:@"two"];
}
- (NSArray *)listOneTwo {
  return [NSArray arrayWithObjects:@"one", @"two", nil];
}

- (BOOL)droppedOnOne {
  return [[self objectForKey:@"lastDropOn"] isEqualToString:@"one"];
}
- (BOOL)droppedOnTwo {
  return [[self objectForKey:@"lastDropOn"] isEqualToString:@"two"];
}
- (BOOL)droppedOnOneTwo {
  return [[self objectForKey:@"lastDropOn"] isEqualToString:@"oneTwo"];
}

- (id)one {
  NSLog(@"one: dropped %@", [self objectForKey:@"droppedObject"]);
  [self setObject:@"one" forKey:@"lastDropOn"];
  return nil;
}
- (id)two {
  NSLog(@"two: dropped %@", [self objectForKey:@"droppedObject"]);
  [self setObject:@"two" forKey:@"lastDropOn"];
  return nil;
}
- (id)oneTwo {
  NSLog(@"oneTwo: dropped %@", [self objectForKey:@"droppedObject"]);
  [self setObject:@"oneTwo" forKey:@"lastDropOn"];
  return nil;
}

@end /* DnD */
