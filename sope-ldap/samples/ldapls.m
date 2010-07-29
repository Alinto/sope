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

#include <EOControl/EOControl.h>
#include <NGLdap/NGLdapFileManager.h>
#include "common.h"

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  NSUserDefaults *ud;
  NSArray        *args;
  NSFileManager  *fm;
  unsigned i;
  BOOL     doDeep = NO;

  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  args = [[NSProcessInfo processInfo] arguments];
  if ([args count] < 1) {
    NSLog(@"usage: %@ <files>", [args objectAtIndex:0]);
    exit(1);
  }
  else if ([args count] == 1)
    args = [args arrayByAddingObject:@"."];
  
  ud = [NSUserDefaults standardUserDefaults];

  fm = [[NGLdapFileManager alloc]
                           initWithHostName:[ud stringForKey:@"LDAPHost"]
	                   port:[ud integerForKey:@"LDAPPort"]
                           bindDN:[ud stringForKey:@"LDAPBindDN"]
                           credentials:[ud stringForKey:@"LDAPPassword"]
                           rootDN:[ud stringForKey:@"LDAPRootDN"]];
  fm = [fm autorelease];
  
  if (fm == nil) {
    NSLog(@"could not open LDAP connection (got no filemanager).");
    exit(2);
  }
  
  // NSLog(@"LDAP: %@", fm);
  
  for (i = 1; i < [args count]; i++) {
    NSString *path;
    BOOL     isDir;
    
    path = [args objectAtIndex:i];

    if ([path hasPrefix:@"-r"]) {
      doDeep = YES;
      continue;
    }
    
    if ([path hasPrefix:@"-"]) {
      i++;
      continue;
    }
    
    if (![fm fileExistsAtPath:path isDirectory:&isDir]) {
      NSLog(@"file/directory does not exist: %@", path);
      continue;
    }
    
    if (isDir) {
      NSArray  *dirContents;
      unsigned i, count;
      NSString *mid;
      
      dirContents = doDeep
        ? [fm subpathsAtPath:path]
        : [fm directoryContentsAtPath:path];
      
      for (i = 0, count = [dirContents count]; i < count; i++) {
        NSString     *cpath, *apath;
        NSDictionary *info;
        NSString     *owner;
        NSString     *date;
        
        cpath = [dirContents objectAtIndex:i];
        apath = [path stringByAppendingPathComponent:cpath];
        
        info = [fm fileAttributesAtPath:apath
                   traverseLink:NO];
        
        mid = [[info objectForKey:@"NSFileIdentifier"] description];
        if ([mid length] > 39) {
          mid = [mid substringToIndex:37];
          mid = [mid stringByAppendingString:@"..."];
        }

        owner = [info objectForKey:NSFileOwnerAccountName];
        date  = [[info objectForKey:NSFileModificationDate] description];

        if (owner == nil)
          owner = @"-";
        if (date == nil)
          date = @"-";
        
        /* id uid date name */
        printf("%-34s  %20s  %-32s %s",
               [mid   cString],
               [owner cString],
               [date  cString],
               [apath cString]);

        if ([[info objectForKey:NSFileType]
                   isEqualToString:NSFileTypeDirectory])
          printf("/\n");
        else
          printf("\n");
      }
    }
    else {
      /* a file */
      NSData   *contents;
      NSString *s;
      
      if ((contents = [fm contentsAtPath:path]) == nil) {
        NSLog(@"could not get content of record: '%@'", path);
      }
      else {
        s = [[NSString alloc] initWithData:contents
                              encoding:[NSString defaultCStringEncoding]];
        printf("%s\n", [s cString]);
        [s release];
      }
    }
  }

  [pool release];
  
  exit(0);
  return 0;
}
