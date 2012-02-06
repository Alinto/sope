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
#ifndef __Networking_NGImap4_NGImap4ServerRoot_H__
#define __Networking_NGImap4_NGImap4ServerRoot_H__

#import  <Foundation/Foundation.h>
#include <NGMime/NGPart.h>
#include <NGImap4/NGImap4Support.h>

@class NSArray, NSString, NSMutableArray, NSNumber;
@class NGHashMap, NGImap4Context, EOQualifier;

@interface NGImap4ServerRoot : NSObject <NGImap4Folder>
{
@private  
  NSString       *name;
  NGImap4Context *context;
  NSArray        *subFolders;
  BOOL           noinferiors;
}

+ (id)serverRootWithContext:(NGImap4Context *)_context;

- (id)initServerRootWithContext:(NGImap4Context *)_context;

- (NSException *)lastException;
- (void)resetLastException;

- (BOOL)isEqual:(id)_obj;
- (BOOL)isEqualToServerRoot:(NGImap4ServerRoot *)_root;

- (NGImap4Context *)context;
- (NGImap4Folder *)parentFolder;

- (NSString *)name;
- (NSString *)absoluteName;
- (BOOL)renameTo:(NSString *)_name;
- (BOOL)isInTrash;

- (NSArray *)messageFlags;
- (NSArray *)messages;
- (NSArray *)messagesForQualifier:(EOQualifier *)_qualifier;
- (NSArray *)messagesForQualifier:(EOQualifier *)_qualifier maxCount:(int)_cnt;
- (BOOL)deleteMessages:(NSArray *)_messages;
- (BOOL)deleteAllMessages;
- (BOOL)moveMessages:(NSArray *)_messages toFolder:(NGImap4Folder *)_folder;
- (BOOL)copyMessages:(NSArray *)_messages toFolder:(NGImap4Folder *)_folder;
- (BOOL)appendMessage:(NSData *)_msg;

- (BOOL)hasNewMessagesSearchRecursiv:(BOOL)_recursiv;
- (BOOL)hasNewMessagesSearchRecursiv:(BOOL)_recursiv fetchOnDemand:(BOOL)_fetch;

- (BOOL)hasNewMessagesSearchRecursiv:(BOOL)_recursiv fetchOnDemand:(BOOL)_fetch;
- (BOOL)hasUnseenMessagesSearchRecursiv:(BOOL)_recursiv;

- (BOOL)addFlag:(NSString *)_flag toMessages:(NSArray *)_messages;
- (BOOL)removeFlag:(NSString *)_flag fromMessages:(NSArray *)_messages;

- (NSArray *)subFolders;
- (NGImap4Folder *)subFolderWithName:(NSString *)_name
  caseInsensitive:(BOOL)_caseIns;
- (BOOL)deleteSubFolder:(NGImap4Folder *)_folder;
- (BOOL)createSubFolderWithName:(NSString *)_name;
- (BOOL)copySubFolder:(NGImap4Folder *)_f to:(NGImap4Folder *)_folder;
- (BOOL)moveSubFolder:(NGImap4Folder *)_f to:(NGImap4Folder *)_folder;

- (BOOL)isReadOnly;

- (BOOL)noselect;
- (BOOL)noinferiors;
- (BOOL)nonexistent;
- (BOOL)haschildren;
- (BOOL)marked;
- (BOOL)unmarked;

- (int)exists;
- (int)recent;
- (int)unseen;
- (BOOL)status;
- (void)select;
- (void)expunge;

- (void)resetFolder;
- (void)resetSubFolders;
- (void)resetStatus;

- (void)resetSync;

- (void)bulkFetchHeadersFor:(NSArray *)_array inRange:(NSRange)_aRange;

- (void)bulkFetchHeadersFor:(NSArray *)_array inRange:(NSRange)_aRange
  withAllUnread:(BOOL)_unread;

@end

#endif /* __Networking_NGImap4_NGImap4ServerRoot_H__ */
