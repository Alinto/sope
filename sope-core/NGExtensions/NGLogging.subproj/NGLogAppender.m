/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  
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

#include "NGLogAppender.h"
#include "NGLogLevel.h"
#include "NGLogEvent.h"
#include "NGLogEventFormatter.h"
#include "common.h"

@implementation NGLogAppender

static NSString *defaultAppenderClassName = nil;

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;

  if (didInit) return;
  
  didInit = YES;
  ud      = [NSUserDefaults standardUserDefaults];
  defaultAppenderClassName =
    [[ud stringForKey:@"NGLogDefaultAppenderClass"] retain];
  if (defaultAppenderClassName == nil)
    defaultAppenderClassName = @"NGLogStdoutAppender";
}

+ (id)logAppenderFromConfig:(NSDictionary *)_config {
  NSString *className;
  Class    clazz;
  id       appender;

  className   = [_config objectForKey:@"Class"];
  if (!className)
    className = defaultAppenderClassName;
  clazz = NSClassFromString(className);
  if (clazz == Nil) {
    NSLog(@"ERROR: can't instantiate appender class named '%@'",
          className);
    return nil;
  }
  appender = [[[clazz alloc] initWithConfig:_config] autorelease];
  return appender;
}

- (id)initWithConfig:(NSDictionary *)_config {
  self = [super init];
  if (self) {
    NSDictionary *formatterConfig;
    
    formatterConfig = [_config objectForKey:@"Formatter"];
    self->formatter =
      [[NGLogEventFormatter logEventFormatterFromConfig:formatterConfig]
                            retain];
  }
  return self;
}

- (void)appendLogEvent:(NGLogEvent *)_event {
#if LIB_FOUNDATION_LIBRARY
  [self subclassResponsibility:_cmd];
#else
  NSLog(@"ERROR(%s): method should be implemented by subclass!",
          __PRETTY_FUNCTION__);
#endif
}

/* formatting */

- (NSString *)formattedEvent:(NGLogEvent *)_event {
  return [self->formatter formattedEvent:_event];
}

@end /* NGLogAppender */
