/*
   NSConcreteFileHandle.m

   Copyright (C) 2000 Helge Hess
   All rights reserved.

   Author: Helge Hess <helge.hess@mdlink.de>
   Date: Feb 2000
   
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
#include <config.h>
#include <Foundation/common.h>

#include "NSConcreteWindowsFileHandle.h"
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSException.h>
#include "exceptions/NSFileHandleExceptions.h"
#include <Foundation/NSString.h>
#include <Foundation/NSData.h>

#ifdef HAVE_WINDOWS_H
#  include <windows.h>
#endif

@implementation NSConcreteWindowsFileHandle

+ (id)fileHandleForReadingAtPath:(NSString *)path
{
    HANDLE fh;

    fh = CreateFile([path fileSystemRepresentation],
		    GENERIC_READ,
		    FILE_SHARE_READ,
		    NULL /* no security */,
		    OPEN_EXISTING,
		    FILE_ATTRIBUTE_NORMAL,
		    NULL /* no attr template */);
    if (fh == INVALID_HANDLE_VALUE)
	return nil;
    
    return
	AUTORELEASE([[self alloc] initWithNativeHandle:fh closeOnDealloc:YES]);
}
+ (id)fileHandleForWritingAtPath:(NSString *)path
{
    HANDLE fh;

    fh = CreateFile([path fileSystemRepresentation],
		    GENERIC_WRITE,
		    0 /* do not share */,
		    NULL /* no security */,
		    CREATE_ALWAYS,
		    FILE_ATTRIBUTE_NORMAL,
		    NULL /* no attr template */);
    if (fh == INVALID_HANDLE_VALUE)
	return nil;
    
    return
	AUTORELEASE([[self alloc] initWithNativeHandle:fh closeOnDealloc:YES]);
}
+ (id)fileHandleForUpdatingAtPath:(NSString *)path
{
    HANDLE fh;

    fh = CreateFile([path fileSystemRepresentation],
		    GENERIC_WRITE,
		    0    /* do not share */,
		    NULL /* no security */,
		    OPEN_ALWAYS,
		    FILE_ATTRIBUTE_NORMAL,
		    NULL /* no attr template */);
    if (fh == INVALID_HANDLE_VALUE)
	return nil;
    
    return
	AUTORELEASE([[self alloc] initWithNativeHandle:fh closeOnDealloc:YES]);
}

- (id)initWithNativeHandle:(void *)_handle closeOnDealloc:(BOOL)_flag
{
    self->handle         = _handle;
    self->closeOnDealloc = _flag;
    return self;
}

- (id)initWithNativeHandle:(void *)_handle
{
    return [self initWithNativeHandle:_handle closeOnDealloc:NO];
}

- (void)dealloc
{
    if ((self->handle != NULL) && (self->closeOnDealloc))
	CloseHandle(self->handle);
    [super dealloc];
}

/* Reading from an NSFileHandle */

- (NSData *)availableData
{
    /* should be improved for sockets .. */
    return [self readDataToEndOfFile];
}
- (NSData *)readDataToEndOfFile
{
    return [self readDataOfLength:UINT_MAX];
}

- (NSData *)readDataOfLength:(unsigned int)length
{
    LPVOID buf, ptr;
    DWORD  readCount;

    if (self->handle == NULL ) {
	THROW([[NSFileHandleOperationException alloc]
		    initWithFileHandle:self
		    operation:@"Try to write in a closed file handle!"]);
    }
    
    if (length == 0) return [NSData data];
    
    ptr = buf = NSZoneMallocAtomic(NULL, length);
    readCount = 0;
    while (readCount < length) {
	DWORD readBytes;
	
	if (ReadFile(self->handle, ptr,
		     (length - readCount), &readBytes,
		     NULL)) {
	    readCount += readBytes;
	    ptr       += readBytes;
	}
	else {
	    DWORD err = GetLastError();

	    if (err == ERROR_HANDLE_EOF)
		break;
	    
	    [NSFileHandleOperationException raise:@"ReadException"
			 format:@"could not write data: %i", err];
	}
    }
    return [NSData dataWithBytesNoCopy:buf length:readCount];
}

/* Writing to an NSFileHandle */

- (void)writeData:(NSData *)data
{
    LPCVOID buf;
    DWORD   count;
    DWORD   written;

    if (self->handle == NULL ) {
	THROW([[NSFileHandleOperationException alloc]
		    initWithFileHandle:self
		    operation:@"Try to write in a closed file handle!"]);
    }
    
    buf   = [data bytes];
    count = [data length];
    
    while (count > 0) {
	if (WriteFile(self->handle, buf, count, &written, NULL)) {
	    count -= written;
	    buf   += written;
	}
	else {
	    DWORD err = GetLastError();
	    [NSFileHandleOperationException raise:@"WriteException"
			 format:@"could not write data: %i", err];
	}
    }
}

@end /* NSConcreteWindowsFileHandle */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
