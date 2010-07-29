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

#ifndef __NGStreams_NGBase64Stream_H__
#define __NGStreams_NGBase64Stream_H__

#include <NGStreams/NGFilterStream.h>

/*
  NGBase64Stream
  
  A filter stream which either decodes or encodes Base64 entities on the fly.
*/

@interface NGBase64Stream : NGFilterStream
{
@protected
  /* decoding */
  unsigned char decBuffer[3]; // output buffer
  unsigned char decBufferLen; // number of bytes in buffer

  /* encoding */
  unsigned int  buf;          // a 24-bit quantity
  unsigned int  bufBytes;     // how many octets are set in it
  unsigned char line[74];     // output buffer
  unsigned char lineLength;   // output buffer fill pointer
}

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len; // decoder
- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len; // encoder

- (BOOL)close;
- (BOOL)flush;

@end

#endif /* __NGStreams_NGBase64Stream_H__ */
