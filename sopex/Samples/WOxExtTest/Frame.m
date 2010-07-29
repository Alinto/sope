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
// $Id: Frame.m 1 2004-08-20 11:17:52Z znek $

#include <NGObjWeb/WOComponent.h>

@class NSString;

@interface Frame : WOComponent
{
  NSString *title;
}
@end

#include "common.h"

@implementation Frame

- (void)dealloc {
  [self->title release];
  [super dealloc];
}

/* accessors */

- (void)setTitle:(NSString *)_t {
  ASSIGNCOPY(self->title, _t);
}
- (NSString *)title {
  return self->title;
}

- (NSString *)xmlContent {
  WOResourceManager *rm;
  NSString          *path;
  NSString          *str;
  
  str  = [[self valueForKey:@"title"] stringByAppendingPathExtension:@"wox"];
  rm   = [[self application] resourceManager];
  
  path = [rm pathForResourceNamed:str
             inFramework:nil
             languages:nil];
  
  str = [NSString stringWithContentsOfFile:path];

  return str;
}

@end /* Frame */
