/* 
   NSPort.h

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

#ifndef __NSPort_H__
#define __NSPort_H__

#include <Foundation/NSObject.h>
#if defined(WIN32)
#  include <windows.h>
#  include <winsock.h>
typedef SOCKET NSSocketNativeHandle;
#else
typedef int NSSocketNativeHandle;
#endif

@class NSDate, NSMutableArray, NSPortMessage, NSData;

@interface NSPort : NSObject < NSCoding, NSCopying >

/* port creation */

+ (NSPort *)port;
+ (NSPort *)portWithMachPort:(int)aMachPort;
- (id)init;
- (id)initWithMachPort:(int)aMachPort;

/* mach port */

- (int)machPort;

/* delegate */

- (void)setDelegate:(id)anObject;
- (id)delegate;

/* validation */

- (void)invalidate;
- (BOOL)isValid;

/* sending messages */

- (BOOL)sendBeforeDate:(NSDate *)limitDate
  components:(NSMutableArray *)components
  from:(NSPort *)receivePort
  reserved:(unsigned)headerSpaceReserved;

- (BOOL)sendBeforeDate:(NSDate *)limitDate
  msgid:(unsigned)_msgid
  components:(NSMutableArray *)components
  from:(NSPort *)receivePort
  reserved:(unsigned)headerSpaceReserved;

- (unsigned)reservedSpaceLength;

@end

@interface NSObject(NSPortDelegate)

- (void)handleMachMessage:(void *)aMachMessage;
- (void)handlePortMessage:(NSPortMessage *)aPortMessage;

@end

LF_EXPORT NSString *NSPortDidBecomeInvalidNotification;

/*
  Concrete subclass of NSPort for local connections only.
*/

@interface NSMessagePort : NSPort
@end

/*
  Concrete subclass of NSPort for socket connections.
*/

@interface NSSocketPort : NSPort
{
@private
  NSSocketNativeHandle sd;
  int protocol;
  int type;
  int family;
}

- (id)init;
- (id)initWithTCPPort:(unsigned short)_port;
- (id)initRemoteWithTCPPort:(unsigned short)_port;

- (id)initWithProtocolFamily:(int)_family
  socketType:(int)_type
  protocol:(int)_protocol
  address:(NSData *)_address;
- (id)initRemoteWithProtocolFamily:(int)_family
  socketType:(int)_type
  protocol:(int)_protocol
  address:(NSData *)_address;

- (id)initWithProtocolFamily:(int)_family
  socketType:(int)_type
  protocol:(int)_protocol
  socket:(NSSocketNativeHandle)_handle;

/* accessors */

- (int)protocol;
- (int)protocolFamily;
- (int)socketType;
- (NSSocketNativeHandle)socket;

@end

#endif /* __NSPort_H__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
