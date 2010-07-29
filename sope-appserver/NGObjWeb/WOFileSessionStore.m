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

#include <NGObjWeb/WOSessionStore.h>

/*
  This store keeps all sessions as archived files inside of a directory.
  It provides session fail-over, but restoring/saving a session takes some
  time ...

  Storage format:
    session-directory/
      sessionid.session
      sessionid.session

  The session-directory can be selected using the WOFileSessionPath default.

  Note: it doesn't provide session distribution between instances, since the
  store doesn't lock the session files.
*/

@class NSString, NSFileManager;

@interface WOFileSessionStore : WOSessionStore
{
  NSFileManager *fileManager;
  NSString      *snPath;
}
@end

#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOSession.h>
#include <NGObjWeb/WOApplication.h>
#include "common.h"

@implementation WOFileSessionStore

static BOOL logExpire = YES;

+ (int)version {
  return [super version] + 0;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)initWithSessionPath:(NSString *)_path {
  NSFileManager *fm;
  BOOL isDir;
  
  if ([_path length] == 0) {
    [self release];
    return nil;
  }
  
  fm = [NSFileManager defaultManager];
  if (![fm fileExistsAtPath:_path isDirectory:&isDir]) {
    if (![fm createDirectoryAtPath:_path attributes:nil]) {
      NSLog(@"%s: could not create a directory at path: %@",
            __PRETTY_FUNCTION__, _path);
      [self release];
      return nil;
    }
  }
  else if (!isDir) {
    NSLog(@"%s: not a directory path: %@", __PRETTY_FUNCTION__, _path);
    [self release];
    return nil;
  }
  
  if ((self = [super init])) {
    self->snPath = [_path copy];
    self->fileManager = [fm retain];
  }
  return self;
}
- (id)init {
  NSString *p;
  p = [[NSUserDefaults standardUserDefaults]
	stringForKey:@"WOFileSessionPath"];
  return [self initWithSessionPath:p];
}

- (void)dealloc {
  [self->fileManager release];
  [self->snPath      release];
  [super dealloc];
}

/* accessors */

- (int)activeSessionsCount {
  return 0;
  //return [[self->fileManager directoryContentsAtPath:self->snPath] count];
}

/* store */

- (NSString *)pathForSessionID:(NSString *)_sid {
  return [self->snPath stringByAppendingPathComponent:_sid];
}

- (void)saveSessionForContext:(WOContext *)_context {
  WOSession *sn;
  NSString *snp;
  
  if (![_context hasSession])
    return;
  
  sn  = [_context session];
  snp = [self pathForSessionID:[sn sessionID]];
  
  if ([sn isTerminating]) {
    sn = RETAIN(sn);
        
    // TODO: NOT IMPLEMENTED (serialized-session termination)
    //NSMapRemove(self->idToSession, [sn sessionID]);
    
    NSLog(@"session %@ terminated at %@ ..",
          [sn sessionID], [NSCalendarDate calendarDate]);
    [sn release];
  }
  else {
    NSData *data;
    
    data = [NSArchiver archivedDataWithRootObject:sn];
    
    if (data) {
      if (![data writeToFile:snp atomically:YES]) {
        [self logWithFormat:
		@"could not write data of session %@ to file: '%@'", sn, snp];
      }
    }
    else
      [self logWithFormat:@"could not archive session: '%@'", sn];
  }
}

- (id)restoreSessionWithID:(NSString *)_sid request:(WORequest *)_request {
  NSAutoreleasePool *pool;
  NSString *snp;
  WOSession *session = nil;

  if ([_sid length] == 0)
    return nil;
  
  if (![_sid isKindOfClass:[NSString class]]) {
    [self warnWithFormat:@"%s: got invalid session id (expected string !): %@",
            __PRETTY_FUNCTION__, _sid];
    return nil;
  }
  
  if ([_sid isEqualToString:@"expired"])
    return nil;
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    snp = [self pathForSessionID:_sid];
    
    if ([self->fileManager fileExistsAtPath:snp]) {
      NSData *data;
      
      if ((data = [self->fileManager contentsAtPath:snp])) {
        session = [NSUnarchiver unarchiveObjectWithData:data];
        // NSLog(@"unarchived session: %@", session);
        
        if (![session isKindOfClass:[WOSession class]]) {
          NSLog(@"object unarchived from %@ isn't a WOSession: %@ ...",
                snp, session);
          session = nil;
        }
      }
      else {
        [self logWithFormat:@"could not read sn file: '%@'", snp];
        session = nil;
      }
    }
    else {
      [self logWithFormat:@"session file does not exist: '%@'", snp];
      session = nil;
    }

    [session retain];
  }
  [pool release];
  
  if (logExpire) {
    if (session == nil)
      [self logWithFormat:@"session with id %@ expired.", _sid];
  }
  
  return [session autorelease];
}

/* termination */

- (void)sessionExpired:(NSString *)_sessionID {
  [self->lock lock];
  {
    // TODO: NOT IMPLEMENTED (serialized session expiration)
    NSLog(@"%@ expired.", _sessionID);
    // NSMapRemove(self->idToSession, _sessionID);
  }
  [self->lock unlock];
}

- (void)sessionTerminated:(WOSession *)_session {
  _session = RETAIN(_session);
  [self->lock lock];
  {
    // TODO: NOT IMPLEMENTED (serialized session termination)
    NSLog(@"%@ terminated.", [_session sessionID]);
    // NSMapRemove(self->idToSession, [_session sessionID]);
  }
  [self->lock unlock];
  RELEASE(_session);
  
  [[WOApplication application]
                  logWithFormat:
                    @"WOFileSessionStore: session %@ terminated.",
                    [_session sessionID]];
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@[0x%p]: path=%@>",
                     NSStringFromClass([self class]), self, self->snPath];
}

@end /* WOFileSessionStore */
