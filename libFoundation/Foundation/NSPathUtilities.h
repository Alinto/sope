/* 
   NSPathUtilities.h

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

#ifndef __NSPathUtilities_h__
#define __NSPathUtilities_h__

#include <Foundation/NSString.h>

/*
 * User Informations
 */

LF_EXPORT NSString *NSUserName(void);
LF_EXPORT NSString *NSHomeDirectory(void);
LF_EXPORT NSString *NSHomeDirectoryForUser(NSString* userName);

LF_EXPORT NSString *NSFullUserName();
LF_EXPORT NSString *NSTemporaryDirectory();

/*
 * Standard System Paths, primarily useful in the GNUstep environment
 */

typedef enum {
    NSUserDomainMask    = 1,
    NSLocalDomainMask   = 2,
    NSNetworkDomainMask = 4,
    NSSystemDomainMask  = 8,
    NSAllDomainsMask    = 255
} NSSearchPathDomainMask;

typedef enum {
    NSApplicationDirectory = 1,
    NSLibraryDirectory,
    NSUserDirectory,
    NSAllApplicationDirectory = 1000,
    NSAllLibrariesDirectory
} NSSearchPathDirectory;

@class NSString, NSArray;

LF_EXPORT NSString *NSOpenStepRootDirectory(void);
LF_EXPORT NSArray  *NSStandardLibraryPaths(void);
LF_EXPORT NSArray  *NSStandardApplicationPaths(void);

LF_EXPORT NSArray *
NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory _directory,
                                    NSSearchPathDomainMask _mask,
                                    BOOL _expandTilde);

/*
 * String file naming utilities
 */

@interface NSString(FilePathMethods)

+ (NSString *)pathWithComponents:(NSArray *)components;
- (NSArray *)pathComponents;
- (unsigned int)completePathIntoString:(NSString **)outputName
  caseSensitive:(BOOL)flag matchesIntoArray:(NSArray **)outputArray
  filterTypes:(NSArray*)filterTypes; 
- (const char *)fileSystemRepresentation;
- (BOOL)getFileSystemRepresentation:(char *)buffer
  maxLength:(unsigned int)maxLength;
- (BOOL)isAbsolutePath;
- (NSString *)lastPathComponent;
- (NSString *)pathExtension;
- (NSString *)stringByAbbreviatingWithTildeInPath;
- (NSString *)stringByAppendingPathComponent:(NSString *)aString;
- (NSString *)stringByAppendingPathExtension:(NSString *)aString;
- (NSString *)stringByDeletingLastPathComponent;
- (NSString *)stringByDeletingPathExtension;
- (NSString *)stringByExpandingTildeInPath;
- (NSString *)stringByResolvingSymlinksInPath;
- (NSString *)stringByStandardizingPath;
- (NSArray *)stringsByAppendingPaths:(NSArray *)paths;

@end

#endif /* __NSPathUtilities_h__ */

#ifndef __NSPathUtilitiesArray_h__
#define __NSPathUtilitiesArray_h__

#include <Foundation/NSArray.h>

@interface NSArray(FilePathMethods)

- (NSArray *)pathsMatchingExtensions:(NSArray *)_exts; /* new in MacOSX */

@end

#endif /* __NSPathUtilitiesArray_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
