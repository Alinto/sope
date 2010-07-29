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
#ifndef __Networking_NGImap4_NGImap4Folder_H__
#define __Networking_NGImap4_NGImap4Folder_H__

#import <Foundation/Foundation.h>
#import <NGMime/NGPart.h>
#import <NGImap4/NGImap4Support.h>

#define USE_MESSAGE_CACHE 0

@class NSArray, NSString, NSMutableArray, NSNumber;
@class EOGlobalID, EOQualifier;
@class NGHashMap;
@class NGImap4Context, NGImap4Message, NGImap4FolderMailRegistry;
@class NGImap4FolderFlags;

@interface NGImap4Folder : NSObject <NGImap4Folder>
{
@private  
  NGImap4FolderFlags *flags;
  NSString           *name;
  NSURL              *url;
  EOGlobalID         *globalID;
  NGImap4Context     *context;
  NSArray            *subFolders;

  NSArray            *msn2UidCache;
  
  id<NGImap4Folder> parentFolder; // not retained

  NSNumber *isReadOnly;
  NSArray  *messageFlags;
  
  int exists;
  int recent;
  int unseen;
  
  BOOL selectSyncState;
  
  int maxQuota;
  int usedSpace;
  int overQuota;

  struct {
    BOOL select:1;
    BOOL status:1;
    BOOL quota:1;
  } failedFlags;
  
  NGImap4FolderMailRegistry *mailRegistry;
  
#if USE_MESSAGE_CACHE
  int cacheIdx;
  
  NSMutableArray *messages;  
  NSMutableArray *qualifierCache;
  NSMutableArray *messagesCache;
#endif  
}

- (id)initWithContext:(NGImap4Context *)_context
  name:(NSString *)_name
  flags:(NSArray *)_flags
  parentFolder:(id<NGImap4Folder>)_folder;

- (BOOL)isEqual:(id)_obj;
- (BOOL)isEqualToImap4Folder:(NGImap4Folder *)_folder;

/* accessors */

- (NGImap4Context *)context;
- (NSException *)lastException;
- (void)resetLastException;
- (id<NGImap4Folder>)parentFolder;

- (NSString *)name;
- (NSString *)absoluteName;
- (NSArray *)flags;

- (NSData *)blobForUid:(unsigned)_mUid
  part:(NSString *)_part;

- (NSArray *)fetchSortedMessages:(NSArray *)_so;

- (void)bulkFetchHeadersFor:(NSArray *)_array inRange:(NSRange)_aRange;
- (void)bulkFetchHeadersFor:(NSArray *)_array inRange:(NSRange)_aRange
  withAllUnread:(BOOL)_allUnread;

- (NSArray *)fetchSortedMessages:(NSRange)_aRange
  sortOrderings:(NSArray *)_so;
- (NSArray *)messageFlags;
- (NSArray *)messages;
- (NSArray *)messagesForQualifier:(EOQualifier *)_qualifier;
- (NSArray *)messagesForQualifier:(EOQualifier *)_qualifier maxCount:(int)_cnt;
- (NSArray *)subFolders;
- (NGImap4Folder *)subFolderWithName:(NSString *)_name
  caseInsensitive:(BOOL)_caseIns;
- (NGImap4Message *)messageForUid:(unsigned)_mUid
  sortOrderings:(NSArray *)_so
  onlyUnread:(BOOL)_unread
  nextMessage:(BOOL)_next;

- (BOOL)isReadOnly;
- (int)exists;
- (int)recent;
- (int)unseen;

- (BOOL)noselect;
- (BOOL)noinferiors;
- (BOOL)nonexistent;
- (BOOL)haschildren;
- (BOOL)hasnochildren;
- (BOOL)marked;
- (BOOL)unmarked;

/* this folder or its subfolders */

- (BOOL)hasNewMessagesSearchRecursiv:(BOOL)_recursiv;
- (BOOL)hasUnseenMessagesSearchRecursiv:(BOOL)_recursiv;
- (BOOL)hasNewMessagesSearchRecursiv:(BOOL)_rec    fetchOnDemand:(BOOL)_fetch;
- (BOOL)hasUnseenMessagesSearchRecursiv:(BOOL)_rec fetchOnDemand:(BOOL)_fetch;

/* Notifications */

- (void)processResponse:(NSDictionary *)_dict;

/* Actions */
- (BOOL)status;
- (BOOL)select;
/* if imm == YES syncState will be ignored */
- (BOOL)selectImmediately:(BOOL)_imm;
- (void)expunge;

- (BOOL)addFlag:(NSString *)_flag toMessages:(NSArray *)_messages;
- (BOOL)removeFlag:(NSString *)_flag fromMessages:(NSArray *)_messages;
- (BOOL)renameTo:(NSString *)_name;

/* returns quota in kBytes */
- (int)usedSpace;
- (int)maxQuota;
- (BOOL)isOverQuota; /* evaluate ALERT sequences during select */

- (BOOL)deleteMessages:(NSArray *)_messages;
- (BOOL)deleteAllMessages;
- (BOOL)moveMessages:(NSArray *)_messages toFolder:(NGImap4Folder *)_folder;
- (BOOL)copyMessages:(NSArray *)_messages toFolder:(NGImap4Folder *)_folder;
- (BOOL)appendMessage:(NSData *)_msg;

- (BOOL)deleteSubFolder:(NGImap4Folder *)_folder;
- (BOOL)createSubFolderWithName:(NSString *)_name;
- (BOOL)copySubFolder:(NGImap4Folder *)_f to:(NGImap4Folder *)_folder;
- (BOOL)moveSubFolder:(NGImap4Folder *)_f to:(NGImap4Folder *)_folder;

- (BOOL)isInTrash;

- (void)resetFolder;
- (void)resetSubFolders;
- (void)resetStatus;

- (void)resetSync;

- (NSURL *)url;
- (EOGlobalID *)serverGlobalID;
- (EOGlobalID *)globalID;

/* message factory */

- (id)messageWithUid:(unsigned int)_uid;

/* message registry */

- (NGImap4FolderMailRegistry *)mailRegistry;

@end

#endif /* __Networking_NGImap4_NGImap4Folder_H__ */
