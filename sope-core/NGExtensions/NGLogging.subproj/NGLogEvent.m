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

#include "NGLogEvent.h"
#include "common.h"

@implementation NGLogEvent

static Class DateClass = Nil;

+ (void)initialize {
  static BOOL didInit = NO;

  if (didInit) return;
  didInit = YES;

  DateClass = [NSCalendarDate class];
}

- (id)initWithLevel:(NGLogLevel)_level message:(NSString *)_msg {
  self = [super init];
  if (self) {
    // TODO: get time using libc function, cheaper
    self->date  = [DateClass timeIntervalSinceReferenceDate];
    self->level = _level;
    self->msg   = [_msg copy];
  }
  return self;
}

- (void)dealloc {
  [self->msg release];
  [super dealloc];
}

/* accessors */

- (NGLogLevel)level {
  return self->level;
}

- (NSString *)message {
  return self->msg;
}

- (NSCalendarDate *)date {
  // TODO: set to GMT?
  return [DateClass dateWithTimeIntervalSinceReferenceDate:self->date];
}

/* description */

- (NSString *)description {
  NSString *lvl;
  
  switch (self->level) {
    case NGLogLevelOff:   lvl = @"OFF";   break;
    case NGLogLevelDebug: lvl = @"DEBUG"; break;
    case NGLogLevelInfo:  lvl = @"INFO";  break;
    case NGLogLevelWarn:  lvl = @"WARN";  break;
    case NGLogLevelError: lvl = @"ERROR"; break;
    case NGLogLevelFatal: lvl = @"FATAL"; break;
    default:              lvl = @"ALL";   break;
  }
  return [NSString stringWithFormat:@"<%@[0x%p] date=%@ level=%@ msg:%@>",
                      NSStringFromClass([self class]), self,
                      [self date], lvl, self->msg];
}

@end /* NGLogEvent */
