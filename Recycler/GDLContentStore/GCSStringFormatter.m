/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

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

#include "GCSStringFormatter.h"
#include "common.h"

@implementation GCSStringFormatter

static NSCharacterSet *escapeSet = nil;

+ (void)initialize {
  static BOOL didInit = NO;

  if(didInit)
    return;

  didInit = YES;
  escapeSet = 
    [[NSCharacterSet characterSetWithCharactersInString:@"\\'"] retain];
}

+ (id)sharedFormatter {
  static id sharedInstance = nil;
  if(!sharedInstance) {
    sharedInstance = [[self alloc] init];
  }
  return sharedInstance;
}

- (NSString *)stringByFormattingString:(NSString *)_s {
  NSString *s;

  s = [_s stringByEscapingCharactersFromSet:escapeSet
          usingStringEscaping:self];
  return [NSString stringWithFormat:@"'%@'", s];
}

- (NSString *)stringByEscapingString:(NSString *)_s {
  if([_s isEqualToString:@"\\"]) {
    return @"\\\\"; /* easy ;-) */
  }
  return @"\\'";
}

@end /* GCSStringFormatter */
