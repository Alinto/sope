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

#include <NGObjWeb/WOComponent.h>

@class NSArray, NSMutableDictionary;

@interface TreeView : WOComponent < NSCoding >
{
  NSArray             *root;
  NSMutableDictionary *state;
  id                  item;

  int clicks;
  id  currentPath;
}
@end

#include "common.h"

@implementation TreeView

- (id)init {
  if ((self = [super init])) {
    WOResourceManager *rm;
    NSString          *path;

    rm   = [[self application] resourceManager];
    
    path = [rm pathForResourceNamed:@"TreeView.plist"
               inFramework:nil
               languages:nil];
    
    self->root      = [[NSArray alloc] initWithContentsOfFile:path];
    self->state     = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)dealloc {
  [self->currentPath release];
  [self->root  release];
  [self->item  release];
  [self->state release];
  [super dealloc];
}

/* accessors */

- (NSArray *)root {
  return self->root;
}

- (NSArray *)oneTags {
  return [NSArray arrayWithObject:@"one"];
}

- (void)setItem:(id)_item {
  ASSIGN(self->item, _item);
}
- (id)item {
  return self->item;
}

- (void)setClicks:(int)_clicks {
  self->clicks = _clicks;
}
- (int)clicks {
  return self->clicks;
}

- (void)setCurrentPath:(NSString *)_value {
  ASSIGN(self->currentPath, _value);
}
- (id)currentPath {
  return self->currentPath;
}

- (NSString *)keyPath {
  return [[[self valueForKey:@"currentPath"]
                 valueForKey:@"key"] componentsJoinedByString:@"."];
}

- (void)setIsZoom:(BOOL)_flag {
  NSString *key;

  key = [self keyPath];

  NSLog(@"setIsZoom is %@", key);
  if (key)
    [self->state setObject:[NSNumber numberWithBool:_flag] forKey:key];
}
- (BOOL)isZoom {
  NSString *key;

  key = [self keyPath];

  NSLog(@"isZoom is %@", key);
  
  if (key == nil)
    return NO;
    
  return [[self->state objectForKey:key] boolValue];
}

- (BOOL)showItem {
  return ([[self keyPath] hasSuffix:@"two"] ||
          [[self keyPath] hasSuffix:@"four"])
    ? NO
    : YES;
}

/* actions */

- (id)countClicks {
  self->clicks++;
  return nil /* stay on page */;
}

- (id)dropAction {
  NSLog(@"... droppedObject is %@", [self valueForKey:@"droppedObject"]);
  return nil;
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  [super encodeWithCoder:_coder];
  [_coder encodeObject:self->root];
  [_coder encodeObject:self->state];
  [_coder encodeObject:self->item];
}
- (id)initWithCoder:(NSCoder *)_coder {
  if ((self = [super initWithCoder:_coder])) {
    self->root  = [[_coder decodeObject] retain];
    self->state = [[_coder decodeObject] retain];
    self->item  = [[_coder decodeObject] retain];
  }
  return self;
}

@end /* TableView */
