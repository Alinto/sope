/*
  Copyright (C) 2005 SKYRIX Software AG
  
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

#include "WOCoreDataApplication.h"
#include "common.h"

@implementation WOCoreDataApplication

- (void)dealloc {
  [self->storeCoordinator   release];
  [self->managedObjectModel release];
  [super dealloc];
}

/* accessors */

- (NSManagedObjectModel *)managedObjectModel {
  NSMutableSet *allBundles;
  
  if (self->managedObjectModel != nil)
    return [self->managedObjectModel isNotNull] ? self->managedObjectModel:nil;

  allBundles = [[NSMutableSet alloc] initWithCapacity:16];
  [allBundles addObject:[NSBundle mainBundle]];
  [allBundles addObject:[NSBundle allFrameworks]];
    
  /* 'nil' says: just scan the mainbundle */
  self->managedObjectModel =
    [[NSManagedObjectModel mergedModelFromBundles:nil] retain];
    
  [allBundles release]; allBundles = nil;
  
  if (self->managedObjectModel == nil)
    [self errorWithFormat:@"Could not create the managed object model!"];
  
  return self->managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
  NSFileManager *fileManager;
  NSError *error;
  BOOL    ok;
  
  if (self->storeCoordinator != nil)
    return [self->storeCoordinator isNotNull] ? self->storeCoordinator : nil;

  /* create support folder */
  
  fileManager = [NSFileManager defaultManager];
  if (![fileManager fileExistsAtPath:[self applicationSupportFolder]
		    isDirectory:NULL] ) {
    [fileManager createDirectoryAtPath:[self applicationSupportFolder]
		 attributes:nil];
  }
    
  /* create store coordinator */
  
  self->storeCoordinator = 
    [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:
					    [self managedObjectModel]];

  ok = [self->storeCoordinator 
	    addPersistentStoreWithType:[self defaultPersistentStoreType]
	    configuration:nil
	    URL:[self defaultPersistentStoreURL]
	    options:nil error:&error] != nil ? YES : NO;
  if (!ok) {
    [self errorWithFormat:
	    @"Failed to create persistent store coordinator: %@", error];
    
    [self->storeCoordinator release]; self->storeCoordinator = nil;
    
    self->storeCoordinator = [[NSNull null] retain];
    return nil;
  }
  
  return self->storeCoordinator;
}

/* locating the default store */

- (NSString *)applicationSupportFolder {
  unsigned char path[1024];
  NSString *p;
  FSRef foundRef;
  OSErr err;
  
  err = FSFindFolder(kUserDomain, kApplicationSupportFolderType, 
		     kDontCreateFolder, &foundRef);
  if (err != noErr) {
    [self errorWithFormat:@"Can't find application support folder."];
    return nil;
  }
  
  FSRefMakePath(&foundRef, path, sizeof(path));
  p = [NSString stringWithUTF8String:(char *)path]; // TODO: is UTF-8 ok?
  p = [p stringByAppendingPathComponent:[self name]];
  return p;
}

- (NSURL *)defaultPersistentStoreURL {
  NSString *s;
  
  s = [[self name] stringByDeletingPathExtension];
  s = [s stringByAppendingPathExtension:@"xml"];
  s = [[self applicationSupportFolder] stringByAppendingPathComponent:s];
  return [NSURL fileURLWithPath:s];
}
- (NSString *)defaultPersistentStoreType {
  return [[[self defaultPersistentStoreURL] path] hasSuffix:@".xml"]
    ? NSXMLStoreType : NSSQLiteStoreType;
}

/* creating editing contexts */

- (NSManagedObjectContext *)createManagedObjectContext {
  NSManagedObjectContext *ctx;
  
  ctx = [[[NSManagedObjectContext alloc] init] autorelease];
  [ctx setPersistentStoreCoordinator:[self persistentStoreCoordinator]];
  return ctx;
}

@end /* WOCoreDataApplication */
