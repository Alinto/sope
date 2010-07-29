/* 
   NSPortMessage.m

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

#include <Foundation/NSPortMessage.h>
#include <Foundation/NSPort.h>
#include <Foundation/NSArray.h>

@implementation NSPortMessage

/* message creation */

- (id)initWithMachMessage:(void *)aMsg
{
    return [self notImplemented:_cmd];
}

- (id)initWithSendPort:(NSPort *)aSendPort
  receivePort:(NSPort *)aReceivePort
  components:(NSArray *)_components
{
    self->components  = RETAIN(_components);
    self->sendPort    = RETAIN(aSendPort);
    self->receivePort = RETAIN(aReceivePort);
    return self;
}

- (void)dealloc
{
    RELEASE(self->components);
    RELEASE(self->sendPort);
    RELEASE(self->receivePort);
    [super dealloc];
}

/* getting message components (NSData's or NSPort's) */

- (NSArray *)components
{
    return self->components;
}

/* identification */

- (void)setMsgid:(unsigned int)aMsgId
{
    self->msgId = aMsgId;
}
- (unsigned int)msgid
{
    return self->msgId;
}

/* ports */

- (NSPort *)sendPort
{
    return self->sendPort;
}
- (NSPort *)receivePort
{
    return self->receivePort;
}

/* send message */

- (BOOL)sendBeforeDate:(NSDate *)limitDate
{
    return [self->receivePort sendBeforeDate:limitDate
                              components:
                                AUTORELEASE([self->components mutableCopy])
                              from:self->sendPort
                              reserved:0];
}

@end

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
