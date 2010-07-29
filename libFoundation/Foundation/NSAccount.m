/* 
   NSAccount.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#include <Foundation/common.h>
#include <Foundation/NSDictionary.h>

#include <sys/types.h>

#if HAVE_PWD_H
#  include <pwd.h>
#endif

#if HAVE_GRP_H
#  include <grp.h>
#endif

#ifdef HAVE_LIBC_H
#  include <libc.h>
#else
#  include <unistd.h>
#endif

#if HAVE_WINDOWS_H
#  include <windows.h>
#endif

#ifdef __MINGW32__
#  include <lmaccess.h>
#  include <lmapibuf.h>
#endif

#if HAVE_LM_H
#  include <lm.h>
#else
# if defined(__MINGW32__)
#  if !HAVE_USER_INFO_11 && 0
typedef struct _USER_INFO_11 {
    LPWSTR    usri11_name;
    LPWSTR    usri11_comment;
    LPWSTR    usri11_usr_comment;
    LPWSTR    usri11_full_name;
    DWORD     usri11_priv;
    DWORD     usri11_auth_flags;
    DWORD     usri11_password_age;
    LPWSTR    usri11_home_dir;
    LPWSTR    usri11_parms;
    DWORD     usri11_last_logon;
    DWORD     usri11_last_logoff;
    DWORD     usri11_bad_pw_count;
    DWORD     usri11_num_logons;
    LPWSTR    usri11_logon_server;
    DWORD     usri11_country_code;
    LPWSTR    usri11_workstations;
    DWORD     usri11_max_storage;
    DWORD     usri11_units_per_week;
    PBYTE     usri11_logon_hours;
    DWORD     usri11_code_page;
} USER_INFO_11;
#  endif
# endif
#endif

#ifdef __MINGW32__
struct passwd {
    const char *pw_name;
    int        pw_uid;
};
#endif

#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSLock.h>

#include "NSAccount.h"

extern NSRecursiveLock *libFoundationLock;

@implementation NSAccount

// Creating an account

+ currentAccount 
{
    [self subclassResponsibility:_cmd];
    return nil; 
}

+ accountWithName:(NSString*)name
{
    [self subclassResponsibility:_cmd];
    return nil; 
}

+ accountWithNumber:(unsigned int)number
{
    [self subclassResponsibility:_cmd];
    return nil; 
}

// Getting account information

- (NSString*)accountName
{
    [self subclassResponsibility:_cmd];
    return nil; 
}

- (unsigned)accountNumber
{
    [self subclassResponsibility:_cmd];
    return 0; 
}

// Copying Protocol

- (id)copy
{
    return RETAIN(self);
}

- (id)copyWithZone:(NSZone*)zone
{
    return RETAIN(self);
}

@end /* NSAccount */

/*
 *  User Account
 */

@implementation NSUserAccount

// Init & dealloc

#if defined(__MINGW32__)
- (id)initWithUserInfo11:(USER_INFO_11 *)_userInfo {
    self->name =
        RETAIN(NSWindowsWideStringToString(_userInfo->usri11_name));
    self->fullName =
        RETAIN(NSWindowsWideStringToString(_userInfo->usri11_full_name));

    self->homeDirectory =
        RETAIN(NSWindowsWideStringToString(_userInfo->usri11_home_dir));


    if ([self->homeDirectory length] == 0) {
        RELEASE(self->homeDirectory); self->homeDirectory = nil;
        self->homeDirectory =
            [[NSString alloc] initWithCString:getenv("HOME")];
    }
    
    return self;
}
#endif

#if defined(__MINGW32__)
- (id)initWithUserName:(const char *)_name homeDirectory:(const char *)_home
{
    self->name          = _name ? [[NSString alloc] initWithCString:_name] : @"";
    self->fullName      = [self->name retain];
    self->homeDirectory = _home ? [[NSString alloc] initWithCString:_home] : @"";
    self->userNumber    = 0;
    return self;
}
#endif

- (id)initWithPasswordStructure:(struct passwd*)ptr
{
    if (ptr == NULL) {
      fprintf(stderr, "%s: missing password structure ..\n",
              __PRETTY_FUNCTION__);
      RELEASE(self);
      return nil;
    }

    self->name =
        RETAIN([NSString stringWithCStringNoCopy:Strdup(ptr->pw_name)
                         freeWhenDone:YES]);
#ifndef __MINGW32__
    self->fullName =
        RETAIN([NSString stringWithCStringNoCopy:Strdup(ptr->pw_gecos)
                         freeWhenDone:YES]);
    self->homeDirectory =
        RETAIN([NSString stringWithCStringNoCopy:Strdup(ptr->pw_dir)
                         freeWhenDone:YES]);
#endif
    
    self->userNumber = ptr->pw_uid;

    return self;
}

- (void)dealloc
{
    RELEASE(self->name);
    RELEASE(self->fullName);
    RELEASE(self->homeDirectory);
    [super dealloc];
}

// Creating an account

static NSUserAccount* currentUserAccount = nil;

+ (void)initialize
{
    static BOOL initialized = NO;

    if (!initialized) {
	[libFoundationLock lock];

#ifndef __MINGW32__
	/* Initialize the group account global variable */
	[NSGroupAccount initialize];
#endif

#if defined(__MINGW32__)
    {
	char         n[60];
	DWORD        len = 60;
        WCHAR        wUserName[256];
        USER_INFO_11 *userInfo = NULL;

        /* get current user name */
	GetUserName(n, &len);

        /* convert current user name to UNICODE */
        MultiByteToWideChar(CP_ACP,    /* ANSI Code Page */
                            0,         /* no special conversion flags */
                            n,         /* ANSI string */
                            len,       /* length of ANSI string */
                            wUserName, /* destination buffer */
                            sizeof(wUserName) / sizeof(WCHAR) /* dest size */);

        /* retrieve user information, level 11 is available for current user */
        if (NetUserGetInfo(NULL,      /* localhost  */
                           wUserName, /* user name  */
                           11,        /* info level */
                           (void*)&userInfo)) {
            fprintf(stderr,
                    "ERROR: could not retrieve info for user '%s' !\n",
                    n);
            currentUserAccount = [[self alloc] init];
        }
        else {
            currentUserAccount = [[self alloc] initWithUserInfo11:userInfo];
        }

        /* release user info structure */
        if (userInfo) {
            NetApiBufferFree(userInfo);
            userInfo = NULL;
        }
    }
#elif HAVE_GETUID
    {
	struct passwd *ptr = getpwuid(getuid());
        
        if (ptr)
            currentUserAccount = [[self alloc] initWithPasswordStructure:ptr];
        else {
            fprintf(stderr,
                    "WARNING: libFoundation couldn't get passwd structure for "
                    "current user (id=%i) !\n", getuid());
            currentUserAccount = nil;
        }
    }
#else
#  error cannot find out current user account
#endif
	[libFoundationLock unlock];
	initialized = YES;
    }
}

+ (id)currentAccount 
{
    return currentUserAccount;
}

+ (id)accountWithName:(NSString *)aName
{
#if defined(__MINGW32__)
    return AUTORELEASE([[self alloc]
                              initWithUserName:[aName cString]
                              homeDirectory:NULL]);
#elif HAVE_GETPWNAM
    struct passwd *ptr;
    
    [libFoundationLock lock];
    ptr = getpwnam((char*)[aName cString]);
    [libFoundationLock unlock];
    return ptr
        ? AUTORELEASE([[self alloc] initWithPasswordStructure:ptr])
	: nil;
#else
    struct passwd pt;
    pt.pw_name = [aName cString];
    pt.pw_uid = 0;
    return AUTORELEASE([[self alloc] initWithPasswordStructure:&pt]);
#endif
}

+ accountWithNumber:(unsigned int)number
{
#if HAVE_GETPWUID
    struct passwd* ptr;

    [libFoundationLock lock];
    ptr = getpwuid(number);
    [libFoundationLock unlock];

    return ptr
        ? AUTORELEASE([[self alloc] initWithPasswordStructure:ptr])
	: nil;
#else
    return 0;
#endif
}

// accessors

- (NSString *)accountName {
    return self->name;
}
- (unsigned)accountNumber {
    return self->userNumber;
}
- (NSString *)fullName {
    return self->fullName;
}
- (NSString *)homeDirectory {
    return self->homeDirectory;
}

@end /* NSUserAccount */

/*
 *  Group Account
 */

@implementation NSGroupAccount

#ifdef __MINGW32__

+ (id)currentAccount 
{
    return nil;
}

+ (id)accountWithName:(NSString*)aName
{
    return nil;
}

+ (id)accountWithNumber:(unsigned int)number
{
    return nil;
}

- (NSArray *)members
{
    return nil;
}

#else /* __MINGW32__ */

// Init & dealloc

- (id)initWithGroupStructure:(struct group*)ptr
{
    int cnt;

    name = RETAIN([NSString stringWithCString:ptr->gr_name]);
    groupNumber = ptr->gr_gid;

    // count group members
    for (cnt = 0; ptr->gr_mem[cnt]; cnt++)
	;
    
    {
	NSString** array = Malloc (cnt * sizeof(id));
	int i;
	
	for (i = 0; i < cnt; i++)
	    array[i] = [NSString stringWithCString:ptr->gr_mem[i]];
	members = [[NSArray alloc] initWithObjects:array count:cnt];
        lfFree (array);
    }
    
    return self;
}

- (void)dealloc
{
    RELEASE(name);
    RELEASE(members);
    [super dealloc];
}

// Creating an account

static NSGroupAccount* currentGroupAccount = nil;

+ (void)initialize
{
    static BOOL initialized = NO;

    if (!initialized) {
	[libFoundationLock lock];
	currentGroupAccount = RETAIN([self accountWithNumber:getgid()]);
	[libFoundationLock unlock];
	initialized = YES;
    }
}

+ (id)currentAccount 
{
    return currentGroupAccount;
}

+ (id)accountWithName:(NSString*)aName
{
    struct group* ptr;

    [libFoundationLock lock];
    ptr = getgrnam((char*)[aName cString]);
    [libFoundationLock unlock];

    return ptr
        ? AUTORELEASE([[self alloc] initWithGroupStructure:ptr])
	: nil;
}

+ (id)accountWithNumber:(unsigned int)number
{
    struct group* ptr;

    [libFoundationLock lock];
    ptr = getgrgid(number);
    [libFoundationLock unlock];

    return ptr
        ? AUTORELEASE([[self alloc] initWithGroupStructure:ptr])
	: nil;
}

- (NSString*)accountName {
    return self->name;
}
- (unsigned)accountNumber {
    return self->groupNumber;
}
- (NSArray*)members {
    return self->members;
}

#endif /* __MINGW32__ */

@end /* NSGroupAccount */
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

