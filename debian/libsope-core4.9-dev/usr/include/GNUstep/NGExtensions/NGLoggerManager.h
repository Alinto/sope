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

#ifndef	__NGExtensions_NGLoggerManager_H_
#define	__NGExtensions_NGLoggerManager_H_

/*
  NGLoggerManager

  Manages a set of loggers by associating logger instances with names. Thus
  clients will be given the same instances if accessing the manager with the
  same name/key. Also, NGLoggerManager offers conditional creation of loggers
  based on user default keys (and special values associated with these keys).

  NGLoggerManager honours the following user default keys:

  User Default key              Function
  ----------------------------------------------------------------------------
  <Name>LoggerConfig            contains the configuration of the logger
                                named <Name>. Depending on what method you used
                                to retrieve the logger, <Name> is either
                                the user default key, class name or another
                                arbitrary name. The config found for that key
                                is used to initialize the logger instance.

  NGLogDebugAllEnabled          if set to "YES" will always return a logger
                                when -loggerForDefaultKey: is called.

*/

#import <Foundation/NSObject.h>

@class NSString, NSMutableDictionary;
@class NGLogger;

@interface NGLoggerManager : NSObject
{
  NSMutableDictionary *loggerMap;
}

+ (id)defaultLoggerManager;

/* Retrieves a logger conditional to the existence of the given default key.
   In order to stay backwards compatible to existing applications, a boolean
   value auf YES associated with this key sets the default log level of this
   logger to NGLogLevelDebug. If the requested default key is not set, *nil* is
   returned.
*/
- (NGLogger *)loggerForDefaultKey:(NSString *)_defaultKey;

/* Retrieves a "named" logger with NGLogLevelAll. */
- (NGLogger *)loggerForFacilityNamed:(NSString *)_name;
- (NGLogger *)loggerForClass:(Class)_clazz;

@end

#endif	/* __NGExtensions_NGLoggerManager_H_ */
