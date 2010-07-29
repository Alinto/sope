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

#include "NGImap4DataSource.h"
#include <NGStreams/NGSocketExceptions.h>
#include "imCommon.h"

@interface NGImap4DataSource(PrivateMethodes)
- (NSArray *)fetchMessages;
@end

@interface EOQualifier(IMAPAdditions)
- (BOOL)isImap4UnseenQualifier;
@end

@implementation NGImap4DataSource

static BOOL profileDS = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  if ((profileDS = [ud boolForKey:@"ProfileImap4DataSource"]))
    NSLog(@"NGImap4DataSource: Profiling enabled!");
}

- (NSNotificationCenter *)notificationCenter {
  static NSNotificationCenter *nc = nil;
  if (nc == nil) nc = [[NSNotificationCenter defaultCenter] retain];
  return nc;
}

- (id)init {
  if ((self = [super init])) {
    NSNotificationCenter *nc = [self notificationCenter];
    
    [nc addObserver:self
        selector:@selector(mailsWereDeleted:)
        name:@"LSWImapMailWasDeleted"
        object:nil];

    [nc addObserver:self
        selector:@selector(folderWasMoved:)
        name:@"LSWImapMailFolderWasDeleted"
        object:nil];
    
    [nc addObserver:self
        selector:@selector(flagsWereChanged:)
        name:@"LSWImapMailFlagsChanged"
        object:nil];
  }
  return self;
}
- (id)initWithFolder:(NGImap4Folder *)_folder {
  if ((self = [self init])) {
    [self setFolder:_folder];
  }
  return self;
}

- (void)dealloc {
  [[self notificationCenter] removeObserver:self];
  [self->folder   release];
  [self->fspec    release];
  [self->messages release];
  [self->oldUnseenMessages release];
  [super dealloc];
}

/* operations */

- (void)folderWasMoved:(id)_obj {
  [self->folder   release]; self->folder   = nil;
  [self->messages release]; self->messages = nil;
  [self->oldUnseenMessages release]; self->oldUnseenMessages = nil;
}

- (void)mailsWereDeleted:(id)_obj {
  [self->messages          release]; self->messages          = nil;
  [self->oldUnseenMessages release]; self->oldUnseenMessages = nil;
}

- (void)flagsWereChanged:(id)_obj {
  [self postDataSourceChangedNotification];
}

- (NSArray *)fetchObjects {
  NSAutoreleasePool *pool;
  NSArray *tmp;
  
  if (self->messages) {
    if (profileDS) [self logWithFormat:@"fetchObjects: already fetched."];
    return self->messages;
  }
    
  pool = [[NSAutoreleasePool alloc] init];
  {  
    if (profileDS) [self logWithFormat:@"fetchObjects: fetch ..."];
    
    tmp = (self->folder != nil)
      ? [self fetchMessages] : (NSArray *)[NSArray array];
    
    if (profileDS) [self logWithFormat:@"fetchObjects:   done ..."];
    ASSIGN(self->messages, tmp);
  }
  [pool release];
  if (profileDS) [self logWithFormat:@"fetchObjects:   pool released."];
  
  return self->messages;
}

- (void)clear {
  if (profileDS) [self logWithFormat:@"clear: do ..."];
  [self->messages release];
  self->messages = nil;
  if (profileDS) [self logWithFormat:@"clear: done."];
}

- (void)setFolder:(NGImap4Folder *)_folder {
  ASSIGN(self->folder, _folder);
  
  [self->messages          release]; self->messages          = nil;
  [self->oldUnseenMessages release]; self->oldUnseenMessages = nil;
  
  [self postDataSourceChangedNotification];
}
- (NGImap4Folder *)folder {
  return self->folder;
}

- (void)setFetchSpecification:(EOFetchSpecification *)_fetchSpec {
  if ([_fetchSpec isEqual:self->fspec]) return;
  
  ASSIGN(self->fspec, _fetchSpec);
  [self->messages release]; self->messages = nil;
  [self postDataSourceChangedNotification];
}
- (EOFetchSpecification *)fetchSpecification {
  return self->fspec;
}

- (int)oldExists {
  return self->oldExists;
}
- (int)oldUnseen {
  return self->oldUnseen;
}

/* private methodes */

- (NSException *)handleImapException:(NSException *)_exception {
  if ([_exception isKindOfClass:[NGImap4ResponseException class]]) {
    NSDictionary *record;
    NSString *str;
    
    record = [[_exception userInfo] objectForKey:@"RawResponse"];
    record = [record objectForKey:@"ResponseResult"];
    str    = [record objectForKey:@"description"];
    fprintf(stderr, "%s", [str cString]);
  }    
  else if ([_exception isKindOfClass:[NGIOException class]]) {
    fprintf(stderr, "%s", [[_exception reason] cString]);
  }
  else if ([_exception isKindOfClass:[NGImap4Exception class]]) {
    fprintf(stderr, "%s", [[_exception description] cString]);
  }
  else {
    fprintf(stderr, "\n");
    return _exception;
  }
  fprintf(stderr, "\n");
  return nil;
}

- (NSArray *)_processUnseen:(NSArray *)result {
  if (profileDS) [self logWithFormat:@"process unseen ..."];
    
  if (self->oldUnseenMessages) { // this implies, the folder hasn't changed
      NSMutableSet *set = nil;
      
      set = [[NSMutableSet alloc] initWithArray:result];
      [set addObjectsFromArray:self->oldUnseenMessages];
      result = [[[set allObjects] retain] autorelease];
      [set release];
  }
  [self->oldUnseenMessages release]; self->oldUnseenMessages = nil;
  ASSIGN(self->oldUnseenMessages, result);
    
  if (profileDS) [self logWithFormat:@"process unseen: done."];
  return result;
}
- (NSArray *)_sortMessages:(NSArray *)result {
  NSArray *sortOrderings;

  if ((sortOrderings = [[self fetchSpecification] sortOrderings]) == nil)
    return result;
  
  if (profileDS) [self logWithFormat:@"sort messages ..."];
  result = [result sortedArrayUsingKeyOrderArray:sortOrderings];
  if (profileDS) [self logWithFormat:@"sort messages: done."];
  return result;
}

- (NSArray *)fetchMessages {
  EOQualifier *qualifier;
  NSArray     *result  = nil;

  if (profileDS) [self logWithFormat:@"fetchMessages: fetch ..."];
  
  qualifier = [[self fetchSpecification] qualifier];
  
  NS_DURING {
    if (![qualifier isImap4UnseenQualifier]) {
      [self->oldUnseenMessages release];
      self->oldUnseenMessages = nil;
    }
    
    if (profileDS) [self logWithFormat:@"fetchMessages:   exists&unseen ..."];
    self->oldExists = [self->folder exists];
    self->oldUnseen = [self->folder unseen];
    
    if (profileDS) [self logWithFormat:@"fetchMessages:   messages ..."];
    result = (qualifier == nil)
      ? [self->folder messages]
      : [self->folder messagesForQualifier:qualifier];
    if (profileDS) [self logWithFormat:@"fetchMessages:   messages done ..."];
  }
  NS_HANDLER {
    [[self handleImapException:localException] raise];
    result = [NSArray array];
  }
  NS_ENDHANDLER;
  
  if (profileDS) [self logWithFormat:@"fetchMessages:   ex handler done ..."];
  
  if ([qualifier isImap4UnseenQualifier])
    result = [self _processUnseen:result];
  
  result = [self _sortMessages:result];
  if (profileDS) [self logWithFormat:@"fetchMessages: done."];
  return result;
}

@end /* NGImap4DataSource */
