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
// $Id: TableView.m 1 2004-08-20 11:17:52Z znek $

#include <NGObjWeb/WOComponent.h>

@class NSArray;

@interface TableView : WOComponent < NSCoding >
{
  NSArray *list;
  int clicks;
}
@end

#include "common.h"

@implementation TableView

- (id)init {
  if ((self = [super init])) {
    WOResourceManager *rm;
    NSString          *file;

    rm   = [[self application] resourceManager];

    file = [rm pathForResourceNamed:@"TableView.plist"
               inFramework:nil
               languages:nil];
                              
    self->list = [[NSArray alloc] initWithContentsOfFile:file];
    
    [self takeValue:@"4"       forKey:@"batchSize"];
    [self takeValue:@"#FCF8DF" forKey:@"evenColor"];
    [self takeValue:@"#FFFFF0" forKey:@"oddColor"];
    [self takeValue:@"#FFDAAA" forKey:@"headerColor"];
    [self takeValue:@"#FFDAAA" forKey:@"footerColor"];
    [self takeValue:@"#FAE8B8" forKey:@"titleColor"];
  }
  return self;
}

- (void)dealloc {
  [self->list release];
  [super dealloc];
}

/* accessors */

- (NSArray *)list {
  return self->list;
}
- (void)setList:(NSArray *)_list {
  ASSIGN(self->list, _list);
}

- (BOOL)isGroupCity {
  id obj1;
  id obj2;

  obj1 = [self valueForKey:@"item"];
  obj2 = [self valueForKey:@"previousItem"];

  return [[obj1 objectForKey:@"city"] isEqualToString:
                                      [obj2 objectForKey:@"city"]];
}

- (BOOL)isGroupZip {
  id obj1;
  id obj2;

  obj1 = [self valueForKey:@"item"];
  obj2 = [self valueForKey:@"previousItem"];
  
  return [[obj1 objectForKey:@"zip"] isEqualToString:
                                     [obj2 objectForKey:@"zip"]];
}

- (void)setClicks:(int)_clicks {
  self->clicks = _clicks;
}
- (int)clicks {
  return self->clicks;
}

/* actions */

- (id)increaseClicks {
  self->clicks++;
  [self takeValue:[self valueForKey:@"item"] forKey:@"clickedItem"];
  return nil;
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  [super encodeWithCoder:_coder];
  [_coder encodeObject:self->list];
}
- (id)initWithCoder:(NSCoder *)_coder {
  if ((self = [super initWithCoder:_coder])) {
    self->list = [[_coder decodeObject] retain];
  }
  return self;
}

@end /* TableView */
