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

#include "NGLogEventFormatter.h"
#include "NGLogEvent.h"
#include "common.h"

@implementation NGLogEventFormatter

static NSString *defaultFormatterClassName = nil;

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;
  
  if (didInit) return;
  
  didInit = YES;
  ud      = [NSUserDefaults standardUserDefaults];
  defaultFormatterClassName =
    [[ud stringForKey:@"NGLogDefaultLogEventFormatterClass"] retain];
  if (defaultFormatterClassName == nil)
    defaultFormatterClassName = @"NGLogEventFormatter";
}

+ (id)logEventFormatterFromConfig:(NSDictionary *)_config {
  NSString *className;
  Class    clazz;
  id       formatter;
  
  className   = [_config objectForKey:@"Class"];
  if (!className)
    className = defaultFormatterClassName;
  clazz = NSClassFromString(className);
  if (clazz == Nil) {
    NSLog(@"ERROR: can't instantiate log event formatter class named '%@'",
          className);
    return nil;
  }
  formatter = [[[clazz alloc] initWithConfig:_config] autorelease];
  return formatter;
}

- (id)initWithConfig:(NSDictionary *)_config {
  self = [super init];
  if (self) {
  }
  return self;
}

/* formatting */

- (NSString *)formattedEvent:(NGLogEvent *)_event {
  return [_event message];
}

@end /* NGLogEventFormatter */
