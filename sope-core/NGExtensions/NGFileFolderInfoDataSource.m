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

#include <NGExtensions/NGFileFolderInfoDataSource.h>
#import <EOControl/EOFetchSpecification.h>
#import <EOControl/EOQualifier.h>
#import <EOControl/EOSortOrdering.h>
#include "common.h"

NGExtensions_DECLARE NSString *NSFileName      = @"NSFileName";
NGExtensions_DECLARE NSString *NSFilePath      = @"NSFilePath";
NGExtensions_DECLARE NSString *NSParentPath    = @"NSParentPath";
NGExtensions_DECLARE NSString *NSTraverseLinks = @"NSTraverseLinks";

@implementation NGFileFolderInfoDataSource

- (id)initWithFolderPath:(NSString *)_path {
  if ((self = [self init])) {
    self->folderPath = [_path copy];
  }
  return self;
}

- (void)dealloc {
  [self->fspec      release];
  [self->folderPath release];
  [super dealloc];
}

/* accessors */

- (void)setFetchSpecification:(EOFetchSpecification *)_fspec {
  ASSIGN(self->fspec, _fspec);
}
- (EOFetchSpecification *)fetchSpecification {
  return self->fspec;
}

/* operations */

- (NSArray *)_attributesForPaths:(NSEnumerator *)_paths
  filterUsingQualifier:(EOQualifier *)_q
  fileManager:(NSFileManager *)_fm
{
  NSMutableArray      *ma;
  NSMutableDictionary *workArea;
  NSArray             *result;
  NSString            *path;
  BOOL                tlinks;
  
  ma       = [NSMutableArray arrayWithCapacity:256];
  workArea = [NSMutableDictionary dictionaryWithCapacity:32];
  
  tlinks = [[[self->fspec hints] objectForKey:@"NSTraverseLinks"] boolValue];
  
  while ((path = [_paths nextObject])) {
    NSDictionary *record;
    NSString     *fullPath;
    
    fullPath = [self->folderPath stringByAppendingPathComponent:path];
    
    [workArea setDictionary:
                [_fm fileAttributesAtPath:fullPath traverseLink:tlinks]];
    [workArea setObject:path             forKey:@"NSFileName"];
    [workArea setObject:fullPath         forKey:@"NSFilePath"];
    [workArea setObject:self->folderPath forKey:@"NSParentPath"];
    
    record = [[workArea copy] autorelease];
    
    if (_q) {
      if (![(id<EOQualifierEvaluation>)_q evaluateWithObject:record])
        /* filter out */
        continue;
    }

    /* add to result set */
    [ma addObject:record];
  }
  
  result = [[ma copy] autorelease];
  return result;
}

- (NSArray *)_fetchObjectsFromFileManager:(NSFileManager *)_fm {
  NSAutoreleasePool *pool;
  BOOL        isDir;
  NSArray     *array;
  NSArray     *sortOrderings;

  if (![_fm fileExistsAtPath:self->folderPath isDirectory:&isDir])
    /* path does not exist */
    return nil;
  if (!isDir)
    /* path is not a directory */
    return nil;
  
  pool = [[NSAutoreleasePool alloc] init];
  
  array = [_fm directoryContentsAtPath:self->folderPath];
  
  if ([array count] == 0) {
    /* no directory contents */
    array = [array retain];
    [pool release];
    return [array autorelease];
  }

  array = [self _attributesForPaths:[array objectEnumerator]
                filterUsingQualifier:[self->fspec qualifier]
                fileManager:_fm];
  
  if ((sortOrderings = [self->fspec sortOrderings]))
    /* sort set */
    array = [array sortedArrayUsingKeyOrderArray:sortOrderings];
  
  array = [array retain];
  [pool release];
  
  return [array autorelease];
}

- (NSArray *)fetchObjects {
  NSFileManager *fm;
  
  fm = [NSFileManager defaultManager];
  return [self _fetchObjectsFromFileManager:fm];
}

@end /* NGFileInfoDataSource */
