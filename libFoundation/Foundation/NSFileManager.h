/* 
   NSFileManager.h

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

#ifndef __NSFileManager_h__
#define __NSFileManager_h__

#include <Foundation/NSObject.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSDictionary.h>

#if defined(__MINGW32__)
#  include <windows.h>
#endif

@class NSNumber;
@class NSString;
@class NSData;
@class NSDate;
@class NSArray;
@class NSMutableArray;

@class NSDirectoryEnumerator;

@interface NSFileManager : NSObject

// Getting the default manager
+ (NSFileManager*)defaultManager;

// Directory operations
- (BOOL)changeCurrentDirectoryPath:(NSString*)path;
- (BOOL)createDirectoryAtPath:(NSString*)path
  attributes:(NSDictionary*)attributes;
- (NSString*)currentDirectoryPath;

// File operations
- (BOOL)copyPath:(NSString*)source toPath:(NSString*)destination
  handler:handler;
- (BOOL)movePath:(NSString*)source toPath:(NSString*)destination 
  handler:handler;
- (BOOL)linkPath:(NSString*)source toPath:(NSString*)destination
  handler:handler;
- (BOOL)removeFileAtPath:(NSString*)path
  handler:handler;
- (BOOL)createFileAtPath:(NSString*)path contents:(NSData*)contents
  attributes:(NSDictionary*)attributes;

// Getting and comparing file contents	
- (NSData*)contentsAtPath:(NSString*)path;
- (BOOL)contentsEqualAtPath:(NSString*)path1 andPath:(NSString*)path2;

// Determining access to files
- (BOOL)fileExistsAtPath:(NSString*)path;
- (BOOL)fileExistsAtPath:(NSString*)path isDirectory:(BOOL*)isDirectory;
- (BOOL)isReadableFileAtPath:(NSString*)path;
- (BOOL)isWritableFileAtPath:(NSString*)path;
- (BOOL)isExecutableFileAtPath:(NSString*)path;
- (BOOL)isDeletableFileAtPath:(NSString*)path;

// Getting and setting attributes
- (NSDictionary*)fileAttributesAtPath:(NSString*)path traverseLink:(BOOL)flag;
- (NSDictionary*)fileSystemAttributesAtPath:(NSString*)path;
- (BOOL)changeFileAttributes:(NSDictionary*)attributes atPath:(NSString*)path;

// Discovering directory contents
- (NSArray*)directoryContentsAtPath:(NSString*)path;
- (NSDirectoryEnumerator*)enumeratorAtPath:(NSString*)path;
- (NSArray*)subpathsAtPath:(NSString*)path;

// Symbolic-link operations
- (BOOL)createSymbolicLinkAtPath:(NSString*)path
  pathContent:(NSString*)otherPath;
- (NSString*)pathContentOfSymbolicLinkAtPath:(NSString*)path;

// Converting file-system representations
- (const char*)fileSystemRepresentationWithPath:(NSString*)path;
- (NSString*)stringWithFileSystemRepresentation:(const char*)string
  length:(unsigned int)len;

@end /* NSFileManager */


@interface NSObject (NSFileManagerHandler)
- (BOOL)fileManager:(NSFileManager*)fileManager
  shouldProceedAfterError:(NSDictionary*)errorDictionary;
- (void)fileManager:(NSFileManager*)fileManager
  willProcessPath:(NSString*)path;
@end


@interface NSDirectoryEnumerator : NSEnumerator
{
    NSMutableArray *enumStack;
    NSMutableArray *pathStack;
    NSString       *currentFileName;
    NSString       *currentFilePath;
    NSString       *topPath;
    struct {
	BOOL isRecursive:1;
 	BOOL isFollowing:1;
   } flags;
}

// Initializing
- (id)initWithDirectoryPath:(NSString *)path 
  recurseIntoSubdirectories:(BOOL)recurse
  followSymlinks:(BOOL)follow
  prefixFiles:(BOOL)prefix;

// Getting attributes
- (NSDictionary *)directoryAttributes;
- (NSDictionary *)fileAttributes;

// Skipping subdirectories
- (void)skipDescendents;

@end /* NSDirectoryEnumerator */

/* File Attributes */

LF_EXPORT NSString *NSFileSize;
LF_EXPORT NSString *NSFileModificationDate;
LF_EXPORT NSString *NSFileOwnerAccountNumber;
LF_EXPORT NSString *NSFileOwnerAccountName;
LF_EXPORT NSString *NSFileGroupOwnerAccountNumber;
LF_EXPORT NSString *NSFileGroupOwnerAccountName;
LF_EXPORT NSString *NSFileReferenceCount;
LF_EXPORT NSString *NSFileIdentifier;
LF_EXPORT NSString *NSFileDeviceIdentifier;
LF_EXPORT NSString *NSFilePosixPermissions;
LF_EXPORT NSString *NSFileType;

/* File Types */

LF_EXPORT NSString *NSFileTypeDirectory;
LF_EXPORT NSString *NSFileTypeRegular;
LF_EXPORT NSString *NSFileTypeSymbolicLink;
LF_EXPORT NSString *NSFileTypeSocket;
LF_EXPORT NSString *NSFileTypeFifo;
LF_EXPORT NSString *NSFileTypeCharacterSpecial;
LF_EXPORT NSString *NSFileTypeBlockSpecial;
LF_EXPORT NSString *NSFileTypeUnknown;

/* FileSystem Attributes */

LF_EXPORT NSString *NSFileSystemFileNumber;
LF_EXPORT NSString *NSFileSystemSize;
LF_EXPORT NSString *NSFileSystemFreeSize;
LF_EXPORT NSString *NSFileSystemNodes;
LF_EXPORT NSString *NSFileSystemFreeNodes;
LF_EXPORT NSString *NSFileSystemNumber;

/* Easy access to attributes in a dictionary */

@interface NSDictionary(NSFileAttributes)
- (NSNumber*)fileSize;
- (NSString*)fileType;
- (NSNumber*)fileOwnerAccountNumber;
- (NSNumber*)fileGroupOwnerAccountNumber;
- (NSDate*)fileModificationDate;
- (NSNumber*)filePosixPermissions;
@end


#endif /* __NSFileManager_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
