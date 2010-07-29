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

#include "common.h"
#include <EOControl/EOControl.h>
#include <NGExtensions/NSFileManager+Extensions.h>
#include <NGExtensions/NGFileFolderInfoDataSource.h>
#include <NGExtensions/NGExtensions.h>

@interface BMLookupTool : NSObject
{
  NGBundleManager *bm;
}

- (int)runWithArguments:(NSArray *)_args;

@end

@implementation BMLookupTool

- (id)init {
  if ((self = [super init])) {
    self->bm = [[NGBundleManager defaultBundleManager] retain];
  }
  return self;
}
- (void)dealloc {
  [self->bm release];
  [super dealloc];
}

- (void)listResourcesOfType:(NSString *)btype {
  NSEnumerator *resources;
  id resource;
  
  printf("lookup resources of type: '%s'\n", [btype cString]);

  resources = [[bm providedResourcesOfType:btype] objectEnumerator];
  while ((resource = [resources nextObject])) {
    NSString *rname;
      
    if ((rname  = [resource objectForKey:@"name"]) != nil) {
      NSBundle *bundle;
      
      bundle = [bm bundleProvidingResource:rname ofType:btype];
      printf("  resource  '%s'\n",  [rname cString]);
      printf("    bundle: '%s'\n", [[bundle bundlePath] cString]);
      printf("    info:   %s\n", [[resource description] cString]);
    }
    else
      printf("  resource info: %s\n", [[resource description] cString]);
  }
}

- (void)lookupResourceWithName:(NSString *)bname ofType:(NSString *)btype {
  NSBundle *bundle;
    
  printf("lookup resource '%s' of type: '%s'\n", 
	 [bname cString], [btype cString]);
    
  bundle = [self->bm bundleProvidingResource:bname ofType:btype];
  printf("  bundle: '%s'\n", [[bundle bundlePath] cString]);
  
  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"load"]) {
    if (![bundle load])
      NSLog(@"Could not load bundle: %@", bundle);
    else
      printf("  did load bundle: %s\n", [[bundle description] cString]);
  }
}

- (int)runWithArguments:(NSArray *)_args {
  if ([_args count] < 2) {
    NSLog(@"usage: %@ type name", [[_args objectAtIndex:0] lastPathComponent]);
    return 1;
  }
  
  if ([_args count] == 2) {
    [self listResourcesOfType:[_args objectAtIndex:1]];
    return 0;
  }
  
  [self lookupResourceWithName:[_args objectAtIndex:2]
	ofType:[_args objectAtIndex:1]];
  return 0;
}

@end /* BMLookupTool */

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  int rc;
  
  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  rc = [[[[BMLookupTool alloc] init] autorelease]
	 runWithArguments:
	   [[NSProcessInfo processInfo] argumentsWithoutDefaults]];
  
  [pool release];
  
  exit(rc);
  return rc;
}
