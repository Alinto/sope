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

#ifndef __NGMail_NGPop3Support_H__
#define __NGMail_NGPop3Support_H__

#import <Foundation/NSObject.h>
#include <NGMail/NGPop3Client.h>

@class NSString;

@interface NGPop3Response : NSObject
{
@protected
  NSString *line;
}

+ (id)responseWithLine:(NSString *)_line;

// accessors

- (BOOL)isPositive;
- (NSString *)line;

@end

@interface NGPop3MessageInfo : NSObject
{
@protected
  NGPop3Client *client;
  int          messageNumber;
  int          messageSize;
}

+ (id)infoForMessage:(int)_num size:(int)_size client:(NGPop3Client *)_client;

// accessors

- (int)messageNumber;
- (int)size;
- (NGPop3Client *)pop3Client;

@end

#import <Foundation/NSEnumerator.h>

@interface NGPop3MailDropEnumerator : NSEnumerator
{
@protected
  NSEnumerator *msgInfos;
}

- (id)initWithMessageInfoEnumerator:(NSEnumerator *)_infos;
- (id)nextObject;

@end

@interface NGPop3Exception : NSException
@end

@interface NGPop3StateException : NGPop3Exception
{
@protected
  NGPop3State requiredState;
}

- (id)initWithClient:(NGPop3Client *)_client requiredState:(NGPop3State)_state;
- (NGPop3State)requiredState;

@end

#endif /* __NGMail_NGPop3Support_H__ */
