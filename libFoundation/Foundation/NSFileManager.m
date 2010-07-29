/* 
   NSFileManager.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
	   Ovidiu Predescu <ovidiu@bx.logicnet.ro>
           Helge Hess <helge@mdlink.de>

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
#include <objc/objc.h>

#include <stdio.h>

/* determine directory reading files */

#if defined(HAVE_DIRENT_H)
#  include <dirent.h>
#elif defined(HAVE_SYS_DIR_H)
#  include <sys/dir.h>
#elif defined(HAVE_SYS_NDIR_H)
#  include <sys/ndir.h>
#elif defined(HAVE_NDIR_H)
#  include <ndir.h>
#elif defined(HAVE_DIR_H)
#  include <dir.h>
#endif

#if defined(HAVE_WINDOWS_H)
#  include <windows.h>
#endif

#if !defined(_POSIX_VERSION)
#  if defined(NeXT)
#    define DIR_enum_item struct direct
#  endif
#endif

#if !defined(DIR_enum_item)
#  define DIR_enum_item struct dirent
#endif

#define DIR_enum_state DIR

/* determine filesystem max path length */

#if defined(_POSIX_VERSION) || defined(__WIN32__)
# include <limits.h>			/* for PATH_MAX */
# if defined(__MINGW32__)
#   include <sys/utime.h>
# else
#   include <utime.h>
# endif
#else
# if HAVE_SYS_PARAM_H
#  include <sys/param.h>		/* for MAXPATHLEN */
# endif
#endif

#ifndef PATH_MAX
# ifdef _POSIX_VERSION
#  define PATH_MAX _POSIX_PATH_MAX
# else
#  ifdef MAXPATHLEN
#   define PATH_MAX MAXPATHLEN
#  else
#   define PATH_MAX 1024
#  endif
# endif
#endif

/* determine if we have statfs struct and function */

#ifdef HAVE_SYS_STATFS_H
# include <sys/statfs.h>
#endif

#ifdef HAVE_SYS_STATVFS_H
# include <sys/statvfs.h>
#endif

#ifdef HAVE_SYS_VFS_H
# include <sys/vfs.h>
#endif

#if HAVE_SYS_FILE_H
#include <sys/file.h>
#endif

#if HAVE_SYS_STAT_H
# include <sys/stat.h>
#endif

#include <fcntl.h>

#if HAVE_UTIME_H
# include <utime.h>
#endif

/* include usual headers */

#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSString.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSException.h>
#include <Foundation/exceptions/GeneralExceptions.h>

@interface NSFileManager (PrivateMethods)

/* Copies the contents of source file to destination file. Assumes source
   and destination are regular files or symbolic links. */
- (BOOL)_copyFile:(NSString*)source toFile:(NSString*)destination
  handler:handler;

/* Recursively copies the contents of source directory to destination. */
- (BOOL)_copyPath:(NSString*)source toPath:(NSString*)destination
  handler:handler;

@end /* NSFileManager (PrivateMethods) */


/*
 * NSFileManager implementation
 */

@implementation NSFileManager

// Getting the default manager

static BOOL isMultithreaded = NO;
static NSFileManager* defaultManager = nil;

+ (void)initialize
{
    static BOOL initialized = NO;

    if (!initialized) {
	defaultManager = [[self alloc] init];
	[[NSNotificationCenter defaultCenter]
	    addObserver:self
	    selector:@selector(taskNowMultiThreaded:)
	    name:NSWillBecomeMultiThreadedNotification
	    object:nil];
	initialized = YES;
    }
}

+ (void)taskNowMultiThreaded:notification
{
    NSThread* currentThread = [NSThread currentThread];

    [[currentThread threadDictionary]
	setObject:AUTORELEASE(defaultManager) forKey:@"DefaultNSFileManager"];
    defaultManager = nil;
    isMultithreaded = YES;
}

extern NSRecursiveLock* libFoundationLock;

+ (NSFileManager*)defaultManager
{
    if (isMultithreaded) {
	NSThread* currentThread = [NSThread currentThread];
	id manager;

	[libFoundationLock lock];
        {
            manager = [[currentThread threadDictionary]
                                      objectForKey:@"DefaultNSFileManager"];
            if (!manager) {
                manager = AUTORELEASE([[self alloc] init]);
                [[currentThread threadDictionary]
                                setObject:manager
                                forKey:@"DefaultNSFileManager"];
            }
        }
	[libFoundationLock unlock];

	return manager;
    } 
    else
	return defaultManager;
}

// Directory operations

- (BOOL)changeCurrentDirectoryPath:(NSString*)path
{
    const char* cpath = [self fileSystemRepresentationWithPath:path];

#if defined(__MINGW32__)
    return SetCurrentDirectory(cpath) == TRUE ? YES : NO;
#else
    return (chdir(cpath) == 0);
#endif
}

#if defined(__MINGW32__)
- (BOOL)createDirectoryAtPath:(NSString*)path
  attributes:(NSDictionary*)attributes
{
    NSEnumerator *paths = [[path pathComponents] objectEnumerator];
    NSString     *subPath;
    NSString     *completePath = nil;

    while ((subPath = [paths nextObject])) {
        BOOL isDir = NO;

        completePath = (completePath == nil)
            ? subPath
            : [completePath stringByAppendingPathComponent:subPath];

        if ([self fileExistsAtPath:completePath isDirectory:&isDir]) {
            if (!isDir) {
                fprintf(stderr,
                        "WARNING: during creation of directory %s:"
                        " sub path %s exists, but is not a directory !",
                      [path cString], [completePath cString]);
            }
        }
        else {
            const char *cpath;
            
            cpath = [self fileSystemRepresentationWithPath:completePath];
            if (CreateDirectory(cpath, NULL) == FALSE)
                // creation failed
                return NO;
        }
    }

    // change attributes of last directory
    return [self changeFileAttributes:attributes
                 atPath:path];
}

#else

- (BOOL)createDirectoryAtPath:(NSString*)path
  attributes:(NSDictionary*)attributes
{
    const char* cpath;
    char        dirpath[PATH_MAX+1];
    struct stat statbuf;
    int         len, cur;
    
    cpath = [self fileSystemRepresentationWithPath:path];
    len = Strlen(cpath);
    if (len > PATH_MAX)
	// name too long
	return NO;
    
    if (Strcmp(cpath, "/") == 0 || len == 0)
	// cannot use "/" or "" as a new dir path
	return NO;
    
    strcpy(dirpath, cpath);
    dirpath[len] = '\0';
    if (dirpath[len-1] == '/')
	dirpath[len-1] = '\0';
    cur = 0;
    
    do {
	// find next path separator
	while (dirpath[cur] != '/' && cur < len)
	    cur++;

	// if first char is '/' then again; (cur == len) -> last component
	if (cur == 0) {
	    cur++;
	    continue;
	}
	// check if path from 0 to cur is valid
	dirpath[cur] = '\0';
	if (stat(dirpath, &statbuf) == 0) {
	    if (cur == len)
		return NO; // already existing last path
	}
	else {
	    // make new directory
#if MKDIR_HAS_TWO_ARGS || defined(__CYGWIN32__)
	    if (mkdir(dirpath, 0777) != 0)
#else
	    if (mkdir(dirpath) != 0)
#endif
		return NO; // could not create component
	    // if last directory and attributes then change
	    if (cur == len && attributes)
		return [self changeFileAttributes:attributes 
		    atPath:[self stringWithFileSystemRepresentation:dirpath
			length:cur]];
	}
	dirpath[cur] = '/';
	cur++;
    } while (cur < len);
    
    return YES;
}
#endif /* __MINGW32__ */

- (NSString*)currentDirectoryPath
{
#if defined(__MINGW32__)
    unsigned char *buf = objc_atomic_malloc(2048);
    DWORD         len = GetCurrentDirectory(2046, buf);

    if (len > 2046) {
        buf = objc_realloc(buf, len + 2);
        len = GetCurrentDirectory(len, buf);
    }
    if (len == 0) return nil;
    self = [NSString stringWithCString:buf length:len];
    objc_free(buf);
    return self;
#else
    char path[PATH_MAX];
#if defined(HAVE_GETCWD)
    if (getcwd(path, PATH_MAX-1) == NULL)
	return nil;
#else
    if (getwd(path) == NULL)
	return nil;
#endif /* HAVE_GETCWD */
    return [self stringWithFileSystemRepresentation:path length:Strlen(path)];
#endif /* __MINGW32__ */
}

// File operations

- (BOOL)copyPath:(NSString*)source toPath:(NSString*)destination
  handler:handler
{
    BOOL         sourceIsDir;
    NSDictionary *attributes;

    if (![self fileExistsAtPath:source isDirectory:&sourceIsDir])
        // source must exist
	return NO;

    if ([self fileExistsAtPath:destination])
        // destination must not exist
	return NO;

#if defined(__MINGW32__)
    if (!CopyFile([self fileSystemRepresentationWithPath:source],
                  [self fileSystemRepresentationWithPath:destination],
                  FALSE /* overwrite if dest exists */)) {
        if (handler) {
            NSDictionary *errorInfo
                = [NSDictionary dictionaryWithObjectsAndKeys:
                                source,              @"Path",
                                destination,         @"ToPath",
                                @"cannot copy file", @"Error",
                                nil];
            if ([handler fileManager:self shouldProceedAfterError:errorInfo])
                return YES;
        }
        return NO;
    }
    return YES;
#else
    attributes = [self fileAttributesAtPath:source traverseLink:NO];

    if (sourceIsDir) {
	/* If destination directory is a descendant of source directory copying
	    isn't possible. */
	if ([[destination stringByAppendingString:@"/"]
                          hasPrefix:[source stringByAppendingString:@"/"]])
	    return NO;

	[handler fileManager:self willProcessPath:destination];
	if (![self createDirectoryAtPath:destination attributes:attributes]) {
	    if (handler) {
		NSDictionary* errorInfo
		    = [NSDictionary dictionaryWithObjectsAndKeys:
			destination,                @"Path",
			@"cannot create directory", @"Error",
			nil];
		return [handler fileManager:self
				shouldProceedAfterError:errorInfo];
	    }
	    else
		return NO;
	}
    }

    if (sourceIsDir) {
	if (![self _copyPath:source toPath:destination handler:handler])
	    return NO;
	else {
	    [self changeFileAttributes:attributes atPath:destination];
	    return YES;
	}
    }
    else {
	[handler fileManager:self willProcessPath:source];
	if (![self _copyFile:source toFile:destination handler:handler])
	    return NO;
	else {
	    [self changeFileAttributes:attributes atPath:destination];
	    return YES;
	}
    }
    return NO;
#endif
}

- (BOOL)movePath:(NSString*)source toPath:(NSString*)destination 
  handler:(id)handler
{
    BOOL       sourceIsDir;
    const char *sourcePath;
    const char *destPath;
#if !defined(__MINGW32__)
    NSString* destinationParent;
    unsigned int sourceDevice, destinationDevice;
#endif

    sourcePath = [self fileSystemRepresentationWithPath:source];
    destPath   = [self fileSystemRepresentationWithPath:destination];
    
    if (![self fileExistsAtPath:source isDirectory:&sourceIsDir])
        // source does not exist
	return NO;

    if ([self fileExistsAtPath:destination])
        // destination does already exist
	return NO;

#if defined(__MINGW32__)
    /*
      Special handling for directories is required !
      (See MoveFile on msdn)
    */
    if (!MoveFile(sourcePath, destPath)) {
        if (handler) {
            NSDictionary *errorInfo
                = [NSDictionary dictionaryWithObjectsAndKeys:
                                source,              @"Path",
                                destination,         @"ToPath",
                                @"cannot move file", @"Error",
                                nil];
            if ([handler fileManager:self shouldProceedAfterError:errorInfo])
                return YES;
        }
        return NO;
    }
    return YES;
#else
    /* Check to see if the source and destination's parent are on the same
       physical device so we can perform a rename syscall directly. */
    sourceDevice = [[[self fileSystemAttributesAtPath:source]
			    objectForKey:NSFileSystemNumber]
			    unsignedIntValue];
    destinationParent = [destination stringByDeletingLastPathComponent];
    if ([destinationParent isEqual:@""])
	destinationParent = @".";
    destinationDevice
	= [[[self fileSystemAttributesAtPath:destinationParent]
		  objectForKey:NSFileSystemNumber]
		  unsignedIntValue];

    if (sourceDevice != destinationDevice) {
	/* If destination directory is a descendant of source directory moving
	    isn't possible. */
	if (sourceIsDir && [[destination stringByAppendingString:@"/"]
			    hasPrefix:[source stringByAppendingString:@"/"]])
	    return NO;

	if ([self copyPath:source toPath:destination handler:handler]) {
	    NSDictionary* attributes;

	    attributes = [self fileAttributesAtPath:source traverseLink:NO];
	    [self changeFileAttributes:attributes atPath:destination];
	    return [self removeFileAtPath:source handler:handler];
	}
	else
	    return NO;
    }
    else {
	/* source and destination are on the same device so we can simply
	   invoke rename on source. */
	[handler fileManager:self willProcessPath:source];
	if (rename (sourcePath, destPath) == -1) {
	    if (handler) {
		NSDictionary* errorInfo
		    = [NSDictionary dictionaryWithObjectsAndKeys:
			source, @"Path",
			destination, @"ToPath",
			@"cannot move file", @"Error",
			nil];
		if ([handler fileManager:self
			     shouldProceedAfterError:errorInfo])
		    return YES;
	    }
	    return NO;
	}
	return YES;
    }
#endif
    return NO;
}

- (BOOL)linkPath:(NSString*)source toPath:(NSString*)destination
  handler:handler
{
    // TODO
    [self notImplemented:_cmd];
    return NO;
}

- (BOOL)removeFileAtPath:(NSString *)path
  handler:(id)handler
{
    // TODO: this method should be cleaned up !!!
    NSDirectoryEnumerator *enumerator;
    NSString              *dirEntry;
    NSString              *completeFilename;
    NSString              *fileType;
    NSDictionary          *attributes;
    const char            *cpath;
    BOOL                  pathIsDir, fileExists;
    CREATE_AUTORELEASE_POOL(pool);
    
    if (path == nil)
	[[InvalidArgumentException new] raise];
    
    if ([path isEqual:@"."] || [path isEqual:@".."])
	[[InvalidArgumentException new] raise];

    fileExists = [self fileExistsAtPath:path isDirectory:&pathIsDir];
    if (!fileExists)
	return NO;

    [handler fileManager:self willProcessPath:path];

    if (!pathIsDir) {
	cpath = [self fileSystemRepresentationWithPath:path];

#if defined(__MINGW32__)
        if (DeleteFile(cpath) == FALSE)
#else
        if (unlink(cpath)) /* use unlink, we know it's a file */
#endif
        {
	    if (handler) {
		NSDictionary *errorInfo;
                errorInfo =
		    [NSDictionary dictionaryWithObjectsAndKeys:
				    path ? path : (NSString *)@"<nil>", 
				    @"Path",
                                    @"cannot remove file", @"Error",
				  nil];
		if (![handler fileManager:self
			      shouldProceedAfterError:errorInfo])
		    return NO;

                /* intended fall-through ? [is this really correct?] */
	    }
	    else
		return NO;
	}
        else
            return YES;
    }
    else {
        enumerator = [self enumeratorAtPath:path];
        while ((dirEntry = [enumerator nextObject])) {
    	attributes = [enumerator fileAttributes];
    	fileType = [attributes objectForKey:NSFileType];
    	completeFilename = [path stringByAppendingPathComponent:dirEntry];
    
    	if ([fileType isEqual:NSFileTypeDirectory]) {
    	    /* Skip the descendants of this directory so they will not be
    	       present in further steps. */
    	    [enumerator skipDescendents];
    	}
    
    	if (![self removeFileAtPath:completeFilename handler:handler])
    	    return NO;
        }
    
    
    	if (rmdir([self fileSystemRepresentationWithPath:path])) {
    	    if (handler) {
    		NSDictionary *errorInfo;
    
                    errorInfo =
    		    [NSDictionary dictionaryWithObjectsAndKeys:
				    path ? path : (NSString *)@"<nil>", 
				    @"Path",
				    @"cannot remove directory", @"Error",
				  nil];
    		if (![handler fileManager:self
    			      shouldProceedAfterError:errorInfo])
    		    return NO;
    	    }
    	    else
    		return NO;
    	}
    }
    
    RELEASE(pool);

    return YES;
}

- (BOOL)createFileAtPath:(NSString*)path contents:(NSData*)contents
  attributes:(NSDictionary*)attributes
{
#if defined(__MINGW32__)
    HANDLE fh;

    fh = CreateFile([self fileSystemRepresentationWithPath:path],
                    GENERIC_WRITE,
                    0,    // fdwShareMode
                    NULL, // security attributes
                    CREATE_ALWAYS,
                    FILE_ATTRIBUTE_NORMAL,
                    NULL);
    if (fh == INVALID_HANDLE_VALUE)
        return NO;
    else {
        DWORD len     = [contents length];
        DWORD written = 0;

        if (len)
            WriteFile(fh, [contents bytes], len, &written, NULL);
        CloseHandle(fh);

        if (![self changeFileAttributes:attributes atPath:path])
            return NO;

        return written == len ? YES : NO;
    }
#else
    int fd, len, written;

    fd = open ([self fileSystemRepresentationWithPath:path],
		O_WRONLY|O_TRUNC|O_CREAT, 0644);
    if (fd < 0)
	return NO;

    if (![self changeFileAttributes:attributes atPath:path]) {
	close (fd);
	return NO;
    }

    len = [contents length];
    if (len)
	written = write (fd, [contents bytes], len);
    else
	written = 0;
    close (fd);

    return written == len;
#endif
}

// Getting and comparing file contents

- (NSData*)contentsAtPath:(NSString*)path
{
    return [NSData dataWithContentsOfFile:path];
}

- (BOOL)contentsEqualAtPath:(NSString*)path1 andPath:(NSString*)path2
{
    // TODO
    [self notImplemented:_cmd];
    return NO;
}

// Detemining access to files

- (BOOL)fileExistsAtPath:(NSString*)path
{
    return [self fileExistsAtPath:path isDirectory:NULL];
}

#if defined(__MINGW32__)
- (BOOL)fileExistsAtPath:(NSString*)path isDirectory:(BOOL*)isDirectory
{
    DWORD result;
    if (path == NULL) return NO;
    result = GetFileAttributes([self fileSystemRepresentationWithPath:path]);
    if (result == -1)
        return NO;

    if (isDirectory)
        *isDirectory = (result & FILE_ATTRIBUTE_DIRECTORY) ? YES : NO;
    return YES;
}

- (BOOL)isReadableFileAtPath:(NSString*)path
{
    DWORD result;
    if (path == NULL) return NO;
    result = GetFileAttributes([self fileSystemRepresentationWithPath:path]);
    if (result == -1)
        return NO;
    return YES;
}
- (BOOL)isWritableFileAtPath:(NSString*)path
{
    DWORD result;
    if (path == NULL) return NO;
    result = GetFileAttributes([self fileSystemRepresentationWithPath:path]);
    if (result == -1)
        return NO;

    return (result & FILE_ATTRIBUTE_READONLY) ? NO : YES;
}
- (BOOL)isExecutableFileAtPath:(NSString*)path
{
    // naive, is there a better way ?
    if ([self isReadableFileAtPath:path]) {
        return [[path pathExtension] isEqualToString:@"exe"];
    }
    else
        return NO;
}
- (BOOL)isDeletableFileAtPath:(NSString*)path
{
    // TODO - handle directories
    return [self isWritableFileAtPath:path];
}

#else
- (BOOL)fileExistsAtPath:(NSString*)path isDirectory:(BOOL*)isDirectory
{
    struct stat statbuf;
    const char* cpath = [self fileSystemRepresentationWithPath:path];

    if (stat(cpath, &statbuf) != 0)
	return NO;
    
    if (isDirectory)
	*isDirectory = ((statbuf.st_mode & S_IFMT) == S_IFDIR);
    return YES;
}

- (BOOL)isReadableFileAtPath:(NSString*)path
{
    const char* cpath = [self fileSystemRepresentationWithPath:path];
    
    return (access(cpath, R_OK) == 0);
}

- (BOOL)isWritableFileAtPath:(NSString*)path
{
    const char* cpath = [self fileSystemRepresentationWithPath:path];
    
    return (access(cpath, W_OK) == 0);
}

- (BOOL)isExecutableFileAtPath:(NSString*)path
{
    const char* cpath = [self fileSystemRepresentationWithPath:path];
    
    return (access(cpath, X_OK) == 0);
}

- (BOOL)isDeletableFileAtPath:(NSString*)path
{
    // TODO - handle directories
    const char* cpath;
    
    cpath = [self fileSystemRepresentationWithPath:
	[path stringByDeletingLastPathComponent]];
    
    if (access(cpath, X_OK | W_OK) != 0)
	return NO;

    cpath = [self fileSystemRepresentationWithPath:path];

    return  (access(cpath, X_OK | W_OK) == 0);
}
#endif    

- (NSDictionary*)fileAttributesAtPath:(NSString*)path traverseLink:(BOOL)flag
{
    struct stat statbuf;
    const char* cpath = [self fileSystemRepresentationWithPath:path];
    int mode;
#if HAVE_GETPWUID
    struct passwd *pw;
#endif
    int count = 10;

    id  values[11];
    id	keys[11] = {
        NSFileSize,
        NSFileModificationDate,
        NSFileOwnerAccountNumber,
        NSFileGroupOwnerAccountNumber,
        NSFileReferenceCount,
        NSFileIdentifier,
        NSFileDeviceIdentifier,
        NSFilePosixPermissions,
        NSFileType,
        NSFileOwnerAccountName
    };

#ifdef S_IFLNK
    if (flag) {
        /* traverseLink */
        if (stat(cpath, &statbuf) != 0)
            return nil;
    }
    else {
        /* do not traverseLink */
        if (lstat(cpath, &statbuf) != 0)
            return nil;
    }
#else
    if (stat(cpath, &statbuf) != 0)
	return nil;
#endif
    
    values[0] = [NSNumber numberWithUnsignedLongLong:statbuf.st_size];
    values[1] = [NSDate dateWithTimeIntervalSince1970:statbuf.st_mtime];
    values[2] = [NSNumber numberWithUnsignedInt:statbuf.st_uid];
    values[3] = [NSNumber numberWithUnsignedInt:statbuf.st_gid];
    values[4] = [NSNumber numberWithUnsignedInt:statbuf.st_nlink];
    values[5] = [NSNumber numberWithUnsignedLong:statbuf.st_ino];
    values[6] = [NSNumber numberWithUnsignedInt:statbuf.st_dev];
    values[7] = [NSNumber numberWithUnsignedInt:statbuf.st_mode];
    
    mode = statbuf.st_mode & S_IFMT;

    if      (mode == S_IFREG)  values[8] = NSFileTypeRegular;
    else if (mode == S_IFDIR)  values[8] = NSFileTypeDirectory;
    else if (mode == S_IFCHR)  values[8] = NSFileTypeCharacterSpecial;
    else if (mode == S_IFBLK)  values[8] = NSFileTypeBlockSpecial;
#ifdef S_IFLNK
    else if (mode == S_IFLNK)  values[8] = NSFileTypeSymbolicLink;
#endif
    else if (mode == S_IFIFO)  values[8] = NSFileTypeFifo;
#ifdef S_IFSOCK
    else if (mode == S_IFSOCK) values[8] = NSFileTypeSocket;
#endif
    else                       values[8] = NSFileTypeUnknown;
    count = 9;
    
#if HAVE_GETPWUID
    pw = getpwuid(statbuf.st_uid);
    
    if (pw) {
	values[count] = [NSString stringWithCString:pw->pw_name];
        count++;
    }
#endif
    
    return AUTORELEASE([[NSDictionary alloc]
                           initWithObjects:values forKeys:keys count:count]);
}

- (NSDictionary*)fileSystemAttributesAtPath:(NSString*)path
{
#if HAVE_SYS_VFS_H || HAVE_SYS_STATFS_H
    struct stat statbuf;
#if HAVE_STATVFS
    struct statvfs statfsbuf;
#else
    struct statfs statfsbuf;
#endif
    long long totalsize, freesize;
    const char* cpath = [self fileSystemRepresentationWithPath:path];
    
    id  values[5];
    id	keys[5] = {
        NSFileSystemSize,
        NSFileSystemFreeSize,
        NSFileSystemNodes,
        NSFileSystemFreeNodes,
        NSFileSystemNumber
    };
    
    if (stat(cpath, &statbuf) != 0)
	return nil;

#if HAVE_STATVFS
    if (statvfs(cpath, &statfsbuf) != 0)
	return nil;
#else
    if (statfs(cpath, &statfsbuf) != 0)
	return nil;
#endif

    totalsize = statfsbuf.f_bsize * statfsbuf.f_blocks;
    freesize = statfsbuf.f_bsize * statfsbuf.f_bfree;
    
    values[0] = [NSNumber numberWithLongLong:totalsize];
    values[1] = [NSNumber numberWithLongLong:freesize];
    values[2] = [NSNumber numberWithLong:statfsbuf.f_files];
    values[3] = [NSNumber numberWithLong:statfsbuf.f_ffree];
    values[4] = [NSNumber numberWithUnsignedInt:statbuf.st_dev];
    
    return AUTORELEASE([[NSDictionary alloc]
                           initWithObjects:values forKeys:keys count:5]);
#else
    return nil;
#endif
}

- (BOOL)changeFileAttributes:(NSDictionary*)attributes atPath:(NSString*)path
{
    const char* cpath = [self fileSystemRepresentationWithPath:path];
    NSNumber* num;
    NSDate* date;
    BOOL allOk = YES;
    
#if HAVE_CHOWN
    num = [attributes objectForKey:NSFileOwnerAccountNumber];
    if (num) {
	allOk &= (chown(cpath, [num intValue], -1) == 0);
    }
    
    num = [attributes objectForKey:NSFileGroupOwnerAccountNumber];
    if (num) {
	allOk &= (chown(cpath, -1, [num intValue]) == 0);
    }
#endif
    
    num = [attributes objectForKey:NSFilePosixPermissions];
    if (num) {
	allOk &= (chmod(cpath, [num intValue]) == 0);
    }
    
    date = [attributes objectForKey:NSFileModificationDate];
    if (date) {
	struct stat sb;
#if defined(_POSIX_VERSION) || defined(__WIN32__)
	struct utimbuf ub;
#else
	time_t ub[2];
#endif

	if (stat(cpath, &sb) != 0)
	    allOk = NO;
	else {
#if defined(_POSIX_VERSION) || defined(__WIN32__)
	    ub.actime = sb.st_atime;
	    ub.modtime = [date timeIntervalSince1970];
	    allOk &= (utime(cpath, &ub) == 0);
#else
	    ub[0] = sb.st_atime;
	    ub[1] = [date timeIntervalSince1970];
	    allOk &= (utime((char*)cpath, ub) == 0);
#endif
	}
    }
    
    return allOk;
}

// Discovering directory contents

- (NSArray *)directoryContentsAtPath:(NSString *)path
{
    NSDirectoryEnumerator* direnum;
    NSMutableArray* content;
    BOOL isDir;
    
    if (![self fileExistsAtPath:path isDirectory:&isDir] || !isDir)
	return nil;
    
    direnum = [[NSDirectoryEnumerator alloc]
	initWithDirectoryPath:path 
	recurseIntoSubdirectories:NO
	followSymlinks:NO
	prefixFiles:NO];
    content = AUTORELEASE([[NSMutableArray alloc] init]);
    
    while ((path = [direnum nextObject]))
	[content addObject:path];

    RELEASE(direnum); direnum = nil;

    return content;
}

- (NSDirectoryEnumerator*)enumeratorAtPath:(NSString*)path
{
    return AUTORELEASE([[NSDirectoryEnumerator alloc]
                           initWithDirectoryPath:path 
                           recurseIntoSubdirectories:YES
                           followSymlinks:NO
                           prefixFiles:YES]);
}

- (NSArray*)subpathsAtPath:(NSString*)path
{
    NSDirectoryEnumerator* direnum;
    NSMutableArray* content;
    BOOL isDir;
    
    if (![self fileExistsAtPath:path isDirectory:&isDir] || !isDir)
	return nil;
    
    direnum = [[NSDirectoryEnumerator alloc]
	initWithDirectoryPath:path 
	recurseIntoSubdirectories:YES
	followSymlinks:NO
	prefixFiles:YES];
    content = AUTORELEASE([[NSMutableArray alloc] init]);
    
    while ((path = [direnum nextObject]))
	[content addObject:path];

    RELEASE(direnum); direnum = nil;

    return content;
}

// Symbolic-link operations

- (BOOL)createSymbolicLinkAtPath:(NSString*)path
  pathContent:(NSString*)otherPath
{
#if HAVE_SYMLINK
    const char* lpath = [self fileSystemRepresentationWithPath:path];
    const char* npath = [self fileSystemRepresentationWithPath:otherPath];
    
    return (symlink(npath, lpath) == 0);
#else
	[[InvalidArgumentException new] raise];
    return NO;
#endif
}

- (NSString*)pathContentOfSymbolicLinkAtPath:(NSString*)path
{
#if HAVE_READLINK
    char  lpath[PATH_MAX];
    const char* cpath = [self fileSystemRepresentationWithPath:path];
    int   llen = readlink(cpath, lpath, PATH_MAX-1);
    
    if (llen > 0)
	return [self stringWithFileSystemRepresentation:lpath length:llen];
    else
#endif
	return nil;
}

// Converting file-system representations

- (const char*)fileSystemRepresentationWithPath:(NSString*)path
{
    return [path cString];
}

- (NSString*)stringWithFileSystemRepresentation:(const char*)string
  length:(unsigned int)len
{
    return [NSString stringWithCString:string length:len];
}

@end /* NSFileManager */

/*
 * NSDirectoryEnumerator implementation
 */

@implementation NSDirectoryEnumerator

#if defined(__MINGW32__)

typedef struct _MingDIR {
    HANDLE          handle;
    WIN32_FIND_DATA info;
    int             dirCount;
} MingDIR;

static inline MingDIR *ming_opendir(const char *cstr) {
    DWORD result;
    
    if (cstr == NULL)
        return NULL;

    result = GetFileAttributes(cstr);
    if (result == 0xFFFFFFFF) {
        NSLog(@"ERROR: could not get file attributes of path '%s'", cstr);
        return NULL;
    }

    if (result & FILE_ATTRIBUTE_DIRECTORY) {
        MingDIR *dir = objc_atomic_malloc(sizeof(MingDIR));
        int     len  = strlen(cstr);
        char    *buf = objc_atomic_malloc(len + 10);

        strcpy(buf, cstr);
        if (len > 0) {
            if (buf[len - 1] == '\\')
                strcat(buf, "*");
            else
                strcat(buf, "\\*");
        }
        else
            strcat(buf, "\\*");

        dir->dirCount = 0;
        dir->handle = FindFirstFile(buf, &(dir->info));
	objc_free(buf); buf = NULL;
        if (dir->handle == INVALID_HANDLE_VALUE) {
            objc_free(dir); dir = NULL;
            return NULL;
        }
        return dir;
    }
    else {
        // not a directory
        NSLog(@"ERROR: path '%s' is not a directory !", cstr);
        return NULL;
    }
}
static inline void ming_closedir(MingDIR *dir) {
    if (dir) {
        if (dir->handle != INVALID_HANDLE_VALUE) {
            FindClose(dir->handle);
            dir->handle = INVALID_HANDLE_VALUE;
        }
        free(dir);
    }
}

static inline WIN32_FIND_DATA *ming_readdir(MingDIR *dir) {
    if (dir->dirCount == 0) {
        // first entry
        dir->dirCount += 1;
        return &(dir->info);
    }
    else if (dir->handle != INVALID_HANDLE_VALUE) {
        if (FindNextFile(dir->handle, &(dir->info)) == FALSE) {
            FindClose(dir->handle);
            dir->handle = INVALID_HANDLE_VALUE;
            return NULL;
        }
        dir->dirCount += 1;
        return &(dir->info);
    }
    else // directory closed
        return NULL;
}

#endif

// Implementation dependent methods

/* 
  recurses into directory `path' 
	- pushes relative path (relative to root of search) on pathStack
	- pushes system dir enumerator on enumPath 
*/
- (void)recurseIntoDirectory:(NSString*)path relativeName:(NSString*)name
{
    const char* cpath;
#if defined(__MINGW32__)
    MingDIR *dir;
#elif HAVE_OPENDIR
    DIR *dir;
#endif

    cpath = [[NSFileManager defaultManager]
                            fileSystemRepresentationWithPath:path];

    if (cpath == NULL)
	[[InvalidArgumentException new] raise];

#if defined(__MINGW32__)
    if ((dir = ming_opendir(cpath))) {
         [pathStack addObject:name];
         [enumStack addObject:[NSValue valueWithPointer:dir]];
    }
#elif HAVE_OPENDIR
    if ((dir = opendir(cpath))) {
	[pathStack addObject:name];
	[enumStack addObject:[NSValue valueWithPointer:dir]];
    }
#else
    [[InvalidArgumentException new] raise];
#endif
}

/*
  backtracks enumeration to the previous dir
  	- pops current dir relative path from pathStack
	- pops system dir enumerator from enumStack
	- sets currentFile* to nil
*/
- (void)backtrack
{
#if defined(__MINGW32__)
    ming_closedir((MingDIR *)[[enumStack lastObject] pointerValue]);
#elif HAVE_OPENDIR
    closedir((DIR *)[[enumStack lastObject] pointerValue]);
#else
    [[InvalidArgumentException new] raise];
#endif
    [enumStack removeLastObject];
    [pathStack removeLastObject];
    RELEASE(currentFileName); currentFileName = nil;
    RELEASE(currentFilePath); currentFilePath = nil;
}

/*
  finds the next file according to the top enumerator
  	- if there is a next file it is put in currentFile
	- if the current file is a directory and if isRecursive calls 
	    recurseIntoDirectory:currentFile
	- if the current file is a symlink to a directory and if isRecursive 
	    and isFollowing calls recurseIntoDirectory:currentFile
	- if at end of current directory pops stack and attempts to
	    find the next entry in the parent
	- sets currentFile to nil if there are no more files to enumerate
*/
- (void)findNextFile
{
    NSFileManager   *manager = [NSFileManager defaultManager];
#if defined(__MINGW32__)
    MingDIR         *dir;
    WIN32_FIND_DATA *dirbuf;
#elif HAVE_OPENDIR
    DIR_enum_state  *dir;
    DIR_enum_item   *dirbuf;
#endif
#if defined(__MINGW32__)
    DWORD           fileAttributes;
#else
    struct stat	    statbuf;
#endif
    const char      *cpath;
    
    RELEASE(self->currentFileName); self->currentFileName = nil;
    RELEASE(self->currentFilePath); self->currentFilePath = nil;
    
    while ([self->pathStack count]) {
#if defined(__MINGW32__)
        dir = (MingDIR *)[[self->enumStack lastObject] pointerValue];
        dirbuf = ming_readdir(dir);

        if (dirbuf == NULL) {
            // If we reached the end of this directory, go back to the upper one
            [self backtrack];
            continue;
        }
	/* Skip "." and ".." directory entries */
	if (Strcmp(dirbuf->cFileName, ".") == 0 || 
	    Strcmp(dirbuf->cFileName, "..") == 0)
		continue;

	self->currentFileName = [manager
		stringWithFileSystemRepresentation:dirbuf->cFileName
		length:Strlen(dirbuf->cFileName)];
#elif HAVE_OPENDIR
	dir    = (DIR*)[[enumStack lastObject] pointerValue];
	dirbuf = readdir(dir);

	/* If we reached the end of this directory, go back to the upper one */
	if (dirbuf == NULL) {
	    [self backtrack];
	    continue;
	}

	/* Skip "." and ".." directory entries */
	if (Strcmp(dirbuf->d_name, ".") == 0 || 
	    Strcmp(dirbuf->d_name, "..") == 0)
		continue;
	// Name of current file
	self->currentFileName = [manager
		stringWithFileSystemRepresentation:dirbuf->d_name
		length:Strlen(dirbuf->d_name)];
#else
	[[InvalidArgumentException new] raise];
#endif
	self->currentFileName
            = RETAIN([[pathStack lastObject]
                         stringByAppendingPathComponent:self->currentFileName]);
        
	// Full path of current file
	self->currentFilePath
            = RETAIN([self->topPath stringByAppendingPathComponent:
                                      self->currentFileName]);
        
	// Check if directory
	cpath = [manager fileSystemRepresentationWithPath:currentFilePath];
        
	// Do not follow links
#ifdef S_IFLNK
	if (!flags.isFollowing) {
	    if (lstat(cpath, &statbuf) < 0) {
		NSLog (@"cannot lstat file '%s'", cpath);
		continue;
	    }
	    // If link then return it as link
	    if (S_IFLNK == (S_IFMT & statbuf.st_mode)) 
		break;
	}
#endif

#if defined(__MINGW32__)
        if ((fileAttributes = GetFileAttributes(cpath)) == 0xFFFFFFFF)
            // could not get file attributes
	    continue;

        if (self->flags.isRecursive) {
            if (fileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
                [self recurseIntoDirectory:self->currentFilePath 
                      relativeName:self->currentFileName];
            }
        }
#else
	// Follow links - check for directory
	if (stat(cpath, &statbuf) < 0)
            // could not stat file
	    continue;

	if (S_IFDIR == (S_IFMT & statbuf.st_mode) && self->flags.isRecursive) {
	    [self recurseIntoDirectory:self->currentFilePath 
                  relativeName:self->currentFileName];
	}
#endif
	break;
    }
}

// Initializing

- (id)initWithDirectoryPath:(NSString*)path 
  recurseIntoSubdirectories:(BOOL)recurse
  followSymlinks:(BOOL)follow
  prefixFiles:(BOOL)prefix
{
    self->pathStack = [[NSMutableArray allocWithZone:[self zone]] init];
    self->enumStack = [[NSMutableArray allocWithZone:[self zone]] init];
    self->flags.isRecursive = recurse;
    self->flags.isFollowing = follow;
    
    self->topPath = [path copyWithZone:[self zone]];
    [self recurseIntoDirectory:path relativeName:@""];
    
    return self;
}

- (void)dealloc
{
    while ([self->pathStack count])
	[self backtrack];
    
    RELEASE(self->pathStack);
    RELEASE(self->enumStack);
    RELEASE(self->currentFileName);
    RELEASE(self->currentFilePath);
    RELEASE(self->topPath);

    [super dealloc];
}

// Getting attributes

- (NSDictionary *)directoryAttributes
{
    return [[NSFileManager defaultManager]
                           fileAttributesAtPath:self->currentFilePath
                           traverseLink:self->flags.isFollowing];
}

- (NSDictionary*)fileAttributes
{
    return [[NSFileManager defaultManager]
                           fileAttributesAtPath:self->currentFilePath
                           traverseLink:self->flags.isFollowing];
}

// Skipping subdirectories

- (void)skipDescendents
{
    if ([self->pathStack count])
	[self backtrack];
}

// Enumerate next

- (id)nextObject
{
    [self findNextFile];
    return self->currentFileName;
}

@end /* NSDirectoryEnumerator */

/*
 * Attributes dictionary access
 */

@implementation NSDictionary(NSFileAttributes)

- (NSNumber *)fileSize
{
    return [self objectForKey:NSFileSize];
}
- (NSString *)fileType;
{
    return [self objectForKey:NSFileType];
}
- (NSNumber *)fileOwnerAccountNumber;
{
    return [self objectForKey:NSFileOwnerAccountNumber];
}
- (NSNumber *)fileGroupOwnerAccountNumber;
{
    return [self objectForKey:NSFileGroupOwnerAccountNumber];
}
- (NSDate *)fileModificationDate;
{
    return [self objectForKey:NSFileModificationDate];
}
- (NSNumber *)filePosixPermissions;
{
    return [self objectForKey:NSFilePosixPermissions];
}
@end

/*
 * File attributes names
 */

/* File Attributes */

LF_DECLARE NSString *NSFileSize                    = @"NSFileSize";
LF_DECLARE NSString *NSFileModificationDate        = @"NSFileModificationDate";
LF_DECLARE NSString *NSFileOwnerAccountNumber      = @"NSFileOwnerAccountNumber";
LF_DECLARE NSString *NSFileOwnerAccountName        = @"NSFileOwnerAccountName";
LF_DECLARE NSString *NSFileGroupOwnerAccountNumber = @"NSFileGroupOwnerAccountNumber";
LF_DECLARE NSString *NSFileGroupOwnerAccountName   = @"NSFileGroupOwnerAccountName";
LF_DECLARE NSString *NSFileReferenceCount          = @"NSFileReferenceCount";
LF_DECLARE NSString *NSFileIdentifier              = @"NSFileIdentifier";
LF_DECLARE NSString *NSFileDeviceIdentifier        = @"NSFileDeviceIdentifier";
LF_DECLARE NSString *NSFilePosixPermissions        = @"NSFilePosixPermissions";
LF_DECLARE NSString *NSFileType                    = @"NSFileType";

/* File Types */

LF_DECLARE NSString *NSFileTypeDirectory           = @"NSFileTypeDirectory";
LF_DECLARE NSString *NSFileTypeRegular             = @"NSFileTypeRegular";
LF_DECLARE NSString *NSFileTypeSymbolicLink        = @"NSFileTypeSymbolicLink";
LF_DECLARE NSString *NSFileTypeSocket              = @"NSFileTypeSocket";
LF_DECLARE NSString *NSFileTypeFifo                = @"NSFileTypeFifo";
LF_DECLARE NSString *NSFileTypeCharacterSpecial    = @"NSFileTypeCharacterSpecial";
LF_DECLARE NSString *NSFileTypeBlockSpecial        = @"NSFileTypeBlockSpecial";
LF_DECLARE NSString *NSFileTypeUnknown             = @"NSFileTypeUnknown";

/* FileSystem Attributes */

LF_DECLARE NSString *NSFileSystemFileNumber        = @"NSFileSystemFileNumber";
LF_DECLARE NSString *NSFileSystemSize              = @"NSFileSystemSize";
LF_DECLARE NSString *NSFileSystemFreeSize          = @"NSFileSystemFreeSize";
LF_DECLARE NSString *NSFileSystemNodes             = @"NSFileSystemNodes";
LF_DECLARE NSString *NSFileSystemFreeNodes         = @"NSFileSystemFreeNodes";
LF_DECLARE NSString *NSFileSystemNumber            = @"NSFileSystemNumber";

@implementation NSFileManager (PrivateMethods)

- (BOOL)_copyFile:(NSString*)source toFile:(NSString*)destination
  handler:handler
{
    NSDictionary* attributes;
    int i, bufsize = 8096;
    int sourceFd, destFd, fileSize, fileMode;
    int rbytes, wbytes;
    char buffer[bufsize];

    /* Assumes source is a file and exists! */
    NSAssert1 ([self fileExistsAtPath:source],
		@"source file '%@' does not exist!", source);

    attributes = [self fileAttributesAtPath:source traverseLink:NO];
    NSAssert1 (attributes, @"could not get the attributes for file '%@'",
		source);

    fileSize = [[attributes objectForKey:NSFileSize] intValue];
    fileMode = [[attributes objectForKey:NSFilePosixPermissions] intValue];

    /* Open the source file. In case of error call the handler. */
    sourceFd = open([self fileSystemRepresentationWithPath:source], O_RDONLY, 0);
    if (sourceFd < 0) {
	if (handler) {
	    NSDictionary* errorInfo
		= [NSDictionary dictionaryWithObjectsAndKeys:
			source, @"Path",
			@"cannot open file for reading", @"Error",
			nil];
	    return [handler fileManager:self
			    shouldProceedAfterError:errorInfo];
	}
	else
	    return NO;
    }

    /* Open the destination file. In case of error call the handler. */
    destFd = open([self fileSystemRepresentationWithPath:destination],
		  O_WRONLY|O_CREAT|O_TRUNC, fileMode);
    if (destFd < 0) {
	if (handler) {
	    NSDictionary* errorInfo
		= [NSDictionary dictionaryWithObjectsAndKeys:
			destination, @"ToPath",
			@"cannot open file for writing", @"Error",
			nil];
	    close (sourceFd);
	    return [handler fileManager:self
			    shouldProceedAfterError:errorInfo];
	}
	else
	    return NO;
    }

    /* Read bufsize bytes from source file and write them into the destination
       file. In case of errors call the handler and abort the operation. */
    for (i = 0; i < fileSize; i += rbytes) {
	rbytes = read (sourceFd, buffer, bufsize);
	if (rbytes < 0) {
	    if (handler) {
		NSDictionary* errorInfo
		    = [NSDictionary dictionaryWithObjectsAndKeys:
			    source, @"Path",
			    @"cannot read from file", @"Error",
			    nil];
		close (sourceFd);
		close (destFd);
		return [handler fileManager:self
				shouldProceedAfterError:errorInfo];
	    }
	    else
		return NO;
	}

	wbytes = write (destFd, buffer, rbytes);
	if (wbytes != rbytes) {
	    if (handler) {
		NSDictionary* errorInfo
		    = [NSDictionary dictionaryWithObjectsAndKeys:
			    source, @"Path",
			    destination, @"ToPath",
			    @"cannot write to file", @"Error",
			    nil];
		close (sourceFd);
		close (destFd);
		return [handler fileManager:self
				shouldProceedAfterError:errorInfo];
	    }
	    else
		return NO;
	}
    }
    close (sourceFd);
    close (destFd);

    return YES;
}

- (BOOL)_copyPath:(NSString*)source
  toPath:(NSString*)destination
  handler:handler
{
    NSDirectoryEnumerator* enumerator;
    NSString* dirEntry;
    NSString* sourceFile;
    NSString* fileType;
    NSString* destinationFile;
    NSDictionary* attributes;
    CREATE_AUTORELEASE_POOL(pool);

    enumerator = [self enumeratorAtPath:source];
    while ((dirEntry = [enumerator nextObject])) {
	attributes = [enumerator fileAttributes];
	fileType = [attributes objectForKey:NSFileType];
	sourceFile = [source stringByAppendingPathComponent:dirEntry];
	destinationFile
		= [destination stringByAppendingPathComponent:dirEntry];

	[handler fileManager:self willProcessPath:sourceFile];
	if ([fileType isEqual:NSFileTypeDirectory]) {
	    if (![self createDirectoryAtPath:destinationFile
			attributes:attributes]) {
		if (handler) {
		    NSDictionary* errorInfo
			= [NSDictionary dictionaryWithObjectsAndKeys:
				destinationFile, @"Path",
				@"cannot create directory", @"Error",
				nil];
		    if (![handler fileManager:self
				  shouldProceedAfterError:errorInfo])
			return NO;
		}
		else
		    return NO;
	    }
	    else {
		[enumerator skipDescendents];
		if (![self _copyPath:sourceFile toPath:destinationFile
			    handler:handler])
		    return NO;
	    }
	}
	else if ([fileType isEqual:NSFileTypeRegular]) {
	    if (![self _copyFile:sourceFile toFile:destinationFile
			handler:handler])
		return NO;
	}
	else if ([fileType isEqual:NSFileTypeSymbolicLink]) {
	    if (![self createSymbolicLinkAtPath:destinationFile
			pathContent:sourceFile]) {
		if (handler) {
		    NSDictionary* errorInfo
			= [NSDictionary dictionaryWithObjectsAndKeys:
				sourceFile, @"Path",
				destinationFile, @"ToPath",
				@"cannot create symbolic link", @"Error",
				nil];
		    if (![handler fileManager:self
				  shouldProceedAfterError:errorInfo])
			return NO;
		}
		else
		    return NO;
	    }
	}
	else {
	    NSLog(@"cannot copy file '%@' of type '%@'", sourceFile, fileType);
	}
	[self changeFileAttributes:attributes atPath:destinationFile];
    }
    RELEASE(pool);

    return YES;
}

@end /* NSFileManager (PrivateMethods) */
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

