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

#include "WETableViewIconConfig.h"
#include "WETableViewDefines.h"
#include "common.h"

@implementation WETableViewIconConfig

- (id)initWithAssociations:(NSDictionary *)_config {
  if ((self = [super initWithAssociations:_config])) {
    self->downwardIcon    = WOExtGetProperty(_config, @"downwardSortIcon");
    self->upwardIcon      = WOExtGetProperty(_config, @"upwardSortIcon");
    self->nonSortIcon     = WOExtGetProperty(_config, @"nonSortIcon");

    self->firstIcon       = WOExtGetProperty(_config, @"firstIcon");
    self->firstBlind      = WOExtGetProperty(_config, @"firstBlindIcon");
    self->previousIcon    = WOExtGetProperty(_config, @"previousIcon");
    self->previousBlind   = WOExtGetProperty(_config, @"previousBlindIcon");
    self->nextIcon        = WOExtGetProperty(_config, @"nextIcon");
    self->nextBlind       = WOExtGetProperty(_config, @"nextBlindIcon");
    self->lastIcon        = WOExtGetProperty(_config, @"lastIcon");
    self->lastBlind       = WOExtGetProperty(_config, @"lastBlindIcon");
    self->selectAllIcon   = WOExtGetProperty(_config, @"selectAllIcon");
    self->deselectAllIcon = WOExtGetProperty(_config, @"deselectAllIcon");
    self->plusResizeIcon  = WOExtGetProperty(_config, @"plusResizeIcon");
    self->minusResizeIcon = WOExtGetProperty(_config, @"minusResizeIcon");
  }
  return self;
}

- (void)dealloc {
  [self->downwardIcon  release];
  [self->upwardIcon    release];
  [self->nonSortIcon   release];
  [self->firstIcon     release];
  [self->firstBlind    release];
  [self->previousIcon  release];
  [self->previousBlind release];
  [self->nextIcon      release];
  [self->nextBlind     release];
  [self->lastIcon      release];
  [self->lastBlind     release];
  [self->selectAllIcon   release];
  [self->deselectAllIcon release];
  [self->plusResizeIcon  release];
  [self->minusResizeIcon release];
  [super dealloc];
}

- (void)updateConfigInContext:(WOContext *)_ctx {
  WOComponent *cmp;
  NSString    *tmp;

  cmp = [_ctx component];
  
#define SetConfigInContext(_a_, _key_)                                  \
      if (_a_ && (tmp = [_a_ valueInComponent:cmp]))                    \
        [_ctx setObject:tmp forKey:_key_];                              \

  SetConfigInContext(self->downwardIcon,    WETableView_downwardIcon);
  SetConfigInContext(self->upwardIcon,      WETableView_upwardIcon);
  SetConfigInContext(self->nonSortIcon,     WETableView_nonSortIcon);
  
  SetConfigInContext(self->firstIcon,       WETableView_first);
  SetConfigInContext(self->firstBlind,      WETableView_first_blind);
  SetConfigInContext(self->previousIcon,    WETableView_previous);
  SetConfigInContext(self->previousBlind,   WETableView_previous_blind);
  SetConfigInContext(self->nextIcon,        WETableView_next);
  SetConfigInContext(self->nextBlind,       WETableView_next_blind);
  SetConfigInContext(self->lastIcon,        WETableView_last);
  SetConfigInContext(self->lastBlind,       WETableView_last_blind);
  SetConfigInContext(self->selectAllIcon,   WETableView_select_all);
  SetConfigInContext(self->deselectAllIcon, WETableView_deselect_all);
#undef SetConfigInContext
}

@end /* WETableViewIconConfig */
