/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#include <NGObjWeb/WOTemplateBuilder.h>
#include <NGObjWeb/WOComponent.h>
#include "common.h"

@interface WOComponentScriptPart(UsedPrivates)
- (void)initScriptWithComponent:(WOComponent *)_object;
@end

@implementation WOComponentScript

- (id)initWithContentsOfFile:(NSString *)_path {
  if ((self = [self init])) {
    WOComponentScriptPart *part;
    
    if ([[_path pathExtension] isEqualToString:@"js"])
      self->language = @"javascript";
    
    part = [[WOComponentScriptPart alloc] initWithContentsOfFile:_path];
    if (part == nil) {
      [self release];
      return nil;
    }
    [self addScriptPart:part];
    [part release];
  }
  return self;
}

- (void)dealloc {
  [self->language    release];
  [self->scriptParts release];
  [super dealloc];
}

/* accessors */

- (NSString *)language {
  return self->language;
}

/* operations */

- (void)addScriptPart:(WOComponentScriptPart *)_part {
  NSArray *tmp;
  
  if (_part == nil) 
    return;
  
  tmp = self->scriptParts
    ? [self->scriptParts arrayByAddingObject:_part]
    : (NSArray *)[NSArray arrayWithObject:_part];
  ASSIGN(self->scriptParts, tmp);
}

- (void)initScriptWithComponent:(WOComponent *)_object {
  NSEnumerator      *e;
  NSAutoreleasePool *pool;
  WOComponentScriptPart *part;
  
  pool = [[NSAutoreleasePool alloc] init];
  
  e = [self->scriptParts objectEnumerator];
  while ((part = [e nextObject]))
    [part initScriptWithComponent:_object];
  
  [pool release];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:32];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  if ([self->language length] > 0)
    [ms appendFormat:@" language=%@", self->language];
  
  if ([self->scriptParts count] == 0)
    [ms appendString:@" no parts"];
  else if ([self->scriptParts count] == 1)
    [ms appendFormat:@" part=%@", [self->scriptParts objectAtIndex:0]];
  else
    [ms appendFormat:@" parts=%@", self->scriptParts];
  
  [ms appendString:@">"];
  return ms;
}

@end /* WOComponentScript */
