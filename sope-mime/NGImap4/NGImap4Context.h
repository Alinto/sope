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

#ifndef __OGo_NGImap4_NGImap4Context_H__
#define __OGo_NGImap4_NGImap4Context_H__

#import <Foundation/NSObject.h>
#include <NGImap4/NGImap4Support.h>

/*
  NGImap4Context
  
  This object is a higher level client object build on top of the NGImap4Client
  object which represents the connection to the IMAP4 server and handles the
  raw IMAP4 processing.
  The NGImap4Context adds to that higher level functionality like caching of
  folders.
*/

@class NSDictionary, NGHashMap, NSMutableArray, NSURL, NSException;
@class EOGlobalID;
@class NGImap4Client, NGImap4Folder, NGImap4ServerRoot;

@interface NGImap4Context : NSObject <NGImap4ResponseReceiver>
{
  NSDictionary      *connectionDictionary;
  NSMutableArray    *folderForRefresh;
  NGImap4Client     *client;
  NGImap4Folder     *selectedFolder; /* not retained */
  NGImap4Folder     *trashFolder;    /* not retained */
  NGImap4Folder     *sentFolder;     /* not retained */
  NGImap4Folder     *draftsFolder;   /* not retained */
  NGImap4Folder     *inboxFolder;    /* not retained */  
  NGImap4ServerRoot *serverRoot;     /* not retained */

  NSArray           *capability; // TODO: array of what?

  NSString *sentFolderName;
  NSString *trashFolderName;
  NSString *draftsFolderName;

  NSString *serverName;
  NSString *serverKind;
  NSNumber *serverVersion;
  NSNumber *serverSubVersion;
  NSNumber *serverTag;
  
  BOOL syncMode;
  
  NSException *lastException;

  NSURL *url;

  int canSort;
  int canQuota;

  NSString *sortEncoding;
  int      subscribeFolderFailed;
  int      showOnlySubscribedInRoot;
  int      showOnlySubscribedInSubFolders;
}


+ (id)imap4ContextWithURL:(id)_url;
+ (id)imap4ContextWithConnectionDictionary:(NSDictionary *)_connection;
- (id)initWithNSURL:(NSURL *)_url;
- (id)initWithURL:(id)_url;
- (id)initWithConnectionDictionary:(NSDictionary *)_connection;

/* accessors */

- (NGImap4Client *)client;
- (EOGlobalID *)serverGlobalID;

- (NSURL *)url;

/* folder tracking */

- (BOOL)isSelectedFolder:(NGImap4Folder *)_folder;
- (BOOL)registerAsSelectedFolder:(NGImap4Folder *)_folder;
- (BOOL)removeSelectedFolder:(NGImap4Folder *)_folder;

- (BOOL)openConnection;
- (BOOL)closeConnection;

// NGImap4ResponseReceiver protocol

- (void)responseNotificationFrom:(NGImap4Client *)_client
  response:(NSDictionary *)_dict;

/* special folders */

- (id)trashFolder;
- (id)sentFolder;
- (id)draftsFolder;
- (id)inboxFolder;
- (id)serverRoot;
- (void)setSentFolder:(NGImap4Folder *)_folder;
- (void)setTrashFolder:(NGImap4Folder *)_folder;
- (void)setDraftsFolder:(NGImap4Folder *)_folder;

- (void)resetSpecialFolders;

- (BOOL)hasNewMessages;
/* returns all new messages from registered folder and inbox */
- (NSArray *)newMessages; // TODO: should be a datasource and/or qual instead!

- (BOOL)registerForRefresh:(NGImap4Folder *)_folder;
- (BOOL)removeFromRefresh:(NGImap4Folder *)_folder;
- (BOOL)removeAllFromRefresh;
- (BOOL)refreshFolder;

- (NGImap4Folder *)folderWithName:(NSString *)_name;
- (NGImap4Folder *)folderWithName:(NSString *)_name caseInsensitive:(BOOL)_b;

- (BOOL)createFolderWithPath:(NSString *)_name;

- (NSString *)host;
- (NSString *)login;

- (id)serverName;
- (id)serverKind;
- (id)serverVersion;
- (id)serverSubVersion;
- (id)serverTag;

- (BOOL)isInSyncMode;
- (void)enterSyncMode;
- (void)leaveSyncMode;
- (void)resetSync;

- (void)setLastException:(NSException *)_exception;
- (NSException *)lastException;
- (void)resetLastException;

/* server depending defaults */

- (BOOL)subscribeFolderFailed;
- (BOOL)showOnlySubscribedInRoot;
- (BOOL)showOnlySubscribedInSubFolders;
- (NSString *)sortEncoding;

- (void)setSortEncoding:(NSString *)_str;
- (void)setSubscribeFolderFailed:(BOOL)_b;
- (void)setShowOnlySubscribedInRoot:(BOOL)_b;
- (void)setShowOnlySubscribedInSubFolders:(BOOL)_b;

/* URL based factory */

+ (id)messageWithURL:(id)_url; /* create context, then message */
- (id)messageWithURL:(id)_url;
- (id)folderWithURL:(id)_url;

@end

@interface NGImap4Context(Capability)

- (BOOL)canSort;
- (BOOL)canQuota;

@end /* NGImap4Context(Capability) */

#endif /* __OGo_NGImap4_NGImap4Context_H__ */
