/*
   NSFileHandle.h

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
#ifndef __NSFileHandle_h__
#define __NSFileHandle_h__

#include <Foundation/NSObject.h>

@class NSString;
@class NSData;
@class NSArray;

@interface NSFileHandle : NSObject

/* Getting an NSFileHandle */
+ (id)fileHandleForReadingAtPath:(NSString*)path;
+ (id)fileHandleForWritingAtPath:(NSString*)path;
+ (id)fileHandleForUpdatingAtPath:(NSString*)path;
+ (id)fileHandleWithStandardInput;
+ (id)fileHandleWithStandardOutput;
+ (id)fileHandleWithStandardError;
+ (id)fileHandleWithNullDevice;

@end


@interface NSFileHandle (NSFileHandleInitialization)

/* Creating an NSFileHandle */
- (id)initWithFileDescriptor:(int)fd;
- (id)initWithFileDescriptor:(int)fd closeOnDealloc:(BOOL)flag;

#if defined(WIN32)
- (id)initWithNativeHandle:(void *)_handle;
- (id)initWithNativeHandle:(void *)_handle closeOnDealloc:(BOOL)flag;
#endif /* WIN32 */

@end


@interface NSFileHandle (NSFileHandleOperations)

/* Getting a file descriptor */
- (int)fileDescriptor;
#if defined(WIN32)
- (void *)nativeHandle;
#endif /* WIN32 */

/* Reading from an NSFileHandle */
- (NSData *)availableData;
- (NSData *)readDataToEndOfFile;
- (NSData *)readDataOfLength:(unsigned int)length;

/* Writing to an NSFileHandle */
- (void)writeData:(NSData*)data;

/* Communicating asynchronously in the background */
- (void)acceptConnectionInBackgroundAndNotifyForModes:(NSArray*)modes;
- (void)acceptConnectionInBackgroundAndNotify;
- (void)readInBackgroundAndNotifyForModes:(NSArray*)modes;
- (void)readInBackgroundAndNotify;
- (void)readToEndOfFileInBackgroundAndNotifyForModes:(NSArray*)modes;
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


@interface NSPipe : NSObject

+ (id)pipe;

- (NSFileHandle *)fileHandleForReading;
- (NSFileHandle *)fileHandleForWriting;

- (id)init;

@end


/* Notifications posted by NSFileHandle */
LF_EXPORT NSString *NSFileHandleConnectionAcceptedNotification;
LF_EXPORT NSString *NSFileHandleReadCompletionNotification;
LF_EXPORT NSString *NSFileHandleReadToEndOfFileCompletionNotification;


/* Keys for accessing user info dictionary */

LF_EXPORT NSString *NSFileHandleNotificationFileHandleItem;
    /* The new file handle object obtained after an accept operation. */

LF_EXPORT NSString *NSFileHandleNotificationDataItem;
    /* The data object containing the data read from the file descriptor by 
       a background read operation. */

LF_EXPORT NSString *NSFileHandleNotificationMonitorModes;
    /* The run loop modes in which the notification can be posted. */

#endif /* __NSFileHandle_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
