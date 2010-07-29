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

#ifndef __NGiCal_NSString_ICal_H__
#define __NGiCal_NSString_ICal_H__

#import <Foundation/NSString.h>

@interface NSString(ICalValue)

/* libical internal C-strings */

- (id)initWithICalCString:(const char *)_cstr;
- (const char *)icalCString;
- (NSString *)icalString;

/* libical values */

- (id)initWithICalValueHandle:(icalvalue *)_handle;
- (id)initWithICalValueOfProperty:(icalproperty *)_prop;

@end /* NSString(ICalValue) */

#endif /* __NGiCal_NSString_ICal_H__ */
