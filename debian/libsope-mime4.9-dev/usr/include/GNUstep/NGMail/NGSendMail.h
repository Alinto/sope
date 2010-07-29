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

#ifndef __NGMail_NGSendMail_H__
#define __NGMail_NGSendMail_H__

#import <Foundation/NSObject.h>
#include <NGMime/NGPart.h>

/*
  NGSendMail
  
  An interface to the local sendmail binary for deliverying mail.
*/

@class NSString, NSArray, NSData, NSException;

@interface NGSendMail : NSObject
{
  NSString *executablePath;
  BOOL isLoggingEnabled;
  BOOL shouldOnlyUseMailboxName;
}

+ (id)sharedSendMail;

- (id)initWithExecutablePath:(NSString *)_path;

/* accessors */

- (NSString *)executablePath;

- (BOOL)isSendLoggingEnabled;
- (BOOL)shouldOnlyUseMailboxName;

/* operations */

- (BOOL)isSendMailAvailable;

- (NSException *)sendMailAtPath:(NSString *)_path toRecipients:(NSArray *)_to
  sender:(NSString *)_sender;
- (NSException *)sendMimePart:(id<NGMimePart>)_pt toRecipients:(NSArray *)_to
  sender:(NSString *)_sender;
- (NSException *)sendMailData:(NSData *)_data toRecipients:(NSArray *)_to
  sender:(NSString *)_sender;

@end

#endif /* __NGMail_NGSendMail_H__ */
