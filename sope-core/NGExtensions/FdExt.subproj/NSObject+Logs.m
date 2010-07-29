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

#include "NSObject+Logs.h"
#include "NGLoggerManager.h"
#include "NGLogger.h"
#include "common.h"

@implementation NSObject(NGLogs)

static Class StringClass = Nil;

static inline Class NSStringClass(void) {
  if (StringClass == Nil) StringClass = [NSString class];
  return StringClass;
}

- (BOOL)isDebuggingEnabled {
#if DEBUG
  return YES;
#else
  return NO;
#endif
}

- (id)logger {
  static NSMapTable      *loggerForClassMap = NULL;
  static NGLoggerManager *lm                = nil;
  NGLogger *logger;

  if (!loggerForClassMap) {
    loggerForClassMap = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                         NSNonRetainedObjectMapValueCallBacks,
                                         200);
    lm = [NGLoggerManager defaultLoggerManager];
  }
  logger = NSMapGet(loggerForClassMap, self->isa);
  if (!logger) {
    logger = [lm loggerForClass:self->isa];
    NSMapInsert(loggerForClassMap, self->isa, logger);
  }

  return logger;
}

- (id)debugLogger {
  return [self logger];
}

- (NSString *)loggingPrefix {
  /* improve perf ... */
  return [NSStringClass() stringWithFormat:@"<0x%p[%@]>",
                       self, NSStringFromClass([self class])];
}


- (void)debugWithFormat:(NSString *)_fmt arguments:(va_list)_va {
#if DEBUG
  NSString *msg, *msg2;
  
  if (![self isDebuggingEnabled]) return;
  
  msg  = [[NSStringClass() alloc] initWithFormat:_fmt arguments:_va];
  msg2 = [[NSStringClass() alloc] initWithFormat:
				    @"<%@>D %@", [self loggingPrefix], msg];
  [[self debugLogger] logLevel:NGLogLevelDebug message:msg2];
  [msg2 release];
  [msg  release];
#else
#  warning debug is disabled, debugWithFormat wont print anything ..
#endif
}

- (void)logWithFormat:(NSString *)_fmt arguments:(va_list)_va {
  NGLogger *logger;
  NSString *msg;
  
  logger = [self logger];
  if (![logger isLogInfoEnabled]) return;
  
  msg = [[NSStringClass() alloc] initWithFormat:_fmt arguments:_va];
  [logger logWithFormat:@"%@ %@", [self loggingPrefix], msg];
  [msg release];
}

- (void)warnWithFormat:(NSString *)_fmt arguments:(va_list)_va {
  NGLogger *logger;
  NSString *msg;

  logger = [self logger];
  if (![logger isLogWarnEnabled]) return;

  msg = [[NSStringClass() alloc] initWithFormat:_fmt arguments:_va];
  [logger warnWithFormat:@"%@ %@", [self loggingPrefix], msg];
  [msg release];
}

- (void)errorWithFormat:(NSString *)_fmt arguments:(va_list)_va {
  NGLogger *logger;
  NSString *msg;
  
  logger = [self logger];
  if (![logger isLogErrorEnabled]) return;

  msg = [[NSStringClass() alloc] initWithFormat:_fmt arguments:_va];
  [logger errorWithFormat:@"%@ %@", [self loggingPrefix], msg];
  [msg release];
}

- (void)fatalWithFormat:(NSString *)_fmt arguments:(va_list)_va {
  NGLogger *logger;
  NSString *msg;
  
  logger = [self logger];
  if (![logger isLogFatalEnabled]) return;

  msg = [[NSStringClass() alloc] initWithFormat:_fmt arguments:_va];
  [logger fatalWithFormat:@"%@ %@", [self loggingPrefix], msg];
  [msg release];
}

- (void)debugWithFormat:(NSString *)_fmt, ... {
  va_list ap;
  
  va_start(ap, _fmt);
  [self debugWithFormat:_fmt arguments:ap];
  va_end(ap);
}
- (void)logWithFormat:(NSString *)_fmt, ... {
  va_list ap;
  
  va_start(ap, _fmt);
  [self logWithFormat:_fmt arguments:ap];
  va_end(ap);
}
- (void)warnWithFormat:(NSString *)_fmt, ... {
  va_list ap;
  
  va_start(ap, _fmt);
  [self warnWithFormat:_fmt arguments:ap];
  va_end(ap);
}
- (void)errorWithFormat:(NSString *)_fmt, ... {
  va_list ap;
  
  va_start(ap, _fmt);
  [self errorWithFormat:_fmt arguments:ap];
  va_end(ap);
}
- (void)fatalWithFormat:(NSString *)_fmt, ... {
  va_list ap;
  
  va_start(ap, _fmt);
  [self fatalWithFormat:_fmt arguments:ap];
  va_end(ap);
}

@end /* NSObject(NGLogs) */
