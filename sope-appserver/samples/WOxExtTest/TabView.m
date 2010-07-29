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

#import <NGObjWeb/WOComponent.h>

@interface TabView : WOComponent
{
  id bgColor;
  id leftCornerIcon;
  id rightCornerIcon;
  id selection;
}
@end

#include "common.h"

@implementation TabView

- (id)init {
  if ((self = [super init])) {
    [self takeValue:@"persons" forKey:@"selection"];
    [self takeValue:@"#FCF8DF" forKey:@"bgColor"];
  }
  return self;
}
- (void)dealloc {
  [self->bgColor         release];
  [self->rightCornerIcon release];
  [self->leftCornerIcon  release];
  [self->selection       release];
  [super dealloc];
}

/* accessors */

- (void)setBgColor:(id)_col {
  ASSIGN(self->bgColor, _col);
}
- (id)bgColor {
  return self->bgColor;
}

- (void)setRightCornerIcon:(id)_icon {
  ASSIGN(self->rightCornerIcon, _icon);
}
- (id)rightCornerIcon {
  return self->rightCornerIcon;
}

- (void)setLeftCornerIcon:(id)_icon {
  ASSIGN(self->leftCornerIcon, _icon);
}
- (id)leftCornerIcon {
  return self->leftCornerIcon;
}

- (void)setSelection:(id)_col {
  ASSIGN(self->selection, _col);
}
- (id)selection {
  return self->selection;
}

/* actions */

- (id)increaseClicks {
  int clicks;

  //[self debugWithFormat:@"increasing clicks .."];
  
  clicks = [[self valueForKey:@"clicks"] intValue];
  clicks++;
  
  [self takeValue:[NSNumber numberWithInt:clicks] forKey:@"clicks"];
  
  return nil;
}

@end /* TabView */
