/* 
   NSPosixFileDescriptor.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#include <errno.h>
#include <stdio.h>

#if defined(__MINGW32__)
# include <windows.h>
# include <winsock.h>
#else
# include <sys/ioctl.h>
#endif

#include <Foundation/common.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSException.h>
#include <Foundation/NSPosixFileDescriptor.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/exceptions/GeneralExceptions.h>

#include "NSMappedData.h"

@implementation NSPosixFileDescriptor

// Getting a standard NSPosixFileDescriptor

static NSPosixFileDescriptor* descriptorForStandardInput = nil;
static NSPosixFileDescriptor* descriptorForStandardOutput = nil;
static NSPosixFileDescriptor* descriptorForStandardError = nil;

+ (void)initialize
{
    if (!descriptorForStandardInput)
	descriptorForStandardInput = [[self alloc] 
	    initWithFileDescriptor:fileno(stdin)];
    if (!descriptorForStandardOutput)
	descriptorForStandardOutput = [[self alloc] 
	    initWithFileDescriptor:fileno(stdout)];
    if (!descriptorForStandardError)
	descriptorForStandardError = [[self alloc] 
	    initWithFileDescriptor:fileno(stderr)];
}

+ (id)descriptorWithStandardInput
{
    return descriptorForStandardInput;
}

+ (id)descriptorWithStandardOutput
{
    return descriptorForStandardOutput;
}

+ (id)descriptorWithStandardError
{
    return descriptorForStandardError;
}

// Initialize

- (id)initWithFileDescriptor:(int)fileDescriptor
{
    fd = fileDescriptor;
    owned = NO;
    return self;
}

- (id)initWithCStringPath:(const char*)aPath flags:(int)someFlags 
  createMode:(int)someMode
{
    fd = open(aPath, someFlags, someMode);
    if (fd == -1) {
#if DEBUG
        NSLog(@"%s: couldn't open file '%s': %s", __PRETTY_FUNCTION__,
              aPath, strerror(errno));
#endif
	(void)RELEASE(self);
	return nil;
    }
    owned = YES;
    return self;
}

- (id)initWithPath:(NSString*)aPath
{
    return [self initWithCStringPath:[aPath fileSystemRepresentation] 
	    flags:O_RDONLY createMode:0];
}

- (id)initWithPath:(NSString*)aPath flags:(int)someFlags
{
    return [self initWithCStringPath:[aPath fileSystemRepresentation] 
	    flags:someFlags createMode:0];
}

- (id)initWithPath:(NSString*)aPath flags:(int)someFlags 
  createMode:(int)someMode
{
    return [self initWithCStringPath:[aPath fileSystemRepresentation] 
	    flags:someFlags createMode:someMode];
}

- (void)dealloc
{
  if (owned)
    close (fd);
  [super dealloc];
}

// Get FD

- (int)fileDescriptor
{
    return self->fd;
}

// Read

- (NSData *)readEntireFile
{
    NSRange range;
    off_t   ret;
    
    if ((ret = lseek(fd, 0, SEEK_END)) == -1) {
        /* lseek failed */
	[[[PosixFileOperationException alloc]
	    initWithFormat:@"could not lseek to end"] raise];
    }
    range.location = 0;
    range.length   = ret;
    return [self readFileRange:range]; 
}

- (NSData *)readRestOfFile
{
    NSRange range;
    off_t   ret;

    if ((ret = lseek(fd, 0, SEEK_CUR)) == -1) {
        /* lseek failed */
	[[[PosixFileOperationException alloc]
	    initWithFormat:@"could not lseek to cur"] raise];
    }
    else
        range.location = ret;

    if ((ret = lseek(fd, 0, SEEK_END)) == -1) {
        /* lseek failed */
	[[[PosixFileOperationException alloc]
	    initWithFormat:@"could not lseek to end"] raise];
    }
    else
        range.location = ret - range.location;
    
    return [self readFileRange:range];
}

- (NSData *)readFileRange:(NSRange)range
{	
    void  *bytes;
    off_t ret;
    
    bytes = MallocAtomic(range.length);
    
    if ((ret = lseek(fd, range.location, SEEK_SET)) == -1) {
        /* lseek failed */
	[[[PosixFileOperationException alloc]
	    initWithFormat:@"could not lseek set"] raise];
    }
    
    if (read(fd, bytes, range.length) != (int)range.length) {
	lfFree(bytes);
	[[[PosixFileOperationException alloc]
	    initWithFormat:@"could not read %d bytes", range.length] raise];
    }
    
    return AUTORELEASE([[NSData alloc]
                           initWithBytesNoCopy:bytes length:range.length]);
}

- (void)readBytes:(void *)bytes range:(NSRange)range
{
    off_t ret;
    
    if ((ret = lseek(fd, range.location, SEEK_SET)) == -1) {
        /* lseek failed */
	[[[PosixFileOperationException alloc]
	    initWithFormat:@"could not lseek set"] raise];
    }
    
    if (read(fd, bytes, range.length) != (int)range.length)
	[[[PosixFileOperationException alloc]
	    initWithFormat:@"could not read %d bytes", range.length] raise];
}

- (NSData *)readFileLength:(long)length
{
    NSRange range;
    off_t   ret;
#if DEBUG
    NSAssert(length >= 0, @"invalid length %i", length);
#endif

    if ((ret = lseek(fd, 0, SEEK_CUR)) == -1) {
        /* lseek failed */
	[[[PosixFileOperationException alloc]
	    initWithFormat:@"could not lseek cur"] raise];
    }
    range.location = ret;
    range.length   = length;
    
    return [self readFileRange:range];
}

// Write

- (void)writeData:(NSData*)aData
{
    NSRange range = {0, [aData length]};    
    [self writeData:aData range:range];
}

- (void)writeData:(NSData*)aData range:(NSRange)range
{
    char *bytes;
    
    if (range.location + range.length > [aData length]) {
	[[[RangeException alloc]
		initWithReason:@"invalid range in NSData" size:[aData length] 
		    index:range.location+range.length] raise];
    }
    
    bytes = (char*)[aData bytes] + range.location;
    if (write(fd, bytes, range.length) != (int)range.length) {
	[[[PosixFileOperationException alloc]
	    initWithFormat:@"could not write %d bytes", range.length] raise];
    }
}

- (void)writeString:(NSString*)string
{
    NSRange range = {0, [string cStringLength]};    
    [self writeString:string range:range];
}

- (void)writeString:(NSString*)string range:(NSRange)range
{
    unsigned len = range.length;
    char* bytes;
    
    if (range.location + range.length > [string cStringLength])
	[[[RangeException alloc]
		initWithReason:@"invalid range in NSString"
		    size:[string cStringLength] 
		    index:range.location + range.length] raise];
    
    bytes = (char*)[string cString] + range.location;
    while (len > 0) {
        int res = write(fd, bytes, len);

        if (res == -1) {
            [[[PosixFileOperationException alloc]
                      initWithFormat:@"could not write %d bytes", len] raise];
        }
        len -= res;
        bytes += res;
    }
}

// Seek

- (int unsigned)fileLength
{
    off_t cur, len, ret;
    
    if ((cur = lseek(fd, 0, SEEK_CUR)) == -1) {
        /* lseek failed */
	[[[PosixFileOperationException alloc]
	    initWithFormat:@"could not lseek to cur"] raise];
    }
    if ((len = lseek(fd, 0, SEEK_END)) == -1) {
        /* lseek failed */
	[[[PosixFileOperationException alloc]
	    initWithFormat:@"could not lseek to end"] raise];
    }
    
    if ((ret = lseek(fd, cur, SEEK_SET)) == -1) {
        /* lseek failed */
	[[[PosixFileOperationException alloc]
	    initWithFormat:@"could not lseek set"] raise];
    }
    return len;
}

- (int unsigned)filePosition
{
    off_t ret;

    if ((ret = lseek(fd, 0, SEEK_CUR)) == -1) {
        /* lseek failed */
	[[[PosixFileOperationException alloc]
	    initWithFormat:@"could not lseek to cur"] raise];
    }
    
    return ret;
}

- (void)seekToEnd
{
    lseek(fd, 0, SEEK_END);
}

- (void)seekToPosition:(long)aPosition
{
    lseek(fd, aPosition, SEEK_SET);
}

- (void)truncateAtPosition:(long)aPosition
{
    lseek(fd, aPosition, SEEK_SET);
#if defined(__MINGW32__)
    if (_chsize(fd, aPosition) != 0)
#else
    if (ftruncate(fd, aPosition) != 0)
#endif
	[[[PosixFileOperationException alloc]
	    initWithFormat:@"could not truncate file"] raise];
}

// Mapping files to memory

- (NSData *)mapFileRange:(NSRange)range
{
    return AUTORELEASE([[NSMappedData alloc]
                           initWithPosixFileDescriptor:self range:range]);
}

- (void)synchronizeFile
{
#if HAVE_FSYNC
    if (fsync(fd) != 0)
	[[[PosixFileOperationException alloc]
	    initWithFormat:@"could not sync file"] raise];
#endif
}

// Monitoring file descriptors

- (void)ceaseMonitoringFileActivity
{
    NSRunLoop* runLoop = [NSRunLoop currentRunLoop];

    fileActivity = 0;
    [runLoop removePosixFileDescriptor:self forMode:[runLoop currentMode]];
}

- (NSPosixFileActivities)fileActivity
{
    return fileActivity;
}

- (void)monitorFileActivity:(NSPosixFileActivities)activity
{
    NSRunLoop* runLoop = [NSRunLoop currentRunLoop];

    fileActivity |= activity;
    [runLoop addPosixFileDescriptor:self forMode:[runLoop currentMode]];
}

- (void)monitorActivity:(NSPosixFileActivities)activity delegate:(id)anObject
{
    [self setDelegate:anObject];
    [self monitorFileActivity:activity];
}

// File descriptor delegate

- (id)delegate
{
    return delegate;
}

- (void)setDelegate:(id)aDelegate
{
    delegate = aDelegate;
}

@end /* NSPosixFileDescriptor */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
