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

#include "NGMimeJoinedData.h"
#include "common.h"
#include "timeMacros.h"
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include "NGMimeFileData.h"

@implementation NGMimeJoinedData

- (id)init {
  if ((self = [super init])) {
    self->joinedDataObjects = [[NSMutableArray alloc] initWithCapacity:16];
  }
  return self;
}

- (void)dealloc {
  [self->joinedDataObjects release];
  [super dealloc];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  // TODO: we are mutable, is -retain a bug or feature?
  return [self retain];
}

/* data */

- (NSArray *)_joinedDataObjects {
  return self->joinedDataObjects;
}

- (NSUInteger)length {
  NSUInteger i, count, size;

  for (i = 0, count = [self->joinedDataObjects count], size = 0; i < count;i++)
    size += [[self->joinedDataObjects objectAtIndex:i] length];
  return size;
}

/* appending data */

- (void)appendData:(NSData *)_data {
  if ([_data isKindOfClass:[NGMimeJoinedData class]]) {
    [self->joinedDataObjects addObjectsFromArray:
         [(NGMimeJoinedData *)_data _joinedDataObjects]];
  }
  else
    [self->joinedDataObjects addObject:_data];
}

- (void)appendBytes:(const void *)_bytes length:(unsigned int)_length {
  NSMutableData *data;

  if (_length == 0)
    return;
  
  data = (NSMutableData *)[self->joinedDataObjects lastObject];
  
  if ([data isKindOfClass:[NSMutableData class]]) {
    [data appendBytes:_bytes length:_length];
  }
  else {
    /* 
       Note: we create a mutable because it is not unlikely that additional
             appends are coming.
    */
    data = [[NSMutableData alloc] initWithBytes:_bytes length:_length];
    if (data != nil) [self->joinedDataObjects addObject:data];
    [data release];
  }
}

/* writing to file */

- (BOOL)writeToFile:(NSString*)_path atomically:(BOOL)_useAuxiliaryFile {
  NSString      *filename = nil;
  NSEnumerator  *enumerator;
  NSData        *data;
  volatile BOOL result;
    
  int fd;
    
  filename = _path;

  fd = open([filename fileSystemRepresentation],
            O_WRONLY | O_CREAT | O_TRUNC, 0600);
  if (fd == -1) {
    fprintf(stderr, "Could not open file for writing %s: %s\n",
            [filename fileSystemRepresentation], strerror(errno));
    return NO;
  }

  result     = YES;
  enumerator = [self->joinedDataObjects objectEnumerator];

  while ((data = [enumerator nextObject])) {

    TIME_START("write bytes ");

    if ([data isKindOfClass:[NGMimeFileData class]]) {
      if (![(NGMimeFileData *)data appendDataToFileDesc:fd]) {
        fprintf(stderr,
#if GS_64BIT_OLD
                "Failed to write %i bytes to %s: %s\n",
#else
                "Failed to write %li bytes to %s: %s\n",
#endif
                [data length],
                [filename fileSystemRepresentation], strerror(errno));
        close(fd);
      }
    }
    else {
      const void *bytes;
      unsigned   len;

      TIME_START("bytes ...")
        bytes  = [data bytes];
        len    = [data length];
      TIME_END;
      
      if (write(fd, bytes, len) != (int)len) {
        fprintf(stderr, "Failed to write %i bytes to %s: %s\n",
                len, [filename fileSystemRepresentation], strerror(errno));
        close(fd);
        return NO;
      }
    }
    TIME_END;
  }
  close(fd);
        
  return result;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [ms appendFormat:@" joinedDataObjects=%d>",
        [self->joinedDataObjects count]];
  [ms appendString:@">"];
  return ms;
}

@end /* NGMimeJoinedData */
