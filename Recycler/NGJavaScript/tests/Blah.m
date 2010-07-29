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
// $Id$

#include "Blah.h"
#include "MyNum.h"
#include "common.h"

@implementation Blah

- (id)_jsprop_sequence {
  static int i = 0;
  i++;
  return [MyNum numberWithInt:i];
  //return [NSNumber numberWithInt:i];
}
- (id)_jsprop_title {
  return @"My Title";
}

- (id)_jsfunc_MyType:(NSArray *)_args {
  return [MyNum numberWithInt:10];
}

- (id)_jsfunc_getContent:(NSArray *)_args {
  return [NSString stringWithFormat:@"My Content String ..."];
}

@end /* Blah */
