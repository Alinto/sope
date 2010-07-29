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

#ifndef __NGStreams_H__
#define __NGStreams_H__

#include <NGStreams/NGStreamsDecls.h>

#include <NGStreams/NGStreamProtocols.h>
#include <NGStreams/NGTextStreamProtocols.h>

#include <NGStreams/NGBase64Stream.h>
#include <NGStreams/NGBufferedStream.h>
#include <NGStreams/NGByteCountStream.h>
#include <NGStreams/NGConcreteStreamFileHandle.h>
#include <NGStreams/NGDataStream.h>
#include <NGStreams/NGFileStream.h>
#include <NGStreams/NGFilterStream.h>
#include <NGStreams/NGLockingStream.h>
#include <NGStreams/NGStream.h>
#include <NGStreams/NGStreamExceptions.h>
#include <NGStreams/NGStringTextStream.h>
#include <NGStreams/NGCTextStream.h>
#include <NGStreams/NGTextStream.h>
#include <NGStreams/NGByteBuffer.h>
#include <NGStreams/NGCharBuffer.h>

#include <NGStreams/NGStreamPipe.h>
#include <NGStreams/NGTerminalSupport.h>

// kit class

@interface NGStreams : NSObject
@end

// static linking

#define LINK_NGStreams \
  void __link_NGStreams(void) { \
    [NGStreams class];  \
    __link_NGStreams(); \
  }

#endif /* __NGStreams_H__ */
