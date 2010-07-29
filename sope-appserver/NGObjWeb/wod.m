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

#import <Foundation/Foundation.h>
#include "WODParser.h"

@interface MyWODHandler : NSObject < WODParserHandler >
@end

@implementation MyWODHandler

- (BOOL)parser:(id)_parser willParseDeclarationData:(NSData *)_data {
  return YES;
}
- (void)parser:(id)_parser finishedParsingDeclarationData:(NSData *)_data
  declarations:(NSDictionary *)_decls
{
}
- (void)parser:(id)_parser failedParsingDeclarationData:(NSData *)_data
  exception:(NSException *)_exception
{
  [_exception raise];
}

- (id)parser:(id)_parser makeAssociationWithValue:(id)_value {
  return nil;
}
- (id)parser:(id)_parser makeAssociationWithKeyPath:(NSString *)_keyPath {
  return nil;
}
- (id)parser:(id)_parser makeDefinitionForComponentNamed:(NSString *)_cname
  associations:(id)_entry
  elementName:(NSString *)_elemName
{
  return nil;
}

@end /* MyWODHandler */

static void processFile(NSString *path) {
  NSUserDefaults *ud;
  NSData         *data;
  NSDictionary   *mappings;
  NSException    *e;
  MyWODHandler   *wodHandler;

  wodHandler = [[[MyWODHandler alloc] init] autorelease];
  ud         = [NSUserDefaults standardUserDefaults];
  mappings   = nil;
  e          = nil;
  
  if ((data = [NSData dataWithContentsOfFile:path]) == nil) {
    fprintf(stderr, "%s: could not open file.\n", [path cString]);
    fflush(stderr);
    return;
  }
  if ([data length] == 0)
    /* no content */
    return;
  
  NS_DURING {
    id parser;

    parser = [[[WODParser alloc] initWithHandler:(id)wodHandler] autorelease];
    
    mappings = [parser parseDeclarationData:data];
  }
  NS_HANDLER {
    e = [localException retain];
    //abort();
  }
  NS_ENDHANDLER;
  
  if (e) {
    NSDictionary *ui;
    int line = -1;
    
    if ((ui = [e userInfo]))
      line = [[ui objectForKey:@"line"] intValue];

    if (line > 0) {
      fprintf(stderr, "%s:%i: %s\n",
              [path cString], line,
              [[e reason] cString]);
    }
    else {
      fprintf(stderr, "%s: %s\n",
              [path cString],
              [[e reason] cString]);
    }
  }
  
  if ([ud objectForKey:@"print"]) {
    NSEnumerator *e;
    NSString *key;

    e = [mappings keyEnumerator];
    while ((key = [e nextObject])) {
      id value;
      
      value = [mappings objectForKey:key];
      printf("%s: %s\n", [key cString], [[value description] cString]);
    }
  }
  
  if ([ud objectForKey:@"list"]) {
    id       keys;
    NSString *key;

    keys = [mappings allKeys];
    keys = [keys sortedArrayUsingSelector:@selector(compare:)];
    keys = [keys objectEnumerator];
    
    while ((key = [keys nextObject])) {
      id value;
      
      value = [mappings objectForKey:key];
      printf("%s: %s\n", [key cString], [[value description] cString]);
    }
  }
}

int main(int argc, char **argv, char **env) {
  NSUserDefaults *ud;
  NSAutoreleasePool *pool;
  NSArray      *args;
  id           paths;
  NSString     *path;
  int          i;
  
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  pool = [[NSAutoreleasePool alloc] init];
  args = [[NSProcessInfo processInfo] arguments];

  if (argc < 1)
    exit(0);
  
  ud    = [NSUserDefaults standardUserDefaults];
  *(&paths) = [NSMutableArray array];

  for (*(&i) = 1; i < argc; i++) {
    if (argv[i][0] == '-') {
      NS_DURING 
        [ud setObject:[NSNumber numberWithBool:YES]
            forKey:[NSString stringWithCString:&(argv[i][1])]];
      NS_HANDLER
        abort();
      NS_ENDHANDLER;
    }
    else {
      [paths addObject:[NSString stringWithCString:argv[i]]];
    }
  }
  paths = [paths objectEnumerator];
  
  while ((path = [paths nextObject])) {
    NSAutoreleasePool *pool2;

    pool2 = [[NSAutoreleasePool alloc] init];
    processFile(path);
    [pool2 release];
  }
  
  [pool release];
  exit(0);
  return 0;
}
