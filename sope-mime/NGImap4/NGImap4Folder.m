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

#include "NGImap4Folder.h"
#include "NGImap4Context.h"
#include "NGImap4Client.h"
#include "NGImap4Message.h"
#include "NGImap4Functions.h"
#include "NGImap4FolderGlobalID.h"
#include "NGImap4FolderMailRegistry.h"
#include "NGImap4FolderFlags.h"
#include "imCommon.h"

@interface NGImap4Message(Private)

- (void)_setHeaders:(NGHashMap *)_headers
  size:(unsigned)_size
  flags:(NSArray *)_flags;

- (BOOL)isComplete;
- (void)setIsRead:(BOOL)_isRead;

@end /* NGImap4Message(Private) */


@interface NGImap4Context(Private)
- (void)setLastException:(NSException *)_exception;
- (void)setSelectedFolder:(NGImap4Folder *)_folder;
@end /* NGImap4Context(Private) */

@interface NGImap4Folder(Private)

- (void)_resetFolder;
- (void)_resetSubFolder;
- (void)quota;
- (NSArray *)initializeMessagesFrom:(unsigned)_from to:(unsigned)_to;
- (NSArray *)initializeMessages;
- (void)initializeSubFolders;
- (void)addSubFolder:(NGImap4Folder *)_folder;
- (BOOL)flag:(NSString*)_doof toMessages:(NSArray*)_msg add:(NSNumber*)_n;
- (BOOL)flagToAllMessages:(NSString *)_flag add:(NSNumber *)_add;
- (NSArray *)fetchMessagesFrom:(unsigned)_from to:(unsigned)_to;
#if USE_MESSAGE_CACHE
- (void)resetQualifierCache;
#endif
- (void)setRecent:(NSNumber *)_rec exists:(NSNumber *)_exists;
- (void)clearParentFolder;

- (BOOL)_testMessages:(NSArray *)_msgs operation:(NSString *)_op;
- (NSArray *)_getMsnRanges:(NSArray *)_msgs;
- (NSArray *)_calculateSequences:(NSMutableArray *)_numbers count:(int)_cnt;

- (NSNotificationCenter *)notificationCenter;
- (void)_registerForNotifications;

@end /* NGImap4Folder(Private) */


@implementation NGImap4Folder

static NSNumber *YesNumber   = nil;
static NSNumber *NoNumber    = nil;
static NSArray  *StatusFlags = nil;
static NSArray  *UnseenFlag  = nil;
static BOOL     ImapDebugEnabled = NO;

static int ShowNonExistentFolder                      = -1;
static int IgnoreHasNoChildrenFlag                    = -1;
static int FetchNewUnseenMessagesInSubFoldersOnDemand = -1;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;
  
  YesNumber = [[NSNumber numberWithBool:YES] retain];
  NoNumber  = [[NSNumber numberWithBool:NO]  retain];

  StatusFlags = [[NSArray alloc]
		  initWithObjects:@"messages", @"recent", @"unseen", nil];
  UnseenFlag = [[NSArray alloc] initWithObjects:@"unseen", nil];

  ShowNonExistentFolder   = [ud boolForKey:@"ShowNonExistentFolder"] ? 1 : 0;
  IgnoreHasNoChildrenFlag = [ud boolForKey:@"IgnoreHasNoChildrenFlag"] ? 1 : 0;
  ImapDebugEnabled        = [ud boolForKey:@"ImapDebugEnabled"];
  
  FetchNewUnseenMessagesInSubFoldersOnDemand =
      [ud boolForKey:@"FetchNewUnseenMessagesInSubFoldersOnDemand"] ? 1 : 0;
}

- (id)init {
  [self release];
  [self logWithFormat:@"ERROR: cannot init NGImap4Folder with -init!"];
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (void)_setupMessageCache {
#if USE_MESSAGE_CACHE
  self->cacheIdx       = 0;    
  self->qualifierCache =
    [[NSMutableArray alloc] initWithCapacity:MAX_QUALIFIER_CACHE];
  self->messagesCache  =
    [[NSMutableArray alloc] initWithCapacity:MAX_QUALIFIER_CACHE];
#endif    
}

- (id)initWithContext:(NGImap4Context *)_context
  name:(NSString *)_name
  flags:(NSArray *)_flags
  parentFolder:(id<NGImap4Folder>)_folder
{
  if ((self = [super init])) {
    self->context      = [_context retain];
    self->flags        = [[NGImap4FolderFlags alloc] initWithFlagArray:_flags];
    self->name         = [_name copy];
    self->parentFolder = _folder;
    self->mailRegistry = [[NGImap4FolderMailRegistry alloc] init];
    
    /* mark as 'to be fetched' */
    self->exists            = -1;
    self->recent            = -1;
    self->unseen            = -1;
    self->usedSpace         = -1;
    self->maxQuota          = -1;
    self->overQuota         = -1;
    
    self->failedFlags.status = NO;
    self->failedFlags.select = NO;
    self->failedFlags.quota  = NO;
    
    // TODO: this also looks pretty weird!
    if ([[self->name lowercaseString] isEqualToString:@"/inbox"] &&
        [self->flags doNotSelectFolder]) {
      NSDictionary *res;

      [self resetLastException];
      
      res = [[self->context client] subscribe:[self absoluteName]];

      if ([self lastException] != nil) {
        [self release];
        return nil;
      }
      
      if ([[res objectForKey:@"result"] boolValue])
	[self->flags allowFolderSelect];
    }
    
    [self _registerForNotifications];
    [self _setupMessageCache];
  }
#if NGIMAP_FOLDER_DEBUG
  return [self->context registerFolder:self];
#else  
  return self;
#endif  
}

- (void)dealloc {
  [[self notificationCenter] removeObserver:self];
  [self->context removeSelectedFolder:self];
  [self->subFolders makeObjectsPerformSelector:@selector(clearParentFolder)];
  
  [self->mailRegistry release];
  [self->msn2UidCache release];
  [self->context      release];
  [self->flags        release];
  [self->name         release];
  [self->subFolders   release]; 
  [self->messageFlags release];
  [self->url          release];
#if USE_MESSAGE_CACHE
  [self->messages       release];
  [self->qualifierCache release];
  [self->messagesCache  release];
#endif
  self->isReadOnly   = nil;
  self->parentFolder = nil;
  
  [super dealloc];
}

- (BOOL)isEqual:(id)_obj {
  if (self == _obj)
    return YES;
  if ([_obj isKindOfClass:[NGImap4Folder class]])
    return [self isEqualToImap4Folder:_obj];
  return NO;
}

- (BOOL)isEqualToImap4Folder:(NGImap4Folder *)_folder {
  if (self == _folder)
    return YES;
  if (([[_folder absoluteName] isEqualToString:self->name]) &&
      [_folder context] == self->context) {
    return YES;
  }
  return NO;
}

/* accessors */

- (NSException *)lastException {
  return [self->context lastException];
}
- (void)resetLastException {
  [self->context resetLastException];
}

- (NGImap4Context *)context {
  return self->context;
}

- (NSString *)name {
  return [[self absoluteName] lastPathComponent];
}

- (NSString *)absoluteName {
  // TODO: sometimes this contains a name with no / in front (eg Dovecot on
  //       MacOSX). Find out why this is.
  return self->name;
}

- (NSArray *)flags {
  return [self->flags flagArray];
}

- (NSArray *)messages {
  return [self initializeMessages];
}

- (BOOL)_checkResult:(NSDictionary *)_dict cmd:(const char *)_command {
  return _checkResult(self->context, _dict, _command);
}

- (NSArray *)messagesForQualifier:(EOQualifier *)_qualifier
  maxCount:(int)_cnt
{
  // TODO: split up method
  NSMutableArray    *mes  = nil;
  NSMutableArray    *msn  = nil;
  NSDictionary      *dict = nil;
  NSAutoreleasePool *pool = nil;

  if ([self->flags doNotSelectFolder] || self->failedFlags.select)
    return nil;
  
  if (![self->context registerAsSelectedFolder:self])
    return nil;

  pool = [[NSAutoreleasePool alloc] init];

#if USE_MESSAGE_CACHE  
  if (self->cacheIdx > 0) {
    NSEnumerator *qualifierEnum = nil;
    EOQualifier  *qual          = nil;
    int          cnt            = 0;

    qualifierEnum = [self->qualifierCache objectEnumerator];

    while ((qual = [qualifierEnum nextObject])) {
      if ([qual isEqual:_qualifier]) {
        NSArray *m;
        
        m = [[self->messagesCache objectAtIndex:cnt] retain];
        [pool release];
        return [m autorelease];
      }
      cnt++;
    }
  }
#endif
  [self resetLastException];
  
  dict = [[self->context client] searchWithQualifier:_qualifier];

  if (![self _checkResult:dict cmd:__PRETTY_FUNCTION__])
    return nil;

  msn  = [[dict objectForKey:@"search"] mutableCopy];
  
  if ((msn == nil) || ![msn isNotEmpty]) {
    mes = [NSArray array];
  }
  else {
    NSEnumerator *seq = nil;
    NSDictionary *obj = nil;
    
    mes = [NSMutableArray arrayWithCapacity:512];
    seq = [[self _calculateSequences:msn count:_cnt] objectEnumerator];
    while ((obj = [seq nextObject])) {
      NSArray *a;
      
      a = [self fetchMessagesFrom:
		  [[obj objectForKey:@"start"] unsignedIntValue]
                to:[[obj objectForKey:@"end"] unsignedIntValue]];
      
      if ([self lastException] != nil)
        break;
      
      if (a)
        [mes addObjectsFromArray:a];
    }
    mes = [[mes copy] autorelease];
  }
  [msn release];

#if USE_MESSAGE_CACHE  
  if (self->cacheIdx == 5)
    self->cacheIdx = 0;

  if ([self->qualifierCache count] == self->cacheIdx)
    [self->qualifierCache addObject:_qualifier];
  else
    [self->qualifierCache replaceObjectAtIndex:self->cacheIdx
         withObject:_qualifier];
  if ([self->messagesCache count] == self->cacheIdx)
    [self->messagesCache addObject:mes];
  else {
    [self->messagesCache replaceObjectAtIndex:self->cacheIdx
                         withObject:mes];
  }
  self->cacheIdx++;
#endif  
  
  mes = [mes retain];
  [pool release];

  if ([self lastException]) {
    [mes release];
    return nil;
  }
  return [mes autorelease];
}

- (NSArray *)messagesForQualifier:(EOQualifier *)_qualifier {
  return [self messagesForQualifier:_qualifier maxCount:-1];
}

- (NSArray *)messageFlags {
  if (self->messageFlags == nil)
    [self->context registerAsSelectedFolder:self];
  return self->messageFlags;
}

- (NSArray *)subFolders {
  if (self->subFolders == nil)
    [self initializeSubFolders];
  return self->subFolders;
}

- (NGImap4Folder *)subFolderWithName:(NSString *)_name
  caseInsensitive:(BOOL)_caseIns
{
  return _subFolderWithName(self, _name, _caseIns);
}

- (id<NGImap4Folder>)parentFolder {
  return self->parentFolder;
}

- (BOOL)isReadOnly {
  if (self->isReadOnly == nil)
    [self->context registerAsSelectedFolder:self];
  return (self->isReadOnly == YesNumber) ? YES : NO;
}

/* flags */

- (BOOL)noselect {
  return [self->flags doNotSelectFolder];
}
- (BOOL)noinferiors {
  return [self->flags doesNotSupportSubfolders];
}
- (BOOL)nonexistent {
  return [self->flags doesNotExist];
}
- (BOOL)haschildren {
  return [self->flags hasSubfolders];
}
- (BOOL)hasnochildren {
  return [self->flags hasNoSubfolders];
}
- (BOOL)marked {
  return [self->flags isMarked];
}
- (BOOL)unmarked {
  return [self->flags isUnmarked];
}

- (int)exists {
  if (self->exists == -1) {
    [self status];
  }
  return self->exists;
}

- (int)recent {
  if (self->recent == -1)
    [self status];
  
  return self->recent;
}

- (int)unseen {
  if (self->unseen == -1)
    [self status];
  
  return self->unseen;
}

- (BOOL)isOverQuota {
  if (self->overQuota == -1)
    [self->context registerAsSelectedFolder:self];
  
  return (self->overQuota == 1)? YES : NO;
}

- (int)usedSpace {
  if (self->usedSpace == -1)
    [self quota];
  
  return self->usedSpace;
}

- (int)maxQuota {
  if (self->maxQuota == -1)
    [self quota];
  
  return self->maxQuota;
}

- (BOOL)hasNewMessagesSearchRecursiv:(BOOL)_rec fetchOnDemand:(BOOL)_fetch {
  if (_fetch) {
    if (([self recent] > 0) && ([self unseen] > 0))
      return YES;
  }
  else {
    if ((self->recent > 0) && (self->unseen > 0))
      return YES;
  }
  
  if (_rec)
    return _hasNewMessagesInSubFolder(self, _fetch);
  
  return NO;
}

- (BOOL)hasNewMessagesSearchRecursiv:(BOOL)_recursiv {
  if (([self recent] > 0) && ([self unseen] > 0))
    return YES;

  if (_recursiv) {
    return _hasNewMessagesInSubFolder(self,
              FetchNewUnseenMessagesInSubFoldersOnDemand);
  }
  return NO;
}

- (BOOL)hasUnseenMessagesSearchRecursiv:(BOOL)_rec fetchOnDemand:(BOOL)_fetch {
  if (_fetch) {
    if ([self unseen] > 0)
      return YES;
  }
  else
    if (self->unseen > 0)
      return YES;

  if (_rec)
    return _hasUnseenMessagesInSubFolder(self, _fetch);
  
  return NO;
}

- (BOOL)hasUnseenMessagesSearchRecursiv:(BOOL)_recursiv {
  if ([self unseen] > 0)
    return YES;

  if (_recursiv)
    return
      _hasUnseenMessagesInSubFolder(self,
                                    FetchNewUnseenMessagesInSubFoldersOnDemand);
  return NO;
}

/* notifications (fix that junk!) */

- (NSNotificationCenter *)notificationCenter {
  static NSNotificationCenter *nc = nil;
  if (nc == nil)
    nc = [[NSNotificationCenter defaultCenter] retain];
  return nc;
}

- (NSString *)resetFolderNotificationName {
  return [@"NGImap4FolderReset_" stringByAppendingString:[self absoluteName]];
}
- (NSString *)resetSubfolderNotificationName {
  return [@"NGImap4SubFolderReset__" 
           stringByAppendingString:[self absoluteName]];
}

- (void)_registerForNotifications {
  NSNotificationCenter *nc;
  NSString             *n;

  nc = [self notificationCenter];
  n  = [self absoluteName];
      
  // TODO: fix that junk!
  if ([n isNotEmpty]) {
    [nc addObserver:self selector:@selector(_resetFolder)
        name:[self resetFolderNotificationName]
        object:nil];
    [nc addObserver:self selector:@selector(_resetSubFolder)
        name:[self resetSubfolderNotificationName]
        object:nil];
  }
}

- (void)_postResetFolderNotification {
  [[self notificationCenter] postNotificationName:
                               [self resetFolderNotificationName] 
                             object:nil];
}
- (void)_postResetSubfolderNotification {
  [[self notificationCenter] postNotificationName:
                               [self resetSubfolderNotificationName] 
                             object:nil];
}

/* private methods */

- (NSArray *)initializeMessages {
  return [self initializeMessagesFrom:0 to:[self exists]];
}

- (NSArray *)initializeMessagesFrom:(unsigned)_from to:(unsigned)_to {
#if USE_MESSAGE_CACHE  
  if (self->messages == nil) {
    self->messages = [[NSMutableArray alloc] initWithCapacity:_to];
  }
  [self->messages addObjectsFromArray:[self fetchMessagesFrom:_from to:_to]];
  return self->messages;
#else
  return [self fetchMessagesFrom:_from to:_to];
#endif  
}

- (NGImap4Message *)createMessageForUid:(unsigned)_uid
  headers:(id)_headers size:(unsigned)_size flags:(NSArray *)_flags
{
  return [[NGImap4Message alloc] initWithUid:_uid
                                 headers:_headers size:_size flags:_flags
                                 folder:self context:self->context];
}

- (NSArray *)_buildMessagesFromFetch:(NSDictionary *)_fetch
  usingMessages:(NSDictionary *)_messages
{
  NSEnumerator        *mEnum;
  NSDictionary        *m;
  NGMimeMessageParser *parser;
  NSMutableArray      *mes;
  NSAutoreleasePool   *pool;

  pool  = [[NSAutoreleasePool alloc] init];
  mEnum = [[_fetch objectForKey:@"fetch"] objectEnumerator];
  mes   = nil;
  
  if (_messages == nil)
    mes = [[NSMutableArray alloc] initWithCapacity:512];
  
  parser = [[[NGMimeMessageParser alloc] init] autorelease];
  // TODO: should we disable parsing of some headers? but which?
  //       is this method only for parsing headers?!
  
  while ((m = [mEnum nextObject])) {
    NGDataStream *stream = nil;
    NSData *headerData;
    id headers, uid, f, size;
    
    headerData = [m objectForKey:@"header"];
    uid        = [m objectForKey:@"uid"];
    f          = [m objectForKey:@"flags"];
    size       = [m objectForKey:@"size"];
    
    if (headerData == nil || uid == nil || f == nil || size == nil) {
      [self logWithFormat:@"WARNING[%s]: got no header, uid, flags, size "
            @"for %@", __PRETTY_FUNCTION__, m];
      continue;
    }
    if (([f containsObject:@"recent"]) && ([f containsObject:@"seen"])) {
        f = [f mutableCopy];
        [f removeObject:@"recent"];
        [f autorelease];
    }
    
    /* setup parser */
    stream = [[NGDataStream alloc] initWithData:headerData 
				   mode:NGStreamMode_readOnly];
    [parser prepareForParsingFromStream:stream];
    [stream release]; stream = nil;
    
    /* parse */
    headers = [parser parseHeader];
    
    if (_messages) {
      NGImap4Message *msg;
      
      if ((msg = [_messages objectForKey:uid]) == nil) {
        [self logWithFormat:@"WARNING[%s]: missing message for uid %@ from "
                @"fetch %@ in dict %@", __PRETTY_FUNCTION__,
                uid, _fetch, _messages];
        continue;
      }
      [msg _setHeaders:headers size:[size intValue] flags:f];
    }
    else {
      NGImap4Message *m;
      
      m = [self createMessageForUid:[uid unsignedIntValue]
		headers:headers size:[size unsignedIntValue] flags:f];
      if (m) [mes addObject:m];
      [m release];
    }
  }
  m = [mes copy];
  [mes release]; mes = nil;
  [pool release];
  
  return [m autorelease];;
}

- (NSArray *)_buildMessagesFromFetch:(NSDictionary *)_fetch {
  return [self _buildMessagesFromFetch:_fetch usingMessages:nil];
}

- (NSArray *)_messageIds:(NSArray *)_so onlyUnseen:(BOOL)_unseen {
  NSAutoreleasePool  *pool;
  NSDictionary       *dict;
  NSArray            *uids;
  static EOQualifier *UnseenQual = nil;

  uids = nil;
  
  /* hack for sorting for unseen/seen */
  if (UnseenQual == nil) {
    UnseenQual = [[EOKeyValueQualifier alloc]
                                       initWithKey:@"flags"
                                       operatorSelector:
                                       EOQualifierOperatorEqual
                                       value:@"unseen"];
  }

  pool = [[NSAutoreleasePool alloc] init];
  
  if ([_so count] == 1) {
    EOSortOrdering *so;

    so = [_so lastObject];

    if ([[so key] isEqualToString:@"unseen"]) {
      static NSArray        *DateSo     = nil;
      static EOQualifier    *SeenQual   = nil;
      
      NSMutableArray *muids;
      EOQualifier    *qual1, *qual2; 

      if (DateSo == nil) {
        DateSo = [[NSArray alloc] initWithObjects:
                          [EOSortOrdering sortOrderingWithKey:@"date"
                                           selector:[so selector]], nil];
      }
      if (SeenQual == nil) {
        SeenQual = [[EOKeyValueQualifier alloc]
                                         initWithKey:@"flags"
                                         operatorSelector:
                                         EOQualifierOperatorEqual
                                         value:@"seen"];
      }
      muids = [[NSMutableArray alloc] initWithCapacity:255];

      if (sel_eq([so selector], EOCompareAscending) ||
          sel_eq([so selector], EOCompareCaseInsensitiveAscending)) {
        qual1 = UnseenQual;
        if (_unseen)
          qual2 = nil;
        else
          qual2 = SeenQual;
      }
      else {
        if (_unseen)
          qual1 = nil;
        else
          qual1 = SeenQual;
        
        qual2 = UnseenQual;
      }
      
      if (qual1 != nil) {
        dict = [[self->context client] sort:DateSo qualifier:qual1
				       encoding:[self->context sortEncoding]];
	
        if (![[dict objectForKey:@"result"] boolValue]) {
          [self logWithFormat:@"ERROR[%s](1): sort failed (sortOrderings %@, "
                @"qual1 %@)", __PRETTY_FUNCTION__, DateSo, qual1];
          return nil;
        }
        [muids addObjectsFromArray:[dict objectForKey:@"sort"]];
      }
      if (qual2 != nil) {
        dict = [[self->context client] sort:DateSo qualifier:qual2
				       encoding:[self->context sortEncoding]];
	
        if (![[dict objectForKey:@"result"] boolValue]) {
          [self logWithFormat:@"ERROR[%s](2): sort failed (sortOrderings %@, "
                @"qual2 %@ ", __PRETTY_FUNCTION__, DateSo, qual2];
          return nil;
        }
        [muids addObjectsFromArray:[dict objectForKey:@"sort"]];
      }
      uids = [muids copy];
      [muids release]; muids = nil;
    }
  }
  if (uids == nil) {
    EOQualifier *qual;

    if (![_so isNotEmpty]) {
      static NSArray *ArrivalSO = nil;

      if (ArrivalSO == nil) {
        ArrivalSO =
          [[NSArray alloc]
                    initWithObjects:
                    [EOSortOrdering sortOrderingWithKey:@"arrival"
                                    selector:EOCompareAscending], nil];
      }
      _so = ArrivalSO;
    }
    if (_unseen) {
      qual = UnseenQual;
    }
    else
      qual = nil;

    [self resetLastException];
    
    dict = [[self->context client] sort:_so qualifier:qual
				   encoding:[self->context sortEncoding]];
    
    if (![self _checkResult:dict cmd:__PRETTY_FUNCTION__])
      return nil;

    uids = [[dict objectForKey:@"sort"] retain];
  }
  [pool release]; pool = nil;
  
  return [uids autorelease];
}

- (NSData *)blobForUid:(unsigned)_mUid part:(NSString *)_part {
  /* 
     called by NGImap4Message -contentsOfPart:
  */
  NSDictionary *result;
  NSArray      *fetchResults;
  NSString     *bodyKey;
  NSArray      *uids, *parts;
  
  if (![self->context registerAsSelectedFolder:self])
    return nil;

  bodyKey = [NSString stringWithFormat:
			@"body[%@]", _part ? _part : (NSString *)@""];
  uids    = [NSArray arrayWithObject:[NSNumber numberWithUnsignedInt:_mUid]];
  parts   = [NSArray arrayWithObject:bodyKey];
  
  result = [[self->context client] fetchUids:uids parts:parts];
  if (![self _checkResult:result cmd:__PRETTY_FUNCTION__]) {
    [self debugWithFormat:@"Note: _checkResult: rejected result %d/%@: %@",
            _mUid, _part, result];
    return nil;
  }
  else if (result == nil) {
    [self debugWithFormat:@"Note: got no result for %d/%@", _mUid, _part];
    return nil;
  }
  
  fetchResults = [result objectForKey:@"fetch"];
  if (![fetchResults isNotEmpty])
    [self debugWithFormat:@"found no fetch result"];
  
  // TODO: using 'lastObject' is certainly wrong? need to search for body
  result = [fetchResults lastObject];
  
  if ((result = [result objectForKey:@"body"]) == nil)
    [self debugWithFormat:@"found no body in fetch results: %@", fetchResults];
  
  return [result objectForKey:@"data"];
}

- (NGImap4Message *)messageForUid:(unsigned)_mUid
  sortOrderings:(NSArray *)_so
  onlyUnread:(BOOL)_unread
  nextMessage:(BOOL)_next
{
  NSArray      *uids, *allSortUids;
  NSEnumerator *enumerator;
  NSNumber     *uid, *eUid, *lastUid;
  
  if ([self->flags doNotSelectFolder] || self->failedFlags.select)
    return nil;
  
  uid         = [NSNumber numberWithUnsignedInt:_mUid];
  allSortUids = [self _messageIds:_so onlyUnseen:NO];

  uids = _unread ? [self _messageIds:_so onlyUnseen:_unread] : (NSArray *)nil;
  
  enumerator  = [allSortUids objectEnumerator];
  lastUid     = nil;
  
  while ((eUid = [enumerator nextObject])) {
    if ([uid isEqual:eUid])
      break;

    if (_unread) {
      if ([uids containsObject:eUid])
        lastUid = eUid;
    }
    else
      lastUid = eUid;
  }
  if (eUid == nil) {
    [self logWithFormat:@"WARNING[%s]: Couldn`t found next/prev message "
          @"(missing orig. message %d for sortordering %@",
          __PRETTY_FUNCTION__, _mUid, _so];
    return nil;
  }
  if (_next) {
    if (_unread) {
      while ((uid = [enumerator nextObject])) {
        if ([uids containsObject:uid])
          break;
      }
    }
    else
      uid = [enumerator nextObject];
  }
  else {
    uid = lastUid;
  }
  if (uid == nil)
    return nil;
  
  return [[[NGImap4Message alloc] initWithUid:[uid unsignedIntValue]
				  folder:self context:self->context]
	                          autorelease];
}

/*
  build NGImap4Messages with sorted uids
*/

- (NSArray *)fetchSortedMessages:(NSArray *)_so {
  NSArray           *uids, *array;
  NSMutableArray    *marray;
  NSAutoreleasePool *pool;
  NSEnumerator      *enumerator;
  NSNumber          *uid;
  
  if ([self->flags doNotSelectFolder] || self->failedFlags.select)
    return nil;

  if (![self->context registerAsSelectedFolder:self])
    return nil;

  pool = [[NSAutoreleasePool alloc] init];

  if (![_so isNotEmpty])
    return [self messages];
  
  if (!(uids = [self _messageIds:_so onlyUnseen:NO]))
    return [self messages];

  enumerator = [uids objectEnumerator];
  marray     = [[NSMutableArray alloc] initWithCapacity:[uids count]];
  
  while ((uid = [enumerator nextObject])) {
    NGImap4Message *m;
    
    m = [[NGImap4Message alloc] initWithUid:[uid intValue]
				folder:self context:self->context];
    if (m) [marray addObject:m];
    [m release];
  }
  array = [marray shallowCopy];

  [marray release]; marray = nil;
  [pool release];   pool   = nil;
  
  return [array autorelease];
}

/*
  fetch headers for _array in range (for use with fetchSortedMessages)
*/

- (void)bulkFetchHeadersFor:(NSArray *)_array inRange:(NSRange)_aRange
  withAllUnread:(BOOL)_unread
{
  NSArray             *messages, *uids;
  NSAutoreleasePool   *pool;
  NSEnumerator        *enumerator;
  NGImap4Message      *message;
  NSMutableDictionary *messageMapping;
  NSDictionary        *dict;
  NSArray             *unreadUids;
  
  if ([self->flags doNotSelectFolder])
    return;

  if (_aRange.length == 0)
    return;

  if (![self->context registerAsSelectedFolder:self])
    return;

  pool = [[NSAutoreleasePool alloc] init];

  if (_aRange.location >= [_array count]) {
    return;
  }
  if (_aRange.location + _aRange.length > [_array count]) {
    _aRange.length = [_array count] - _aRange.location;
  }
  messages   = [_array subarrayWithRange:_aRange];
  unreadUids = nil;
  
  if (_unread) {
    EOQualifier  *q;
    NSDictionary *d;

    q = [EOQualifier qualifierWithQualifierFormat:@"flags = \"unseen\""];
    d = [[self->context client] searchWithQualifier:q];

    if ([[d objectForKey:@"result"] boolValue])
      unreadUids = [d objectForKey:@"search"];
  }
  enumerator     = [messages objectEnumerator];
  messageMapping = [NSMutableDictionary dictionaryWithCapacity:
                                        [messages count]];
  while ((message = [enumerator nextObject]) != nil) {
    if (![message isComplete]) {
      [messageMapping setObject:message
                      forKey:[NSNumber numberWithUnsignedInt:[message uid]]];
    }
  }
  if ([unreadUids isNotEmpty]) {
    enumerator = [_array objectEnumerator];
    while ((message = [enumerator nextObject])) {
      NSNumber *number;

      number = [NSNumber numberWithUnsignedInt:[message uid]];

      if ([unreadUids containsObject:number])
        [messageMapping setObject:message forKey:number];
    }
  }
  if ([messageMapping isNotEmpty]) {
    static NSArray *sortKeys = nil;
    
    uids = [messageMapping allKeys];
    
    if (sortKeys == nil) {
      sortKeys = [[NSArray alloc] initWithObjects:@"uid",
                                                  @"rfc822.header",
                                                  @"rfc822.size", @"flags",
                                                  nil];
    }
    dict = [[self->context client] fetchUids:uids parts:sortKeys];
    if ([self _checkResult:dict cmd:__PRETTY_FUNCTION__]) {
      [self _buildMessagesFromFetch:dict usingMessages:messageMapping];

      if (_unread) { /* set unfetched messeges to unread */
        NSEnumerator   *enumerator;
        NGImap4Message *m;

        enumerator = [_array objectEnumerator];

        while ((m = [enumerator nextObject])) {
          NSNumber *n;

          n = [NSNumber numberWithUnsignedInt:[m uid]];

          if (![uids containsObject:n])
            [m setIsRead:YES];
        }
      }
    }
  }
  [pool release]; pool = nil;
  return;
}

- (void)bulkFetchHeadersFor:(NSArray *)_array inRange:(NSRange)_aRange {
  [self bulkFetchHeadersFor:_array inRange:_aRange withAllUnread:NO];
}

/*
  fetch only sorted messages in range
*/

- (NSArray *)fetchSortedMessages:(NSRange)_aRange
  sortOrderings:(NSArray *)_so
{
  static NSArray *sortKeys = nil;
  NSDictionary      *dict;
  NSArray           *uids, *m;
  NSAutoreleasePool *pool;
  
  if ([self->flags doNotSelectFolder] || self->failedFlags.select)
    return nil;
  
  if (_aRange.length == 0)
    return [NSArray array];

  if (![self->context registerAsSelectedFolder:self])
    return nil;

  pool = [[NSAutoreleasePool alloc] init];

  if ((uids = [self _messageIds:_so onlyUnseen:NO]) == nil)
    return nil;
  
  if (_aRange.location + _aRange.length > [uids count])
    _aRange.length = [uids count] - _aRange.location;
  
  uids = [uids subarrayWithRange:_aRange];
  
  if (sortKeys == nil) {
    sortKeys = [[NSArray alloc] initWithObjects:@"uid",
                                                @"rfc822.header",
                                                @"rfc822.size", @"flags",
                                                nil];
  }
  dict = [[self->context client] fetchUids:uids parts:sortKeys];

  if (![self _checkResult:dict cmd:__PRETTY_FUNCTION__])
    return nil;
  
  m = [[self _buildMessagesFromFetch:dict] retain];
  [pool release];
  return [m autorelease];
}

- (NSArray *)fetchMessagesFrom:(unsigned)_from to:(unsigned)_to {
  static NSArray *sortKeys = nil;
  NSAutoreleasePool   *pool;
  NSDictionary        *dict;
  NSArray             *m;

  if ([self->flags doNotSelectFolder])
    return nil;
  
  if (_from == 0)
    _from = 1;
  
  if (![self->context registerAsSelectedFolder:self])
    return nil;
 
  if (_to == 0)
    return [NSArray array];

  pool = [[NSAutoreleasePool alloc] init];

  [self resetLastException];
  
  /* TODO: normalize sort-key arrays? */
  if (sortKeys == nil) {
    sortKeys = [[NSArray alloc] initWithObjects:@"uid",
                                                @"rfc822.header",
                                                @"rfc822.size", @"flags",
                                                nil];
  }
  dict = [[self->context client] fetchFrom:_from to:_to parts:sortKeys];
  if (![self _checkResult:dict cmd:__PRETTY_FUNCTION__])
    return nil;
  
  m = [[self _buildMessagesFromFetch:dict] retain];
  
  [pool release];
  return [m autorelease];
}

- (void)initializeSubFolders {
  NSString     *n;
  NSEnumerator *folders;
  NSDictionary *res;
  id           folder, *objs;
  unsigned     cnt, nl;
  BOOL         showSubsrcFolders;
  NSString     *pattern;
  
  if ([self->flags doesNotSupportSubfolders])
    return;

  if (!IgnoreHasNoChildrenFlag && [self->flags hasNoSubfolders])
    return;
    
  if (self->subFolders)
    [self resetSubFolders];
  
  [self resetLastException];
 
  showSubsrcFolders = [self->context showOnlySubscribedInSubFolders];
  
  pattern = [[self absoluteName] stringByAppendingString:@"/%"];
  res = (showSubsrcFolders)
    ? [[self->context client] lsub:@"" pattern:pattern]
    : [[self->context client] list:@"" pattern:pattern];
  
  if (![self _checkResult:res cmd:__PRETTY_FUNCTION__])
    return;
  
  res = [res objectForKey:@"list"];

  objs = calloc([res count] + 2, sizeof(id));
  {
    NSArray *names;
    names   = [res allKeys];    
    names   = [names sortedArrayUsingSelector:
                     @selector(caseInsensitiveCompare:)];
    folders = [names objectEnumerator];
  }
  
  cnt = 0;
  if (showSubsrcFolders) {
    n  = [self absoluteName];
    nl = [n length];
  }
  
  while ((folder = [folders nextObject])) {
    NGImap4Folder *newFolder;
    NSArray *f;

    f = [res objectForKey:folder];

    if (!ShowNonExistentFolder) {
      if ([f containsObject:@"nonexistent"])
        continue;
    }
    newFolder = [NGImap4Folder alloc]; /* to keep gcc happy */
    objs[cnt] = [[newFolder initWithContext:self->context
                            name:folder flags:f parentFolder:self]
		            autorelease];
    if (objs[cnt] == nil)
      break;
    cnt++;
  }
  if (folder == nil)
    self->subFolders = [[NSArray alloc] initWithObjects:objs count:cnt];
  
  if (objs) free(objs);
}

- (BOOL)select {
  return [self selectImmediately:NO];
}

- (BOOL)selectImmediately:(BOOL)_imm {
  NSDictionary *dict;

  if ([self->flags doNotSelectFolder]) {
    [self logWithFormat:@"WARNING[%s]: try to select folder with noselect "
          @"flag <%@>", __PRETTY_FUNCTION__, self];
    return NO;
  }
  if (self->failedFlags.select)
    return NO;
  
  if (!_imm) {
    if ([[self context] isInSyncMode] && self->selectSyncState)
      return YES;
  }
  [self resetLastException];
  
  dict = [[self->context client] select:[self absoluteName]];
  if (![self _checkResult:dict cmd:__PRETTY_FUNCTION__]) {
    self->failedFlags.select = YES;
    return NO;
  }
  [self->context setSelectedFolder:self];

  ASSIGN(self->messageFlags, [dict objectForKey:@"flags"]);

  self->isReadOnly = 
    [[dict objectForKey:@"access"] isEqualToString:@"READ-WRITE"]
    ? NoNumber : YesNumber;
  
  // TODO: isn't there a better way to check for overquota?
  if ([[dict objectForKey:@"alert"] isEqualToString:@"Mailbox is over quota"])
    self->overQuota = 1;
  else
    self->overQuota = 0;

  [self setRecent:[dict objectForKey:@"recent"]
        exists:[dict objectForKey:@"exists"]];
  
  self->maxQuota          = -1;
  self->usedSpace         = -1;
  self->failedFlags.quota = NO;
  self->selectSyncState   = YES;

  return YES;
}

- (BOOL)status {
  NSDictionary *dict;

  if ([self->flags doNotSelectFolder])
    return NO;

  if (self->failedFlags.status)
    return NO;
  
  [self->context resetLastException];

  dict = [[self->context client] status:[self absoluteName] flags:StatusFlags];

  if (![self _checkResult:dict cmd:__PRETTY_FUNCTION__]) {
    self->unseen             = -1;
    self->recent             = -1;
    self->exists             = -1;
    self->maxQuota           = -1;
    self->usedSpace          = -1;
    self->overQuota          = -1;
    self->failedFlags.status = YES;
    self->failedFlags.quota  = NO;
    
    return NO;
  }
  [self setRecent:[dict objectForKey:@"recent"]
        exists:[dict objectForKey:@"messages"]];
  self->unseen = [[dict objectForKey:@"unseen"] intValue];

  return YES;
}

/* actions */

- (void)resetFolder {
  // TODO: shouldn't the post happen after the expunge?
  [self _postResetFolderNotification];
  [self expunge];
}

- (void)_resetFolder {
#if USE_MESSAGE_CACHE  
  [self resetQualifierCache];
#endif
  [self->msn2UidCache release]; self->msn2UidCache = nil;       
  [self->flags        release]; self->flags        = nil;
  [self->messageFlags release]; self->messageFlags = nil;
#if USE_MESSAGE_CACHE  
  [self->messages     release]; self->messages     = nil;  
#endif
  self->maxQuota           = -1;
  self->usedSpace          = -1;
  self->overQuota          = -1;
  self->failedFlags.select = NO;
  self->failedFlags.quota  = NO;
  self->isReadOnly         = nil;
  [self resetStatus];
}

- (void)resetStatus {
  self->unseen             = -1;
  self->exists             = -1;
  self->recent             = -1;
  self->failedFlags.status = NO;
}

- (void)_resetSubFolder {
  id ctx;

  ctx = [self context];
  
  if ((self->parentFolder == nil) || (self == [ctx inboxFolder]))
    [ctx resetSpecialFolders];

  [self->subFolders release]; self->subFolders = nil;
}

- (void)resetSubFolders {
  // TODO: explain in detail what this does
  NSString *n;
  
  n = [self absoluteName];
  if ([n isNotEmpty])
    [self _postResetSubfolderNotification];
  else
    [self _resetSubFolder];
}

- (BOOL)renameTo:(NSString *)_name {
  NSString     *n;
  NSDictionary *dict;

  if ([self isReadOnly])
    return NO;
  
  if ((_name == nil) || ([_name length] == 0))
    return NO;
  
  n = [[self->name stringByDeletingLastPathComponent]
                   stringByAppendingPathComponent:_name];

  [self resetLastException];

  dict = [[self->context client] rename:[self absoluteName] to:n];

  if (![self _checkResult:dict cmd:__PRETTY_FUNCTION__])
    return NO;
  
  ASSIGNCOPY(self->name, n);
  [self->globalID release]; self->globalID = nil;
  
  [self resetSubFolders];
 
  dict = [[self->context client] subscribe:self->name];

  if (![self _checkResult:dict cmd:__PRETTY_FUNCTION__])
    return NO;

  return YES;
}

/* folder */

- (BOOL)deleteSubFolder:(NGImap4Folder *)_folder {
  if ([self isReadOnly])
    return NO;
  return _deleteSubFolder(self, _folder);;
}

- (BOOL)copySubFolder:(NGImap4Folder *)_f to:(NGImap4Folder *)_folder {
  return _copySubFolder(self, _f, _folder);
}

- (BOOL)moveSubFolder:(NGImap4Folder *)_f to:(NGImap4Folder *)_folder {
  if ([self isReadOnly])
    return NO;
  return _moveSubFolder(self, _f, _folder);
}

- (BOOL)createSubFolderWithName:(NSString *)_name {
  if ([self isReadOnly])
    return NO;
  return _createSubFolderWithName(self, _name, YES);
}

- (void)expunge {
  NSDictionary *dict;
  
  if ([self->flags doNotSelectFolder] || self->failedFlags.select)
    return;

  if ([self isReadOnly])
    return;
  if (![self->context registerAsSelectedFolder:self])
    return;
      
  dict = [[self->context client] expunge];
  if (![self _checkResult:dict cmd:__PRETTY_FUNCTION__])
    return;
  
  [self setRecent:[dict objectForKey:@"recent"]
        exists:[dict objectForKey:@"exists"]];
}

- (BOOL)addFlag:(NSString *)_flag toMessages:(NSArray *)_messages {
  return [self flag:_flag toMessages:_messages add:YesNumber];
}

- (BOOL)removeFlag:(NSString *)_flag fromMessages:(NSArray *)_messages {
  return [self flag:_flag toMessages:_messages add:NoNumber];
}

- (BOOL)flag:(NSString *)_flag toMessages:(NSArray *)_messages
  add:(NSNumber *)_add
{
  NSEnumerator   *enumerator;
  NGImap4Message *message;
  NSDictionary   *obj;
  BOOL           add;
  NSArray        *flagArray;
  
  add = [_add boolValue];   

  if ([self->flags doNotSelectFolder])
    return NO;

  if (_flag == nil) {
    [self logWithFormat:@"WARNING[%s]: try to set an empty flag",
          __PRETTY_FUNCTION__];
    return NO;
  }
  if ([self isReadOnly])
    return NO;
  
  if (![self->context registerAsSelectedFolder:self])
    return NO;

  if (![self _testMessages:_messages operation:@"store"])
    return NO;

  [self resetLastException];
  
  enumerator = [[self _getMsnRanges:_messages] objectEnumerator];
  if (enumerator == nil) {
    [self resetStatus];
    [self->context removeSelectedFolder:self];
    return NO;
  }
  
  flagArray = [_flag isNotNull] ? [NSArray arrayWithObject:_flag] : nil;
  while ((obj = [enumerator nextObject])) {
    NSDictionary *res;
    int objEnd, objStart;
    
    if ((objEnd = [[obj objectForKey:@"end"] unsignedIntValue]) <= 0)
      continue;
    
    objStart = [[obj objectForKey:@"start"] unsignedIntValue];
    res = [[self->context client]
                          storeFrom:objStart to:objEnd
                          add:_add flags:flagArray];

    if (![self _checkResult:res cmd:__PRETTY_FUNCTION__])
      break;
  }
  if (obj)
    return NO;

  enumerator = [_messages objectEnumerator];
  while ((message = [enumerator nextObject])) {
    if (add)
      [message addFlag:_flag];
    else
      [message removeFlag:_flag];
  }
  [self resetStatus];
  return YES;
}

- (BOOL)flagToAllMessages:(NSString *)_flag add:(NSNumber *)_add {
#if USE_MESSAGE_CACHE
  BOOL            add        = [_add boolValue];
  NSEnumerator   *enumerator = nil;
  NGImap4Message *m          = nil;
#endif

  if ([self->flags doNotSelectFolder])
    return NO;
  
  if (_flag == nil)
    return NO;

  if ([self isReadOnly])
    return NO;

  if (![self->context registerAsSelectedFolder:self])
    return NO;

  
  if ([self exists] > 0) {
    NSDictionary *res;
    
    [self resetLastException];
    
    res = [[self->context client] storeFrom:0 to:[self exists]
                                  add:_add
                                  flags:[NSArray arrayWithObject:_flag]];

    if (![self _checkResult:res cmd:__PRETTY_FUNCTION__])
      return NO;
    
#if USE_MESSAGE_CACHE
    enumerator = [self->messages objectEnumerator];
    while ((m = [enumerator nextObject])) {
      (add)
        ? [m addFlag:_flag]
        : [m removeFlag:_flag];
    }
#endif
  }
  return YES;
}

- (BOOL)deleteAllMessages {
  if ([self isReadOnly])
    return NO;

  if ([self flagToAllMessages:@"Deleted" add:YesNumber]) {
    [self resetFolder];
    return YES;
  }
  return NO;
}

- (BOOL)deleteMessages:(NSArray *)_messages {
  if ([self isReadOnly])
    return NO;

  if ([self addFlag:@"Deleted" toMessages:_messages]) {
    [self resetFolder];
    return YES;
  }
  return NO;
}

- (BOOL)moveMessages:(NSArray *)_messages toFolder:(NGImap4Folder *)_folder {
  if ([self isReadOnly])
    return NO;

  if (_folder != nil) {
    if ([self copyMessages:_messages toFolder:_folder]) {
      return [self deleteMessages:_messages];
    }
  }
  return NO;
}

- (BOOL)copyMessages:(NSArray *)_messages toFolder:(NGImap4Folder *)_folder {
  NSEnumerator *enumerator;
  NSDictionary *obj;
  NSString     *folderName;

  if ([self->flags doNotSelectFolder])
    return NO;
  
  folderName = [_folder absoluteName];  

  if (_folder == nil) {
    [self logWithFormat:@"WARNING[%s]: try to copy to nil folder",
          __PRETTY_FUNCTION__];
    return NO;
  }
  [self resetLastException];
  
  if ([_folder isReadOnly]) {
    NGImap4ResponseException *exc;

    [self logWithFormat:@"WARNING[%s]: try to copy to readonly folder %@",
          __PRETTY_FUNCTION__, _folder];

    exc = [[NGImap4ResponseException alloc] initWithFormat:
                                            @"copy to read only folder"];
    [self->context setLastException:exc];
    [exc release]; exc = nil;
    return NO;
  }
  if (![self->context registerAsSelectedFolder:self])
    return NO;
  
  if (![self _testMessages:_messages operation:@"copy"])
    return NO;
  
  enumerator = [[self _getMsnRanges:_messages] objectEnumerator];
  if (enumerator == nil) {
    [self resetStatus];
    [self->context removeSelectedFolder:self];
    return NO;
  }
  
  [self resetLastException];
  if (![self->context registerAsSelectedFolder:self])
    return NO;
  
  while ((obj = [enumerator nextObject])) {
    int objEnd;
    
    objEnd = [[obj objectForKey:@"end"] unsignedIntValue];

    if (objEnd > 0) {
      NSDictionary *res;
      unsigned int start;
      
      start = [[obj objectForKey:@"start"] unsignedIntValue];
      res = [[self->context client]
                            copyFrom:start to:objEnd toFolder:folderName];
      if (![self _checkResult:res cmd:__PRETTY_FUNCTION__])
        break;
    }
  }
  [_folder resetFolder];
  return (obj == nil) ? YES : NO;
}

- (BOOL)appendMessage:(NSData *)_msg {
  if ([self isReadOnly])
    return NO;

  if (_msg != nil) {
    NSDictionary *dict;

    dict = [[self->context client]
                           append:_msg toFolder:[self absoluteName]
                           withFlags:[NSArray arrayWithObject:@"seen"]];

    if ([self _checkResult:dict cmd:__PRETTY_FUNCTION__]) {
      [self resetFolder];
      return YES;
    }
  }
  return NO;
}

#if USE_MESSAGE_CACHE
- (void)resetQualifierCache {
  self->cacheIdx = 0;
  [self->qualifierCache removeAllObjects];
}
#endif

/* notifications */

- (void)setRecent:(NSNumber *)_rec exists:(NSNumber *)_exists {
#if USE_MESSAGE_CACHE  
  BOOL resetQualifier = NO;
  if (_rec != nil) {
    int tmp = [_rec intValue];
      if (self->recent != tmp) {
        self->recent   = tmp;
        resetQualifier = YES;
      }
  }
  if (_exists != nil) {
    int tmp = [_exists intValue];
    if (self->exists != tmp) {
      self->exists = tmp;
      resetQualifier = YES;
    }
  }
  if (resetQualifier) 
    [self resetQualifierCache];
#else
  {
    if (_exists != nil) {
      int      e;

      e = [_exists intValue];

      if (e == 0) {
        self->exists = 0;
        self->recent = 0;
        self->unseen = 0;
      }
      else {
        int      r;
    
        r  = [_rec intValue];

        if ((e != self->exists) || (r != self->recent)) {
          self->exists = e;
          self->recent = r;
          self->unseen = -1;
        }
      }
    }
  }
#endif  
}

- (void)processResponse:(NSDictionary *)_dict {
#if USE_MESSAGE_CACHE  
  id exp = [_dict objectForKey:@"expunge"];
#endif

  [self setRecent:[_dict objectForKey:@"recent"]
        exists:[_dict objectForKey:@"exists"]];

#if USE_MESSAGE_CACHE  
  if ((exp != nil) && ([exp count] > 0) && ([self->messages count] > 0)) {
    NSEnumerator *enumerator;
    id           obj;
    
    enumerator = [exp objectEnumerator];
    while ((obj = [enumerator nextObject])) {
      int n = [obj intValue] - 1;

      [self->messages removeObjectAtIndex:n];
    }
    [self resetQualifierCache];
  }
#endif  
}

- (BOOL)isInTrash {
  id<NGImap4Folder> f, trash;

  trash = [self->context trashFolder];

  if (trash == nil) {
    [self logWithFormat:@"WARNING[%s]: No trash folder was set",
          __PRETTY_FUNCTION__];
    return NO;
  }

  for (f = self; f; f = [f parentFolder]) {
    if ([f isEqual:trash])
      return YES;
  }
  return NO;
}

- (void)resetSync {
  NSEnumerator *enumerator;
  id           folder;

  self->selectSyncState = NO;
  
  if (self->subFolders == nil)
    return;
  
  enumerator = [[self subFolders] objectEnumerator];
  while ((folder = [enumerator nextObject]))
    [folder resetSync];
}

- (NSURL *)url {
  NSString *p;
  NSURL *base;
  
  if (self->url != nil)
    return self->url;
  
  if ((base = [self->context url]) == nil) {
    [self logWithFormat:@"ERROR: got no URL for context: %@", self->context];
    return nil;
  }
  
  if ((p = [self absoluteName]) == nil)
    return nil;
  
  if (![p hasPrefix:@"/"]) p = [@"/" stringByAppendingString:p];
  self->url = [[NSURL alloc]
		initWithScheme:[base scheme] host:[base host] path:p];
  return self->url;
}

- (EOGlobalID *)serverGlobalID {
  return [self->context serverGlobalID];
}
- (EOGlobalID *)globalID {
  if (self->globalID)
    return self->globalID;

  self->globalID = [[NGImap4FolderGlobalID alloc] initWithServerGlobalID:
						    [self serverGlobalID]
						  andAbsoluteName:
						    [self absoluteName]];
  return self->globalID;
}

/* quota information */

- (void)quota {
  NSString     *n;
  NSDictionary *quota;

  if (self->failedFlags.quota)
    return;

  if (![self->context canQuota]) {
    [self logWithFormat:@"WARNING[%s] call quota but capability contains"
          @" no quota string", __PRETTY_FUNCTION__];
    return;
  }
  n     = [self absoluteName];
  [self resetLastException];

  if ([self->flags doNotSelectFolder])
    return;
  
  quota = [[self->context client] getQuotaRoot:n];

  if (![self _checkResult:quota cmd:__PRETTY_FUNCTION__]) {
    self->failedFlags.quota = YES;
    return;
  }
  
  quota = [quota objectForKey:@"quotas"];
  quota = [quota objectForKey:n];
  
  self->maxQuota  = [[quota objectForKey:@"maxQuota"]  intValue];
  self->usedSpace = [[quota objectForKey:@"usedSpace"] intValue];
}


- (BOOL)_testMessages:(NSArray *)_messages operation:(NSString *)_operation {
  NSEnumerator *enumerator;
  id           obj;
  
  enumerator = [_messages objectEnumerator];
  while ((obj = [enumerator nextObject])) {
    if ([obj folder] != self) {
      [self logWithFormat:@"ERROR: try to %@ mails in folder who didn`t own"
            @" this mail \nFolder %@\nMail %@ allMessages %@",
            _operation, self, obj, _messages];
      return NO;
    }
  }
  return YES;
}

- (NSArray *)_getMsnRanges:(NSArray *)_messages {
  // TODO: might split up? document!
  static NSArray      *UidKey     = nil;
  
  NSArray             *result;
  NSMutableDictionary *map;
  NSMutableArray      *msn;
  NSEnumerator        *enumerator;  
  NSDictionary        *obj;
  NSAutoreleasePool   *pool;
  NGImap4Message      *message;
  
  if ([self exists] == 0)
    return [NSArray array];

  pool = [[NSAutoreleasePool alloc] init];
  
  if (UidKey == nil) {
    id objs = nil;

    objs   = @"uid";
    UidKey = [[NSArray alloc] initWithObjects:&objs count:1];
  }

  [self resetLastException];
  
  if (![self->context registerAsSelectedFolder:self])
    return nil;

  if ([_messages count] > [self->msn2UidCache count]) {
    [self->msn2UidCache release]; 
    self->msn2UidCache = nil;
  }
  
  if (!self->msn2UidCache) {
    NSDictionary *res;

    res = [[self->context client] fetchFrom:1 to:[self exists] parts:UidKey];

    if (![self _checkResult:res cmd:__PRETTY_FUNCTION__])
      return nil;
    
    self->msn2UidCache = [[res objectForKey:@"fetch"] retain];
  }
  map = [[NSMutableDictionary alloc] initWithCapacity:
                                     [self->msn2UidCache count]];
  enumerator = [self->msn2UidCache objectEnumerator];
  
  while ((obj = [enumerator nextObject]))
    [map setObject:[obj objectForKey:@"msn"] forKey:[obj objectForKey:@"uid"]];
  
  msn = [[NSMutableArray alloc] initWithCapacity:[_messages count]];
  enumerator = [_messages objectEnumerator];
  while ((message = [enumerator nextObject])) {
    id m;
    
    m = [map objectForKey:[NSNumber numberWithUnsignedInt:[message uid]]];
    
    if (m == nil) {
      [self logWithFormat:@"WARNING[%s]: Couldn`t map a message sequence "
            @"number to message %@ numbers %@ messages %@ "
            @"self->msn2UidCache %@",
            __PRETTY_FUNCTION__, message, map, _messages, self->msn2UidCache];
      [msn  release];
      [map  release];
      [pool release];
      return nil;
    }
    [msn addObject:m];
  }
  [map release]; map = nil;
  
  result = [self _calculateSequences:msn count:-1];
  
  result = [result retain];
  [msn release]; msn = nil;
  [pool release];
  return [result autorelease];
}

- (NSArray *)_calculateSequences:(NSMutableArray *)_numbers count:(int)_cnt {
  // TODO: might split up? document! This looks pretty weird
  NSAutoreleasePool   *pool;
  NSEnumerator        *enumerator;
  NSMutableDictionary *range;
  NSMutableArray      *ranges;
  id                  obj, buffer;
  int                 cntMsgs;

  pool = [[NSAutoreleasePool alloc] init];

  if (_cnt == -1)
    _cnt = [_numbers count];
  
  [_numbers sortUsingSelector:@selector(compare:)];
  
  ranges     = [NSMutableArray arrayWithCapacity:[_numbers count]];
  enumerator = [_numbers objectEnumerator];
  buffer     = [NSNumber numberWithInt:0];
  range      = nil;
  cntMsgs    = 0;
  while (((obj = [enumerator nextObject])) && (cntMsgs < _cnt)) {
    cntMsgs++;
    if (range == nil) {
      range = [NSMutableDictionary dictionaryWithCapacity:2];
      [range setObject:buffer forKey:@"start"];
    }
    
    if ([obj intValue] != [buffer intValue] + 1) {
      NSDictionary *ir;
      
      [range setObject:buffer forKey:@"end"];
      ir = [range copy];
      [ranges addObject:ir];
      [ir release];
      range = nil;
    }
    buffer = obj;
  }
  if (range != nil) {
    [range setObject:buffer forKey:@"end"];
    [ranges addObject:range];
  }
  else {
    NSDictionary *d;
    
    d = [[NSDictionary alloc] initWithObjectsAndKeys:
				buffer, @"start", buffer, @"end", nil];
    [ranges addObject:d];
    [d release];
  }
  range = [ranges objectAtIndex:0];
  if ([[range objectForKey:@"end"] intValue] == 0)
    [ranges removeObjectAtIndex:0];
  
  obj = [ranges copy];
  [pool release];
  return [obj autorelease];
}

- (void)clearParentFolder {
  self->parentFolder = nil;
}

/* message factory */

- (id)messageWithUid:(unsigned int)_uid {
  return [[[NGImap4Message alloc] 
	                   initWithUid:_uid folder:self context:[self context]]
	                   autorelease];
}

/* message registry */

- (NGImap4FolderMailRegistry *)mailRegistry {
  return self->mailRegistry;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return ImapDebugEnabled;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  NSString        *tmp;

  ms = [NSMutableString stringWithCapacity:64];

  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  if ((tmp = [self name]))
    [ms appendFormat:@" name=%@", tmp];
  if ((tmp = [self absoluteName]))
    [ms appendFormat:@" absolute=%@", tmp];
  if ((tmp = [[self flags] componentsJoinedByString:@","]))
    [ms appendFormat:@" flags=%@", tmp];
  
  [ms appendString:@">"];

  return ms;
}

@end /* NGImap4Folder */

#if 0
@implementation NSData(xxxx)
- (NSString *)description {
  return [NSString stringWithFormat:@"NSData len: %d",
                   [self length]];
}
@end
#endif
