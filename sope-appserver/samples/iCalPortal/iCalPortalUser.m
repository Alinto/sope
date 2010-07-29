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

#include "iCalPortalUser.h"
#include "iCalPortalDatabase.h"
#include "iCalPortalCalendar.h"
#include "common.h"

@implementation iCalPortalUser

- (id)initWithDatabase:(iCalPortalDatabase *)_db {
  if (_db == nil) {
    [self release];
    return nil;
  }
  if ((self = [super init])) {
    self->database = [_db retain];

    if ((self->fileManager = [[_db fileManager] retain]) == nil) {
      [self release];
      return nil;
    }
  }
  return self;
}

- (id)initWithPath:(NSString *)_path
  login:(NSString *)_login
  database:(iCalPortalDatabase *)_db;
{
  if ((self = [self initWithDatabase:_db])) {
    self->path  = [_path copy];
    self->login = [_login copy];

    if (self->path) {
      if (![self read]) {
	[self release];
	return nil;
      }
    }
  }
  return self;
}

- (id)init {
  return [self initWithDatabase:nil];
}

- (void)dealloc {
  [self->firstName    release];
  [self->lastName     release];
  [self->street       release];
  [self->city         release];
  [self->email        release];
  [self->address      release];
  [self->country      release];
  [self->phone        release];
  [self->state        release];
  [self->zip          release];
  [self->wantIcalNews   release];
  [self->wantSkyrixNews release];
  
  [self->login       release];
  [self->fileManager release];
  [self->database    release];
  [self->path        release];
  [super dealloc];
}

/* accessors */

- (iCalPortalDatabase *)database {
  return self->database;
}

- (void)setFirstName:(NSString *)_value {
  ASSIGN(self->firstName, _value);
}
- (NSString *)firstName {
  return self->firstName;
}

- (void)setLastName:(NSString *)_value {
  ASSIGN(self->lastName, _value);
}
- (NSString *)lastName {
  return self->lastName;
}

- (void)setStreet:(NSString *)_value {
  ASSIGN(self->street, _value);
}
- (NSString *)street {
  return self->street;
}

- (void)setCity:(NSString *)_value {
  ASSIGN(self->city, _value);
}
- (NSString *)city {
  return self->city;
}

- (void)setEmail:(NSString *)_value {
  ASSIGN(self->email, _value);
}
- (NSString *)email {
  return self->email;
}

- (void)setLogin:(NSString *)_login {
  /* do not allow login change via KVC ! ... */
}
- (NSString *)login {
  return self->login;
}

- (void)setAddress:(NSString *)_value {
  ASSIGN(self->address, _value);
}
- (NSString *)address {
  return self->address;
}
- (void)setCountry:(NSString *)_value {
  ASSIGN(self->country, _value);
}
- (NSString *)country {
  return self->country;
}
- (void)setPhone:(NSString *)_value {
  ASSIGN(self->phone, _value);
}
- (NSString *)phone {
  return self->phone;
}
- (void)setState:(NSString *)_value {
  ASSIGN(self->state, _value);
}
- (NSString *)state {
  return self->state;
}
- (void)setZip:(NSString *)_value {
  ASSIGN(self->zip, _value);
}
- (NSString *)zip {
  return self->zip;
}

- (void)setWantIcalNews:(NSString *)_value {
  ASSIGN(self->wantIcalNews, _value);
}
- (NSString *)wantIcalNews {
  return self->wantIcalNews;
}
- (void)setWantSkyrixNews:(NSString *)_value {
  ASSIGN(self->wantSkyrixNews, _value);
}
- (NSString *)wantSkyrixNews {
  return self->wantSkyrixNews;
}

/* do not store password in process ! ... */

- (void)setPassword:(NSString *)_value {
}
- (NSString *)password {
  return nil;
}
- (void)setCryptedPassword:(NSString *)_value {
}
- (NSString *)cryptedPassword {
  return nil;
}

/* load/store */

- (NSDictionary *)accountDictionary {
  NSDictionary *d;
  NSString     *p;
  
  if ([self->path length] < 4) {
    [self logWithFormat:@"tried to read an account which has no path ..."];
    return nil;
  }
  
  p = [self->path stringByAppendingPathComponent:@".account.plist"];
  
  if ((d = [NSDictionary dictionaryWithContentsOfFile:p]) == nil) {
    [self logWithFormat:@"couldn't load dictionary of account (%@) ...", p];
    return nil;
  }
  
  return d;
}

- (BOOL)read {
  NSDictionary *d;
  
  if ((d = [self accountDictionary]) == nil)
    return NO;
  
  [self takeValuesFromDictionary:d];
  return YES;
}

- (BOOL)write {
  return NO;
}

/* password checking */

- (BOOL)authenticate:(NSString *)_pwd {
  NSDictionary *d;
  NSString *tmp;
  
  if ([_pwd length] < 4) 
    return NO;
  
  if ((d = [self accountDictionary]) == nil)
    return NO;
  
  if ((tmp = [d objectForKey:@"cryptedPassword"]))
    return [_pwd compareWithCryptedString:tmp];
  
  if ((tmp = [d objectForKey:@"password"])) {
    if ([tmp isEqualToString:_pwd]) {
      [self logWithFormat:@"authenticated account."];
      return YES;
    }
    [self logWithFormat:@"got invalid password for account"];
    return NO;
  }
  
  return NO;
}

/* calendars */

- (BOOL)containsUnsafeChars:(NSString *)_path {
  /* check for dangerous stuff ... */
  NSRange r;

  if ([_path hasPrefix:@"."]) return YES;
  
  r = [_path rangeOfString:@".."];
  if (r.length > 0) return YES;
  r = [_path rangeOfString:@"/"];
  if (r.length > 0) return YES;
  r = [_path rangeOfString:@"~"];
  if (r.length > 0) return YES;
  r = [_path rangeOfString:@"\\"];
  if (r.length > 0) return YES;

  return NO;
}

- (NSString *)cleanupCalendarPath:(NSString *)_path {
  static NSArray *validExts = nil;
  NSString *calName;
  NSString *ext;
  
  if (validExts == nil) {
    validExts = [[NSArray alloc] initWithObjects:
				   @"ics", @"vfb", @"ifb",
				   @"ical", @"cal", nil];
  }
  
  if ((calName = [_path lastPathComponent]) == nil)
    return nil;
  
  ext = [calName pathExtension]; 
  
  if ([ext length] == 0) {
    calName = [calName stringByAppendingPathComponent:@"ics"];
  }
  else if (![validExts containsObject:ext]) {
    [self logWithFormat:@"invalid calendar extension '%@': %@", ext, _path];
    return nil;
  }
  
  if ([self containsUnsafeChars:calName])
    return nil;
  
  return [self->path stringByAppendingPathComponent:calName];
}

- (NSException *)invalidPathException:(NSString *)_path {
  return [NSException exceptionWithName:@"InvalidCalendarPath"
		      reason:@"got an invalid calendar path ..."
		      userInfo:nil];
}

- (iCalPortalCalendar *)calendarAtPath:(NSString *)_path {
  NSString *calpath;
  BOOL     isDir;
  iCalPortalCalendar *cal;
  
  if ((calpath = [self cleanupCalendarPath:_path]) == nil)
    return nil;
  
  if (![self->fileManager fileExistsAtPath:calpath isDirectory:&isDir]) {
    [self debugWithFormat:@"  cal '%@' does not exist ...", _path];
    return nil;
  }
  if (isDir) {
    [self logWithFormat:@"  calpath is a directory: %@ !", calpath];
    return nil;
  }
  
  cal = [[iCalPortalCalendar alloc] initWithUser:self path:calpath];
  if (cal == nil) return nil;
  
  return [cal autorelease];
}
- (EODataSource *)dataSourceAtPath:(NSString *)_path {
  iCalPortalCalendar *cal;
  
  if ((cal = [self calendarAtPath:_path]) == nil)
    return nil;
  return [cal dataSource];
}

- (NSException *)deleteCalendarWithPath:(NSString *)_path {
  NSString *calpath;
  BOOL isDir;
  
  if ((calpath = [self cleanupCalendarPath:_path]) == nil)
    return [self invalidPathException:_path];
  
  [self debugWithFormat:@"delete calendar: %@", calpath];
  
  if (![self->fileManager fileExistsAtPath:calpath isDirectory:&isDir]) {
    [self debugWithFormat:@"  cal does not exist ..."];
    return nil;
  }
  if (isDir) {
    [self logWithFormat:@"  calpath to be deleted is a directory: %@ !",
	    calpath];
    return nil;
  }
  
  /* go on, delete ... */
  if (![self->fileManager removeFileAtPath:calpath handler:nil]) {
    [self logWithFormat:@"  failed to delete calendar %@", path];
    return [NSException exceptionWithName:@"DeleteError"
			reason:@"reason unknown"
			userInfo:nil];
  }
  
  return nil;
}

- (NSException *)writeICalendarData:(NSData *)_data toCalendar:(NSString *)_path{
  NSString *calpath;
  
  if ((calpath = [self cleanupCalendarPath:_path]) == nil)
    return [self invalidPathException:_path];
  
  [self debugWithFormat:@"upload calendar data: %@, size %i", 
	  calpath, [_data length]];

  if (![_data writeToFile:calpath atomically:YES]) {
    [self logWithFormat:@"  failed to write calendar of size %i to path %@",
 	    [_data length], calpath];
    return [NSException exceptionWithName:@"WriteError"
			reason:@"reason unknown"
			userInfo:nil];
  }
  
  return nil;
}

- (NSArray *)calendarNames {
  NSAutoreleasePool *pool;
  NSEnumerator      *e;
  NSString          *filename;
  NSMutableArray    *md = nil;
  
  e = [[self->fileManager directoryContentsAtPath:self->path]
	objectEnumerator];

  pool = [[NSAutoreleasePool alloc] init];
  
  while ((filename = [e nextObject])) {
    iCalPortalCalendar *cal;
    
    if ([self containsUnsafeChars:filename]) continue;
    
    if ((cal = [self calendarAtPath:filename]) == nil)
      continue;
    
    if (md == nil)
      md = [[NSMutableArray alloc] initWithCapacity:16];
    
    [md addObject:filename];
  }
  
  [md sortUsingSelector:@selector(compare:)];
  [pool release];
  
  return [md autorelease];
}
- (NSDictionary *)calendars {
  NSEnumerator        *e;
  NSString            *filename;
  NSMutableDictionary *md = nil;
  
  e = [[self->fileManager directoryContentsAtPath:self->path]
	objectEnumerator];
  
  while ((filename = [e nextObject])) {
    iCalPortalCalendar *cal;
    
    if ([self containsUnsafeChars:filename]) continue;
    
    if ((cal = [self calendarAtPath:filename]) == nil)
      continue;
    
    if (md == nil)
      md = [[NSMutableDictionary alloc] init];

    [md setObject:cal forKey:filename];
  }
  return md;
}

/* logging */

- (BOOL)isDebuggingEnabled {
  return YES;
}
- (NSString *)loggingPrefix {
  return [NSString stringWithFormat:@"[user:%@]", 
		     self->login ? self->login : @"<new>"];
}

- (NSString *)description {
  NSMutableString *s;
  
  s = [NSMutableString stringWithCapacity:128];
  [s appendFormat:@"<0x%p[%@]: ", self, NSStringFromClass([self class])];
  [s appendFormat:@" login=%@", self->login];
  [s appendFormat:@" path=%@",  self->path];
  [s appendString:@">"];
  
  return s;
}

@end /* iCalPortalUser */
