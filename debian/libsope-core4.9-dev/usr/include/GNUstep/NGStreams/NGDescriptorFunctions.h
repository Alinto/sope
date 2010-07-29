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

#ifndef __NGStreams_NGDescriptorFunctions_H__
#define __NGStreams_NGDescriptorFunctions_H__

#import <Foundation/NSObject.h>

#if !defined(WIN32)

/*
  Polls a descriptor. Returns 1 if events occurred, 0 if a timeout occured
  and -1 if an error other than EINTR or EAGAIN occured.
*/
extern int NGPollDescriptor(int _fd, short _events, int _timeout);

/*
  Set/Get descriptor flags
*/
extern int  NGGetDescriptorFlags(int _fd);
extern void NGSetDescriptorFlags(int _fd, int _flags);
extern void NGAddDescriptorFlag (int _fd, int _flag);

/*
  Reading and writing with non-blocking IO support.
  The functions return
    -1  on error, with errno set to either recv's or poll's errno
    0   on the end of file condition
    -2  if the operation timed out

  Enable login topic 'nonblock' to find out about timeouts.
*/
extern int NGDescriptorRecv(int _fd, char *_buf, int _len,
                            int _flags, int _timeout);
extern int NGDescriptorSend(int _fd, const char *_buf, int _len,
                            int _flags, int _timeout);

/*
  Check whether the descriptor is associated to a terminal device.
  Get the name of the associated terminal device.
*/
extern BOOL     NGDescriptorIsAtty(int _fd);
extern NSString *NGDescriptorGetTtyName(int _fd);

#endif /* !WIN32 */

#endif /* __NGStreams_NGDescriptorFunctions_H__ */
