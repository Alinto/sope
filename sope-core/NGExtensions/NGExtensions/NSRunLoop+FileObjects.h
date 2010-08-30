/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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
// Created by Helge Hess on Mon Mar 11 2002.

#ifndef __FoundationExt_NSRunLoop_FileObjects__
#define __FoundationExt_NSRunLoop_FileObjects__

#if !LIB_FOUNDATION_LIBRARY

#import <Foundation/NSRunLoop.h>

typedef enum {
    NSPosixNoActivity = 0,
    NSPosixReadableActivity = 1,
    NSPosixWritableActivity = 2,
    NSPosixExceptionalActivity = 4
} NSPosixFileActivities;

extern NSString *NSFileObjectBecameActiveNotificationName;

@interface NSRunLoop(FileObjects)

/* Monitoring file objects */

- (void)addFileObject:(id)_fileObject
  activities:(NSUInteger)_activities
  forMode:(NSString *)_mode;
  
- (void)removeFileObject:(id)_fileObject
  forMode:(NSString *)_mode;

@end

@interface NSObject(RunloopFileObject)

- (BOOL)isOpen;
- (int)fileDescriptor;

@end

#endif /* !LIB_FOUNDATION_LIBRARY */

#endif /* __FoundationExt_NSRunLoop_FileObjects__ */
