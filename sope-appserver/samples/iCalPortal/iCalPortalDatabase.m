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

#include "iCalPortalDatabase.h"
#include "iCalPortalUser.h"
#include "common.h"

@interface NSString(Crypt)
- (NSString *)cryptString;
- (BOOL)compareWithCryptedString:(NSString *)_crypt;
@end

@implementation iCalPortalDatabase

- (id)initWithPath:(NSString *)_path {
  if ((self = [super init])) {
    BOOL isDir;
    
    self->fileManager = [[NSFileManager defaultManager] retain];
    self->rootPath    = [_path copy];
    
    if (![self->fileManager fileExistsAtPath:_path isDirectory:&isDir]) {
      [self logWithFormat:@"database path %@ does not exist ...", _path];
      [self release];
      return nil;
    }
    if (!isDir) {
      [self logWithFormat:@"database path %@ is not a directory ...", _path];
      [self release];
      return nil;
    }
  }
  return self;
}
- (id)init {
  return [self initWithPath:@"."];
}

- (void)dealloc {
  [self->fileManager release];
  [self->rootPath release];
  [super dealloc];
}

/* accessors */

- (NSFileManager *)fileManager {
  return self->fileManager;
}

/* name->path */

- (NSString *)pathForLogin:(NSString *)_login {
  static NSString *escapeChars[] = {
    @"/", @"_s_",
    @".", @"_p_",
    @"~", @"_t_",
    @"$", @"_d_",
    nil, nil
  };
  NSRange  r;
  NSString *p;
  int i;

  if ([self->rootPath length] < 4)
    return nil;
  if ([_login length] < 3)
    return nil;
  if ([_login rangeOfString:@" "].length > 0)
    return nil;
  if ([_login rangeOfString:@"\t"].length > 0)
    return nil;
  
  if ([_login length] > 63)
    _login = [_login substringToIndex:63];
  
  p = [[_login copy] autorelease];
  
  /* first quote quoting chars ;-) */
  r = [p rangeOfString:@"_"];
  if (r.length == 0) p = [p stringByReplacingString:@"_" withString:@"__"];
  
  /* now quote special chars */
  for (i = 0; escapeChars[i] != nil; i+=2) {
    r = [p rangeOfString:escapeChars[i]];
    if (r.length > 0) {
      p = [p stringByReplacingString:escapeChars[i] 
	     withString:escapeChars[i + 1]];
    }
  }
  
  return [self->rootPath stringByAppendingPathComponent:p];
}

/* operations */

- (iCalPortalUser *)userWithName:(NSString *)_name password:(NSString *)_pwd {
  /* return an authenicated user object */
  iCalPortalUser *user;
  
  if ([_pwd length] < 4) {
    [self logWithFormat:@"password smaller than minimum length ..."];
    return nil;
  }
  
  if ((user = [self userWithName:_name]) == nil)
    return nil;
  
  if (![user authenticate:_pwd]) {
    [self logWithFormat:@"got wrong password for user '%@' ...", _name];
    return nil;
  }
  
  return user;
}

- (iCalPortalUser *)userWithName:(NSString *)_name {
  /* return a user object */
  NSString       *p;
  iCalPortalUser *user;
  
  if ((p = [self pathForLogin:_name]) == nil) {
    [self logWithFormat:@"couldn't transform name '%@' into path ...", _name];
    return nil;
  }
  
  if (![self->fileManager fileExistsAtPath:p]) {
    [self logWithFormat:@"user '%@' does not exist (path=%@) !", _name, p];
    return nil;
  }

  user = [[iCalPortalUser alloc] initWithPath:p login:_name database:self];
  
  if (user == nil) {
    [self logWithFormat:@"couldn't allocate object for user '%@' ...", _name];
    return nil;
  }
  
  return [user autorelease];
}

- (BOOL)createUser:(NSString *)_login
  info:(NSDictionary *)_userInfo
  password:(NSString *)_pwd
{
  NSString *p;
  NSMutableDictionary *ui;
  
  if ([_userInfo count] < 3) {
    [self debugWithFormat:@"invalid userinfo: %@", _userInfo];
    return NO;
  }
  if ([_pwd length] < 6) {
    [self debugWithFormat:@"got invalid passwrd ..."];
    return NO;
  }
  
  ui = [_userInfo mutableCopy];

  if ((p = [self pathForLogin:_login]) == nil) {
    [self logWithFormat:@"couldn't transform name '%@' into path ...", _login];
    return NO;
  }

  [ui setObject:[_pwd cryptString] forKey:@"cryptedPassword"];
  
  if (![self->fileManager createDirectoryAtPath:p attributes:nil]) {
    [self logWithFormat:@"couldn't create user directory: '%@'.", p];
    return NO;
  }
  
  [ui writeToFile:[p stringByAppendingPathComponent:@".account.plist"]
      atomically:NO];
  [ui release];
  
  return YES;
}

- (BOOL)isLoginNameValid:(NSString *)_name {
  return [self pathForLogin:_name] == nil ? NO : YES;
}

- (BOOL)isLoginNameUsed:(NSString *)_name {
  NSString *p;
  
  if ((p = [self pathForLogin:_name]) == nil)
    return YES;
  
  if ([self->fileManager fileExistsAtPath:p])
    return YES;
  
  return NO;
}

- (BOOL)isPasswordValid:(NSString *)_pwd {
  if ([_pwd length] < 6)  return NO;
  if ([_pwd length] > 16) return NO;
  return YES;
}

@end /* iCalPortalDatabase */

#include <unistd.h>
#if !defined(__APPLE__)
#include <crypt.h>
#endif

@implementation NSString(Crypt)

static void _makeSalt(unsigned char *s) {
  int           i, timeInt;
  unsigned char c;    
  
  timeInt = (int)time(0);
  srand(timeInt);
  
  for (i = 0; i < 2; i++) {
    do {
      c = 46 + (rand() % 76);
    }
    while (((c > 57) && (c < 65)) || ((c > 90) && (c < 97)));
    
    s[i] = c;
  }
}

- (NSString *)cryptString {
  unsigned char *s;
  unsigned char salt[4] = { 0,0,0,0 };
  
  _makeSalt(salt);
  s = (void*)[self cString];
  s = crypt(s, salt);
  return [[[NSString alloc] initWithCString:s] autorelease];
}

- (BOOL)compareWithCryptedString:(NSString *)_crypt {
  unsigned char *s, *cs;
  
  if ([_crypt length] < 2) 
    /* not a valid crypt string ... */
    return NO;
  if ((cs = (unsigned char *)[_crypt cString]) == NULL)
    return NO;
  if (strlen(cs) < 2)
    return NO;
  
  s = (unsigned char *)[self cString];
  s = crypt(s, cs);
  return strcmp(s, cs) == 0 ? YES : NO;
}

@end /* NSString(Crypt) */
