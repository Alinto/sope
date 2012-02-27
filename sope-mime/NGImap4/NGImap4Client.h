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

#ifndef __SOPE_NGImap4_NGImap4Client_H__
#define __SOPE_NGImap4_NGImap4Client_H__

#import <Foundation/NSObject.h>
#include <NGStreams/NGStreams.h>
#include <NGStreams/NGSocketProtocols.h>
#include <NGImap4/NGImap4Support.h>

/*
  NGImap4Client
  
  An IMAP4 client object. This object is a thin wrapper around the TCP/IP
  socket (id<NGActiveSocket> object) connecting to the IMAP4 server.
  
  While it is pretty near to the IMAP4 raw protocol, it already does some
  normalization of responses. We might want to have something which is even
  lower level in the future.
  
  Responses are send to all registered response receivers.
  TODO: explain notification system.
*/

@class NSMutableArray, NSString, NSNumber, NSDictionary, NSArray, NSURL;
@class EOGlobalID, EOQualifier;
@class NGHashMap;
@class NGImap4ResponseParser, NGImap4Client, NGImap4ResponseNormalizer;

typedef enum {
  UnConnected_NGImap4State = 1,
  NonAuthenticated_NGImap4State,
  Authenticated_NGImap4State,
  Selected_NGImap4State,
} NGImap4State;

@interface NGImap4Client : NSObject
{
  id<NGActiveSocket>        socket;
  id<NGActiveSocket>        previous_socket;
  id<NGExtendedTextStream>  text;
  id<NGSocketAddress>       address;
  NGImap4ResponseParser     *parser;
  NGImap4ResponseNormalizer *normer;
  NSMutableArray            *responseReceiver;  

  BOOL	   loggedIn;

  BOOL     isLogin;
  unsigned tagId;

  NSString *delimiter;
  NSString *selectedFolder;
  NSString *login;
  NSString *password;

  NSMutableArray *enabledExtensions;

  BOOL debug;
  BOOL useSSL;
  BOOL useTLS;
  BOOL useUTF8;

  NGImap4Context *context; /* not retained, used to store exceptions */
  EOGlobalID *serverGID;
}

+ (id)clientWithURL:(NSURL *)_url;
+ (id)clientWithAddress:(id<NGSocketAddress>)_address;
+ (id)clientWithHost:(id)_host;

- (id)initWithURL:(NSURL *)_url;
- (id)initWithHost:(id)_host;
- (id)initWithAddress:(id<NGSocketAddress>)_address;

/* equality */

- (BOOL)isEqualToClient:(NGImap4Client *)_obj;

/* accessors */

- (id<NGActiveSocket>)socket;
- (id<NGSocketAddress>)address;
- (NSString *)delimiter;
- (EOGlobalID *)serverGlobalID;

- (NSString *)selectedFolderName;

/* notifications */

- (void)registerForResponseNotification:(id<NGImap4ResponseReceiver>)_obj;
- (void)removeFromResponseNotification:(id<NGImap4ResponseReceiver>)_obj;

/* connection */

- (NSDictionary *)openConnection;
- (void)closeConnection;
- (NSNumber *)isConnected;
- (void)reconnect;

/* commands */

- (NSDictionary *)login:(NSString *)_login password:(NSString *)_passwd;
- (NSDictionary *)logout;
- (NSDictionary *)noop;
  
- (NSDictionary *)capability;
- (NSDictionary *)enable:(NSArray *)_extensions;

- (NSDictionary *)namespace;
- (NSDictionary *)list:(NSString *)_folder pattern:(NSString *)_pattern;
- (NSDictionary *)lsub:(NSString *)_folder pattern:(NSString *)_pattern;
- (NSDictionary *)select:(NSString *)_folder;
- (NSDictionary *)unselect;
- (NSDictionary *)status:(NSString *)_folder flags:(NSArray *)_flags;
- (NSDictionary *)rename:(NSString *)_folder to:(NSString *)_newName;
- (NSDictionary *)delete:(NSString *)_folder;
- (NSDictionary *)create:(NSString *)_name;
- (NSDictionary *)subscribe:(NSString *)_name;
- (NSDictionary *)unsubscribe:(NSString *)_name;
- (NSDictionary *)expunge;
  
- (NSDictionary *)sort:(id)_sortOrderings qualifier:(EOQualifier *)_qual
  encoding:(NSString *)_encoding;
- (NSDictionary *)fetchUids:(NSArray *)_uids parts:(NSArray *)_parts;
- (NSDictionary *)fetchUid:(unsigned)_uid    parts:(NSArray *)_parts;
- (NSDictionary *)fetchVanished:(uint64_t)_modseq;
- (NSDictionary *)fetchFrom:(unsigned)_from to:(unsigned)_to
  parts:(NSArray *)_parts;
- (NSDictionary *)storeUid:(unsigned)_uid add:(NSNumber *)_add
  flags:(NSArray *)_flags;
- (NSDictionary *)storeFrom:(unsigned)_from to:(unsigned)_to
  add:(NSNumber *)_add flags:(NSArray *)_flags;
- (NSDictionary *)storeFlags:(NSArray *)_flags forUIDs:(id)_uids
  addOrRemove:(BOOL)_flag;

- (NSDictionary *)copyUid:(unsigned)_uid    toFolder:(NSString *)_folder;
- (NSDictionary *)copyUids:(NSArray *)_uids toFolder:(NSString *)_folder;
- (NSDictionary *)copyFrom:(unsigned)_from to:(unsigned)_to
  toFolder:(NSString *)_folder;

- (NSDictionary *)append:(NSData *)_message toFolder:(NSString *)_folder
  withFlags:(NSArray *)_flags;
- (NSDictionary *)threadBySubject:(BOOL)_bySubject
                          charset:(NSString *)_charSet
                        qualifier:(EOQualifier *)_qual;
- (NSDictionary *)getQuotaRoot:(NSString *)_folder;

- (NSDictionary *)searchWithQualifier:(EOQualifier *)_qualifier;

/* ACLs */

- (NSDictionary *)getACL:(NSString *)_folder;
- (NSDictionary *)setACL:(NSString *)_folder rights:(NSString *)_r
  uid:(NSString *)_uid;
- (NSDictionary *)deleteACL:(NSString *)_folder uid:(NSString *)_uid;
- (NSDictionary *)listRights:(NSString *)_folder uid:(NSString *)_uid;
- (NSDictionary *)myRights:(NSString *)_folder;

/* context accessors (DEPRECATED) */

- (void)setContext:(NGImap4Context *)_ctx;
- (NGImap4Context *)context;

/* raw methods */

- (NSDictionary *)primarySort:(NSString *)_sortString
  qualifierString:(NSString *)_qualString
  encoding:(NSString *)_encoding;

@end

#endif /* __SOPE_NGImap4_NGImap4Client_H__ */
