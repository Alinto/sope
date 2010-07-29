/*
   NSConcreteFileHandle.h

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
#ifndef __NSConcreteFileHandle_h__
#define __NSConcreteFileHandle_h__

#include <Foundation/NSPosixFileDescriptor.h>
#include <Foundation/NSFileHandle.h>

@class NSPosixFileDescriptor;

typedef enum {
    NSFileHandleNoOperation = 0,
    NSFileHandleAcceptOperation,
    NSFileHandleReadOperation,
    NSFileHandleReadToEndOfFileOperation
} NSFileHandleOperation;

typedef enum {
    NSFileHandleNoType = 0,
    NSFileHandleSocket,
    NSFileHandleUnixFile
} NSFileHandleType;

@class NSArray;
@class NSData;
@class NSMutableData;

@interface NSConcreteFileHandle : NSPosixFileDescriptor
{
    int                   blockSize;
    BOOL                  closeOnDealloc;
    BOOL                  isOpened;
    NSFileHandleOperation operation;
    NSFileHandleType      type;
    NSArray               *modes;
}

/* Creating an NSFileHandle */
- (id)initWithFileDescriptor:(int)fd;
- (id)initWithFileDescriptor:(int)fd closeOnDealloc:(BOOL)flag;
- (id)initWithPath:(NSString *)aPath flags:(int)flags createMode:(int)mode;

+ (id)fileHandleForReadingAtPath:(NSString *)path;
+ (id)fileHandleForWritingAtPath:(NSString *)path;
+ (id)fileHandleForUpdatingAtPath:(NSString *)path;

@end


@interface NSConcreteFileHandle (NSFileHandleOperations)

/* Getting a file descriptor */
- (int)fileDescriptor;

/* Reading from an NSFileHandle */
- (NSData *)availableData;
- (NSData *)readDataToEndOfFile;
- (NSData *)readDataOfLength:(unsigned int)length;

/* Writing to an NSFileHandle */
- (void)writeData:(NSData *)data;

/* Communicating asynchronously in the background */
- (void)acceptConnectionInBackgroundAndNotifyForModes:(NSArray *)modes;
- (void)acceptConnectionInBackgroundAndNotify;
- (void)readInBackgroundAndNotifyForModes:(NSArray *)modes;
- (void)readInBackgroundAndNotify;
- (void)readToEndOfFileInBackgroundAndNotifyForModes:(NSArray *)modes;
- (void)readToEndOfFileInBackgroundAndNotify;

/* Seeking within a file */
- (unsigned long long)offsetInFile;
- (unsigned long long)seekToEndOfFile;
- (void)seekToFileOffset:(unsigned long long)offset;

/* Operating on a file */
- (void)closeFile;
- (void)synchronizeFile;
- (void)truncateFileAtOffset:(unsigned long long)offset;

@end


@interface NSNullDeviceFileHandle : NSFileHandle
@end

@interface NSConcretePipeFileHandle : NSFileHandle
{
    int  fd;
    BOOL closeOnDealloc;
}

@end

#endif /* __NSConcreteFileHandle_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
