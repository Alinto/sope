/* 
   NSSocketPort.m

   Copyright (C) 2000 Helge Hess.
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

#include <Foundation/NSPort.h>

@implementation NSSocketPort

- (id)init
{
  /* invalid call ? */
  return [self notImplemented:_cmd];
}
  
- (id)initWithTCPPort:(unsigned short)_port
{
  /* bind */
  return [self notImplemented:_cmd];
}
- (id)initRemoteWithTCPPort:(unsigned short)_port
{
  /* connect */
  return [self notImplemented:_cmd];
}

- (id)initWithProtocolFamily:(int)_family
  socketType:(int)_type
  protocol:(int)_protocol
  address:(NSData *)_address
{
  /* bind */
  return [self notImplemented:_cmd];
}
- (id)initRemoteWithProtocolFamily:(int)_family
  socketType:(int)_type
  protocol:(int)_protocol
  address:(NSData *)_address
{
  /* connect */
  return [self notImplemented:_cmd];
}

- (id)initWithProtocolFamily:(int)_family
  socketType:(int)_type
  protocol:(int)_protocol
  socket:(NSSocketNativeHandle)_handle
{
  self->protocol = _protocol;
  self->type     = _type;
  self->family   = _family;
  self->sd       = _handle;
  return self;
}

/* accessors */

- (int)protocol
{
  return self->protocol;
}
- (int)protocolFamily
{
  return self->family;
}
- (int)socketType
{
  return self->type;
}
- (NSSocketNativeHandle)socket
{
  return self->sd;
}

@end /* NSSocketPort */
