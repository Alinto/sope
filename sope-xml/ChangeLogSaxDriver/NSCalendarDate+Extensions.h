/*
  Copyright (C) 2004 Marcus Mueller <znek@mulle-kybernetik.com>

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

#ifndef	__ChangeLogSaxDriver_NSCalendarDate_Extensions_H_
#define	__ChangeLogSaxDriver_NSCalendarDate_Extensions_H_

#import <Foundation/Foundation.h>

@interface NSCalendarDate (ChangeLogSaxDriverExtensions)

/* see http://www.w3.org/TR/NOTE-datetime */
/* this is Complete date plus hours, minutes and seconds, with timezone
   set to 'Zulu', i.e. 1994-11-05T13:15:30Z
*/
- (NSString *)w3OrgDateTimeRepresentation;

@end

#endif	/* __ChangeLogSaxDriver_NSCalendarDate_Extensions_H_ */
