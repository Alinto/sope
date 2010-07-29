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

#include "NGLogger.h"
#include "NGLogEvent.h"
#include "NGLogAppender.h"
#include "NSNull+misc.h"
#include "common.h"

@interface NGLogger (PrivateAPI)
+ (NGLogLevel)_logLevelForString:(NSString *)_level;
@end

@implementation NGLogger

static Class      NSStringClass   = Nil;
static NGLogger   *defaultLogger  = nil;
static NGLogLevel defaultLogLevel = NGLogLevelInfo;

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;
  NSString       *level;

  if (didInit) return;

  didInit         = YES;
  NSStringClass   = [NSString class];
  ud              = [NSUserDefaults standardUserDefaults];
  level           = [ud stringForKey:@"NGLogDefaultLogLevel"];
  defaultLogLevel = [self _logLevelForString:level];
  defaultLogger   = [[self alloc] init];
}

+ (id)loggerWithConfigFromUserDefaults:(NSString *)_defaultName {
  NSUserDefaults *ud;
  NSDictionary   *config;
  id             logger;

  ud     = [NSUserDefaults standardUserDefaults];
  config = [ud dictionaryForKey:_defaultName];
  if(!config)
    return defaultLogger;
  logger = [[[NGLogger alloc] initWithConfig:config] autorelease];
  return logger;
}

- (id)init {
  return [self initWithConfig:nil];
}

- (id)initWithConfig:(NSDictionary *)_config {
  self = [super init];
  if (self) {
    NSArray       *appenderConfigs;
    NGLogAppender *appender;
    NSString      *levelString;
    NGLogLevel    level;
    unsigned      count;

    self->appenders = [[NSMutableArray alloc] initWithCapacity:1];

    levelString = [_config objectForKey:@"LogLevel"];
    level       = [NGLogger _logLevelForString:levelString];
    [self setLogLevel:level];

    appenderConfigs = [_config objectForKey:@"Appenders"];
    count           = [appenderConfigs count];
    if(!count) {
      /* create a default appender */
      appender = [NGLogAppender logAppenderFromConfig:nil];
      [self addAppender:appender];
    }
    else {
      unsigned i;

      for(i = 0; i < count; i++) {
        NSDictionary  *appenderConfig;

        appenderConfig = [appenderConfigs objectAtIndex:i];
        appender       = [NGLogAppender logAppenderFromConfig:appenderConfig];
        if(appender)
          [self addAppender:appender];
      }
    }
  }
  return self;
}

- (id)initWithLogLevel:(NGLogLevel)_level {
  self = [self initWithConfig:nil];
  if (self) {
    [self setLogLevel:_level];
  }
  return self;
}

- (void)dealloc {
  [self->appenders release];
  [super dealloc];
}

/* accessors */

- (void)setLogLevel:(NGLogLevel)_level {
  self->logLevel = _level;
}
- (NGLogLevel)logLevel {
  return self->logLevel;
}

- (void)addAppender:(NGLogAppender *)_appender {
  [self->appenders addObject:_appender];
}

- (void)removeAppender:(NGLogAppender *)_appender {
  [self->appenders removeObject:_appender];
}

/* logging */

- (void)debugWithFormat:(NSString *)_fmt arguments:(va_list)_va {
  NSString *msg;

  if (self->logLevel < NGLogLevelDebug) return;

  msg = [[NSStringClass alloc] initWithFormat:_fmt arguments:_va];
  [self logLevel:NGLogLevelDebug message:msg];
  [msg release];
}

- (void)logWithFormat:(NSString *)_fmt arguments:(va_list)_va {
  NSString *msg;

  if (self->logLevel < NGLogLevelInfo) return;

  msg = [[NSStringClass alloc] initWithFormat:_fmt arguments:_va];
  [self logLevel:NGLogLevelInfo message:msg];
  [msg release];
}

- (void)warnWithFormat:(NSString *)_fmt arguments:(va_list)_va {
  NSString *msg;

  if (self->logLevel < NGLogLevelWarn) return;

  msg = [[NSStringClass alloc] initWithFormat:_fmt arguments:_va];
  [self logLevel:NGLogLevelWarn message:msg];
  [msg release];
}

- (void)errorWithFormat:(NSString *)_fmt arguments:(va_list)_va {
  NSString *msg;

  if (self->logLevel < NGLogLevelError) return;

  msg = [[NSStringClass alloc] initWithFormat:_fmt arguments:_va];
  [self logLevel:NGLogLevelError message:msg];
  [msg release];
}

- (void)fatalWithFormat:(NSString *)_fmt arguments:(va_list)_va {
  NSString *msg;

  if (self->logLevel < NGLogLevelFatal) return;

  msg = [[NSStringClass alloc] initWithFormat:_fmt arguments:_va];
  [self logLevel:NGLogLevelFatal message:msg];
  [msg release];
}

- (void)logLevel:(NGLogLevel)_level message:(NSString *)_msg {
  NGLogEvent *event;
  unsigned   i, count;

  event = [[NGLogEvent alloc] initWithLevel:_level message:_msg];

  count = [self->appenders count];
  for(i = 0; i < count; i++) {
    NGLogAppender *appender;
    
    appender = [self->appenders objectAtIndex:i];
    [appender appendLogEvent:event];
  }
  [event release];
}

/* log conditions */

- (BOOL)isDebuggingEnabled {
  return self->logLevel >= NGLogLevelDebug;
}
- (BOOL)isLogInfoEnabled {
  return self->logLevel >= NGLogLevelInfo;
}
- (BOOL)isLogWarnEnabled {
  return self->logLevel >= NGLogLevelWarn;
}
- (BOOL)isLogErrorEnabled {
  return self->logLevel >= NGLogLevelError;
}
- (BOOL)isLogFatalEnabled {
  return self->logLevel >= NGLogLevelFatal;
}


/* Private */

+ (NGLogLevel)_logLevelForString:(NSString *)_level {
  if (![_level isNotNull]) {
    _level = [_level uppercaseString];
    if ([_level isEqualToString:@"DEBUG"])
      return NGLogLevelDebug;
    else if ([_level isEqualToString:@"INFO"])
      return NGLogLevelInfo;
    else if ([_level isEqualToString:@"WARN"])
      return NGLogLevelWarn;
    else if ([_level isEqualToString:@"ERROR"])
      return NGLogLevelError;
    else if ([_level isEqualToString:@"FATAL"])
      return NGLogLevelFatal;
    return NGLogLevelAll; /* better than nothing */
  }
  return NGLogLevelInfo;
}

/* description */

- (NSString *)description {
  NSString *lvl;
  
  switch (self->logLevel) {
    case NGLogLevelOff:   lvl = @"OFF";   break;
    case NGLogLevelDebug: lvl = @"DEBUG"; break;
    case NGLogLevelInfo:  lvl = @"INFO";  break;
    case NGLogLevelWarn:  lvl = @"WARN";  break;
    case NGLogLevelError: lvl = @"ERROR"; break;
    case NGLogLevelFatal: lvl = @"FATAL"; break;
    default:              lvl = @"ALL";   break;
  }
  return [NSString stringWithFormat:@"<%@[0x%p] logLevel=%@ appenders:%@>",
                     NSStringFromClass([self class]), self,
                     lvl, self->appenders];
}

@end /* NGLogger */
