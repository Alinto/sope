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
// $Id: CalendarField.m 1 2004-08-20 11:17:52Z znek $

#import <NGObjWeb/NGObjWeb.h>

@interface CalendarField : WOComponent
@end

@implementation CalendarField

- (id)init {
  if ((self = [super init])) {
    [self takeValue:@"12"   forKey:@"hour"];
    [self takeValue:@"30"   forKey:@"minute"];
    [self takeValue:@"50"   forKey:@"second"];

    [self takeValue:@"2001" forKey:@"year"];
    [self takeValue:@"5"    forKey:@"month"];
    [self takeValue:@"23"   forKey:@"day"];

    [self takeValue:[NSCalendarDate date] forKey:@"date"];
  }
  return self;
}
@end
