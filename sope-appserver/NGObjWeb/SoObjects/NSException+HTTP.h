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

#ifndef __SoObjects_NSException_HTTP_H__
#define __SoObjects_NSException_HTTP_H__

#import <Foundation/NSException.h>

@interface NSException(HTTP)

+ (id)exceptionWithHTTPStatus:(unsigned short)_status;
+ (id)exceptionWithHTTPStatus:(unsigned short)_status reason:(NSString *)_r;
- (id)initWithHTTPStatus:(unsigned short)_status reason:(NSString *)_r;

+ (NSString *)exceptionNameForHTTPStatus:(unsigned short)_status;
+ (NSString *)exceptionReasonForHTTPStatus:(unsigned short)_status;

- (unsigned short)httpStatus;

@end

@interface SoHTTPException : NSException
{
  unsigned short status;
}

@end

#endif /* __SoObjects_NSException_HTTP_H__ */
