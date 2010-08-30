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

#ifndef __NGMime_NGMimeFileData_H__
#define __NGMime_NGMimeFileData_H__

#import <Foundation/NSData.h>

/*
  NGMimeFileData
  
  TODO: explain. Somehow this is an object to save loading an NSData to RAM.
  
  Note: the -initWithBytes:length: method creates a temporary file!
  
  Checked in:
  - NGMimeBodyGenerator
  - NGMimeBodyPart
  - NGMimeJoinedData
*/

@class NSString;

@interface NGMimeFileData : NSData
{
  NSString *path;
  BOOL     removeFile;
  int      length;
}

- (id)initWithPath:(NSString *)_path removeFile:(BOOL)_remove;
- (id)initWithBytes:(const void *)_bytes length:(NSUInteger)_length;

/* operations */

- (BOOL)appendDataToFileDesc:(int)_fd;

@end /* NGMimeFileData */

#endif /* __NGMime_NGMimeFileData_H__ */
