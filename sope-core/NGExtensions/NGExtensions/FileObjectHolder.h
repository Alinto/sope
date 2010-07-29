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
// Created by Helge Hess on Wed Apr 17 2002.

#ifndef __testrunloop_FileObject__
#define __testrunloop_FileObject__

#import <Foundation/NSObject.h>

@class NSFileHandle, NSNotificationCenter;

/*
  This class is used to implement Unix filedescriptor notification
  on the MacOSX Foundation library.
*/

@interface FileObjectHolder : NSObject 
{
  NSFileHandle *fileHandle;
  NSString     *mode;
  id   fileObject;
  int  fd;
  int  activities;
  BOOL waitActive;
}

- (id)initWithFileObject:(id)_obj activities:(int)_act mode:(NSString *)_mode;

/* accessors */

- (NSFileHandle *)fileHandle;
- (id)fileObject;
- (int)fileDescriptor;
- (int)activities;
- (NSString *)mode;

- (NSNotificationCenter *)notificationCenter;

/* operations */

- (void)wait;
- (void)stopWaiting;

@end

#endif /* __testrunloop_FileObject__ */
