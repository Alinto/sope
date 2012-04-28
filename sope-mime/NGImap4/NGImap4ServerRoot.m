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

#include "NGImap4ServerRoot.h"
#include "NGImap4Context.h"
#include "NGImap4Client.h"
#include "NGImap4Message.h"
#include "NGImap4Functions.h"
#include "NGImap4Folder.h"
#include "imCommon.h"

@interface NGImap4ServerRoot(Private)
- (void)initializeSubFolders;
@end

@implementation NGImap4ServerRoot

static int ShowNonExistentFolder                      = -1;
static int FetchNewUnseenMessagesInSubFoldersOnDemand = -1;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

  // TODO: document the meaning!
  ShowNonExistentFolder =
    [ud boolForKey:@"ShowNonExistentFolder"] ? 1 : 0;
  FetchNewUnseenMessagesInSubFoldersOnDemand =
    [ud boolForKey:@"FetchNewUnseenMessagesInSubFoldersOnDemand"] ? 1 : 0;
}

+ (id)serverRootWithContext:(NGImap4Context *)_context {
  return [[[self alloc] initServerRootWithContext:_context] autorelease];
}

- (id)init {
  [self release];
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (id)initServerRootWithContext:(NGImap4Context *)_context {
  if ((self = [super init])) {
    self->context    = [_context retain];
    self->name       = [[_context host] copy];
    self->subFolders = nil;

    self->noinferiors = ([[_context serverKind] isEqualToString:@"courier"])
      ? YES : NO;
  }
  return self;
}

- (void)dealloc {
  [self->context    resetSpecialFolders];
  [self->context    release];
  [self->name       release];
  [self->subFolders makeObjectsPerformSelector:@selector(clearParentFolder)];
  [self->subFolders release];
  [super dealloc];
}

- (NSException *)lastException {
  return [self->context lastException];
}
- (void)resetLastException {
  [self->context resetLastException];
}

- (BOOL)isEqual:(id)_obj {
  if (self == _obj)
    return YES;
  if ([_obj isKindOfClass:[NGImap4ServerRoot class]])
    return [self isEqualToServerRoot:_obj];
  return NO;
}

- (BOOL)isEqualToServerRoot:(NGImap4ServerRoot *)_root {
  if (_root == self)
    return YES;
  if ([_root context] == self->context)
    return YES;
  return NO;
}

/* accessors */

- (NGImap4Context *)context {
  return self->context;
}

- (NSString *)name {
  return self->name;
}

- (NSString *)absoluteName {
  return self->name;
}

- (NSArray *)messages {
  return nil;
}

- (NSArray *)messagesForQualifier:(EOQualifier *)_qualifier {
  return nil;
}

- (NSArray *)messagesForQualifier:(EOQualifier *)_q maxCount:(int)_cnt {
  return nil;
}

- (NSArray *)fetchSortedMessages:(NSArray *)_so {
  return nil;
}

- (void)bulkFetchHeadersFor:(NSArray *)_array inRange:(NSRange)_aRange {
}

- (void)bulkFetchHeadersFor:(NSArray *)_array inRange:(NSRange)_aRange
  withAllUnread:(BOOL)_unread
{
}

- (NSArray *)messageFlags { 
  return nil;
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

- (NGImap4Folder *)parentFolder {
  return nil;
}

- (BOOL)isReadOnly {
  return YES;
}

- (BOOL)noinferiors {
  return self->noinferiors;
}

- (BOOL)noselect {
  return YES;
}

- (BOOL)nonexistent {
  return NO;
}
- (BOOL)haschildren {
  return YES;
}
- (BOOL)hasnochildren {
  return NO;
}
- (BOOL)marked {
  return NO;
}
- (BOOL)unmarked {
  return NO;
}

- (int)exists {
  return 0;
}

- (int)recent {
  return 0;
}

- (int)unseen {
  return 0;
}

- (int)usedSpace {
  return 0;
}

- (int)maxQuota {
  return 0;
}

- (BOOL)isOverQuota {
  return NO;
}

- (BOOL)hasNewMessagesSearchRecursiv:(BOOL)_recursiv fetchOnDemand:(BOOL)_fetch {
  if (_recursiv)
    return _hasNewMessagesInSubFolder(self, _fetch);
  return NO;
}

- (BOOL)hasNewMessagesSearchRecursiv:(BOOL)_recursiv {
  if (!_recursiv)
    return NO;
  return _hasNewMessagesInSubFolder(self,
	     FetchNewUnseenMessagesInSubFoldersOnDemand);
}

- (BOOL)hasUnseenMessagesSearchRecursiv:(BOOL)_recursiv 
  fetchOnDemand:(BOOL)_fetch 
{
  if (_recursiv)
    return _hasUnseenMessagesInSubFolder(self, _fetch);
  return NO;
}

- (BOOL)hasUnseenMessagesSearchRecursiv:(BOOL)_recursiv {
  if (_recursiv) {
    return _hasUnseenMessagesInSubFolder(self,
	       FetchNewUnseenMessagesInSubFoldersOnDemand);
  }
  return NO;
}

// private methods

/*"
** Should only happens if folder is rootfolder
"*/

- (void)initializeSubFolders {
  NSEnumerator *folders;
  NSDictionary *res;
  id           *objs, folder;
  unsigned     cnt;
  BOOL         gotInbox;
  
  if (self->subFolders != nil) {
    [self resetSubFolders];
  }

  if ([self->context showOnlySubscribedInRoot]) {
    res = [[self->context client] lsub:@"" pattern:@"%"];
  }
  else {
    res = [[self->context client] list:@"" pattern:@"%"];
  }

  if (!_checkResult(self->context, res, __PRETTY_FUNCTION__))
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
  cnt      = 0;
  gotInbox = NO;
  
  while ((folder = [folders nextObject])) {
    NSArray *f;

    f = [res objectForKey:folder];

    if (!ShowNonExistentFolder) {
      if ([f containsObject:@"nonexistent"])
        continue;
    }

    objs[cnt] = [[[NGImap4Folder alloc] initWithContext:self->context
					name:folder flags:f parentFolder:self] 
		                 autorelease];
    cnt++;
    
    if ([[folder lowercaseString] isEqualToString:@"/inbox"])
      gotInbox = YES;
  }
  if (!gotInbox && [self->context showOnlySubscribedInRoot]) {
    /* try unsubscribed */
    res = [[[self->context client] list:@"" pattern:@"%"] objectForKey:@"list"];

    {
      NSArray *names;
    
      names   = [res allKeys];
      names   = [names sortedArrayUsingSelector:
                       @selector(caseInsensitiveCompare:)];
      folders = [names objectEnumerator];
    }
    while ((folder = [folders nextObject])) {
      if ([[folder lowercaseString] isEqualToString:@"/inbox"]) {
        objs[cnt] = [[[NGImap4Folder alloc] initWithContext:self->context
					    name:folder 
					    flags:[res objectForKey:folder]
					    parentFolder:self]
		                     autorelease];
	cnt++;
        break;
      }
    }
  }
  self->subFolders = [[NSArray alloc] initWithObjects:objs count:cnt];
  if (objs) free(objs); objs = NULL;
}

- (void)select {
}

- (BOOL)status {
  return YES;
}

/* actions */

- (void)resetFolder {
}

- (void)resetStatus {
}

- (void)resetSubFolders {
  [self->context resetSpecialFolders];
  [self->subFolders release]; self->subFolders = nil;
}

- (BOOL)renameTo:(NSString *)_name {
  return NO;
}

/* folder */

- (BOOL)deleteSubFolder:(NGImap4Folder *)_folder {
  return _deleteSubFolder(self, _folder);
}

- (BOOL)copySubFolder:(NGImap4Folder *)_f to:(NGImap4Folder *)_folder {
  return _copySubFolder(self, _f, _folder);
}

- (BOOL)moveSubFolder:(NGImap4Folder *)_f to:(NGImap4Folder *)_folder {
  return _moveSubFolder(self, _f, _folder);
}

- (BOOL)createSubFolderWithName:(NSString *)_name {
  return _createSubFolderWithName(self, _name, NO);
}

- (void)expunge {
}

- (BOOL)addFlag:(NSString *)_flag toMessages:(NSArray *)_messages {
  return NO;
}

- (BOOL)removeFlag:(NSString *)_flag fromMessages:(NSArray *)_messages {
  return NO;
}

- (BOOL)flag:(NSString *)_flag toMessages:(NSArray *)_messages
        add:(NSNumber *)_add
{
  return NO;
}

- (BOOL)flagToAllMessages:(NSString *)_flag add:(NSNumber *)_add {
  return NO;
}

- (BOOL)deleteAllMessages {
  return NO;
}

- (BOOL)deleteMessages:(NSArray *)_messages {
  return NO;
}

- (BOOL)moveMessages:(NSArray *)_messages toFolder:(NGImap4Folder *)_folder {
  return NO;
}

- (BOOL)copyMessages:(NSArray *)_messages toFolder:(NGImap4Folder *)_folder {
  return NO;
}

- (BOOL)appendMessage:(NSData *)_msg {
  return NO;
}

- (BOOL)isInTrash {
  return NO;
}

- (NSString *)description {
  NSMutableString *ms;
  NSString *tmp;

  ms = [NSMutableString stringWithCapacity:64];

  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  if ((tmp = [self name]))
    [ms appendFormat:@" name=%@", tmp];
  if ((tmp = [self absoluteName]))
    [ms appendFormat:@" absolute=%@", tmp];
  
  [ms appendString:@">"];

  return ms;
}

- (void)resetSync {
  NSEnumerator *enumerator;
  id           folder;

  enumerator = [[self subFolders] objectEnumerator];
  
  while ((folder = [enumerator nextObject])) {
    [folder resetSync];
  }
}

@end /* NGImap4ServerRoot */
