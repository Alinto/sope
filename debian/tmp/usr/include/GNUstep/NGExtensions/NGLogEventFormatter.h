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

#ifndef	__NGExtensions_NGLogEventFormatter_H_
#define	__NGExtensions_NGLogEventFormatter_H_

/*
  NGLogEventFormatter
 
  Suits as factory and base class for all custom log event formatters.
  Its purpose is to offer a lightweight interface to transform NGLogEvent
  objects into string representations.

 
  NGLogEventFormatter honours the following user default keys:
 
  User Default key                       Function
  ----------------------------------------------------------------------------
  NGLogDefaultLogEventFormatterClass     The formatter class to use if no class
                                         information was provided by the
                                         configuration.
                                         The fallback is "NGLogEventFormatter".
 
  The following keys in the configuration dictionary will be recognized:
 
  Key                           Function
  ----------------------------------------------------------------------------
  "Class"                       The class to use for instance creation. If no
                                class name is provided, the fallback path
                                described above will be taken.
*/

#import <Foundation/NSObject.h>
#include <NGExtensions/NGLogLevel.h>

@class NSDictionary, NGLogEvent;

@interface NGLogEventFormatter : NSObject
{
}

+ (id)logEventFormatterFromConfig:(NSDictionary *)_config;

- (id)initWithConfig:(NSDictionary *)_config;

/* formatting */
- (NSString *)formattedEvent:(NGLogEvent *)_event;

@end

#endif	/* __NGExtensions_NGLogEventFormatter_H_ */
