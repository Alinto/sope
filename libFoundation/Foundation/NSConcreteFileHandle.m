/*
   NSConcreteFileHandle.m

   Copyright (C) 1995, 1996, 1997 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: May 1997

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

#include <Foundation/common.h>

#include <errno.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#ifdef __MINGW32__
#  include <winsock.h>
#else
#  include <sys/un.h>
#  include <netinet/in.h>
#  include <sys/socket.h>
#  include <sys/ioctl.h>

enum {
    non_blocking =
#if O_NDELAY
    O_NDELAY
#elif FNDELAY
    FNDELAY
#elif O_NONBLOCK
    O_NONBLOCK
#endif
};
#endif

#if HAVE_LIBC_H
# include <libc.h>
#else
# include <unistd.h>
#endif

#include <Foundation/NSData.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSException.h>
#include <Foundation/exceptions/GeneralExceptions.h>
#include <Foundation/exceptions/NSFileHandleExceptions.h>
#include "NSConcreteFileHandle.h"

#if !defined(__MINGW32__) && 0

static BOOL _isFdNonBlocking(int fd) {
    unsigned fileStatus;
    
    fileStatus = fcntl (fd, F_GETFL, 0);
    return (fileStatus & non_blocking) ? YES : NO;
}

static void _setFdBlocking(int fd, BOOL nonBlocking) {
    int flags;

    if ((flags = fcntl(fd, F_GETFL, 0)) >= 0) {
        if (nonBlocking)
            flags |= non_blocking;
        else
            flags &= ~non_blocking;

        if (fcntl(fd, F_SETFL, flags) < 0)
            NSLog(@"WARNING: fcntl() call failed: %s", strerror(errno));
    }
    else
        NSLog(@"WARNING: fcntl() call failed: %s", strerror(errno));
}

#endif

@implementation NSConcreteFileHandle

+ (id)fileHandleForReadingAtPath:(NSString *)path
{
    return AUTORELEASE([[self alloc]
                           initWithPath:path flags:O_RDONLY createMode:0]);
}

+ (id)fileHandleForWritingAtPath:(NSString *)path
{
    /* note: it's intended that flags do not include O_CREAT ! (see doc) */
    return AUTORELEASE([[self alloc]
                              initWithPath:path flags:O_WRONLY
                              createMode:0]);
}

+ (id)fileHandleForUpdatingAtPath:(NSString *)path
{
    /* note: it's intended that flags do not include O_CREAT ! (see doc) */
    return AUTORELEASE([[self alloc]
                              initWithPath:path flags:O_RDWR
                              createMode:0]);
}

- (void)_determineFileType
{
    struct stat statbuf;

    if (fstat (fd, &statbuf) == -1) {
	NSLog (@"warning: cannot determine the type of file descriptor %d in"
	       @" NSFileHandle %x", fd, self);
	type = NSFileHandleNoType;
    }
    else {
#ifdef S_IFSOCK
	if ((statbuf.st_mode & S_IFSOCK) == statbuf.st_mode)
	    type = NSFileHandleSocket;
	else
#endif
#ifdef S_IFIFO
	/* System V FIFOs, treat them as sockets since the system
	   calls that use them are similar. */
	if ((statbuf.st_mode & S_IFIFO) == statbuf.st_mode)
	    type = NSFileHandleSocket;
	else
#endif
	    type = NSFileHandleUnixFile;

#if 0
	NSLog (@"file type is %s, mode = %o",
	       type == NSFileHandleUnixFile ? "file" : "socket",
	       statbuf.st_mode);
#endif

#if !defined(__MINGW32__)
	/* Is st_blksize set on System V? */
	blockSize = statbuf.st_blksize;
	if (!blockSize)
	    blockSize = 4096;
#else
        blockSize = 4096;
#endif
    }
}

- (id)initWithFileDescriptor:(int)_fd
{
    return [self initWithFileDescriptor:_fd closeOnDealloc:NO];
}

- (id)initWithFileDescriptor:(int)_fd closeOnDealloc:(BOOL)flag
{
    self = [super initWithFileDescriptor:_fd];
    if (!self)
	return nil;

    closeOnDealloc = flag;
    isOpened = YES;
    operation = NSFileHandleNoOperation;
    [self _determineFileType];
    [self setDelegate:self];
    return self;
}

- (id)initWithPath:(NSString*)aPath flags:(int)flags createMode:(int)mode
{
    if ((self = [super initWithPath:aPath flags:flags createMode:mode])) {
        closeOnDealloc = YES;
        isOpened       = YES;
        operation      = NSFileHandleNoOperation;
        [self _determineFileType];
        [self setDelegate:self];
    }
    return self;
}

- (void)dealloc
{
    if (closeOnDealloc && isOpened)
      close (fd);
    [super dealloc];
}

- (NSData *)availableData
{
    NSData* data;

    /* Force the compiler to allocate `data' on stack */
    *&data = nil;
    
    if (!isOpened) {
	[[[NSFileHandleOperationException alloc]
		    initWithFileHandle:self
		    operation:@"Try to read from a closed file descriptor!"] raise];
    }
    
    if (type == NSFileHandleUnixFile) {
	data = [self readRestOfFile];
    }
    else if (type == NSFileHandleSocket) {
	data = [self readDataOfLength:blockSize];
    }
    else
	[[[NSFileHandleUnknownTypeException alloc]
			initWithFileHandle:self] raise];

    return data;
}

- (NSData *)readDataToEndOfFile
{
    /*
      invalid implementation, -readDataOfLength: only returns the
      available bytes on sockets.
    */
    return [self readDataOfLength:UINT_MAX];
}

- (NSData *)readDataOfLength:(unsigned int)length
{
    NSData *data;

    /* Force the compiler to allocate `data' on stack */
    *&data = nil;

    if (!isOpened) {
	[[[NSFileHandleOperationException alloc]
		    initWithFileHandle:self
		    operation:@"Try to read from a closed file descriptor!"] raise];
    }
    
    if (type == NSFileHandleUnixFile) {
        if (length == UINT_MAX)
            data = [self readFileLength:LONG_MAX];
        else {
            NSAssert(length < INT_MAX,
                     @"cannot handle read's with %d bytes",
                     length);
            data = [self readFileLength:length];
        }
    }
    else if (type == NSFileHandleSocket) {
	void *buffer;
	int  howMany;

	/* Force the compiler to allocate `buffer' on stack */
	*&buffer = MallocAtomic(length);

	howMany = read(fd, buffer, length);
	if (howMany == -1) {
	    lfFree(buffer);
	    [[[NSFileHandleOperationException alloc]
		      initWithFileHandle:self
		      operation:@"Error while reading from socket!"] raise];
	}
	if (howMany < (int)length)
	    buffer = Realloc(buffer, howMany);
	data = [NSData dataWithBytesNoCopy:buffer length:howMany];
    }
    else {
	[[[NSFileHandleUnknownTypeException alloc]
			initWithFileHandle:self] raise];
    }

    return data;
}

- (void)writeData:(NSData*)data
{
    if (!isOpened) {
	[[[NSFileHandleOperationException alloc]
		    initWithFileHandle:self
		    operation:@"Try to write in a closed file descriptor!"] raise];
    }

    TRY {
	[super writeData:data];
    } END_TRY
    CATCH(PosixFileOperationException) {
	[[[NSFileHandleUnknownTypeException alloc]
			initWithFileHandle:self] raise];
    } END_CATCH
}

- (void)_registerToRunLoopForModes:(NSArray*)_modes
{
    NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
    int i, count;

    if (!_modes)
	_modes = [NSArray arrayWithObject:[runLoop currentMode]];

    ASSIGN(modes, _modes);

    count = [modes count];
    for (i = 0; i < count; i++)
	[runLoop addPosixFileDescriptor:self forMode:[modes objectAtIndex:i]];
}

- (void)acceptConnectionInBackgroundAndNotifyForModes:(NSArray*)_modes
{
    if (!isOpened)
	[[[NSFileHandleOperationException alloc]
		  initWithFileHandle:self
		  operation:@"Try to accept connections on a closed socket!"] raise];
    if (operation != NSFileHandleNoOperation) {
	NSString* reason = [NSString stringWithFormat:@"Another operation (%s)"
		      @" is already in progress!",
		      (operation == NSFileHandleAcceptOperation
		       ? "accept"
		       : (operation == NSFileHandleReadOperation
			  ? "read"
			  : (operation == NSFileHandleReadToEndOfFileOperation
			     ? "read to end of file"
			     : "unknown")))];
	[[[NSFileHandleOperationException alloc]
		  initWithFileHandle:self
		  operation:reason] raise];
    }

    operation = NSFileHandleAcceptOperation;
    fileActivity = NSPosixReadableActivity;

    [self _registerToRunLoopForModes:_modes];
}

- (void)acceptConnectionInBackgroundAndNotify
{
    [self acceptConnectionInBackgroundAndNotifyForModes:nil];
}

- (void)readInBackgroundAndNotifyForModes:(NSArray*)_modes
{
    if (!isOpened) {
	[[[NSFileHandleOperationException alloc]
		  initWithFileHandle:self
		  operation:@"Try to read in background from a closed file"
			    @" descriptor!"] raise];
    }
    if (operation != NSFileHandleNoOperation) {
	NSString* reason = [NSString stringWithFormat:@"Another operation (%s)"
		      @" is already in progress!",
		      (operation == NSFileHandleAcceptOperation
		       ? "accept"
		       : (operation == NSFileHandleReadOperation
			  ? "read"
			  : (operation == NSFileHandleReadToEndOfFileOperation
			     ? "read to end of file"
			     : "unknown")))];
	[[[NSFileHandleOperationException alloc]
		  initWithFileHandle:self
		  operation:reason] raise];
    }

    operation = NSFileHandleReadOperation;
    fileActivity = NSPosixReadableActivity;

    [self _registerToRunLoopForModes:_modes];
}

- (void)readInBackgroundAndNotify
{
    [self readInBackgroundAndNotifyForModes:nil];
}

- (void)readToEndOfFileInBackgroundAndNotifyForModes:(NSArray*)_modes
{
    if (!isOpened)
	[[[NSFileHandleOperationException alloc]
		  initWithFileHandle:self
		  operation:@"Try to read to end of file in background from a"
			    @" closed file descriptor!"] raise];
    if (operation != NSFileHandleNoOperation) {
	NSString* reason = [NSString stringWithFormat:@"Another operation (%s)"
		      @" is already in progress!",
		      (operation == NSFileHandleAcceptOperation
		       ? "accept"
		       : (operation == NSFileHandleReadOperation
			  ? "read"
			  : (operation == NSFileHandleReadToEndOfFileOperation
			     ? "read to end of file"
			     : "unknown")))];
	[[[NSFileHandleOperationException alloc]
		  initWithFileHandle:self
		  operation:reason] raise];
    }

    operation = NSFileHandleReadToEndOfFileOperation;
    fileActivity = NSPosixReadableActivity;

    [self _registerToRunLoopForModes:_modes];
}

- (void)readToEndOfFileInBackgroundAndNotify
{
    [self readToEndOfFileInBackgroundAndNotifyForModes:nil];
}

- (unsigned long long)offsetInFile
{
    if (!isOpened)
	[[[NSFileHandleOperationException alloc]
		  initWithFileHandle:self
		  operation:@"Error getting the offset from a closed file!"] raise];
    if (type != NSFileHandleUnixFile)
	[[[NSFileHandleOperationException alloc]
		  initWithFileHandle:self
		  operation:@"Error getting an offset from a non-file!"] raise];

    return [self filePosition];
}

- (unsigned long long)seekToEndOfFile
{
    if (!isOpened)
	[[[NSFileHandleOperationException alloc]
		initWithFileHandle:self
		operation:@"Error seeking to end of file on a closed file!"] raise];
    if (type != NSFileHandleUnixFile)
	[[[NSFileHandleOperationException alloc]
		  initWithFileHandle:self
		  operation:@"Error seeking to end of file on a non-file!"] raise];

    [self seekToEnd];
    return [self offsetInFile];
}

- (void)seekToFileOffset:(unsigned long long)offset
{
    if (!isOpened)
	[[[NSFileHandleOperationException alloc]
		initWithFileHandle:self
		operation:@"Error seeking to a position on a closed file!"] raise];
    if (type != NSFileHandleUnixFile)
	[[[NSFileHandleOperationException alloc]
		  initWithFileHandle:self
		  operation:@"Error seeking to a position on a non-file!"] raise];

    [self seekToPosition:offset];
}

- (void)closeFile
{
    if (isOpened)
	close (fd);

    isOpened = NO;
}

- (void)truncateFileAtOffset:(unsigned long long)offset
{
    if (!isOpened)
	[[[NSFileHandleOperationException alloc]
		initWithFileHandle:self
		operation:@"Error truncating a closed file!"] raise];
    if (type != NSFileHandleUnixFile)
	[[[NSFileHandleOperationException alloc]
		  initWithFileHandle:self
		  operation:@"Error truncating a non-file!"] raise];

    [self truncateAtPosition:offset];
}

- (void)activity:(NSPosixFileActivities)activity
  posixFileDescriptor:(NSPosixFileDescriptor*)fileDescriptor
{
    NSNotification* notification = nil;
    NSDictionary* userInfo;

    switch (activity) {
	case NSPosixReadableActivity:
	    if (operation == NSFileHandleReadOperation) {
		/* Try to avoid a blocking operation in case the file
		   descriptor is a socket, so we differentiate here between
		   normal files and sockets. */
		NSData* data = nil;

		if (type == NSFileHandleUnixFile) {
		    /* Reading from files cannot block so do an unconditional
		       read here. */
		    data = [self readDataOfLength:blockSize];
		}
#if defined(WIN32)
#  warning NSFileHandleSocket not supported in WIN32
#else
		else if (type == NSFileHandleSocket) {
		    /* Determine if the file descriptor does nonblocking I/O.
		       If it doesn't temporary change it to do, read as many
		       bytes as possible and change it back to blocking I/O.
		     */
		    unsigned fileStatus = fcntl (fd, F_GETFL, 0);
		    BOOL isNonBlocking = (fileStatus & non_blocking);
                    
		    /* Temporary set the file status to nonblocking I/O */
		    if (!isNonBlocking) {
			if(fcntl(fd, F_SETFL, fileStatus|non_blocking) == -1) {
			    NSLog (@"cannot set nonblocking status to file "
				   @"descriptor %d of NSFileHandle %x",
				   fd, self);
			}
		    }

		    data = [self readDataOfLength:blockSize];

		    /* Restore the blocking I/O if it's the case */
		    if (!isNonBlocking) {
			if(fcntl(fd, F_SETFL, fileStatus) == -1) {
			    NSLog (@"cannot restore blocking status of file "
				   @"descriptor %d of NSFileHandle %x",
				   fd, self);
			}
		    }
		}
#endif

		userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			data, NSFileHandleNotificationDataItem,
			modes, NSFileHandleNotificationMonitorModes,
			nil];
		notification = [NSNotification notificationWithName:
				  NSFileHandleReadCompletionNotification
						object:self
						userInfo:userInfo];
	    }
#if defined(__MINGW32__)
#  warning NSFileHandleAcceptOperation not yet supported in mingw32
#else
	    else if (operation == NSFileHandleAcceptOperation) {
		NSFileHandle* newFileHandle;
		union {
		    struct sockaddr_in in_addr;
		    struct sockaddr_un un_addr;
		} sock_address;
		unsigned len = sizeof(sock_address);
		int newFd;

		operation = NSFileHandleNoOperation;
		newFd = accept (fd, (struct sockaddr*)&sock_address, &len);
		newFileHandle = AUTORELEASE([[NSFileHandle alloc]
                                                initWithFileDescriptor:newFd
                                                closeOnDealloc:YES]);
		userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			newFileHandle, NSFileHandleNotificationFileHandleItem,
			modes, NSFileHandleNotificationMonitorModes,
			nil];
		notification = [NSNotification notificationWithName:
				  NSFileHandleConnectionAcceptedNotification
						object:self
						userInfo:userInfo];
	    }
#endif

	    else if (operation == NSFileHandleReadToEndOfFileOperation) {
		NSData* data = nil;

		/* We use a similar algorithm as above here to read from
		   the file descriptor. */
		if (type == NSFileHandleUnixFile) {
		    /* Reading from files cannot block so do an unconditional
		       read here. */
		    data = [self readDataToEndOfFile];
		}
#if defined(__MINGW32__)
#  warning NSFileHandleSocket not yet supported in mingw32
#else
		else if (type == NSFileHandleSocket) {
		    unsigned fileStatus = fcntl (fd, F_GETFL, 0);
		    BOOL isNonBlocking = (fileStatus & non_blocking);

		    /* Determine if the file descriptor does nonblocking I/O.
		       If it doesn't temporary change it to do, read as many
		       bytes as possible and change it back to blocking I/O.
		     */
		    /* Temporary set the file status to nonblocking I/O */
		    if (!isNonBlocking) {
			if(fcntl(fd, F_SETFL, fileStatus|non_blocking) == -1) {
			    NSLog (@"cannot set nonblocking status to file "
				   @"descriptor %d of NSFileHandle %x",
				   fd, self);
			}
		    }

		    data = [self readDataToEndOfFile];

		    /* Restore the blocking I/O if it's the case */
		    if (!isNonBlocking) {
			if(fcntl(fd, F_SETFL, fileStatus) == -1) {
			    NSLog (@"cannot restore blocking status of file "
				   @"descriptor %d of NSFileHandle %x",
				   fd, self);
			}
		    }

		    /* Post the notification */
		    userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			    data, NSFileHandleNotificationDataItem,
			    modes, NSFileHandleNotificationMonitorModes,
			    nil];
		    notification = [NSNotification notificationWithName:
			  NSFileHandleReadToEndOfFileCompletionNotification
						    object:self
						    userInfo:userInfo];
		}
#endif
	    }
	    [[NSNotificationCenter defaultCenter]
		    postNotification:notification];
	    [self ceaseMonitoringFileActivity];
	    break;

	default:
	    break;
    }
}

@end /* NSConcreteFileHandle */


@implementation NSNullDeviceFileHandle

- (NSData*)availableData
{
    return [NSData data];
}

- (NSData*)readDataToEndOfFile
{
    return [NSData data];
}

- (NSData*)readDataOfLength:(unsigned int)length
{
    return [NSData data];
}

- (void)writeData:(NSData*)data
{}

- (void)acceptConnectionInBackgroundAndNotifyForModes:(NSArray*)_modes
{}

- (void)acceptConnectionInBackgroundAndNotify
{}

- (void)readInBackgroundAndNotifyForModes:(NSArray*)_modes
{}

- (void)readInBackgroundAndNotify
{}

- (void)readToEndOfFileInBackgroundAndNotifyForModes:(NSArray*)_modes
{}

- (void)readToEndOfFileInBackgroundAndNotify
{}

- (unsigned long long)offsetInFile
{
    return -1;
}

- (unsigned long long)seekToEndOfFile
{
    return -1;
}

- (void)seekToFileOffset:(unsigned long long)offset
{}

- (void)synchronizeFile
{}

- (void)closeFile
{}

- (void)truncateFileAtOffset:(unsigned long long)offset
{}

- (int)fileDescriptor
{
    return -1;
}

@end /* NSNullDeviceFileHandle */

@implementation NSConcretePipeFileHandle

- (id)initWithFileDescriptor:(int)_fd
{
    return [self initWithFileDescriptor:_fd closeOnDealloc:NO];
}
- (id)initWithFileDescriptor:(int)_fd closeOnDealloc:(BOOL)_flag
{
    self->fd             = _fd;
    self->closeOnDealloc = _flag;
    return self;
}

- (void)dealloc
{
    if (self->closeOnDealloc && (self->fd != -1))
        [self closeFile];
    [super dealloc];
}

/* Getting a file descriptor */

- (int)fileDescriptor
{
    return self->fd;
}

/* Reading from an NSFileHandle */

- (NSData *)availableData
{
    NSData   *data;
    unsigned fileStatus;
    BOOL     isNonBlocking;
    
    /* Determine if the file descriptor does nonblocking I/O.
       If it doesn't temporary change it to do, read as many
       bytes as possible and change it back to blocking I/O.
    */
    fileStatus    = fcntl (fd, F_GETFL, 0);
    isNonBlocking = (fileStatus & non_blocking);
                    
    /* Temporary set the file status to nonblocking I/O */
    if (!isNonBlocking) {
        if(fcntl(fd, F_SETFL, fileStatus|non_blocking) == -1) {
            NSLog (@"cannot set nonblocking status to file "
                   @"descriptor %d of NSFileHandle %x",
                   fd, self);
        }
    }

    data = [self readDataOfLength:4096];

    /* Restore the blocking I/O if it's the case */
    if (!isNonBlocking) {
        if(fcntl(fd, F_SETFL, fileStatus) == -1) {
            NSLog (@"cannot restore blocking status of file "
                   @"descriptor %d of NSFileHandle %x",
                   fd, self);
        }
    }
    return data;
}

- (NSData *)readDataToEndOfFile
{
    NSMutableData *mdata;
    NSData        *data;
    char          buffer[2048];
    
    mdata = [[NSMutableData alloc] initWithCapacity:4096];

    while (YES) {
        size_t readLen;
        
        readLen = read(self->fd, buffer, sizeof(buffer));
        
        if (readLen == 0) {
            /* EOF */
            if ([mdata length] == 0) {
                /* EOF on first read */
                RELEASE(mdata);
                return nil;
            }
            break;
        }
        else if ((int)readLen == -1) {
            /* read failed */
#if defined(EINTR)
            if (errno == EINTR)
                /* read() was interrupted */
                continue;
#endif
#if defined(EAGAIN)
            if (errno == EAGAIN)
                /* read() was interrupted */
                continue;
#endif
            
            [[[PosixFileOperationException alloc]
                             initWithFormat:@"could not read bytes"] raise];
        }
        else
            [mdata appendBytes:buffer length:readLen];
    }
    
    data = [mdata copy];
    RELEASE(mdata);
    return AUTORELEASE(data);
}

- (NSData *)readDataOfLength:(unsigned int)length
{
    NSMutableData *mdata;
    NSData        *data;
    unsigned int  bufSize = 2048 > length ? length : 2048;
    unsigned int  totalRead;
    char          buffer[bufSize];
    
    mdata = [[NSMutableData alloc] initWithCapacity:2048];
    totalRead = 0;
    
    while (YES) {
        size_t readLen, toBeRead;
        
        readLen  = bufSize;
        toBeRead = length - totalRead;
        if (toBeRead < readLen)
            readLen = toBeRead;
        
        readLen = read(self->fd, buffer, readLen);
        
        if ((readLen == 0) && (totalRead == 0)) {
            /* EOF on first read */
            RELEASE(mdata);
            return nil;
        }
        
        if ((int)readLen == -1) {
            /* read failed */
#if defined(EINTR)
            if (errno == EINTR)
                /* read() was interrupted */
                continue;
#endif
#if defined(EAGAIN)
            if (errno == EAGAIN)
                /* read() was interrupted */
                continue;
#endif
            
            [[[PosixFileOperationException alloc]
                             initWithFormat:@"could not read bytes"] raise];
        }
        
        if (readLen > 0) {
            /* add read data to buffer */
            [mdata appendBytes:buffer length:readLen];
            totalRead += readLen;
        }
        
        if ((readLen < bufSize) && (readLen > 0)) {
            /* some bytes where available, return them */
            break;
        }
        
        if (readLen == 0)
            /* EOF */
            break;

        /* all bytes where available, so continue */
    }
    
    data = [mdata copy];
    RELEASE(mdata);
    return AUTORELEASE(data);
}

/* Writing to a pipe */

- (void)writeData:(NSData *)_data
{
    const char *bytes;
    size_t toGo;
    
    bytes = [_data bytes];
    toGo  = [_data length];

    while (toGo > 0) {
        size_t didWrite;
        
        didWrite = write(self->fd, bytes, toGo);
        if ((int)didWrite == -1) {
            /* write failed */
#if defined(EINTR)
            if (errno == EINTR)
                /* read() was interrupted */
                continue;
#endif
#if defined(EAGAIN)
            if (errno == EAGAIN)
                /* read() was interrupted */
                continue;
#endif
            
            [[[PosixFileOperationException alloc]
               initWithFormat:@"could not write %d bytes", [_data length]] raise];
        }
        toGo  -= didWrite;
        bytes += didWrite;
    }
}

/* Communicating asynchronously in the background */

- (void)acceptConnectionInBackgroundAndNotifyForModes:(NSArray *)modes
{
    [self shouldNotImplement:_cmd];
}
- (void)acceptConnectionInBackgroundAndNotify
{
    [self shouldNotImplement:_cmd];
}

- (void)readInBackgroundAndNotifyForModes:(NSArray *)modes
{
    [self notImplemented:_cmd];
}
- (void)readInBackgroundAndNotify
{
    [self notImplemented:_cmd];
}
- (void)readToEndOfFileInBackgroundAndNotifyForModes:(NSArray *)modes
{
    [self notImplemented:_cmd];
}
- (void)readToEndOfFileInBackgroundAndNotify
{
    [self notImplemented:_cmd];
}

/* Seeking within a file (not implemented on pipe's) */

- (unsigned long long)offsetInFile
{
    [self shouldNotImplement:_cmd];
    return 0;
}
- (unsigned long long)seekToEndOfFile
{
    [self shouldNotImplement:_cmd];
    return 0;
}
- (void)seekToFileOffset:(unsigned long long)offset
{
    [self shouldNotImplement:_cmd];
}

/* Operating on a file */

- (void)closeFile
{
    close(self->fd);
    self->fd = -1;
}
- (void)synchronizeFile
{
}
- (void)truncateFileAtOffset:(unsigned long long)offset
{
    [self shouldNotImplement:_cmd];
}

@end /* NSConcretePipeFileHandle */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
