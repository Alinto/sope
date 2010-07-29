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

#ifndef __NGMime_NGImap4_NGImap4Functions_H__
#define __NGMime_NGImap4_NGImap4Functions_H__

#import <Foundation/NSObject.h>
#include <NGImap4/NGImap4Folder.h>

@class NSString, NSException;

@interface NGImap4FolderHandler : NSObject

+ (id)sharedImap4FolderHandler;

- (NGImap4Folder *)subfolderWithName:(NSString *)_name
  parentFolder:(id<NGImap4Folder>)_parent
  ignoreCase:(BOOL)_caseIns;

- (BOOL)isFolder:(id<NGImap4Folder>)_child 
  aSubfolderOf:(id<NGImap4Folder>)_parent;

- (NSException *)createSubfolderWithName:(NSString *)_name
  parentFolder:(id<NGImap4Folder>)_parent
  append:(BOOL)_append;

@end

NGImap4Folder *_subFolderWithName(id<NGImap4Folder> self, NSString *_name,
                                  BOOL _caseIns);
BOOL _checkResult(NGImap4Context *_ctx, NSDictionary *_dict,
                  const char *_command);
BOOL _isSubFolder(id<NGImap4Folder> self, id<NGImap4Folder>_folder);
BOOL _hasNewMessagesInSubFolder(id<NGImap4Folder> self, BOOL _fetch);
BOOL _hasUnseenMessagesInSubFolder(id<NGImap4Folder> self, BOOL _fetch);
BOOL _deleteSubFolder(id<NGImap4Folder> self, NGImap4Folder *_folder);
BOOL _copySubFolder(id<NGImap4Folder> self,
                    id<NGImap4Folder> _f, id<NGImap4Folder> _toFolder);
BOOL _moveSubFolder(id<NGImap4Folder> self, NGImap4Folder *_f,
                    id<NGImap4Folder>_folder);
BOOL _createSubFolderWithName(id<NGImap4Folder> self, NSString *_name, BOOL _app);

NSString *SaneFolderName(NSString *folderName);

#endif /* __NGMime_NGImap4_NGImap4Functions_H__ */
