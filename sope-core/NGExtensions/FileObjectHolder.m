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

#include "FileObjectHolder.h"
#include "NSRunLoop+FileObjects.h"
#import <Foundation/NSException.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSFileHandle.h>
#include "common.h"

@implementation FileObjectHolder

- (id)initWithFileObject:(id)_object
  activities:(int)_activities
  mode:(NSString *)_mode 
{
  if (_object == nil) {
    [self release];
    return nil;
  }
  self->fileObject = [_object retain];
  self->fd         = [_object fileDescriptor];
  self->activities = _activities;
  self->mode       = [_mode copy];
  self->fileHandle =
    [[NSFileHandle alloc] initWithFileDescriptor:self->fd closeOnDealloc:NO];
  NSAssert(self->fileHandle, @"couldn't create filehandle ...");

  [[self notificationCenter]
         addObserver:self selector:@selector(_dataAvailable:)
         name:NSFileHandleDataAvailableNotification 
         object:self->fileHandle];
  [[self notificationCenter]
         addObserver:self selector:@selector(_acceptAvailable:)
         name:NSFileHandleConnectionAcceptedNotification
         object:self->fileHandle];
  
  return self;
}

- (void)dealloc {
  if (self->waitActive)
    [[self notificationCenter] removeObserver:self];
  [self->mode       release];
  [self->fileHandle release];
  [self->fileObject release];
  [super dealloc];
}

/* accessors */

- (int)fileDescriptor {
  return self->fd;
}
- (NSFileHandle *)fileHandle {
  return self->fileHandle;
}
- (id)fileObject {
  return self->fileObject;
}
- (int)activities {
  return self->activities;
}
- (NSString *)mode {
  return self->mode;
}

- (NSArray *)modes {
  return [NSArray arrayWithObject:[self mode]];
}

/* notifications */

- (NSNotificationCenter *)notificationCenter {
  return [NSNotificationCenter defaultCenter];
}

- (void)handleException:(NSException *)_exception {
  NSLog(@"%s: catched: %@", __PRETTY_FUNCTION__, _exception);
}

- (void)_dataAvailable:(NSNotification *)_notification {
  if ([_notification object] != self->fileHandle) {
    NSLog(@"%s: notification object %@ does not match file handle %@",
          __PRETTY_FUNCTION__, [_notification object], self->fileHandle);
    return;
  }
  
  if (![self->fileObject isOpen]) {
    //NSLog(@"file object is closed ...");
    return;
  }
  
  NS_DURING {
    self->waitActive = NO;
    [self wait];
    [[self notificationCenter]
           postNotificationName:NSFileObjectBecameActiveNotificationName
           object:self->fileObject];
  }
  NS_HANDLER
    [self handleException:localException];
  NS_ENDHANDLER;
}

- (void)_acceptAvailable:(NSNotification *)_notification {
  NSLog(@"accept available ...");
  if ([_notification object] != self->fileHandle) {
    NSLog(@"%s: notification object %@ does not match file handle %@",
          __PRETTY_FUNCTION__, [_notification object], self->fileHandle);
    return;
  }
  [[self notificationCenter]
         postNotificationName:NSFileObjectBecameActiveNotificationName
         object:self->fileObject];
}

/* operations */

- (void)wait {
  if (self->waitActive) return;
  
  if (![self->fileObject isOpen]) return;
  
  self->waitActive = YES;
  
#if 0
  /* use accept for passive fileobjects ?, wait seems to work too ... :-) */
  if ([self->fileObject isPassive]) {
    NSLog(@"add passive %@ ..", self->fileObject);
// => this also accepts the connection :-(
    [self->fileHandle acceptConnectionInBackgroundAndNotifyForModes:
                        [self modes]];
  }
  else
#endif
    [self->fileHandle waitForDataInBackgroundAndNotifyForModes:[self modes]];
}
- (void)stopWaiting {
}

/* equality */

- (BOOL)isEqualToFileObjectHolder:(FileObjectHolder *)_other {
  if (self->fd != _other->fd) return NO;
  if (![self->mode isEqualToString:_other->mode]) return NO;
  if (![self->fileObject isEqual:_other->fileObject]) return NO;
  return YES;
}
- (BOOL)isEqual:(id)_other {
  if (_other == self) return YES;
  if (_other == nil)  return NO;
  if ([_other class] != [self class]) return NO;
  return [self isEqualToFileObjectHolder:_other];
}

/* description */

@end /* FileObject */
