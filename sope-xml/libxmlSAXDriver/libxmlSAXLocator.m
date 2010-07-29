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

#import "libxmlSAXLocator.h"
#include "common.h"

@implementation libxmlSAXLocator

- (id)initWithSaxLocator:(xmlSAXLocatorPtr)_loc parser:(id)_parser {
  if (_loc == NULL) {
    [self release];
    return nil;
  }
  self->parser = _parser;
  self->getPublicId     = _loc->getPublicId;
  self->getSystemId     = _loc->getSystemId;
  self->getLineNumber   = _loc->getLineNumber;
  self->getColumnNumber = _loc->getColumnNumber;
  return self;
}

- (void)clear {
  self->parser = nil;
}

/* accessors */

- (int)columnNumber {
  //return -1;
  NSAssert(self->ctx, @"missing locator ctx ..");
  return self->getColumnNumber ? self->getColumnNumber(self->ctx) : -1;
}
- (int)lineNumber {
  //return -1;
  NSAssert(self->ctx, @"missing locator ctx ..");
  return self->getLineNumber ? self->getLineNumber(self->ctx) : -1;
}

- (NSString *)publicId {
  const xmlChar *s;
  //return nil;
  s = self->getPublicId ? self->getPublicId(self->ctx) : NULL;
  return s ? [NSString stringWithCString:(const char *)s] : nil;
}

- (NSString *)systemId {
  const xmlChar *s;
  //return nil;
  s = self->getSystemId ? self->getSystemId(self->ctx) : NULL;
  return s ? [NSString stringWithCString:(const char *)s] : nil;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<0x%p[%@]: pub=%@ sys=%@ L%i C%i>",
                     self, NSStringFromClass([self class]),
                     [self publicId], [self systemId],
                     [self lineNumber], [self columnNumber]];
}

@end /* libxmlSaxLocator */
