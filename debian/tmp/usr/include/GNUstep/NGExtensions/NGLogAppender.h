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

#ifndef	__NGExtensions_NGLogAppender_H_
#define	__NGExtensions_NGLogAppender_H_

/*
  NGLogAppender

  Abstract superclass for all log appenders.

  NGLogAppender honours the following user default keys:
 
  User Default key              Function
  ----------------------------------------------------------------------------
  NGLogDefaultAppenderClass     The appender class to use if no class
                                information was provided by the configuration.
                                The fallback is "NGLogStdoutAppender".
 
 
  The following keys in the configuration dictionary will be recognized:
 
  Key                           Function
  ----------------------------------------------------------------------------
  "Class"                       The class to use for instance creation. If no
                                class name is provided, the fallback path
                                described above will be taken.

  "Formatter"                   Dictionary suitable as configuration
                                provided to NGLogEventFormatters's factory
                                method. Please see NGLogEventFormatteer.h for
                                further explanation.
*/

#import <Foundation/NSObject.h>
#include <NGExtensions/NGLogLevel.h>

@class NSDictionary, NGLogEvent, NGLogEventFormatter;

@interface NGLogAppender : NSObject
{
  NGLogEventFormatter *formatter;
}

/* factory method */
+ (id)logAppenderFromConfig:(NSDictionary *)_config;

/* designated initializer */
- (id)initWithConfig:(NSDictionary *)_config;

/* subclass responsibility */
- (void)appendLogEvent:(NGLogEvent *)_event;
- (NSString *)formattedEvent:(NGLogEvent *)_event;

@end

#endif	/* __NGExtensions_NGLogAppender_H_ */
