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

#include "NGImap4FolderMailRegistry.h"
#include "NGImap4Message.h"
#include "imCommon.h"

@interface NGImap4Message(UsedPrivates)
- (NSString *)_addFlagNotificationName;
- (NSString *)_removeFlagNotificationName;
- (void)_addFlag:(NSNotification *)_n;
- (void)_removeFlag:(NSNotification *)_n;
@end

typedef enum {
  NGImap4_FlagAdd = 0,
  NGImap4_FlagDel = 1
} NGImap4FlagOp;

@implementation NGImap4FolderMailRegistry

static BOOL useObjectObserver = NO;
static BOOL logFlagPostings   = NO;
static BOOL useFlatArray      = YES;
static int  initialCapacity   = 100;
static NSNotificationCenter *nc = nil;
static Class DictClass = Nil;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  BOOL useOwnNC  = YES;
  BOOL disableNC = NO;
  
  useFlatArray = [ud boolForKey:@"ImapUseOldMailNotificationSystem"]?NO:YES;
  if (useFlatArray) {
    disableNC = YES;
    NSLog(@"Note: using flat-array message notifications!");
  }
  
  if (disableNC) {
    nc = nil;
    if (!useFlatArray)
      NSLog(@"WARNING: NGImap4Message notifications disabled!");
  }
  else {
    nc = useOwnNC
      ? [[NSNotificationCenter alloc] init]
      : [[NSNotificationCenter defaultCenter] retain];
  }
  DictClass = [NSDictionary class];
}

- (void)dealloc {
  if (self->observers) free(self->observers);
  [super dealloc];
}

/* flat array */

- (void)_ensureArraySize {
  if (self->capacity > self->len)
    return;

  if (self->observers == NULL) {
    self->capacity  = initialCapacity;
    self->observers = calloc(self->capacity, sizeof(id));
  }
  else {
    self->capacity *= 2;
    self->observers = realloc(self->observers, (self->capacity * sizeof(id)));
  }
}

/* operations */

- (void)registerObject:(NGImap4Message *)_mail {
  if (_mail == nil)
    return;
  
  if (useFlatArray) {
    if (self->capacity <= self->len)
      [self _ensureArraySize];
    
    self->observers[self->len] = _mail;
    self->len++;
  }
  else {
    if (useObjectObserver) {
      [nc addObserver:_mail selector:@selector(_addFlag:)
	  name:@"NGImap4MessageAddFlag"
	  object:[_mail globalID]];
      [nc addObserver:_mail selector:@selector(_removeFlag:)
	  name:@"NGImap4MessageRemoveFlag"
	  object:[_mail globalID]];
    }
    else {
      [nc addObserver:_mail selector:@selector(_addFlag:)
	  name:[_mail _addFlagNotificationName]
	  object:nil];
      [nc addObserver:_mail selector:@selector(_removeFlag:)
	  name:[_mail _removeFlagNotificationName]
	  object:nil];
    }
  }
}

- (void)forgetObject:(NGImap4Message *)_mail {
  register signed int i;
    
  if (_mail == nil)
    return;

  if (!useFlatArray) {
    [nc removeObserver:_mail];
    return;
  }
  
  /* scan for index to be deleted ... */
  for (i = self->len - 1; i >= 0; i--) {
    if (self->observers[i] == _mail) {
      /* found */
      break;
    }
  }
    
  if (i >= 0) { /* found */
    self->observers[i] = self->observers[self->len - 1];
    self->len--;
  }
  else
    [self logWithFormat:@"did not find object to be removed!"];
}

/* notifications */

static NSString *keys[2] = { @"flag", nil };

- (void)postFlagChange:(NGImap4FlagOp)_op flag:(NSString *)_flag 
  inMessage:(NGImap4Message *)_msg 
{
  NSDictionary *ui;
  
  if (_flag == nil) return;
  if (_msg  == nil) return;
  
  if (logFlagPostings) {
    [self logWithFormat:@"%s flag '%@' msg %d (0x%p)", 
	    (_op == NGImap4_FlagAdd ? "add" : "del"), _flag, [_msg uid], _msg];
  }
  
  // TODO: pretty lame
  ui = [[DictClass alloc] initWithObjects:&_flag forKeys:keys count:1];
  
  if (useFlatArray) {
    register signed int i;
    register unsigned   suid;
    NSNotification *notification = nil;
    
    suid = [_msg uid];
    
    /* fullscan (duplicates are possible, both uid and id!) */
    for (i = self->len - 1; i >= 0; i--) {
      if (self->observers[i] != _msg) {
	if ([self->observers[i] uid] != suid)
	  // TODO: we might want to cache the selector
	  // TODO: we even might want to cache the uid in the array?
	  continue;
      }
      
      /* OK, either exact match or uid match */
      
      if (notification == nil) {
	NSString *n;

	n = (_op == NGImap4_FlagAdd
	     ? @"NGImap4MessageAddFlag" : @"NGImap4MessageRemoveFlag");
#if !LIB_FOUNDATION_LIBRARY
        notification = [NSNotification notificationWithName:n 
                                       object:_msg userInfo:ui];
#else
	notification = [[NSNotification alloc] initWithName:n
					       object:_msg
					       userInfo:ui];
#endif
      }
      
      if (logFlagPostings)
	[self logWithFormat:@"  post to 0x%p ...", self->observers[i]];
      
      if (_op == NGImap4_FlagAdd)
	[self->observers[i] _addFlag:notification];
      else
	[self->observers[i] _removeFlag:notification];

      if (logFlagPostings)
	[self logWithFormat:@"  done post to 0x%p.", self->observers[i]];
    }
    
#if LIB_FOUNDATION_LIBRARY
    if (notification)
      [notification release];
#endif
  }
  else if (useObjectObserver) {
    [nc postNotificationName:
	  (_op == NGImap4_FlagAdd
	   ? @"NGImap4MessageAddFlag" : @"NGImap4MessageRemoveFlag")
	object:[_msg globalID] 
	userInfo:ui];
  }
  else {
    [nc postNotificationName:
	  (_op == NGImap4_FlagAdd
	   ? [_msg _addFlagNotificationName] 
	   : [_msg _removeFlagNotificationName])
	object:nil userInfo:ui];
  }
  
  [ui release];
}

- (void)postFlagAdded:(NSString *)_flag inMessage:(NGImap4Message *)_msg {
  [self postFlagChange:NGImap4_FlagAdd flag:_flag inMessage:_msg];
}
- (void)postFlagRemoved:(NSString *)_flag inMessage:(NGImap4Message *)_msg {
  [self postFlagChange:NGImap4_FlagDel flag:_flag inMessage:_msg];
}

@end /* NGImap4FolderMailRegistry */
