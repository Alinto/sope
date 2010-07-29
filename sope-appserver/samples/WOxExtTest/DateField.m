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

#include <NGObjWeb/NGObjWeb.h>

@interface DateField : WOComponent
{
}
@end

#include "common.h"

@implementation DateField

- (id)init {
  if ((self = [super init]) != nil) {
    [self takeValue:@"2000" forKey:@"year"];
    [self takeValue:@"10"   forKey:@"month"];
    [self takeValue:@"20"   forKey:@"day"];
    [self takeValue:[NSCalendarDate date] forKey:@"date"];
  }                           
  return self;
}

@end /* DateField */
