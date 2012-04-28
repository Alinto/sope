/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __NGImap4Connection_H__
#define __NGImap4Connection_H__

#import <Foundation/NSObject.h>

/*
  NGImap4Connection
  
  A cached connection to an IMAP4 server plus some cached objects. Do not
  instantiate this object directly but rather use the NGImap4ConnectionManager.
  
  This API is intended to be simpler and more consistent than NGImap4Client.
  
  It caches:
   - the folder hierarchy
   - uid sets?
   - 'myrights' permissions of mailboxes
   ?
*/

@class NSString, NSDate, NSArray, NSDictionary, NSMutableArray, NSURL, NSMutableDictionary;
@class NSException, NSData;
@class NGImap4Client;

@interface NGImap4Connection : NSObject
{
@public
  NGImap4Client *client;
  NSString      *password;
  NSDate        *creationTime;
  NSString      *separator;

  /* hierarchy cache */
  NSMutableDictionary  *subfolders;

  /* permission cache */
  NSMutableDictionary *urlToRights;
  
  /* uids cache */
  NSArray *cachedUIDs;
  NSURL   *uidFolderURL;
  id      uidSortOrdering;
}

- (id)initWithClient:(NGImap4Client *)_client password:(NSString *)_pwd;

/* accessors */

- (NGImap4Client *)client;
- (BOOL)isValidPassword:(NSString *)_pwd;

- (NSDate *)creationTime;

- (void)cacheHierarchyResults:(NSDictionary *)_hierarchy
                       forURL:(NSURL *)_url;
- (NSDictionary *)cachedHierarchyResultsForURL:(NSURL *)_url;
- (void)flushFolderHierarchyCache;

- (id)cachedUIDsForURL:(NSURL *)_url qualifier:(id)_q sortOrdering:(id)_so;
- (void)cacheUIDs:(NSArray *)_uids forURL:(NSURL *)_url
  qualifier:(id)_q sortOrdering:(id)_so;

- (NSString *)cachedMyRightsForURL:(NSURL *)_url;
- (void)cacheMyRights:(NSString *)_rights forURL:(NSURL *)_url;

- (void)flushMailCaches;

/* utilities */
- (NSString *)imap4FolderNameForURL:(NSURL *)_url;
- (NSString *)imap4FolderNameForURL:(NSURL *)_url removeFileName:(BOOL)_delfn;

/* extensions methods */
- (NSException *)enableExtensions:(NSArray *)_extensions;

/* folder operations */

- (NSArray *)subfoldersForURL:(NSURL *)_url;
- (NSArray *)subfoldersForURL:(NSURL *)_url
  onlySubscribedFolders: (BOOL) subscribedFoldersOnly;
- (NSArray *)allFoldersForURL:(NSURL *)_url;
- (NSArray *)allFoldersForURL:(NSURL *)_url
  onlySubscribedFolders: (BOOL) subscribedFoldersOnly;
- (BOOL)selectFolder:(id)_url;

/* message operations */

- (NSArray *)fetchUIDsInURL:(NSURL *)_url
                  qualifier:(id)_qualifier
               sortOrdering:(id)_so;
- (NSArray *)fetchThreadedUIDsInURL:(NSURL *)_url
                          qualifier:(id)_qualifier
                       sortOrdering:(id)_so;
- (NSArray *)fetchUIDs:(NSArray *)_uids inURL:(NSURL *)_url
  parts:(NSArray *)_parts;
- (id)fetchURL:(NSURL *)_url parts:(NSArray *)_parts;
- (NSData *)fetchContentOfBodyPart:(NSString *)_partId atURL:(NSURL *)_url;
- (NSData *)fetchContentOfBodyPart:(NSString *)_partId atURL:(NSURL *)_url
                          withPeek:(BOOL)_withPeek;

/* message flags */

- (NSException *)addOrRemove:(BOOL)_flag flags:(id)_f toURL:(NSURL *)_url;
- (NSException *)addFlags:(id)_f    toURL:(NSURL *)_u;
- (NSException *)removeFlags:(id)_f toURL:(NSURL *)_u;
- (NSException *)markURLDeleted:(NSURL *)_url;
- (NSException *)addFlags:(id)_f toAllMessagesInURL:(NSURL *)_url;

/* posting new data */

- (NSException *)postData:(NSData *)_data flags:(id)_f toFolderURL:(NSURL *)_u;

/* operations */

- (NSException *)expungeAtURL:(NSURL *)_url;

/* copying and moving */

- (NSException *)copyMailURL:(NSURL *)_srcurl toFolderURL:(NSURL *)_desturl;

/* managing folders */

- (BOOL)doesMailboxExistAtURL:(NSURL *)_url;
- (id)infoForMailboxAtURL:(NSURL *)_url;
- (NSException *)createMailbox:(NSString *)_mailbox atURL:(NSURL *)_url;
- (NSException *)deleteMailboxAtURL:(NSURL *)_url;
- (NSException *)moveMailboxAtURL:(NSURL *)_srcurl toURL:(NSURL *)_desturl;

/* ACLs */

- (NSDictionary *)aclForMailboxAtURL:(NSURL *)_url;
- (NSString *)myRightsForMailboxAtURL:(NSURL *)_url;

@end

#endif /* __NGImap4Connection_H__ */
