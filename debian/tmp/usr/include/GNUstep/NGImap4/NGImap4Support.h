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

#ifndef __Networking_NGImap4_NGImap4Support_H__
#define __Networking_NGImap4_NGImap4Support_H__

#import <Foundation/NSException.h>

@class NSDictionary, NSString, NSArray, EOQualifier, NSNumber, NSData;
@class NGImap4Client, NGImap4Context, NGImap4Folder;

@protocol NGImap4Folder <NSObject>

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

- (int)exists;
- (int)recent;
- (int)unseen;
- (void)status;
- (void)select;
- (void)expunge;

- (int)usedSpace;
- (int)maxQuota;
- (BOOL)isOverQuota;

- (void)resetFolder;
- (void)resetSubFolders;
- (void)resetStatus;

- (void)resetSync;


@end

@protocol NGImap4ResponseReceiver
- (void)responseNotificationFrom:(NGImap4Client *)_client
  response:(NSDictionary *)_dict;
@end

@interface NGImap4Exception : NSException
@end

@interface NGImap4ParserException : NGImap4Exception
@end
@interface NGImap4ConnectionException : NGImap4Exception
@end
@interface NGImap4ResponseException : NGImap4Exception
@end
@interface NGImap4SearchException : NGImap4Exception
@end

#endif /* __Networking_NGImap4_NGImap4Support_H__ */
