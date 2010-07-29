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

#ifndef __NGImap4_NGImap4Envelope_H__
#define __NGImap4_NGImap4Envelope_H__

#import <Foundation/NSObject.h>

/*
  NGImap4Envelope
  
  Wraps the raw envelope as parsed from an IMAP4 fetch response.
*/

@class NSString, NSArray, NSCalendarDate, NSDictionary;
@class NGImap4EnvelopeAddress;

@interface NGImap4Envelope : NSObject
{
@public
  NSCalendarDate         *date;
  id                     subject; /* can be either NSData or NSString */
  NSString               *inReplyTo;
  NSString               *msgId;
  NGImap4EnvelopeAddress *sender;
  NSArray *from;
  NSArray *replyTo;
  NSArray *to;
  NSArray *cc;
  NSArray *bcc;
}

- (id)initWithMessageID:(NSString *)_msgID subject:(NSString *)_subject
  from:(NSArray *)_sender replyTo:(NSArray *)_replyTo
  to:(NSArray *)_to cc:(NSArray *)_cc bcc:(NSArray *)_bcc;

- (id)initWithBodyStructureInfo:(NSDictionary *)_info;

/* accessors */

- (NSCalendarDate *)date;
- (id)subject;
- (NSString *)inReplyTo;
- (NSString *)messageID;
- (NGImap4EnvelopeAddress *)sender;
- (NSArray *)from;
- (NSArray *)replyTo;
- (NSArray *)to;
- (NSArray *)cc;
- (NSArray *)bcc;

/* derived accessors */

- (BOOL)hasTo;
- (BOOL)hasCC;
- (BOOL)hasBCC;

@end

#endif /* __NGImap4_NGImap4Envelope_H__ */
