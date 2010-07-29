/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#ifndef __NGStreams_NGCharBuffer_H__
#define __NGStreams_NGCharBuffer_H__

#include <NGStreams/NGFilterTextStream.h>
#include <NGStreams/NGTextStreamProtocols.h>
#include <NGStreams/NGStreamProtocols.h>

struct NGCharBufferLA;

/*
  Although NGCharBuffer is defined to be a stream, it is usually not used as
  such. Instead most parsers implemented using NGCharBuffer will only call
  -la: and -consume.

  Note that -la: return -1 on EOF and -readCharacter throws an
  NGEndOfStreamException. -readCharacter is basically a -la:0 followed by a
  -consume.
*/

@interface NGCharBuffer : NGFilterTextStream
{
@protected
  struct NGCharBufferLA *la;

  int  bufLen;
  BOOL wasEOF;
  int  headIdx;
  int  sizeLessOne;
  
  unichar (*readCharacter)(id, SEL);
}

+ (id)charBufferWithSource:(id<NGTextStream>)_source la:(int)_la;
- (id)initWithSource:(id<NGTextStream>)_source la:(int)_la;

// LA
- (int)la:(int)_ls;

- (void)consume;           // consume one character
- (void)consume:(int)_cnt; // consume _cnt characters

// NGTextStream
- (unichar)readCharacter;

@end

#endif /* __NGStreams_NGCharBuffer_H__ */
