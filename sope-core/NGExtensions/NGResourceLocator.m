/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#include "NGResourceLocator.h"
#include "NSNull+misc.h"
#include "common.h"

@implementation NGResourceLocator

+ (id)resourceLocatorForGNUstepPath:(NSString *)_path fhsPath:(NSString *)_fhs{
  return [[[self alloc] initWithGNUstepPath:_path fhsPath:_fhs] autorelease];
}

- (id)initWithGNUstepPath:(NSString *)_path fhsPath:(NSString *)_fhs {
  if ((self = [super init])) {
    self->gsSubPath   = [_path copy];
    self->fhsSubPath  = [_fhs  copy];
    self->fileManager = [[NSFileManager defaultManager] retain];
    
    self->flags.cacheSearchPathes = 1;
    self->flags.cachePathMisses   = 1;
    self->flags.cachePathHits     = 1;
  }
  return self;
}
- (id)init {
#if GNUSTEP_BASE_LIBRARY
  return [self initWithGNUstepPath:@"Resources" fhsPath:@"share"];
#else
  return [self initWithGNUstepPath:@"Library/Resources" fhsPath:@"share"];
#endif
}

- (void)dealloc {
  [self->nameToPathCache release];
  [self->searchPathes release];
  [self->fhsSubPath   release];
  [self->gsSubPath    release];
  [self->fileManager  release];
  [super dealloc];
}

/* search pathes */

- (NSArray *)gsRootPathes {
  static NSArray *pathes = nil;
  NSDictionary *env;
  NSString *apath;
  
  if (pathes != nil)
    return [pathes isNotNull] ? pathes : (NSArray *)nil;
  
  env = [[NSProcessInfo processInfo] environment];
  if ((apath = [env objectForKey:@"GNUSTEP_PATHPREFIX_LIST"]) == nil)
    apath = [env objectForKey:@"GNUSTEP_PATHLIST"];
  
  if (![apath isNotNull]) return nil;
  pathes = [[apath componentsSeparatedByString:@":"] copy];
  return pathes;
}

- (NSArray *)fhsRootPathes {
  // TODO: we probably want to make this configurable?! At least with an envvar
  static NSArray *pathes = nil;
  if (pathes == nil) {
    pathes = [[NSArray alloc] initWithObjects:
#ifdef FHS_INSTALL_ROOT
				FHS_INSTALL_ROOT,
#endif
				@"/usr/local/", @"/usr/", nil];
  }
  return pathes;
}

- (NSArray *)collectSearchPathes {
  NSMutableArray *ma;
  NSEnumerator *e;
  NSString *p;
  
  ma = [NSMutableArray arrayWithCapacity:6];

  if ([self->gsSubPath length] > 0) {
    
#if GNUSTEP_BASE_LIBRARY
    NSString *directory;

    e = [NSStandardLibraryPaths() objectEnumerator];
    while ((directory = [e nextObject]))
      [ma addObject: [directory stringByAppendingPathComponent:self->gsSubPath]];
#else

    /* Old hack using GNUSTEP_PATHLIST.  Should be removed at some point.  */
    e = [[self gsRootPathes] objectEnumerator];
    while ((p = [e nextObject]) != nil) {
      p = [p stringByAppendingPathComponent:self->gsSubPath];
      if ([ma containsObject:p])
	continue;
      
      if (![self->fileManager fileExistsAtPath:p])
	continue;
      
      [ma addObject:p];
    }
#endif
  }
  
  e = ([self->fhsSubPath length] > 0)
    ? [[self fhsRootPathes] objectEnumerator]
    : (NSEnumerator *)nil;
  while ((p = [e nextObject]) != nil) {
    p = [p stringByAppendingPathComponent:self->fhsSubPath];
    if ([ma containsObject:p])
      continue;
    
    if (![self->fileManager fileExistsAtPath:p])
      continue;
    
    [ma addObject:p];
  }
  
  return ma;
}

- (NSArray *)searchPathes {
  NSArray *a;
  
  if (self->searchPathes != nil)
    return self->searchPathes;
  
  a = [self collectSearchPathes];
  if (self->flags.cacheSearchPathes) {
    ASSIGNCOPY(self->searchPathes, a);
    return self->searchPathes; /* return copy */
  }
  
  return a;
}

/* cache */

- (void)cachePath:(NSString *)_path forName:(NSString *)_name {
  if (self->nameToPathCache == nil)
    self->nameToPathCache = [[NSMutableDictionary alloc] initWithCapacity:64];
  
  [self->nameToPathCache setObject:(_path ? _path : (NSString *)[NSNull null])
                         forKey:_name];
}

/* operation */

- (NSString *)lookupFileWithName:(NSString *)_name {
  NSEnumerator *e;
  NSString *p;
  
  if (![_name isNotNull] || [_name length] == 0)
    return nil;
  if ((p = [self->nameToPathCache objectForKey:_name]) != nil)
    return [p isNotNull] ? p : (NSString *)nil;
  
  e = [[self searchPathes] objectEnumerator];
  while ((p = [e nextObject]) != nil) {
    p = [p stringByAppendingPathComponent:_name];
    
    if (![self->fileManager fileExistsAtPath:p])
      continue;
    
    [self cachePath:p forName:_name];
    return p;
  }
  
  if (self->flags.cachePathMisses)
    [self cachePath:nil forName:_name];
  return nil;
}

- (NSString *)lookupFileWithName:(NSString *)_name extension:(NSString *)_ext {
  if ([_ext isNotNull] && [_ext length] > 0)
    _name = [_name stringByAppendingPathExtension:_ext];
  return [self lookupFileWithName:_name];
}

- (NSArray *)lookupAllFilesWithExtension:(NSString *)_ext
  doReturnFullPath:(BOOL)_withPath
{
  /* only deliver each filename once */
  NSMutableArray *pathes;
  NSMutableSet   *uniquer;
  NSArray  *lSearchPathes;
  unsigned i, count;
  
  _ext  = ([_ext length] > 0)
    ? [@"." stringByAppendingString:_ext]
    : (NSString *)nil;
  
  uniquer       = [NSMutableSet setWithCapacity:128];
  pathes        = _withPath ? [NSMutableArray arrayWithCapacity:64] : nil;
  lSearchPathes = [self searchPathes];
  
  for (i = 0, count = [lSearchPathes count]; i < count; i++) {
    NSArray  *filenames;
    unsigned j, jcount;
    
    filenames = [self->fileManager directoryContentsAtPath:
		       [lSearchPathes objectAtIndex:i]];
    
    for (j = 0, jcount = [filenames count]; j < jcount; j++) {
      NSString *fn, *pn;
      
      fn = [filenames objectAtIndex:j];
      if (_ext != nil) {
	if (![fn hasSuffix:_ext])
	  continue;
      }
      
      if ([uniquer containsObject:fn])
	continue;
      
      [uniquer addObject:fn];

      /* build and cache path */
      pn = [[lSearchPathes objectAtIndex:i] stringByAppendingPathComponent:fn];
      [self cachePath:pn forName:fn];
      if (_withPath) [pathes addObject:pn];
    }
  }
  
  return _withPath ? (NSArray *)pathes : [uniquer allObjects];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  [ms appendFormat:@" gs=%@ fhs=%@", self->gsSubPath, self->fhsSubPath];
  
  [ms appendString:@" cache"];
  if (self->flags.cacheSearchPathes)
    [ms appendString:@":pathes"];
  if (self->flags.cachePathHits)
    [ms appendString:@":hits"];
  if (self->flags.cachePathMisses)
    [ms appendString:@":misses"];
  [ms appendFormat:@":#%d", [self->nameToPathCache count]];
  
  [ms appendString:@">"];
  return ms;
}

@end /* NGResourceLocator */
