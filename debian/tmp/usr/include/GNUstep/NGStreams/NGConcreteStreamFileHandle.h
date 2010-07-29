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

#ifndef __NGStreams_NGConcreteStreamFileHandle_H__
#define __NGStreams_NGConcreteStreamFileHandle_H__

#import <Foundation/NSFileHandle.h>
#include <NGStreams/NGStream.h>

@class NSData;

@interface NGConcreteStreamFileHandle : NSFileHandle
{
  id<NGStream> stream;
}

- (id)initWithStream:(id<NGStream>)_stream;

// accessors

- (id<NGStream>)stream;

// ops

- (void)closeFile;
- (int)fileDescriptor; // abstract

// buffering

- (void)synchronizeFile;

// reading

- (NSData *)readDataOfLength:(unsigned int)_length;
- (NSData *)readDataToEndOfFile;

// writing

- (void)writeData:(NSData *)_data;

// seeking

- (void)seekToFileOffset:(unsigned long long)_offset;

@end

#endif /* __NGStreams_NGConcreteStreamFileHandle_H__ */
