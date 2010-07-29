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

#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include "common.h"
#include "NGBufferedDescriptor.h"

// returns the number of bytes which where read from the buffer
#define numberOfConsumedReadBufferBytes(self) \
  ((self->readBufferSize == 0) ? 0 : (self->readBufferPos - self->readBuffer))

// returns the number of bytes which can be read from buffer (without source access)
#define numberOfAvailableReadBufferBytes(self) \
  (self->readBufferFillSize - numberOfConsumedReadBufferBytes(self))

// look whether all bytes in the buffer where consumed, if so, reset the buffer
#define checkReadBufferFillState(self) \
  if (numberOfAvailableReadBufferBytes(self) == 0) { \
    self->readBufferPos = self->readBuffer; \
    self->readBufferFillSize = 0;  \
  }

// implementation

NGBufferedDescriptor *
NGBufferedDescriptor_newWithDescriptorAndSize(int _fd, int _size)
{
  NGBufferedDescriptor *self = malloc(sizeof(NGBufferedDescriptor));
  if (self) {
    self->fd                  = _fd;
    self->readBuffer          = malloc(_size);
    self->writeBuffer         = malloc(_size);
    self->readBufferPos       = self->readBuffer;
    self->readBufferSize      = _size;
    self->readBufferFillSize  = 0; // no bytes are read from source
    self->writeBufferFillSize = 0;
    self->writeBufferSize     = _size;
    self->ownsFd              = 0;
  }
  return self;
}

NGBufferedDescriptor *NGBufferedDescriptor_newWithDescriptor(int _fd) {
  return NGBufferedDescriptor_newWithDescriptorAndSize(_fd, 1024);
}
NGBufferedDescriptor *
NGBufferedDescriptor_newWithOwnedDescriptorAndSize(int _fd, int _size) {
  NGBufferedDescriptor *self = NULL;
  
  if ((self = NGBufferedDescriptor_newWithDescriptorAndSize(_fd, _size)))
    self->ownsFd = 1;
  else
    close(_fd);
  return self;
}

void NGBufferedDescriptor_free(NGBufferedDescriptor *self) {
  if (self) {
    NGBufferedDescriptor_flush(self);

    if (self->ownsFd && self->fd != -1) {
      close(self->fd);
      self->fd = -1;
    }

    if (self->readBuffer) {
      free(self->readBuffer);
      self->readBuffer    = NULL;
      self->readBufferPos = NULL;
    }
    self->readBufferFillSize = 0;
    self->readBufferSize     = 0;

    if (self->writeBuffer) {
      free(self->writeBuffer);
      self->writeBuffer = NULL;
    }
    self->writeBufferFillSize = 0;
    self->writeBufferSize     = 0;
    
    free(self);
  }
}

int NGBufferedDescriptor_getReadBufferSize(NGBufferedDescriptor *self) {
  if (self == NULL) return 0;
  return self->readBufferSize;
}
int NGBufferedDescriptor_getWriteBufferSize(NGBufferedDescriptor *self) {
  if (self == NULL) return 0;
  return self->writeBufferSize;
}

int NGBufferedDescriptor_read(NGBufferedDescriptor *self,
			      void *_buf, int _len)
{
  register int availBytes;
  
  if (self == NULL) return 0;
  
  if (self->readBufferSize == 0) // no read buffering is done (buffersize==0)
    return read(self->fd, _buf, _len);
  
  availBytes = numberOfAvailableReadBufferBytes(self);
  if (availBytes >= _len) {
    // there are enough bytes in the buffer to fulfill the request
    if (_len == 1) {
      *(unsigned char *)_buf = *(unsigned char *)self->readBufferPos;
      self->readBufferPos++;
    }
    else {
      memcpy(_buf, self->readBufferPos, _len);
      self->readBufferPos += _len;  // update read position (consumed-size)
    }
    checkReadBufferFillState(self); // check whether all bytes where consumed
    return _len;
  }
  else if (availBytes > 0) {
    // there are some bytes in the buffer, these are returned
    
    memcpy(_buf, self->readBufferPos, availBytes); // copy all bytes from buffer
    self->readBufferPos      = self->readBuffer; // reset position
    self->readBufferFillSize = 0;        // no bytes available in buffer anymore
    return availBytes;
  }
  else if (_len > self->readBufferSize) {
    // requested _len is bigger than the buffersize, so we can bypass the
    // buffer (which is empty, as guaranteed by the previous 'ifs'
    return read(self->fd, _buf, _len);
  }
  else {
    // no bytes are available and the requested _len is smaller than the possible
    // buffer size, we have to read the next block of input from the source

    self->readBufferFillSize = read(self->fd,
                                    self->readBuffer, self->readBufferSize);

    // no comes a section which is roughly the same like the first to conditionals
    // in this method
    if (self->readBufferFillSize >= _len) {
      // there are enough bytes in the buffer to fulfill the request
    
      memcpy(_buf, self->readBufferPos, _len);
      self->readBufferPos += _len;          // update read position (consumed-size)
      checkReadBufferFillState(self); // check whether all bytes where consumed
      return _len;
    }
    else { // (readBufferFillSize > 0) (this is ensured by the above assert)
      // there are some bytes in the buffer, these are returned

      availBytes = self->readBufferFillSize;
      memcpy(_buf, self->readBufferPos, self->readBufferFillSize); // copy all bytes from buffer
      self->readBufferPos      = self->readBuffer; // reset position
      self->readBufferFillSize = 0;          // no bytes available in buffer anymore
      return availBytes;
    }
  }
}

int NGBufferedDescriptor_write(NGBufferedDescriptor *self,
                               const void *_buf, int _len)
{
  register int  tmp       = 0;
  register int  remaining = _len;
  register void *track    = (void *)_buf;

  if (self == NULL) return 0;
  
  while (remaining > 0) {
    // how much bytes available in buffer ?
    tmp = self->writeBufferSize - self->writeBufferFillSize; 
    tmp = (tmp > remaining) ? remaining : tmp;
  
    memcpy((self->writeBuffer + self->writeBufferFillSize), track, tmp);
    track += tmp;
    remaining -= tmp;
    self->writeBufferFillSize += tmp;

    if (self->writeBufferFillSize == self->writeBufferSize) {
      void *pos = self->writeBuffer;

      while (self->writeBufferFillSize > 0) {
        int result;
        
        result = write(self->fd, pos, self->writeBufferFillSize);
        
        if ((result == 0) || (result < 0)) { // socket closed || error
          self->writeBufferFillSize = 0; // content is lost ..
          return result;
        }
        self->writeBufferFillSize -= result;
        pos += result;
      }
    }
  }

#if 0
  if (self->flags._flushOnNewline == 1) {
    // scan buffer for newlines, if one is found, flush buffer
    
    for (tmp = 0; tmp < _len; tmp++) {
      if (tmp == '\n') {
        NGBufferedDescriptor_flush(self);
        break;
      }
    }
  }
#endif
  
  // clean up for GC
  tmp       = 0;    
  track     = NULL; // clean up for GC
  remaining = 0;
  
  return _len;
}

char NGBufferedDescriptor_flush(NGBufferedDescriptor *self) {
  if (self == NULL) return 0;
  
  if (self->writeBufferFillSize > 0) {
    int  toGo = self->writeBufferFillSize;
    void *pos = self->writeBuffer;

    while (toGo > 0) {
      int result = write(self->fd, pos, toGo);

      if (result == 0) // socket was closed
        return 0;
      else if (result < 1) // socket error
        return 0;

      toGo -= result;
      pos  += result;
    }
    self->writeBufferFillSize = 0;
  }
  return 1;
}

unsigned char NGBufferedDescriptor_safeRead(NGBufferedDescriptor *self,
                                            void *_buffer, int _len) {
  if (self == NULL) return 0;
  
  if (_len > 0) {
    while (_len > 0) {
      int result = NGBufferedDescriptor_read(self, _buffer, _len);

      if (result == 0) // socket was closed
        return 0;
      else if (result < 1) // socket error
        return 0;

      _len    -= result;
      _buffer += result;
    }
  }
  return 1;
}
char NGBufferedDescriptor_safeWrite(NGBufferedDescriptor *self,
                                    const void *_buffer, int _len) {
  if (self == NULL) return 0;
  
  if (_len > 0) {
    while (_len > 0) {
      int result;
      
      result = NGBufferedDescriptor_write(self, _buffer, _len);
      
      if (result == 0) // socket was closed
        return 0;
      else if (result < 1) // socket error
        return 0;

      _len    -= result;
      _buffer += result;
    }
  }
  return 1;
}

int NGBufferedDescriptor_readChar(NGBufferedDescriptor *self) {
  unsigned char c;
  return (NGBufferedDescriptor_safeRead(self, &c, 1)) ? c : -1;
}

char NGBufferedDescriptor_writeHttpHeader(NGBufferedDescriptor *self,
                                          const char *_key,
                                          const unsigned char *_value)
{
  register unsigned int len;
  
  if (!NGBufferedDescriptor_safeWrite(self, _key, strlen((char *)_key)))
    return 0;
  
  if (!NGBufferedDescriptor_safeWrite(self, ": ", 2))
    return 0;
  
  len = strlen((char *)_value);
  
  /*
     Required for deliverying certificates, we encode \n and \r as %10 and %13
     assuming that the certficiate is in base64. To safeguard, we also encode
     % as %25.
  */
  if (len > 0 && (index((char *)_value, '\n') != NULL || 
		  index((char *)_value, '\r') !=NULL)) {
    for (len = 0; _value[len] != '\0'; len++) {
      switch (_value[len]) {
      case '%':
      case '\r':
      case '\n': {
        char buf[4];
        sprintf(buf, "%%%02i", _value[len]);
        if (NGBufferedDescriptor_write(self, buf, 3) <= 0)
          return 0;
        break;
      }
      default:
        if (NGBufferedDescriptor_write(self, &(_value[len]), 1) <= 0)
          return 0;
        break;
      }
    }
  }
  else {
    if (!NGBufferedDescriptor_safeWrite(self, _value, len))
      return 0;
  }
  
  if (!NGBufferedDescriptor_safeWrite(self, "\r\n", 2))
    return 0;
  
  return 1;
}
