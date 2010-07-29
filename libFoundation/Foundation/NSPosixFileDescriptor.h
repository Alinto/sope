/* 
   NSPosixFileDescriptor.h

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

#ifndef __NSPosixFileDescriptor_h__
#define __NSPosixFileDescriptor_h__

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <Foundation/NSObject.h>
#include <Foundation/NSRange.h>

@class NSData;
@class NSString;

typedef enum {
    NSPosixNoActivity = 0,
    NSPosixReadableActivity = 1,
    NSPosixWritableActivity = 2,
    NSPosixExceptionalActivity = 4
} NSPosixFileActivities;

@interface NSPosixFileDescriptor : NSObject
{
    int      fd;
    id       delegate;
    unsigned fileActivity;
    BOOL     owned;
}

// Getting a standard NSPosixFileDescriptor

+ (id)descriptorWithStandardInput;
+ (id)descriptorWithStandardOutput;
+ (id)descriptorWithStandardError;

// Initialize

- (id)initWithFileDescriptor:(int)fileDescriptor;
- (id)initWithPath:(NSString*)aPath;
- (id)initWithPath:(NSString*)aPath flags:(int)flags;
- (id)initWithPath:(NSString*)aPath flags:(int)flags createMode:(int)mode;

// Get FD

- (int)fileDescriptor;

// Read

- (NSData *)readEntireFile;
- (NSData *)readFileRange:(NSRange)aRange;
- (NSData *)readFileLength:(long)length;
- (NSData *)readRestOfFile;
- (void)readBytes:(void*)bytes range:(NSRange)range;

// Write

- (void)writeData:(NSData*)aData;
- (void)writeData:(NSData*)aData range:(NSRange)aRange;
- (void)writeString:(NSString*)string;
- (void)writeString:(NSString*)string range:(NSRange)aRange;

// Seek & Truncate

- (int unsigned)fileLength;
- (int unsigned)filePosition;
- (void)seekToEnd;
- (void)seekToPosition:(long)aPosition;
- (void)truncateAtPosition:(long)aPosition;

// Mapping files to memory

- (NSData *)mapFileRange:(NSRange)range;
- (void)synchronizeFile;

// Monitoring file descriptors

- (void)monitorFileActivity:(NSPosixFileActivities)activity;
- (void)monitorActivity:(NSPosixFileActivities)activity delegate:(id)delegate;
- (void)ceaseMonitoringFileActivity;
- (NSPosixFileActivities)fileActivity;

// File descriptor delegate

- (id)delegate;
- (void)setDelegate:(id)delegate;

@end /* NSPosixFileDescriptor */


@interface NSObject (NSPosixFileDescriptorDelegateMethod)

- (void)activity:(NSPosixFileActivities)activity
  posixFileDescriptor:(NSPosixFileDescriptor *)fileDescriptor;

@end

LF_EXPORT NSString *NSPosixFileOperationException;

#endif /* __NSPosixFileDescriptor_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
