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

#include "NGImap4Message.h"
#include "NGImap4Folder.h"
#include "NGImap4Context.h"
#include "NGImap4Functions.h"
#include "NGImap4Client.h"
#include "NGImap4MessageGlobalID.h"
#include "NGImap4FolderMailRegistry.h"
#include <NGExtensions/NGFileManager.h>
#include "imCommon.h"

#include "NGImap4Message+BodyStructure.h"

@class NSNotification;

@interface NGImap4Message(Internals)

- (void)initializeMessage;
- (void)fetchMessage;
- (void)parseMessage;
- (void)generateBodyStructure;
- (NSString *)_addFlagNotificationName;
- (NSString *)_removeFlagNotificationName;
- (void)_removeFlag:(NSNotification *)_obj;
- (void)_addFlag:(NSNotification *)_obj;
- (void)setIsRead:(BOOL)_isRead;

@end /* NGImap4Message(Internals) */

#define USE_OWN_GLOBAL_ID 1

@implementation NGImap4Message

static Class             NumClass   = Nil;
static NSNumber          *YesNumber = nil;
static NSNumber          *NoNumber  = nil;
static NGMimeHeaderNames *Fields    = NULL;
static NSArray           *CoreMsgAttrNames = nil;
static NSArray           *bodyNameArray    = nil;
static NSArray           *rfc822NameArray  = nil;
static BOOL              debugFlags        = NO;
static BOOL              ImapDebugEnabled  = NO;

+ (int)version {
  return 2;
}

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;
  
  NumClass = [NSNumber class];
  YesNumber = [[NumClass numberWithBool:YES] retain];
  NoNumber  = [[NumClass numberWithBool:NO]  retain];  
  Fields    = (NGMimeHeaderNames *)[NGMimePartParser headerFieldNames];
  
  CoreMsgAttrNames = [[NSArray alloc] initWithObjects:@"rfc822.header",
                                          @"rfc822.size", @"flags", nil];
  bodyNameArray   = [[NSArray alloc] initWithObjects:@"body", nil];
  rfc822NameArray = [[NSArray alloc] initWithObjects:@"rfc822", nil];
  
  ImapDebugEnabled = [ud boolForKey:@"ImapDebugEnabled"];
}

- (id)initWithUid:(unsigned)_uid folder:(NGImap4Folder *)_folder
  context:(NGImap4Context *)_ctx
{
  return [self initWithUid:_uid headers:nil size:-1 flags:nil
               folder:_folder context:_ctx];
}

- (id)initWithUid:(unsigned)_uid headers:(NGHashMap *)_headers
  size:(unsigned)_size flags:(NSArray *)_flags folder:(NGImap4Folder *)_folder
  context:(NGImap4Context *)_ctx
{
  if ((self = [super init])) {
    self->uid     = _uid;
    self->size    = _size;
    self->folder  = _folder;
    self->headers = [_headers retain];
    self->flags   = [_flags   retain];
    self->context = [_ctx     retain];
    self->isRead  = -1;
    
    if (self->folder) {
      // Note: we can safely retain the registry since it doesn't retain the
      //       mails
      self->mailRegistry = [[self->folder mailRegistry] retain];
      [self->mailRegistry registerObject:self];
    }
    else
      [self logWithFormat:@"WARNING(-init): not attached to a folder!"];
    
  }
  return self;
}

- (void)dealloc {
  if (self->mailRegistry) {
    [self->mailRegistry forgetObject:self];
    [self->mailRegistry release];
  }
  else
    [self logWithFormat:@"WARNING(-dealloc): not attached to a registry!"];
  
  [self->headers              release];
  [self->flags                release];
  [self->context              release];
  [self->rawData              release];
  [self->message              release];
  [self->bodyStructure        release];
  [self->url                  release];
  [self->bodyStructureContent release];
  [self->globalID             release];
  [self->removeFlagNotificationName release];
  [self->addFlagNotificationName    release];
  self->folder = nil;
  [super dealloc];
}

/* internal methods */

- (void)_setHeaders:(NGHashMap *)_headers
  size:(unsigned)_size
  flags:(NSArray *)_flags
{
  ASSIGN(self->headers, _headers);
  ASSIGN(self->flags,   _flags);
  self->size = _size;
}

- (BOOL)isComplete {
  return (self->headers != nil) && (self->flags != nil);
}

/* accessors */

- (NSException *)lastException {
  return [self->context lastException];
}
- (void)resetLastException {
  [self->context resetLastException];
}

- (unsigned)uid {
  return self->uid;
}

- (NGHashMap *)headers {
  if (self->headers == nil)
    [self initializeMessage];
  return self->headers;
}

- (int)size {
  if (self->size == -1)
    [self initializeMessage];
  return self->size;
}

- (NSArray *)flags {
  if (self->flags == nil)
    [self initializeMessage];
  return self->flags;
}

- (NSData *)rawData {
  if (self->rawData == nil)
    [self fetchMessage];
  return self->rawData;
}

- (NSData *)contentsOfPart:(NSString *)_part {
  NSData *result;

  if (_part == nil)
    _part = @"";
  
  /* apparently caches the data for a part ID like "1.2.3" */
  if (self->bodyStructureContent == nil) {
    self->bodyStructureContent = 
      [[NSMutableDictionary alloc] initWithCapacity:8];
  }
  
  if ((result = [self->bodyStructureContent objectForKey:_part]) == nil) {
    if ((result = [self->folder blobForUid:self->uid part:_part]) != nil)
      [self->bodyStructureContent setObject:result forKey:_part];
  }
  return result;
}

- (id<NGMimePart>)bodyStructure {
  if (self->bodyStructure == nil)
    [self generateBodyStructure];
  
  return self->bodyStructure;
}

- (id<NGMimePart>)message {
  if (self->message == nil) 
    [self parseMessage];
  return self->message;
}

- (NGImap4Folder *)folder {
  return self->folder;
}

- (NGImap4Context *)context {
  return self->context;
}

- (BOOL)isRead {
  if ((self->flags == nil) && (self->isRead != -1))
    return (self->isRead == 1) ? YES : NO;

  return [[self flags] containsObject:@"seen"];
}

- (void)markRead {
  if (![self isRead])
    [self addFlag:@"seen"];

  [self removeFlag:@"recent"];
}

- (void)markUnread {
  if ([self isRead]);
  [self removeFlag:@"seen"];
}

- (BOOL)isFlagged {
  return [[self flags] containsObject:@"flagged"];
}

- (void)markFlagged {
  if (![self isFlagged])
    [self addFlag:@"flagged"];
}

- (void)markUnFlagged {
  if ([self isFlagged]) {
    [self removeFlag:@"flagged"];
  }
}

- (BOOL)isAnswered {
  return [[self flags] containsObject:@"answered"];
}

- (void)markAnswered {
  if (![self isAnswered])
    [self addFlag:@"answered"];
}

- (void)markNotAnswered {
  if ([self isAnswered])
    [self removeFlag:@"answered"];
}

- (void)addFlag:(NSString *)_flag {
  NSDictionary *res;
  
  if (_flag == nil)
    return;
  
  if (self->mailRegistry) 
    [self->mailRegistry postFlagAdded:_flag inMessage:self];
  else
    [self logWithFormat:@"WARNING(-addFlag:): no folder attached to message!"];
  
  if (![[self->folder messageFlags] containsObject:_flag])
    return;
    
  if (![self->context registerAsSelectedFolder:self->folder])
    return;
  res = [[self->context client] storeUid:self->uid add:YesNumber
				flags:[NSArray arrayWithObject:_flag]];
  if (!_checkResult(self->context, res, __PRETTY_FUNCTION__))
    return;
  
  [self->folder resetStatus];
}

- (void)removeFlag:(NSString *)_flag {
  NSDictionary *res;
    
  if (_flag == nil) return;
  
  if (self->mailRegistry) 
    [self->mailRegistry postFlagRemoved:_flag inMessage:self];
  else
    [self logWithFormat:@"WARNING(-remFlag:): no folder attached to message!"];
  
  if (![[self->folder messageFlags] containsObject:_flag])
    return;
  
  if (![self->context registerAsSelectedFolder:self->folder])
    return;

  res = [[self->context client] storeUid:self->uid add:NoNumber
				flags:[NSArray arrayWithObject:_flag]];
  if (!_checkResult(self->context, res, __PRETTY_FUNCTION__))
    return;
    
  [self->folder resetStatus];
}

/* equality */

- (BOOL)isEqual:(id)_obj {
  if (_obj == self)
    return YES;
  if ([_obj isKindOfClass:[NGImap4Message class]])
    return [self isEqualToNGImap4Message:_obj];
  return NO;
}

- (BOOL)isEqualToNGImap4Message:(NGImap4Message *)_messages {
  if ([_messages uid] != self->uid)
    return NO;
  if (![[_messages context] isEqual:self->context])
    return NO;
  if (![[_messages folder] isEqual:self->folder])
    return NO;
  
  return YES;
}

- (unsigned)hash {
  return self->uid;
}

- (EOGlobalID *)globalID {
#if USE_OWN_GLOBAL_ID
  EOGlobalID *fgid;
  
  if (self->globalID)
    return self->globalID;

  if ((fgid = [[self folder] globalID]) == nil) {
    [self logWithFormat:@"WARNING(-globalID): got no globalID for folder: %@",
            [self folder]];
  }
  
  self->globalID = [[NGImap4MessageGlobalID alloc] initWithFolderGlobalID:fgid
                                                   andUid:[self uid]];
  return self->globalID;
#else
  id keys[4];

  if (self->globalID)
    return self->globalID;
  
  // TODO: this needs to be invalidated, if a folder is moved!
  
  keys[0] = [NumClass numberWithUnsignedInt:[self uid]];
  keys[1] = [[self folder]  absoluteName];
  keys[2] = [[self context] host];
  keys[3] = [[self context] login];
  
  globalID = [[EOKeyGlobalID globalIDWithEntityName:@"NGImap4Message"
                             keys:keys keyCount:4
                             zone:NULL] retain];
  return globalID;
#endif
}

/* key-value coding */

- (id)valueForKey:(NSString *)_key {
  // TODO: might want to add some more caching
  unsigned len;
  id v = nil;
  
  if ((len = [_key length]) == 0)
    return nil;
  
  if ([_key characterAtIndex:0] == 'N') {
    if (len < 9)
      ;
    else if ([_key isEqualToString:@"NSFileIdentifier"])
      v = [[self headers] objectForKey:Fields->messageID];
    else if ([_key isEqualToString:NSFileSize])
      v = [NumClass numberWithInt:[self size]];
    else if ([_key isEqualToString:NSFileModificationDate])
      v = [[self headers] objectForKey:Fields->date];
    else if ([_key isEqualToString:NSFileType])
      v = NSFileTypeRegular;
    else if ([_key isEqualToString:NSFileOwnerAccountName])
      v = [self->context login];
    else if ([_key isEqualToString:@"NGFileSubject"])
      v = [[self headers] objectForKey:Fields->subject];
    else if ([_key isEqualToString:@"NSFileSubject"])
      v = [[self headers] objectForKey:Fields->subject];
    else if ([_key isEqualToString:@"NGFilePath"]) 
      v = [NSString stringWithFormat:@"%@/%d",
		      [self->folder absoluteName],
		      [self uid]];
    else if ([_key isEqualToString:@"url"])
      v = [self url];

    if (v) return v;
  }
  
  if ((v = [[self headers] objectForKey:_key]))
    return v;
  
  return [super valueForKey:_key];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  id tmp;
  
  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [ms appendFormat:@" uid=%d size=%d", self->uid, self->size];

  if (self->headers != nil) {
    tmp = [[self headers] objectForKey:@"subject"];
    if ([tmp isNotEmpty])
      [ms appendFormat:@" subject='%@'", tmp];
    else
      [ms appendString:@" no-subject"];
  }
  else {
    [ms appendString:@" [header not fetched]"];
  }
  tmp = [self->folder absoluteName];
  if (tmp)
    [ms appendFormat:@" folder='%@'", tmp];

  if (self->flags) {
    tmp = [self flags];

    if ([tmp isNotEmpty])
      [ms appendFormat:@"flags: (%@)", [tmp componentsJoinedByString:@", "]];
    else
      [ms appendString:@"no-flags"];
  }
  else
    [ms appendString:@" [flags not fetched]"];
  
  [ms appendString:@">"];
  return ms;
}

- (NSURL *)url {
  NSURL    *base;
  NSString *path, *s;
  char buf[64];
  
  if (self->url) return self->url;

  base = [self->folder url];
  
  sprintf(buf, "%d", [self uid]);
  s = [[NSString alloc] initWithCString:buf];
  path = [[base path] stringByAppendingPathComponent:s];
  [s release];
  
  self->url = [[NSURL alloc] initWithScheme:[base scheme]
			     host:[base host]
			     path:path];
  return self->url;
}

/* Internals */

- (void)initializeMessage {
  NSDictionary        *dict;
  NSDictionary        *fetch;
  NSAutoreleasePool   *pool;

  pool = [[NSAutoreleasePool alloc] init];

  if (![self->context registerAsSelectedFolder:self->folder])
    return;
  
  [self resetLastException];

  dict = [[self->context client]
                         fetchUid:self->uid
                         parts:CoreMsgAttrNames];

  if (!_checkResult(self->context, dict, __PRETTY_FUNCTION__))
    return;
  
  fetch = [[[dict objectForKey:@"fetch"] objectEnumerator] nextObject];

  if (fetch == nil) {
    NSLog(@"WARNING[%s] : couldn`t fetch message with id %d",
          __PRETTY_FUNCTION__, self->uid);
    return;
  }
  {
    id                  h, f, s;
    NGMimeMessageParser *parser;
    NGDataStream        *stream;  

    h   = [fetch objectForKey:@"header"];
    f   = [fetch objectForKey:@"flags"];
    s   = [fetch objectForKey:@"size"];

    if ((h == nil) || (f == nil) || (s == nil)) {
      NSLog(@"WARNING[%s]: got no header, flags, size for %@",
            __PRETTY_FUNCTION__, fetch);
      return;
    }
    parser = [[[NGMimeMessageParser alloc] init] autorelease];
    stream = [[[NGDataStream alloc] initWithData:h] autorelease];
    
    [parser prepareForParsingFromStream:stream];
    
    ASSIGN(self->headers, [parser parseHeader]);

    self->size = [s intValue];

    if (([f containsObject:@"recent"]) && ([f containsObject:@"seen"])) {
      f = [[f mutableCopy] autorelease];
      [f removeObject:@"recent"];
    }
    ASSIGNCOPY(self->flags, f);
  }
  [pool release]; pool = nil;
}

- (void)fetchMessage {
  NSDictionary *dict, *fetch;

  if (![self->context registerAsSelectedFolder:self->folder])
    return;

  [self resetLastException];
  
  dict = [[self->context client] fetchUid:self->uid parts:rfc822NameArray];
  if (!_checkResult(self->context, dict, __PRETTY_FUNCTION__))
      return;
  
  fetch = [[[dict objectForKey:@"fetch"] objectEnumerator] nextObject];

  if (fetch == nil) {
    NSLog(@"WARNING[%s]: couldn`t fetch message with id %d",
          __PRETTY_FUNCTION__, self->uid);
    return;
  }
  ASSIGN(self->rawData, [fetch objectForKey:@"message"]);
}

- (void)_processBodyStructureEncoding:(NSDictionary *)bStruct {
  NGHashMap *orgH;
  NGMutableHashMap *h;

  orgH = [self headers];

  if ([[orgH objectForKey:@"encoding"] isNotEmpty])
    return;
      
  h = [[self headers] mutableCopy];
  
  [h setObject:[[bStruct objectForKey:@"encoding"] lowercaseString]
     forKey:@"content-transfer-encoding"];
  
  ASSIGNCOPY(self->headers, h);
  [h release];
}
- (void)generateBodyStructure {
  NSDictionary *dict, *bStruct;
  NSArray      *fetchResponses;

  [self->bodyStructure release]; self->bodyStructure = nil;

  [self resetLastException];

  if (![self->context registerAsSelectedFolder:self->folder])
    return;
  
  dict = [[self->context client] fetchUid:self->uid parts:bodyNameArray];
  
  if (!(_checkResult(self->context, dict, __PRETTY_FUNCTION__)))
    return;

  /*
    TODO: the following seems to fail with Courier, see OGo bug #800:
    ---snip---
    C[0x8b4e754]: 27 uid fetch 635 (body)
    S[0x8c8b4e4]: * 627 FETCH (UID 635 BODY 
      ("text" "plain" ("charset" "iso-8859-1" "format" "flowed") 
      NIL NIL "8bit" 2474 51))
    S[0x8c8b4e4]: * 627 FETCH (FLAGS (\Seen))
    S[0x8c8b4e4]: 27 OK FETCH completed.
    Jun 26 18:38:15 OpenGroupware [30904]: <0x08A73DCC[NGImap4Message]>
      WARNING[-[NGImap4Message generateBodyStructure]]: could not fetch body of
      message with id 635
  */
  
  fetchResponses = [dict objectForKey:@"fetch"];
  if ([fetchResponses count] == 1) {
    /* like with Cyrus, "old" behaviour */
    bStruct = 
      [(NSDictionary *)[fetchResponses lastObject] objectForKey:@"body"];
  }
  else if (![fetchResponses isNotEmpty]) {
    /* no results */
    bStruct = nil;
  }
  else {
    /* need to scan for the 'body' response, Courier 'behaviour' */
    NSEnumerator *e;
    NSDictionary *response;
    
    bStruct = nil;
    e = [fetchResponses objectEnumerator];
    while ((response = [e nextObject])) {
      if ((bStruct = [response objectForKey:@"body"]) != nil)
	break;
    }
  }
  
  if (bStruct == nil) {
    [self logWithFormat:
	    @"WARNING[%s]: could not fetch body of message with id %d.",
            __PRETTY_FUNCTION__, self->uid];
    if (ImapDebugEnabled) {
      [self logWithFormat:@"  raw:   %@", dict];
      [self logWithFormat:@"  fetch: %@", [dict objectForKey:@"fetch"]];
      [self logWithFormat:@"  last:  %@", 
	      [[dict objectForKey:@"fetch"] lastObject]];
    }
    return;
  }
  
  /* set encoding */
  if ([[bStruct objectForKey:@"encoding"] isNotEmpty])
    [self _processBodyStructureEncoding:bStruct];
  
  self->bodyStructure = [[NGMimeMessage alloc] initWithHeader:[self headers]];
  [self->bodyStructure setBody:
       _buildMimeMessageBody(self, [self url], bStruct, self->bodyStructure)];
}

- (void)parseMessage {
  NGMimeMessageParser *parser;

  parser = [[NGMimeMessageParser alloc] init];
  ASSIGN(self->message, [parser parsePartFromData:[self rawData]]);
  [parser release];
}

/* flag notifications */

- (NSString *)_addFlagNotificationName {
  if (self->addFlagNotificationName)
    return self->addFlagNotificationName;
  
  self->addFlagNotificationName =
      [[NSString alloc]
                 initWithFormat:@"NGImap4MessageAddFlag_%@_%d",
                 [[self folder] absoluteName], self->uid];
  
  return self->addFlagNotificationName;
}

- (NSString *)_removeFlagNotificationName {
  if (self->removeFlagNotificationName)
    return self->removeFlagNotificationName;
  
  self->removeFlagNotificationName =
      [[NSString alloc]
                 initWithFormat:@"NGImap4MessageRemoveFlag_%@_%d",
                 [[self folder] absoluteName], self->uid];
  return self->removeFlagNotificationName;
}

- (void)_removeFlag:(NSNotification *)_notification {
  NSMutableArray *tmp;
  NSString *flag;

  flag = [[_notification userInfo] objectForKey:@"flag"];
  if (debugFlags) [self logWithFormat:@"_del flag: %@", flag];

  if (![self->flags containsObject:flag]) {
    if (debugFlags) [self logWithFormat:@"  not set."];
    return;
  }

  tmp = [self->flags mutableCopy];
  [tmp removeObject:flag];

  ASSIGNCOPY(self->flags, tmp);
  [tmp release];
}
- (void)_addFlag:(NSNotification *)_notification {
  NSArray  *tmp;
  NSString *flag;

  flag = [[_notification userInfo] objectForKey:@"flag"];
  if (debugFlags) [self logWithFormat:@"_add flag: %@", flag];
  
  if ([self->flags containsObject:flag]) {
    if (debugFlags) [self logWithFormat:@"  already set."];
    return;
  }
  
  tmp = self->flags;
  self->flags = [[self->flags arrayByAddingObject:flag] copy];
  [tmp release];
}

- (void)setIsRead:(BOOL)_isRead {
  self->isRead = (_isRead)?1:0;
}

@end /* NGImap4Message */
