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

#include "iCalPortal.h"
#include "iCalPortalDatabase.h"
#include "iCalRequestHandler.h"
#include <NGObjWeb/WORequestHandler.h>
#include "common.h"

@implementation iCalPortal

- (id)init {
  if ((self = [super init])) {
    WORequestHandler *rh;
    NSString *dbpath;

    /* setup database */
    
    dbpath = [[NSUserDefaults standardUserDefaults] stringForKey:@"DBPath"];
    if ([dbpath length] == 0) {
      [self logWithFormat:@"configured no DBPath, using ./db ..."];
      dbpath = [[NSFileManager defaultManager] currentDirectoryPath];
      dbpath = [dbpath stringByAppendingPathComponent:@"db"];
    }
    
    self->db = [[iCalPortalDatabase alloc] initWithPath:dbpath];
    
    if (self->db == nil) {
      [self logWithFormat:@"couldn't setup database at path: %@", dbpath];
      [self release];
      exit(1);
      return nil;
    }
    
    /* setup request handlers */
    
    rh = [[NSClassFromString(@"OWViewRequestHandler") alloc] init];
    [self registerRequestHandler:rh
          forKey:[WOApplication componentRequestHandlerKey]];
    [rh release];
    
    rh = [self requestHandlerForKey:
		 [WOApplication directActionRequestHandlerKey]];
    [self setDefaultRequestHandler:rh];

    rh = [[iCalRequestHandler alloc] init];
    [self registerRequestHandler:rh forKey:@"ical"];
    [rh release];
  }
  return self;
}

- (void)dealloc {
  [self->db release];
  [super dealloc];
}

/* exception handling */

- (WOResponse *)handleException:(NSException *)_exc
  inContext:(WOContext *)_ctx
{
  printf("EXCEPTION: %s\n", [[_exc description] cString]);
  abort();
}

/* accessors */

- (iCalPortalDatabase *)database {
  return self->db;
}

@end /* iCalPortal */

@implementation NSObject(A)
- (int)indexOfString:(NSString *)_s {
  printf("NOPE!:\n");
  printf("%s\n%s\n", [self cString], [_s cString]);
  abort();
}
@end

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;

  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  WOWatchDogApplicationMain(@"iCalPortal", argc, (void*)argv);

  [pool release];
  return 0;
}
