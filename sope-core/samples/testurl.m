/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#import <Foundation/NSObject.h>
#include <NGExtensions/NSURL+misc.h>

@class NSArray;

@interface TestURL : NSObject

- (int)runWithArguments:(NSArray *)_args;

@end

#include "common.h"

@implementation TestURL

- (void)testUrlSlashSuffix:(NSString *)_url {
  NSURL *url;
  
  url  = [NSURL URLWithString:_url];
  [self logWithFormat:@"Url  URL:  %@", url];
  [self logWithFormat:@"     Abs:  %@", [url absoluteString]];
  [self logWithFormat:@"     Path: %@", [url path]];
  [self logWithFormat:@"  RelPath: %@", [url relativePath]];

  if ([[url absoluteString] hasSuffix:@"/"]
      != [[url path] hasSuffix:@"/"]) {
    [self logWithFormat:@"ERROR: path suffix different from URL suffix!"];
  }
  else
    [self logWithFormat:@"OK: suffix seems to match."];
}

- (void)testStringValueRelativeToURL:(NSString *)_url base:(NSString *)_base 
  expect:(NSString *)_result
{
  NSURL    *url, *base;
  NSString *result;

  base = [NSURL URLWithString:_base];
  [self logWithFormat:@"Base URL:  %@", base];
  [self logWithFormat:@"     Abs:  %@", [base absoluteString]];
  [self logWithFormat:@"     Path: %@", [base path]];
  
  url  = [NSURL URLWithString:_url];
  [self logWithFormat:@"Url  URL:  %@", url];
  [self logWithFormat:@"     Abs:  %@", [url absoluteString]];
  [self logWithFormat:@"     Path: %@", [url path]];
  
  result = [url stringValueRelativeToURL:base];
  [self logWithFormat:@"Relative: %@", result];

  if ([result isEqualToString:_result])
    [self logWithFormat:@"OK matches expected result '%@'", _result];
  else
    [self logWithFormat:@"ERROR: does not meet expectation: '%@'", _result];
}

- (int)runWithArguments:(NSArray *)_args {
  [self testUrlSlashSuffix:@"http://localhost:20000/dbd.woa/so/localhost/"];
  
  [self testStringValueRelativeToURL:
	  @"http://localhost:20000/dbd.woa/so/localhost/Databases/OGo"
	base:@"http://localhost:20000/dbd.woa/so/localhost/"
	expect:@"Databases/OGo"];
  return 0;
}

@end /* TestURL */

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  TestURL *tool;
  int rc;
  
  pool = [[NSAutoreleasePool alloc] init];

#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  tool = [[TestURL alloc] init];
  rc = [tool runWithArguments:
	       [[NSProcessInfo processInfo] argumentsWithoutDefaults]];
  [tool release];
  [pool release];
  return 0;
}
