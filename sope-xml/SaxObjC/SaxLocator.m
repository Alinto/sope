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

#include "SaxLocator.h"
#include "common.h"

@implementation SaxLocator

- (id)init {
  return self;
}
- (id)initWithLocator:(id<SaxLocator>)_locator {
  if ((self = [self init])) {
    self->column = [_locator columnNumber];
    self->line   = [_locator lineNumber];
    self->pubId  = [[_locator publicId] copy];
    self->sysId  = [[_locator systemId] copy];
  }
  return self;
}

- (void)dealloc {
  [self->pubId release];
  [self->sysId release];
  [super dealloc];
}

/* accessors */

- (void)setColumnNumber:(NSInteger)_col {
  self->column = _col;
}
- (NSInteger)columnNumber {
  return self->column;
}

- (void)setLineNumber:(NSInteger)_line {
  self->line = _line;
}
- (NSInteger)lineNumber {
  return self->line;
}

- (void)setPublicId:(NSString *)_pubId {
  id o = self->pubId;
  self->pubId = [_pubId copy];
  [o release];
}
- (NSString *)publicId {
  return self->pubId;
}

- (void)setSystemId:(NSString *)_sysId {
  id o = self->sysId;
  self->sysId = [_sysId copy];
  [o release];
}
- (NSString *)systemId {
  return self->sysId;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [[[self class] allocWithZone:_zone] initWithLocator:self];
}

@end /* SaxLocator */
