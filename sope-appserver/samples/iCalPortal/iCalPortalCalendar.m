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

#include "iCalPortalCalendar.h"
#include "iCalPortalUser.h"
#include "common.h"
#include <NGiCal/iCalDataSource.h>

@implementation iCalPortalCalendar

- (id)initWithUser:(iCalPortalUser *)_user path:(NSString *)_path {
  if ((self->user = [_user retain]) == nil) {
    [self release];
    return nil;
  }
  if ((self->path = [_path copy]) == nil) {
    [self release];
    return nil;
  }
  
  return self;
}

- (void)dealloc {
  [self->content release];
  [self->path    release];
  [self->user    release];
  [super dealloc];
}

/* accessors */

- (iCalPortalUser *)user {
  return self->user;
}

/* access */

- (BOOL)isPublic {
  return YES;
}

- (NSData *)rawContent {
  if (self->content == nil)
    self->content = [[NSData alloc] initWithContentsOfMappedFile:self->path];
  
  return self->content;
}

- (EODataSource *)dataSource {
  iCalDataSource *ds;
  
  if ([self->path length] == 0)
    return nil;
  if ((ds = [[iCalDataSource alloc] initWithPath:self->path]) == nil)
    return nil;
  
  return [ds autorelease];
}

/* logging */

- (BOOL)isDebuggingEnabled {
  return YES;
}
- (NSString *)loggingPrefix {
  return [NSString stringWithFormat:@"[cal:%@]", 
		     self->path ? self->path : @"<new>"];
}

- (NSString *)description {
  NSMutableString *s;
  
  s = [NSMutableString stringWithCapacity:128];
  [s appendFormat:@"<0x%p[%@]: ", self, NSStringFromClass([self class])];
  [s appendFormat:@" path=%@", self->path];
  
  if ([self isPublic])
    [s appendString:@" public"];
  
  [s appendString:@">"];
  
  return s;
}

@end /* iCalPortalCalendar */
