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

#ifndef __NGBufferedDescriptor_H__
#define __NGBufferedDescriptor_H__

typedef struct _NGBufferedDescriptor {
  int  fd; // descriptor
  void *readBuffer;
  void *readBufferPos;     // current position (ptr) in buffer
  int  readBufferFillSize; // number of 'read' bytes in the buffer
  int  readBufferSize;     // maximum capacity in bytes
  void *writeBuffer;
  int  writeBufferFillSize;
  int  writeBufferSize;
  char ownsFd;
} NGBufferedDescriptor;

NGBufferedDescriptor *
NGBufferedDescriptor_newWithOwnedDescriptorAndSize(int _fd, int _size);
NGBufferedDescriptor *
NGBufferedDescriptor_newWithDescriptorAndSize(int _fd, int _size);
NGBufferedDescriptor *
NGBufferedDescriptor_newWithDescriptor(int _fd);

void NGBufferedDescriptor_free(NGBufferedDescriptor *self);

// accessors

int  NGBufferedDescriptor_getReadBufferSize(NGBufferedDescriptor *self);
int  NGBufferedDescriptor_getWriteBufferSize(NGBufferedDescriptor *self);

// primary read functions

int  NGBufferedDescriptor_read(NGBufferedDescriptor *self,
                               void *_buffer, int _len);
int  NGBufferedDescriptor_write(NGBufferedDescriptor *self,
                                const void *_buffer, int _len);

// following functions return 1 on success and 0 and error/close

char NGBufferedDescriptor_flush(NGBufferedDescriptor *self);

unsigned char NGBufferedDescriptor_safeRead(NGBufferedDescriptor *self,
                                   void *_buffer, int _len);
char NGBufferedDescriptor_safeWrite(NGBufferedDescriptor *self,
                                    const void *_buffer, int _len);

int  NGBufferedDescriptor_readChar(NGBufferedDescriptor *self);

char NGBufferedDescriptor_writeHttpHeader(NGBufferedDescriptor *self,
                                          const char *_key,
                                          const unsigned char *_value);

#endif
