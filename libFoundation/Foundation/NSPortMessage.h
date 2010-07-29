/* 
   NSPortMessage.h

   Copyright (C) 1999 Helge Hess.
   All rights reserved.

   Author: Helge Hess <hh@mdlink.de>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#ifndef __NSPortMessage_H__
#define __NSPortMessage_H__

#include <Foundation/NSObject.h>

@class NSArray, NSDate, NSPort;

@interface NSPortMessage : NSObject
{
    NSArray      *components;
    NSPort       *sendPort;
    NSPort       *receivePort;
    unsigned int msgId;
}

/* message creation */

- (id)initWithMachMessage:(void *)aMsg;

- (id)initWithSendPort:(NSPort *)aSendPort
  receivePort:(NSPort *)aReceivePort
  components:(NSArray *)components;

/* getting message components (NSData's or NSPort's) */

- (NSArray *)components;

/* identification */

- (void)setMsgid:(unsigned int)aMsgId;
- (unsigned int)msgid;

/* ports */

- (NSPort *)sendPort;
- (NSPort *)receivePort;

/* send message */

- (BOOL)sendBeforeDate:(NSDate *)limitDate;

@end

#endif /* __NSPortMessage_H__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
