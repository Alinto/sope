/*
  Copyright (C) 2000-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess

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

#include "NGMimeFileData.h"
#include "common.h"
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

@implementation NGMimeFileData

static NSString      *TmpPath = nil;
static NSProcessInfo *Pi      = nil;
static unsigned      tmpmask  = 0600;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  if (TmpPath == nil) {
    TmpPath = [ud stringForKey:@"NGMimeBuildMimeTempDirectory"];
    if (TmpPath == nil) TmpPath = @"/tmp/";
    TmpPath = [[TmpPath stringByAppendingPathComponent:@"OGo"] copy];
  }
  if (Pi == nil) Pi = [[NSProcessInfo processInfo] retain];
}

- (id)initWithPath:(NSString *)_path removeFile:(BOOL)_remove {
#if !GNUSTEP_BASE_LIBRARY
  /*
    see OGo bug #1890, the gstep-base -init clashes and we don't exactly need
    it ... (but I guess its better to call it on other Foundations)
  */
  if ((self = [super init]) != nil) {
#endif
    if (![[NSFileManager defaultManager] fileExistsAtPath:_path]) {
      NSLog(@"ERROR[%s]: missing file at path %@", __PRETTY_FUNCTION__, _path);
      [self release];
      return nil;
    }
    self->path       = [_path copy];
    self->removeFile = _remove;
    self->length     = -1;
#if !GNUSTEP_BASE_LIBRARY
  }
#endif
  return self;
}

- (id)initWithBytes:(const void*)_bytes
  length:(NSUInteger)_length
{
  NSString *filename = nil;
  int      fd;
  
  filename = [Pi temporaryFileName:TmpPath];

  fd = open([filename fileSystemRepresentation],
            O_WRONLY | O_CREAT | O_TRUNC, tmpmask);
  if (fd == -1) {
    fprintf(stderr, "Could not open file for writing %s: %s\n",
            [filename fileSystemRepresentation], strerror(errno));
    [self release];
    return nil;
  }
  if (write(fd, _bytes, _length) != (int)_length) {
    fprintf(stderr,
#if GS_64BIT_OLD
            "Failed to write %i bytes to %s: %s\n",
#else
            "Failed to write %li bytes to %s: %s\n",
#endif
            _length, [filename fileSystemRepresentation], strerror(errno));
    close(fd);
    [self release];
    return nil;
  }
  return [self initWithPath:filename removeFile:YES];
}

- (void)dealloc {
  if (self->removeFile) {
    [[NSFileManager defaultManager]
                    removeFileAtPath:self->path handler:nil];
  }
  [self->path release];
  [super dealloc];
}

- (NSData *)_data {
  return [NSData dataWithContentsOfMappedFile:self->path];
}

- (id)copyWithZone:(NSZone *)zone {
  return [self retain];
}

- (const void*)bytes {
  return [[self _data] bytes];
}

- (unsigned int)length {
  if (self->length == -1) {
    self->length = [[[[NSFileManager defaultManager]
                                     fileAttributesAtPath:self->path
                                     traverseLink:NO]
                                     objectForKey:NSFileSize] intValue];
  }
  return self->length;
}

- (BOOL)appendDataToFileDesc:(int)_fd {
  NGFileStream *fs;
  int  bufCnt = 8192;
  char buffer[bufCnt];
  BOOL result;
  int  fileLen;

  if (![[NSFileManager defaultManager] isReadableFileAtPath:self->path]) {
    NSLog(@"ERROR[%s] missing file at path %@", __PRETTY_FUNCTION__, 
          self->path);
    return NO;
  }
  
  fileLen = [self length];
  result  = YES;
  fs      = [NGFileStream alloc]; /* to keep gcc 3.4 happy */
  fs      = [fs initWithPath:self->path];

  if (![fs openInMode:@"r"]) {
    NSLog(@"%s: could not open file stream ... %@",
          __PRETTY_FUNCTION__, self->path);
    [fs release]; fs = nil;
    return NO;
  }

  NS_DURING {
    NSInteger read;
    NSInteger alreadyRead;

    alreadyRead = 0;
    
    read = (bufCnt > (fileLen - alreadyRead)) ? fileLen - alreadyRead : bufCnt;
    
    while ((read = [fs readBytes:buffer count:read])) {
      alreadyRead += read;
      if (write(_fd, buffer, read) != read) {
        fprintf(stderr,
#if GS_64BIT_OLD
                "%s: Failed to write %i bytes to file\n",
#else
                "%s: Failed to write %li bytes to file\n",
#endif
                __PRETTY_FUNCTION__, read);
        result = NO;
        break;
      }
      if (alreadyRead == fileLen)
        break;
    }
  }
  NS_HANDLER {
    printf("got exceptions %s\n", [[localException description] cString]);
    if (![localException isKindOfClass:[NGEndOfStreamException class]]) {
      [fs release]; fs = nil;
      result = NO;
    }
  }
  NS_ENDHANDLER;
  [fs release]; fs = nil;
  return result;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<0x%p[%@]: path=%@>",
                     self, NSStringFromClass([self class]), self->path];
}

@end /* NGMimeFileData */
