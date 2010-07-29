/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#include "OFSFolder.h"
#include "common.h"

/*
  Some special WebDAV keys:
    .autodiskmounted - queried by the MacOSX DAV filesystem
    .directory       - queried by Nautilus
  
  both seem to work if the keys do not exist (no special handling required).
*/

@implementation OFSFolder(SoDAV)

static int davDebugOn = 0;

- (BOOL)davIsCollection {
  return YES;
}
- (BOOL)davIsFolder {
  /* this can be overridden by compound documents (aka filewrappers) */
  return [self davIsCollection];
}

- (BOOL)davHasSubFolders {
  /* search for subfolders (tries to be smart and load as little as p. ;-) */
  NSArray  *ak;
  unsigned i, count;
  
  if ((ak = [self allKeys]) == nil) return NO;
  if ((count = [ak count]) == 0) return NO;
  
  /* first scan the already loaded children */
  for (i = 0; i < count; i++) {
    id child;
    
    child = [self->children objectForKey:[ak objectAtIndex:i]];
    if ([child davIsFolder]) return YES;
  }
  
  /* now scan all children */
  
  if (self->flags.didLoadAll) 
    return NO; /* we've already seen all children */
  [self allValues];          /* otherwise trigger a load */
  
  for (i = 0; i < count; i++) {
    id child;
    
    child = [self->children objectForKey:[ak objectAtIndex:i]];
    if ([child davIsFolder]) return YES;
  }
  
  return NO;
}

- (NSString *)fileExtensionForChildrenInContext:(id)_ctx {
  /* 
     This can be used to enforce a common extension for all children, this is
     useful for WebDAV directory listings (eg all children of an address folder
     can appear as vcf files in cadaver or OSX).
  */
  return nil;
}

- (NSEnumerator *)davChildKeysInContext:(id)_ctx {
  NSArray  *keys;
  NSString *ext;
  unsigned len;
  
  keys = [self allKeys];
  if ((len = [keys count]) == 0) {
    if (davDebugOn)
      [self debugWithFormat:@"no DAV child keys for delivery ..."];
    return [keys objectEnumerator];
  }
  
  if ((ext = [self fileExtensionForChildrenInContext:_ctx])) {
    NSMutableArray *ma;
    unsigned i;
    BOOL didChange;
    
    ma = [NSMutableArray arrayWithCapacity:len];
    didChange = NO;
    for (i = 0; i < len; i++) {
      NSString *k, *pe;
      
      k = [keys objectAtIndex:i];
      
      if ((pe = [k pathExtension]) == nil)
	[ma addObject:k];
      else if ([pe length] == 0)
	[ma addObject:k];
      else {
	k = [k stringByDeletingPathExtension];
	k = [k stringByAppendingPathExtension:ext];
	[ma addObject:k];
	didChange = YES;
      }
    }
    if (didChange) keys = ma;
  }
  if (davDebugOn) {
    [self debugWithFormat:@"DAV child keys for delivery: %@",
	    [keys componentsJoinedByString:@","]];
  }
  return [keys objectEnumerator];
}

- (NSException *)davCreateCollection:(NSString *)_name inContext:(id)_ctx {
  id<NSObject,NGFileManager> fm;
  NSString *p;
  BOOL     ok;
  
  if ([_name hasPrefix:@"."]) {
    return [NSException exceptionWithHTTPStatus:405 /* not allowed */
                        reason:@"creation of collections with a "
                          @"leading dot is not allowed."];
  }
  
  [self debugWithFormat:@"should create collection: %@", _name];
  
  p = [[self storagePath] stringByAppendingPathComponent:_name];
  [self debugWithFormat:@"  path for new collection: %@", p];
  
  fm = [self fileManager];
  ok = [fm createDirectoryAtPath:p attributes:nil];
  if (!ok) {
    [self debugWithFormat:@"  could not created collection at: %@", p];
    return [NSException exceptionWithHTTPStatus:405 /* not allowed */
                        reason:
                          @"this OFSFolder could not create the collection"];
  }
  
  [self debugWithFormat:@"  created collection."];
  self->flags.didLoadAll = NO; /* not valid anymore */
  return nil;
}

@end /* OFSFolder(SoDAV) */
