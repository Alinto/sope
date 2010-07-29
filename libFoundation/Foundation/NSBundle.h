/* 
   NSBundle.h

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

#ifndef __NSBundle_h__
#define __NSBundle_h__

#include <Foundation/NSObject.h>
#include <Foundation/NSUtilities.h>

@class NSString;
@class NSArray;
@class NSDictionary;
@class NSMutableDictionary;

@interface NSBundle : NSObject
{
    NSString            *fullPath;
    NSDictionary        *infoDictionary;
    Class               firstLoadedClass;
    NSMutableDictionary *stringTables;
    BOOL                codeLoaded;
}

// Initializing an NSBundle 

- (id)initWithPath:(NSString*)path;

// Getting an NSBundle 

+ (NSArray *)allBundles;
+ (NSArray *)allFrameworks;
+ (NSBundle *)bundleForClass:(Class)aClass;
+ (NSBundle *)bundleWithPath:(NSString*)path;
+ (NSBundle *)mainBundle;

// Getting a Bundled Class 

- (Class)classNamed:(NSString *)className;
- (Class)principalClass;

// loading the bundles executable code

- (BOOL)load;

// Finding a Resource 

+ (NSString *)pathForResource:(NSString *)name ofType:(NSString *)ext
  inDirectories:(NSArray*)directories;
- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)ext;
- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)ext
  inDirectory:(NSString *)bundlePath;
- (NSString*)pathForResource:(NSString*)name ofType:(NSString*)ext
  inDirectory:(NSString*)directory
  forLocalization:(NSString*)localizationName;
- (NSArray *)pathsForResourcesOfType:(NSString *)extension
  inDirectory:(NSString *)bundlePath;
- (NSArray *)pathsForResourcesOfType:(NSString *)extension
  inDirectory:(NSString *)bundlePath
  forLocalization:(NSString *)localizationName;

- (NSString *)resourcePath;

// Getting the Bundle Directory 

- (NSString *)bundlePath;

// Getting bundle information

- (NSDictionary *)infoDictionary;

// Managing Localized Resources

- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value
  table:(NSString *)tableName;
- (void)releaseStringtableCache;

// Private methods
+ (NSString *)_fileResourceNamed:(NSString *)fileName
  extension:(NSString *)extension
  inDirectory:(NSString *)directoryName;

@end /* NSBundle */

#endif /* __NSBundle_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
