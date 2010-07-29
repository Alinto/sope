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

#ifndef __OFS_OFSFactoryContext_H__
#define __OFS_OFSFactoryContext_H__

#import <Foundation/NSObject.h>
#include <NGExtensions/NGFileManager.h>

/*
  OFSFactoryContext

  The factory context is used to transport the instantiation environment
  for OFS objects.
*/

@class NSString;
@class OFSFolder;

@interface OFSFactoryContext : NSObject
{
@public
  id<NSObject,NGFileManager> fileManager;
  NSString *storagePath;
  NSString *fileType;
  NSString *mimeType;
  NSString *name;
  id       container;
  BOOL     isNewObject;
}

+ (OFSFactoryContext *)contextForChild:(NSString *)_name
  storagePath:(NSString *)_sp
  ofFolder:(OFSFolder *)_folder;
+ (OFSFactoryContext *)contextWithFileManager:(id<NSObject,NGFileManager>)_fm
  storagePath:(NSString *)_sp;

+ (OFSFactoryContext *)contextForNewChild:(NSString *)_name
  storagePath:(NSString *)_sp
  ofFolder:(OFSFolder *)_folder;

/* accessors */

- (id<NSObject,NGFileManager>)fileManager;
- (NSString *)storagePath;
- (id)container;
- (NSString *)nameInContainer;

- (NSString *)fileType;
- (NSString *)mimeType;

- (BOOL)isNewObject;

@end

#endif /* __OFS_OFSFactoryContext_H__ */
