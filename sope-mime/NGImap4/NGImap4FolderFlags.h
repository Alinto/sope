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

#ifndef __NGImap4_NGImap4FolderFlags_H__
#define __NGImap4_NGImap4FolderFlags_H__

#import <Foundation/NSObject.h>

@class NSArray;

@interface NGImap4FolderFlags : NSObject
{
  NSArray *flags; // TODO: document
  
  struct {
    BOOL nonexistent:1; /* Cyrus set this flag, 
			   if the folder exist in cache only */
    BOOL noselect:1;
    BOOL haschildren:1;
    BOOL hasnochildren:1;
    BOOL noinferiors:1;
    BOOL marked:1;
    BOOL unmarked:1;
  } listFlags;
}

- (id)initWithFlagArray:(NSArray *)_array;

/* accessors */

- (NSArray *)flagArray;
- (BOOL)doNotSelectFolder;
- (BOOL)doesNotSupportSubfolders;
- (BOOL)doesNotExist;
- (BOOL)hasSubfolders;
- (BOOL)hasNoSubfolders;
- (BOOL)isMarked;
- (BOOL)isUnmarked;

/* operations */

- (void)allowFolderSelect;

@end

#endif /* __NGImap4_NGImap4FolderFlags_H__ */
