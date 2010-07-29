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

#ifndef __NGStreams_NGFilterStream_H__
#define __NGStreams_NGFilterStream_H__

#include <NGStreams/NGStream.h>

/*
  NGFilterStream
  
  This is an abstract superclass for streams which just operate on 'basic'
  streams like sockets or file streams. As an example subclass take the
  buffered stream which performs buffered IO on any given stream.
*/

@interface NGFilterStream : NGStream
{
@protected
  id                  source;
  NGIOReadMethodType  readBytes;
  NGIOWriteMethodType writeBytes;
}

+ (id)filterWithInputSource:(id<NGInputStream>)_source;
+ (id)filterWithOutputSource:(id<NGOutputStream>)_source;
+ (id)filterWithSource:(id<NGStream>)_source;
- (id)initWithInputSource:(id<NGInputStream>)_source;
- (id)initWithOutputSource:(id<NGOutputStream>)_source;
- (id)initWithSource:(id<NGStream>)_source;

/* accessors */

- (id<NGInputStream>)inputStream;
- (id<NGOutputStream>)outputStream;
- (id<NGStream>)source;

/* primitives */

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len;
- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len;
- (BOOL)flush;
- (BOOL)close;

- (NGStreamMode)mode;
- (BOOL)isRootStream;

@end

#endif /* __NGStreams_NGFilterStream_H__ */
