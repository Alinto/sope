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

#include "NGImap4Context.h"
#include "NGImap4Client.h"
#include "NGImap4Folder.h"
#include "NGImap4ServerRoot.h"
#include "NGImap4Support.h"
#include "NGImap4Functions.h"
#include "imCommon.h"

@interface NGImap4Context(Private)
- (void)initializeSentFolder;
- (void)initializeTrashFolder;
- (void)initializeDraftsFolder;
- (void)initializeInboxFolder;
- (void)initializeServerRoot;

- (void)_setSortEncoding:(NSString *)_str;
- (void)_setSubscribeFolderFailed:(BOOL)_b;
- (void)_setShowOnlySubscribedInRoot:(BOOL)_b;
- (void)_setShowOnlySubscribedInSubFolders:(BOOL)_b;
@end

@implementation NGImap4Context

static id  DefaultForSortEncoding                   = nil;
static id  DefaultForSubscribeFailed                = nil;
static id  DefaultForShowOnlySubscribedInRoot       = nil;
static id  DefaultForShowOnlySubscribedInSubFolders = nil;
static int ImapLogEnabled                           = -1;

+ (void)initialize {
  NSUserDefaults *ud;
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;

  ud = [NSUserDefaults standardUserDefaults];

  DefaultForSortEncoding    = [[ud stringForKey:@"ImapSortEncoding"] copy];
  DefaultForSubscribeFailed = 
    [[ud stringForKey:@"ImapSubscribedCouldFailed"] copy];
  DefaultForShowOnlySubscribedInSubFolders =
    [[ud stringForKey:@"ShowOnlySubscribedInSubFolders"] copy];
  DefaultForShowOnlySubscribedInRoot =
    [[ud stringForKey:@"ShowOnlySubscribedInRoot"] copy];
  
  ImapLogEnabled = [ud boolForKey:@"ImapLogEnabled"]?1:0;
}

+ (id)imap4ContextWithURL:(id)_url {
  if (_url == nil)
    return nil;
  if (![_url isKindOfClass:[NSURL class]]) 
    _url = [NSURL URLWithString:[_url stringValue]];
  
  return [[(NGImap4Context *)[self alloc] initWithURL:_url] autorelease];
}
+ (id)imap4ContextWithConnectionDictionary:(NSDictionary *)_connection {
  return [[[self alloc] initWithConnectionDictionary:_connection] autorelease];
}

- (id)initWithConnectionDictionary:(NSDictionary *)_connection {
  if ((self = [super init])) {
    self->connectionDictionary = [_connection copy];
    self->folderForRefresh = [[NSMutableArray alloc] initWithCapacity:512];
    self->syncMode = NO;

    self->subscribeFolderFailed = (DefaultForSubscribeFailed)
      ? [DefaultForSubscribeFailed boolValue]?1:0
      : -1;

    self->showOnlySubscribedInRoot = (DefaultForShowOnlySubscribedInRoot)
      ? [DefaultForShowOnlySubscribedInRoot boolValue]?1:0
      : -1;

    self->showOnlySubscribedInSubFolders =
      (DefaultForShowOnlySubscribedInSubFolders)
      ? [DefaultForShowOnlySubscribedInSubFolders boolValue]?1:0
      : -1;

    self->sortEncoding = (DefaultForSortEncoding)
      ? [DefaultForSortEncoding retain]
      : nil;

  }
  return self;
}
- (id)initWithNSURL:(NSURL *)_url {
  NSMutableDictionary *md;
  id                  tmp;
  
  if (_url == nil) {
    [self release];
    return nil;
  }
  
  md = [NSMutableDictionary dictionaryWithCapacity:4];
  if ((tmp = [_url host]))     [md setObject:tmp forKey:@"host"];
  if ((tmp = [_url port]))     [md setObject:tmp forKey:@"port"];
  if ((tmp = [_url user]))     [md setObject:tmp forKey:@"login"];
  if ((tmp = [_url password])) [md setObject:tmp forKey:@"passwd"];
  
  if ([[_url scheme] isEqualToString:@"imaps"])
    [md setObject:[NSNumber numberWithBool:YES] forKey:@"SSL"];
  
  return [self initWithConnectionDictionary:md];
}
- (id)initWithURL:(id)_url {
  if ((_url != nil) && ![_url isKindOfClass:[NSURL class]])
    _url = [NSURL URLWithString:[_url stringValue]];
  
  return [self initWithNSURL:_url];
}

- (void)dealloc {
  [self->url release];
  [self->client removeFromResponseNotification:self];
  [self->connectionDictionary release];
  [self->client           release];
  [self->folderForRefresh release];
  [self->serverName       release];       
  [self->serverKind       release];       
  [self->serverVersion    release];    
  [self->serverSubVersion release]; 
  [self->serverTag        release];        
  [self->lastException    release];

  self->selectedFolder = nil; /* not retained */  
  self->trashFolder    = nil; /* not retained */  
  self->draftsFolder   = nil; /* not retained */  
  self->sentFolder     = nil; /* not retained */
  self->inboxFolder    = nil; /* not retained */
  self->serverRoot     = nil; /* not retained */

  [self->capability   release];
  [self->sortEncoding release];
  
  [super dealloc];
}

/* accessors */

- (NSException *)lastException {
  return self->lastException;
}

- (void)setLastException:(NSException *)_exception {
  ASSIGN(self->lastException, _exception);
}

- (void)resetLastException {
  [self->lastException release]; self->lastException = nil;
}

- (NGImap4Client *)client {
  if (self->client == nil)
    [self openConnection];
  return self->client;
}

- (EOGlobalID *)serverGlobalID {
  if (self->client == nil) {
    // TODO: construct global-id using connectionDictionary!
    [self logWithFormat:@"WARNING: could not construct GID (client not set!)"];
    return nil;
  }
  return [self->client serverGlobalID];
}

- (NSURL *)url {
  NSString *scheme;
  
  if (self->url != nil)
    return self->url;
  
  scheme = [[self->connectionDictionary objectForKey:@"SSL"] boolValue]
    ? @"imaps" : @"imap";
  
  self->url = [[NSURL alloc]
		initWithScheme:scheme
		host:[self->connectionDictionary objectForKey:@"host"]
		path:@"/"];
  return self->url;
}

/* folder tracking */

- (BOOL)isSelectedFolder:(NGImap4Folder *)_folder {
  return [self->selectedFolder isEqual:_folder];
}

- (void)setSelectedFolder:(NGImap4Folder *)_folder {
  self->selectedFolder = _folder;
}

- (BOOL)registerAsSelectedFolder:(NGImap4Folder *)_folder {
  id tmp;
  
  if (self->selectedFolder == _folder)
    return YES;
  
  if ([_folder noselect])
    return NO;
  
  tmp = self->selectedFolder;
  self->selectedFolder = _folder;
  if (![_folder selectImmediately:YES]) {
    self->selectedFolder = tmp;
    return NO;
  }

  return YES;
}

- (BOOL)removeSelectedFolder:(NGImap4Folder *)_folder {
  if (self->selectedFolder == _folder)
    self->selectedFolder = nil;
  return YES;
}

- (BOOL)openConnection {
  NSString *login;
  NSString *passwd;
  NSString *host;

  login  = [self->connectionDictionary objectForKey:@"login"];
  passwd = [self->connectionDictionary objectForKey:@"passwd"];
  host   = [self->connectionDictionary objectForKey:@"host"];

  [self resetSpecialFolders];

  if ((login == nil) || (passwd == nil) || (host == nil)) {
    id exc;
    
    exc = [[NGImap4ConnectionException alloc] 
	    initWithFormat:
	      @"missing login, passwd or host in connection-dictionary <%@>",
	      self->connectionDictionary];
    ASSIGN(self->lastException, exc);
    [exc release];
    return NO;
  }
  if (self->client == nil) {
    self->client = [[NGImap4Client alloc] initWithHost:host];
    [self->client registerForResponseNotification:self];
    [self->client setContext:self];
  }
  if (![[self->client isConnected] boolValue]) {
    NSDictionary *res;
    
    [self resetLastException];
    
    res = [self->client openConnection];
    if (!_checkResult(self, res, __PRETTY_FUNCTION__))
      return NO;
    
    [self->serverName       release]; self->serverName       = nil;
    [self->serverKind       release]; self->serverKind       = nil;
    [self->serverVersion    release]; self->serverVersion    = nil;
    [self->serverSubVersion release]; self->serverSubVersion = nil;
    [self->serverTag        release]; self->serverTag        = nil;

    self->serverName = [[res objectForKey:@"server"]     retain];
    self->serverKind = [[res objectForKey:@"serverKind"] retain];

    if (ImapLogEnabled) {
      [self logWithFormat:@"Server greeting: <%@> parse serverkind: <%@>",
            self->serverName, self->serverKind];
    }
    
    // TODO: move capability to specialized object!
    //   Note: capability of the IMAP4 server should be always configurable
    //         using defaults because the identification might be broken for
    //         security reasons
    
    if (self->serverKind != nil) {
      self->serverVersion    = [[res objectForKey:@"version"]    retain];
      self->serverSubVersion = [[res objectForKey:@"subversion"] retain];
      self->serverTag        = [[res objectForKey:@"tag"]        retain];
    }
    if ([self->serverKind isEqual:@"courier"]) {
      [self _setSortEncoding:@"US-ASCII"];
      [self _setSubscribeFolderFailed:NO];
      [self _setShowOnlySubscribedInRoot:0];
      [self _setShowOnlySubscribedInSubFolders:0];
    }
    else if ([self->serverKind isEqual:@"washington"]) {
      [self _setSortEncoding:@"UTF-8"];
      [self _setSubscribeFolderFailed:YES];
      [self _setShowOnlySubscribedInRoot:1];
      [self _setShowOnlySubscribedInSubFolders:1];
    }
    else if ([self->serverKind isEqual:@"cyrus"]) {
      [self _setSortEncoding:@"UTF-8"];
      [self _setSubscribeFolderFailed:YES];
      [self _setShowOnlySubscribedInRoot:0];
      [self _setShowOnlySubscribedInSubFolders:0];
    }
    if (ImapLogEnabled)
      [self logWithFormat:@"sortEncoding %@ subscribeFolderFailed %@ "
            @"showOnlySubscribedInSubFolders %@ showOnlySubscribedInRoot %@",
            [self sortEncoding],
            [self subscribeFolderFailed]         ? @"YES" : @"NO",
            [self showOnlySubscribedInSubFolders]? @"YES" : @"NO",
            [self showOnlySubscribedInRoot]      ? @"YES" : @"NO"];
      
    [self resetLastException];
    res = [self->client login:login password:passwd];
    if (!_checkResult(self, res, __PRETTY_FUNCTION__))
      return NO;
  }
  {
    NSDictionary *res;

    [self->capability release]; self->capability = nil;
    res = [self->client capability];

    if (!_checkResult(self, res, __PRETTY_FUNCTION__))
      return NO;

    self->capability = [[res objectForKey:@"capability"] retain];
  }

  self->canSort  = -1;
  self->canQuota = -1;
  
  return YES;
}

- (void)_setSortEncoding:(NSString *)_str {
  if (!DefaultForSortEncoding)
    ASSIGN(self->sortEncoding, _str);
}

- (void)_setSubscribeFolderFailed:(BOOL)_b {
  if (!DefaultForSubscribeFailed)
    self->subscribeFolderFailed = _b?1:0;
}

- (void)_setShowOnlySubscribedInRoot:(BOOL)_b {
  if (!DefaultForShowOnlySubscribedInRoot)
    self->showOnlySubscribedInRoot = _b?1:0;
}

- (void)_setShowOnlySubscribedInSubFolders:(BOOL)_b {
  if (!DefaultForShowOnlySubscribedInSubFolders)
    self->showOnlySubscribedInSubFolders = _b?1:0;
}

- (void)setSortEncoding:(NSString *)_str {
  ASSIGN(self->sortEncoding, _str);
}

- (void)setSubscribeFolderFailed:(BOOL)_b {
  self->subscribeFolderFailed = _b?1:0;
}

- (void)setShowOnlySubscribedInRoot:(BOOL)_b {
  self->showOnlySubscribedInRoot = _b?1:0;
}

- (void)setShowOnlySubscribedInSubFolders:(BOOL)_b {
  self->showOnlySubscribedInSubFolders = _b?1:0;
}

- (BOOL)closeConnection {
  [self->client closeConnection];
  [self resetSpecialFolders];
  [self->capability release]; self->capability = nil;
  self->canSort = -1;
  self->canQuota = -1;

  
  return YES;
}

/*"
**  NGImap4ResponseReceiver protocol
**  If the NGImap4Context receive a response-notification it
**  updates the selected folder
"*/

- (void)responseNotificationFrom:(NGImap4Client *)_client
   response:(NSDictionary *)_dict
{
  if (![[_dict objectForKey:@"result"] boolValue]) {
    id       exc;
    NSString *str;
    
    if ((str = [_dict objectForKey:@"reason"]) == nil)
      str = @"Response failed";
    
    exc = [[NGImap4ResponseException alloc] 
      initWithName:@"NGImap4ResponseException" reason:str userInfo:_dict];
    ASSIGN(self->lastException, exc);
    return;
  }

  if (self->selectedFolder)
    [self->selectedFolder processResponse:_dict];
}

- (id)trashFolder {
  if (self->trashFolder == nil)
    [self initializeTrashFolder];
  return self->trashFolder;
}
- (void)setTrashFolder:(NGImap4Folder *)_folder {
  self->trashFolder = _folder;
}

- (id)sentFolder {
  if (self->sentFolder == nil)
    [self initializeSentFolder];
  return self->sentFolder;
}
- (void)setSentFolder:(NGImap4Folder *)_folder {
  self->sentFolder = _folder;
}

- (id)draftsFolder {
  if (self->draftsFolder == nil)
    [self initializeDraftsFolder];
  return self->draftsFolder;
}
- (void)setDraftsFolder:(NGImap4Folder *)_folder {
  self->draftsFolder = _folder;
}

- (id)inboxFolder {
  if (self->inboxFolder == nil)
    [self initializeInboxFolder];
  return self->inboxFolder;
}

- (id)serverRoot {
  if (self->serverRoot == nil)
    [self initializeServerRoot];
  return self->serverRoot;
}

- (void)initializeServerRoot {
  if (self->serverRoot == nil) {
    /*
      Note: serverRoot is not retained by NGImap4Context to avoid a
      retain cycle. This is why the object is autoreleased immediatly
      after creation (the usercode uses -serverRoot to access the result).
    */
    [self resetSpecialFolders];
    self->serverRoot = [[NGImap4ServerRoot alloc]
                                           initServerRootWithContext:self];
    self->serverRoot = [self->serverRoot autorelease];
  }
}

- (void)_checkFolder:(id)_folder folderName:(NSString *)_name
{
  NSDictionary *res;
  NSArray      *list;

  [self resetLastException];
  res = [self->client list:@"" pattern:_name];

  if (![[res objectForKey:@"result"] boolValue])
    return;

  list = [res objectForKey:@"list"];

  if ([list isNotEmpty]) { /* folder exist but is not subscribed */
    [self->client subscribe:_name];
  }
  else { /* try to create folder */
    [_folder createSubFolderWithName:[_name lastPathComponent]];
  }
  [_folder resetSubFolders];
  [self->lastException release]; self->lastException = nil;
}

- (NGImap4Folder *)_getFolderWithName:(NSString *)_name {
  NSEnumerator  *enumerator;
  NGImap4Folder *folder;

  if (self->serverRoot == nil)
    [self initializeServerRoot];

  enumerator = [[self->serverRoot subFolders] objectEnumerator];
  while ((folder = [enumerator nextObject])) {
    NSString *name;

    name = [[folder name] lowercaseString];

    if ([name isEqualToString:[_name lowercaseString]]) {
      return folder;
    }
  }
  if ([[_name lowercaseString] isEqual:@"inbox"]) {
    [self resetLastException];
    [self->client subscribe:_name];
    if (self->lastException != nil) {
      [self->serverRoot createSubFolderWithName:_name];
      [self->lastException release]; self->lastException = nil;
    }
    [self resetSpecialFolders];
  }
  else {
    if ([[self inboxFolder] noinferiors]) {
      /* try to create Sent/Trash/Drafts in root */
      [self _checkFolder:self->serverRoot folderName:_name];
    }
    else {
      /* take a look in inbox */
      NGImap4Folder *f;
      NSString      *absoluteName;

      f      = [self inboxFolder];
      folder = [f subFolderWithName:[_name lowercaseString]
                  caseInsensitive:YES];
      if (folder != nil)
        return folder;
      
      absoluteName = [[f absoluteName] stringByAppendingPathComponent:_name];
      
      [self _checkFolder:f folderName:absoluteName];
    }
  }
  return nil;
}

- (NSString *)sentFolderName {
  static NSString *SentFolderName = nil;

  if (SentFolderName == nil) {
    SentFolderName = [[[NSUserDefaults standardUserDefaults]
                                      stringForKey:@"ImapSentFolderName"]
                                       retain];

    if (!SentFolderName)
      SentFolderName = @"Sent";
  }
  return SentFolderName;
}

- (NSString *)trashFolderName {
  static NSString *TrashFolderName = nil;

  if (TrashFolderName == nil) {
    TrashFolderName = [[[NSUserDefaults standardUserDefaults]
                                      stringForKey:@"ImapTrashFolderName"]
                                       retain];

    if (!TrashFolderName)
      TrashFolderName = @"Trash";
  }
  return TrashFolderName;
}

- (NSString *)draftsFolderName {
  static NSString *DraftsFolderName = nil;

  if (DraftsFolderName == nil) {
    DraftsFolderName = [[[NSUserDefaults standardUserDefaults]
                                      stringForKey:@"ImapDraftsFolderName"]
                                       retain];

    if (!DraftsFolderName)
      DraftsFolderName = @"Drafts";
  }
  return DraftsFolderName;
}

- (void)initializeSentFolder {
  if ((self->sentFolder = [self _getFolderWithName:
                                [self sentFolderName]]) == nil)
    self->sentFolder = [self _getFolderWithName:
                             [self sentFolderName]];
  if (self->sentFolder == nil)
    NSLog(@"WARNING[%s]: Couldn't find/create sentFolder", __PRETTY_FUNCTION__);
}

- (void)initializeTrashFolder {
  if ((self->trashFolder = [self _getFolderWithName:
                                 [self trashFolderName]]) == nil)
    self->trashFolder = [self _getFolderWithName:[self trashFolderName]];
  if (self->trashFolder == nil)
    NSLog(@"WARNING[%s]: Couldn't find/create trashFolder", __PRETTY_FUNCTION__);
}

- (void)initializeDraftsFolder {
  if ((self->draftsFolder = [self _getFolderWithName:
                                  [self draftsFolderName]]) == nil)
    self->draftsFolder = [self _getFolderWithName:
                               [self draftsFolderName]];
  if (self->draftsFolder == nil)
    NSLog(@"WARNING[%s]: Couldn't find/create draftsFolder", __PRETTY_FUNCTION__);
}

- (void)initializeInboxFolder {
  if ((self->inboxFolder = [self _getFolderWithName:@"Inbox"]) == nil)
    self->inboxFolder = [self _getFolderWithName:@"Inbox"];
  
  if (self->inboxFolder == nil)
    NSLog(@"WARNING[%s]: Couldn't find/create inbox", __PRETTY_FUNCTION__);
}

- (NGImap4Folder *)folderWithName:(NSString *)_name {
  return [self folderWithName:_name caseInsensitive:NO];
}

- (NGImap4Folder *)folderWithName:(NSString *)_name
  caseInsensitive:(BOOL)_caseIn 
{
  NSEnumerator  *enumerator;
  id            obj;
  NGImap4Folder *f;

  [self resetLastException];
  enumerator = [[_name componentsSeparatedByString:@"/"] objectEnumerator];
  f          = [self serverRoot];
  
  while ((obj = [enumerator nextObject]) != nil) {
    if ([obj isNotEmpty])
      f = [f subFolderWithName:obj caseInsensitive:_caseIn];
  }
  return self->lastException ? (NGImap4Folder *)nil : f;
}

- (BOOL)createFolderWithPath:(NSString *)_name {
  NSEnumerator      *enumerator;
  id<NGImap4Folder> f1, f2; 
  NSString          *name;

  [self resetLastException];
  
  enumerator = [[_name componentsSeparatedByString:@"/"] objectEnumerator];
  f1         = [self serverRoot];
  f2         = nil;
  while ((name = [enumerator nextObject])) {
    if ((f2 = [f1 subFolderWithName:name caseInsensitive:YES]) == nil)
      break;
    f1 = f2;
  }
  if (name != nil) {
    do {
      if (![f1 createSubFolderWithName:name])
        break;
      f1 = [f1 subFolderWithName:name caseInsensitive:YES];
    } while ((name = [enumerator nextObject]));
  }
  return self->lastException ? NO : YES;
}

- (void)resetSpecialFolders {
  self->sentFolder   = nil;
  self->trashFolder  = nil;
  self->draftsFolder = nil;
  self->inboxFolder  = nil;
  self->serverRoot   = nil;
}

- (NSArray *)newMessages {
  NSEnumerator   *enumerator;
  NGImap4Folder  *f;
  NSMutableArray *result;
  EOQualifier    *qual;

  [self resetLastException];
  
  qual   = [EOQualifier qualifierWithQualifierFormat:@"flags = \"recent\""];
  result = [NSMutableArray array];
  
  [self->inboxFolder status];
  if ([self->inboxFolder hasNewMessagesSearchRecursiv:NO]) {
    NSArray *array;

    array = [self->inboxFolder messagesForQualifier:qual];
    if (array != nil)
      [result addObjectsFromArray:array];
  }
  enumerator = [self->folderForRefresh objectEnumerator];  
  while ((f = [enumerator nextObject])) {
    [f status];
    if ([f hasNewMessagesSearchRecursiv:NO]) {
    NSArray *array;

    array = [self->inboxFolder messagesForQualifier:qual];
    if (array != nil)
      [result addObjectsFromArray:array];
    }
  }
  return self->lastException ? (NSMutableArray *)nil : result;
}

- (BOOL)hasNewMessages {
  NSEnumerator  *enumerator;
  NGImap4Folder *f;
  BOOL          result;

  [self resetLastException];
  
  [self->inboxFolder status];
  if ([self->inboxFolder hasNewMessagesSearchRecursiv:NO])
    return YES;

  result     = NO;
  enumerator = [self->folderForRefresh objectEnumerator];
  
  while ((f = [enumerator nextObject])) {
    [f status];
    if ([f hasNewMessagesSearchRecursiv:NO]) {
      result = YES;
      break;
    }
  }
  return self->lastException ? NO : result;
}

- (NSString *)host {
  return [self->connectionDictionary objectForKey:@"host"];
}
- (NSString *)login {
  return [self->connectionDictionary objectForKey:@"login"];
}

- (BOOL)registerForRefresh:(NGImap4Folder *)_folder {
  [self->folderForRefresh addObject:_folder];
  return YES;
}

- (BOOL)removeFromRefresh:(NGImap4Folder *)_folder {
  [self->folderForRefresh removeObject:_folder];
  return YES;
}

- (BOOL)removeAllFromRefresh {
  [self->folderForRefresh removeAllObjects];
  return YES;
}

- (BOOL)refreshFolder {
  // TODO: explain
  //       this runs status on each folder and status triggers notifications?
  NSEnumerator  *enumerator;
  NGImap4Folder *f;
  BOOL          refreshInbox = NO;

  if ([self lastException] != nil)
    return NO;
  
  enumerator = [self->folderForRefresh objectEnumerator];

  [self resetLastException];

  while ((f = [enumerator nextObject])) {
    if ([f isEqual:self->inboxFolder])
      refreshInbox = YES;
    
    [f status];
  }
  
  if (!refreshInbox)
    [self->inboxFolder status];
    
  return self->lastException ? NO : YES;
}

- (id)serverName {
  return self->serverName;
}
- (id)serverKind {
  return self->serverKind;
}
- (id)serverVersion {
  return self->serverVersion;
}
- (id)serverSubVersion {
  return self->serverSubVersion;
}
- (id)serverTag {
  return self->serverTag;
}

/* synchronize */

- (void)resetSync {
  if (self->syncMode) 
    [self->serverRoot resetSync];
  else
    [self logWithFormat:@"WARNING: resetSync has no effect if syncMode == NO"];
}

- (BOOL)isInSyncMode {
  return self->syncMode;
}

- (void)enterSyncMode {
  self->syncMode = YES;
  [self resetSync];
}

- (void)leaveSyncMode {
  self->syncMode = NO;
}

- (BOOL)showOnlySubscribedInRoot {
  if (self->showOnlySubscribedInRoot == -1)
    return NO;
  
  return (self->showOnlySubscribedInRoot == 1) ? YES : NO;
}

- (BOOL)showOnlySubscribedInSubFolders {
  if (self->showOnlySubscribedInSubFolders == -1)
    return NO;
  
  return (self->showOnlySubscribedInSubFolders == 1) ? YES : NO;
}

- (BOOL)subscribeFolderFailed {
  if (self->subscribeFolderFailed == -1)
    return YES;
  
  return (self->subscribeFolderFailed == 1) ? YES : NO;
}

- (NSString *)sortEncoding {
  if (self->sortEncoding == nil)
    self->sortEncoding = @"UTF-8";
  
  return self->sortEncoding;
}

/* Capability */

- (BOOL)canSort {
  if (self->capability == nil) {
    if (![self openConnection])
      return NO;
  }
  if (self->canSort == -1) {
    self->canSort =
      ([self->capability containsObject:@"sort"])? 1 : 0;
  }
  return self->canSort;
}

- (BOOL)canQuota {
  if (self->capability == nil) {
    if (![self openConnection])
      return NO;
  }
  if (self->canQuota == -1) {
    self->canQuota =
      ([self->capability containsObject:@"quota"])? 1 : 0;
  }
  return self->canQuota;
}

/* URL based factory */

+ (id)messageWithURL:(id)_url {
  NGImap4Context *ctx;
  
  if (_url == nil) 
    return nil;
  if (![_url isKindOfClass:[NSURL class]]) 
    _url = [NSURL URLWithString:[_url stringValue]];
  
  if ((ctx = [self imap4ContextWithURL:_url]) == nil) {
    NSLog(@"WARNING(%s): got no IMAP4 context for URL: %@", 
	  __PRETTY_FUNCTION__, _url);
    return nil;
  }
  return [ctx messageWithURL:_url];
}
- (id)folderWithURL:(id)_url {
  NSString *path, *folderPath;
  
  if (_url != nil && ![_url isKindOfClass:[NSURL class]]) 
    _url = [NSURL URLWithString:[_url stringValue]];
  if (_url == nil) 
    return nil;
  
  path       = [_url path];
  folderPath = [path stringByDeletingLastPathComponent];
  
  return [self folderWithName:folderPath];
}
- (id)messageWithURL:(id)_url {
  NSString      *path, *folderPath;
  NGImap4Folder *f;
  unsigned      messageID;
  
  if (_url != nil && ![_url isKindOfClass:[NSURL class]]) 
    _url = [NSURL URLWithString:[_url stringValue]];
  if (_url == nil) 
    return nil;
  
  path       = [_url path];
  folderPath = [path stringByDeletingLastPathComponent];
  messageID  = [[path lastPathComponent] intValue];
  
  if ((f = [self folderWithName:folderPath]) == nil) {
    [self logWithFormat:@"WARNING(%s): missing folder for URL: '%@'",
          __PRETTY_FUNCTION__, _url];
    return nil;
  }
  return [f messageWithUid:messageID];
}

/* description */

- (void)appendAttributesToDescription:(NSMutableString *)ms {
  NSString *tmp;
  
  if ((tmp = [self host]) != nil)
    [ms appendFormat:@" host=%@", tmp];
  if ((tmp = [self login]) != nil)
    [ms appendFormat:@" login=%@", tmp];
  
  if ((tmp = [self serverName]) != nil)
    [ms appendFormat:@" server='%@'", tmp];
  
  [ms appendFormat:@" kind=%@/v%@.%@/tag=%@",
        [self serverName],
        [self serverKind],
        [self serverVersion],
        [self serverSubVersion],
        [self serverTag]];
  
  if (self->syncMode)
    [ms appendString:@" syncmode"];
}

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [self appendAttributesToDescription:ms];
  [ms appendString:@">"];
  return ms;
}

@end /* NGImap4Context(Capability) */
