/*
  Copyright (C) 2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __NGImap4MailboxInfo_H__
#define __NGImap4MailboxInfo_H__

#import <Foundation/NSObject.h>

/*
  NGImap4MailboxInfo
  
  Represents the info returned by an IMAP4 select. Use NGImap4Connection to
  retrieve the data.
*/

@class NSString, NSDate, NSArray, NSURL, NSDictionary;

@interface NGImap4MailboxInfo : NSObject
{
  NSDate   *timestamp;
  NSURL    *url;
  NSString *name;
  NSArray  *allowedFlags;
  NSString *access;
  unsigned int recent;
}

- (id)initWithURL:(NSURL *)_url folderName:(NSString *)_name
  selectDictionary:(NSDictionary *)_dict;

/* accessors */

- (NSDate *)timestamp;
- (NSURL *)url;
- (NSString *)name;
- (NSArray *)allowedFlags;
- (NSString *)access;
- (unsigned int)recent;

@end

#endif /* __NGImap4MailboxInfo_H__ */
