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

#include "WETableViewColorConfig.h"
#include "WETableViewDefines.h"
#include "common.h"

@implementation WETableViewColorConfig

- (id)initWithAssociations:(NSDictionary *)_config {
  if ((self = [super initWithAssociations:_config])) {
    self->titleColor  = WOExtGetProperty(_config, @"titleColor");
    self->headerColor = WOExtGetProperty(_config, @"headerColor");
    self->footerColor = WOExtGetProperty(_config, @"footerColor");
    self->evenColor   = WOExtGetProperty(_config, @"evenColor");
    self->oddColor    = WOExtGetProperty(_config, @"oddColor");
  }
  return self;
}

- (void)dealloc {
  [self->titleColor  release];
  [self->headerColor release];
  [self->footerColor release];
  [self->evenColor   release];
  [self->oddColor    release];
  [super dealloc];
}

- (void)updateConfigInContext:(WOContext *)_ctx {
  WOComponent *cmp;
  NSString    *tmp;

  cmp = [_ctx component];
  
#define SetConfigInContext(_a_, _key_)           \
  if (_a_ && (tmp = [_a_ valueInComponent:cmp])) \
    [_ctx setObject:tmp forKey:_key_];
  
  SetConfigInContext(self->titleColor,      WETableView_titleColor);
  SetConfigInContext(self->headerColor,     WETableView_headerColor);
  SetConfigInContext(self->footerColor,     WETableView_footerColor);
  SetConfigInContext(self->evenColor,       WETableView_evenColor);
  SetConfigInContext(self->oddColor,        WETableView_oddColor);
#undef SetConfigInContext
}

@end /* WETableViewColorConfig */
