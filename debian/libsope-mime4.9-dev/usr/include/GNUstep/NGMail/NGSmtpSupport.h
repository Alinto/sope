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

#ifndef __NGMail_NGSmtpSupport_H__
#define __NGMail_NGSmtpSupport_H__

#import <Foundation/NSObject.h>
#include <NGMail/NGSmtpReplyCodes.h>

@class NSString;


NSString *NGSmtpDescriptionForReplyCode(NGSmtpReplyCode _code);


@interface NGSmtpResponse : NSObject
{
@protected
  NGSmtpReplyCode code;
  NSString        *text;
}

+ (id)responseWithCode:(NGSmtpReplyCode)_code text:(NSString *)_text;

// accessors

- (NGSmtpReplyCode)code;
- (NSString *)text;

// special accessors

- (NSString *)lastLine;

- (BOOL)isPositive;          // <400 code groups
- (BOOL)isTransientNegative; // 400 code group
- (BOOL)isPermanentNegative; // 500 code group

@end

#endif /* __NGMail_NGSmtpSupport_H__ */
