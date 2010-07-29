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

#include "NGLoggerManager.h"
#include "NGLogLevel.h"
#include "NGLogger.h"
#include "NSNull+misc.h"
#include "common.h"

@interface NGLoggerManager (PrivateAPI)
- (NGLogger *)_getConfiguredLoggerNamed:(NSString *)_name;
@end

@implementation NGLoggerManager

static NGLoggerManager *sharedInstance = nil;
static NSNull          *sharedNull     = nil;
static BOOL            debugAll        = NO;

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;

  if (didInit) return;
  
  didInit         = YES;
  sharedInstance  = [[self alloc] init];
  sharedNull      = [[NSNull null] retain];
  ud              = [NSUserDefaults standardUserDefaults];
  debugAll        = [ud boolForKey:@"NGLogDebugAllEnabled"];
}

+ (id)defaultLoggerManager {
  return sharedInstance;
}
+ (id)defaultManager {
  NSLog(@"WARNING(%s): called deprecated method.", __PRETTY_FUNCTION__);
  return [self defaultLoggerManager];
}

- (id)init {
  self = [super init];
  if (self) {
    self->loggerMap = [[NSMutableDictionary alloc] initWithCapacity:50];
  }
  return self;
}

- (void)dealloc {
  [self->loggerMap release];
  [super dealloc];
}

/* operations */

- (NGLogger *)loggerForDefaultKey:(NSString *)_defaultKey {
  id logger;

  logger = [self->loggerMap objectForKey:_defaultKey];
  if (!logger) {
    NSUserDefaults *ud;

    ud = [NSUserDefaults standardUserDefaults];
    if (!debugAll && ![ud boolForKey:_defaultKey]) {
      [self->loggerMap setObject:sharedNull forKey:_defaultKey];
      logger = sharedNull;
    }
    else {
      logger = [self _getConfiguredLoggerNamed:_defaultKey];
      [self->loggerMap setObject:logger forKey:_defaultKey];
    }
  }
  return (logger != sharedNull) ? logger : nil;
}

- (NGLogger *)loggerForFacilityNamed:(NSString *)_name {
  NGLogger *logger;
  
  // TODO: expensive, use a faster map (at least NSMapTable)
  if ((logger = [self->loggerMap objectForKey:_name]) != nil)
    return logger;

  logger = [self _getConfiguredLoggerNamed:_name];
  [self->loggerMap setObject:logger forKey:_name];
  return logger;
}

- (NGLogger *)loggerForClass:(Class)_clazz {
  NSString *name;
  
  name = _clazz != Nil ? NSStringFromClass(_clazz) : (NSString *)nil;
  return [self loggerForFacilityNamed:name];
}

/* Private */

- (NGLogger *)_getConfiguredLoggerNamed:(NSString *)_name {
  NSString *configKey;
  
  configKey = [NSString stringWithFormat:@"%@LoggerConfig", _name];
  return [NGLogger loggerWithConfigFromUserDefaults:configKey];
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@[0x%p] debugAll=%@ #loggers=%d>",
                     NSStringFromClass([self class]), self,
                     debugAll ? @"YES" : @"NO", [self->loggerMap count]];
}

@end /* NGLoggerManager */
