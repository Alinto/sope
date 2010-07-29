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

#include "WETableViewLabelConfig.h"
#include "WETableViewDefines.h"
#include "common.h"

@implementation WETableViewLabelConfig

- (id)initWithAssociations:(NSDictionary *)_config {
  if ((self = [super initWithAssociations:_config])) {
    self->ofLabel        = WOExtGetProperty(_config, @"ofLabel");
    self->toLabel        = WOExtGetProperty(_config, @"toLabel");
    self->firstLabel     = WOExtGetProperty(_config, @"firstLabel");
    self->previousLabel  = WOExtGetProperty(_config, @"previousLabel");
    self->nextLabel      = WOExtGetProperty(_config, @"nextLabel");
    self->lastLabel      = WOExtGetProperty(_config, @"lastLabel");
    self->pageLabel      = WOExtGetProperty(_config, @"pageLabel");
    self->sortLabel      = WOExtGetProperty(_config, @"sortLabel");

    /* defaults */
#define SetAssociationValue(_a_, _value_) \
         if (_a_ == nil)                  \
           _a_ = [[WOAssociation associationWithValue:_value_] retain];
    
    SetAssociationValue(self->ofLabel,       @"/");
    SetAssociationValue(self->toLabel,       @"-");
    SetAssociationValue(self->firstLabel,    @"<<");
    SetAssociationValue(self->previousLabel, @"<");
    SetAssociationValue(self->nextLabel,     @">");
    SetAssociationValue(self->lastLabel,     @">>");
    SetAssociationValue(self->pageLabel,     @"Page");
    SetAssociationValue(self->sortLabel,     @"sort column");
#undef SetAssociationValue
  }
  return self;
}

- (void)dealloc {
  [self->ofLabel       release];
  [self->toLabel       release];
  [self->firstLabel    release];
  [self->previousLabel release];
  [self->nextLabel release];
  [self->lastLabel release];
  [self->pageLabel release];
  [self->sortLabel release];
  [super dealloc];
}

- (void)updateConfigInContext:(WOContext *)_ctx {
  WOComponent *cmp;
  NSString    *tmp;

  cmp = [_ctx component];
  
#define SetConfigInContext(_a_, _key_)                                  \
      if (_a_ && (tmp = [_a_ valueInComponent:cmp]))                    \
        [_ctx setObject:tmp forKey:_key_];
  SetConfigInContext(self->ofLabel,         WETableView_ofLabel);
  SetConfigInContext(self->toLabel,         WETableView_toLabel);
  SetConfigInContext(self->firstLabel,      WETableView_firstLabel);
  SetConfigInContext(self->previousLabel,   WETableView_previousLabel);
  SetConfigInContext(self->nextLabel,       WETableView_nextLabel);
  SetConfigInContext(self->lastLabel,       WETableView_lastLabel);
  SetConfigInContext(self->pageLabel,       WETableView_pageLabel);
  SetConfigInContext(self->sortLabel,       WETableView_sortLabel);
#undef SetConfigInContext
}

@end /* WETableViewLabelConfig */
