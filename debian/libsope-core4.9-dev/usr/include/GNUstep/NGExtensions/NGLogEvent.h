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

#ifndef	__NGExtensions_NGLogEvent_H_
#define	__NGExtensions_NGLogEvent_H_

/*
  NGLogEvent
 
  Instances of this class encapsulate log events, retaining all vital
  information associated with it. Log events are generally passed on to
  log appenders for further treatment.
*/

#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>
#include <NGExtensions/NGLogLevel.h>

@class NSString, NSCalendarDate;

@interface NGLogEvent : NSObject
{
  NSString       *msg;
  NGLogLevel     level;
  NSTimeInterval date;
}

- (id)initWithLevel:(NGLogLevel)_level message:(NSString *)_msg;

/* accessors */

- (NGLogLevel)level;
- (NSString *)message;
- (NSCalendarDate *)date;

@end

#endif	/* __NGExtensions_NGLogEvent_H_ */
