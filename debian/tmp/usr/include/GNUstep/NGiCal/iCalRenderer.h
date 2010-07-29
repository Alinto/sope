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

#ifndef	__NGiCal_iCalRenderer_H_
#define	__NGiCal_iCalRenderer_H_

#import <Foundation/NSObject.h>

/*
  iCalRenderer

  Transform an iCalEvent into an iCalendar formatted string.
*/

@class NSString, NSCharacterSet;
@class iCalEvent;

@interface iCalRenderer : NSObject
{
}

+ (id)sharedICalendarRenderer;

- (NSString *)vEventStringForEvent:(iCalEvent *)_apt;
- (NSString *)iCalendarStringForEvent:(iCalEvent *)_apt;

@end

#import <Foundation/NSString.h>

@interface NSString (SOGoiCal)

- (NSString *)iCalDQUOTESafeString;
- (NSString *)iCalSafeString;
- (NSString *)iCalEscapedStringWithEscapeSet:(NSCharacterSet *)_es;
    
@end

#endif /* __NGiCal_iCalRenderer_H_ */
