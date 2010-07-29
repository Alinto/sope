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

#ifndef	__NGExtensions_NGLogger_H_
#define	__NGExtensions_NGLogger_H_

/*
  NGLogger
  
  NGLogger has a minimum log level and passes messages to its appenders
  only if this minimum log level is satisfied - otherwise it silently drops
  these messages.

  NGLogger also offers a factory to instantiate loggers from configs stored
  in NSUserDefaults.

  NOTE: Except in rare circumstances, do not allocate loggers yourself!
        Always try to use the appropriate API of NGLoggerManager if possible.


  NGLogger honours the following user default keys:

  User Default key              Function
  ----------------------------------------------------------------------------
  NGLogDefaultLogLevel          The log level to use as a fallback, if no
                                log level is provided during initialization.
                                The default is "INFO".

 
  The following keys in the configuration dictionary will be recognized:
 
  Key                           Function
  ----------------------------------------------------------------------------
  "LogLevel"                    The log level to use for this logger. If no
                                log level is provided, sets log level according
                                to fallback described above.

  "Appenders"                   Array of dictionaries suitable as configuration
                                provided to NGLogAppender's factory method.
                                Please see NGLogAppender.h for further
                                explanation.

  LoggerConfig example:
 
  WOHttpTransactionLoggerConfig = {
    "LogLevel"  = "INFO";
    "Appenders" = (
      {
        "Class"     = "NGLogStdoutAppender";
        "Formatter" = {
          "Class" = "NGLogEventFormatter";
        };
      },
    );
  };
 
*/

#import <Foundation/NSObject.h>
#include <NGExtensions/NGLogLevel.h>

@class NSMutableArray, NSString, NSDictionary, NGLogAppender;

@interface NGLogger : NSObject
{
  NSMutableArray *appenders;
  @public
  NGLogLevel     logLevel;
}

+ (id)loggerWithConfigFromUserDefaults:(NSString *)_defaultName;

- (id)initWithConfig:(NSDictionary *)_config;
- (id)initWithLogLevel:(NGLogLevel)_level;

/* accessors */

- (void)setLogLevel:(NGLogLevel)_level;
- (NGLogLevel)logLevel;

- (void)addAppender:(NGLogAppender *)_appender;
- (void)removeAppender:(NGLogAppender *)_appender;

/* logging */

- (void)logLevel:(NGLogLevel)_level message:(NSString *)_msg;

/* conditions */

- (BOOL)isDebuggingEnabled;
- (BOOL)isLogInfoEnabled;
- (BOOL)isLogWarnEnabled;
- (BOOL)isLogErrorEnabled;
- (BOOL)isLogFatalEnabled;
  
@end

#endif	/* __NGExtensions_NGLogger_H_ */
