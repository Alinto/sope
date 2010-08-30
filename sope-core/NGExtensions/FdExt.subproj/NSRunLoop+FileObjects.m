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
// Created by Helge Hess on Mon Mar 11 2002.

#if !LIB_FOUNDATION_LIBRARY

#include <stdlib.h>
#include "NSRunLoop+FileObjects.h"
#include "FileObjectHolder.h"
#import <Foundation/NSMapTable.h>
#import <Foundation/NSNotification.h>
#include "common.h"

NSString *NSFileObjectBecameActiveNotificationName =
  @"NSFileObjectBecameActiveNotification";

#if GNUSTEP_BASE_LIBRARY

@interface NSObject(FileObjectWatcher) < RunLoopEvents >
@end

@implementation NSObject(FileObjectWatcher)

- (NSDate *)timedOutEvent:(void *)_fdData
  type: (RunLoopEventType)_type
  forMode: (NSString *)_mode
{
  NSLog(@"%s: timed out ...", __PRETTY_FUNCTION__);
  return nil;
}

- (void)receivedEvent:(void *)_fdData
  type:(RunLoopEventType)_type
  extra:(void *)_extra
  forMode:(NSString *)_mode
{
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  
  [nc postNotificationName:NSFileObjectBecameActiveNotificationName
      object:self];
}

@end /* NSObject(FileObjectWatcher) */

#endif

@implementation NSRunLoop(FileObjects)

#if GNUSTEP_BASE_LIBRARY

/* implement using -addEvent:type:watcher:forMode: */

- (void)addFileObject:(id)_fileObject
  activities:(NSUInteger)_activities
  forMode:(NSString *)_mode
{
  NSInteger evType = 0;
  
  _fileObject = RETAIN(_fileObject);
  
  [self addEvent:(void *) ((NSInteger) [_fileObject fileDescriptor])
        type:evType
        watcher:_fileObject
        forMode:_mode];
}
- (void)removeFileObject:(id)_fileObject
  forMode:(NSString *)_mode
{
  int evType = 0;
  
  _fileObject = AUTORELEASE(_fileObject);
  [self removeEvent:(void *) ((NSInteger) [_fileObject fileDescriptor])
        type:evType
        forMode:_mode
        all:NO];
}

#else /* eg MacOSX Foundation ... */

static NSMutableArray *activeHandles = nil;

- (void)addFileObject:(id)_fileObject
  activities:(unsigned int)_activities
  forMode:(NSString *)_mode
{
  FileObjectHolder *fo;
  
  if (activeHandles == nil)
    activeHandles = [[NSMutableArray alloc] init];
  
  fo = [[FileObjectHolder alloc] initWithFileObject:_fileObject
                                 activities:_activities
                                 mode:_mode];
  [activeHandles addObject:fo];
  [fo wait];
  [fo release];
}

- (FileObjectHolder *)_findHolderForObject:(id)_fileObject {
  NSEnumerator *e;
  FileObjectHolder *fo;
  
  if (activeHandles == nil) return NULL;
  e = [activeHandles objectEnumerator];
  while ((fo = [e nextObject])) {
    if ([fo fileObject] == _fileObject)
      break;
  }
  return fo;
}
  
- (void)removeFileObject:(id)_fileObject
  forMode:(NSString *)_mode
{
  FileObjectHolder *fo;

  if ((fo = [self _findHolderForObject:_fileObject]) == nil) {
    NSLog(@"found no holder for fileobject %@ ...", _fileObject);
    return;
  }
  
  [fo retain];
  [activeHandles removeObject:fo];
  [fo stopWaiting];
  [fo release];
}

#endif /* !GNUSTEP_BASE_LIBRARY */

@end /* NSRunLoop(FileObjects) */

#endif /* !LIB_FOUNDATION_LIBRARY */
