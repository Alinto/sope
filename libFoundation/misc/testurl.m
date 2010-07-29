/*
  Checks some URL parsing methods.
*/

#include <Foundation/Foundation.h>

static void test(void) {
  NSString *s;
  NSURL    *u;
  
  s = @"http://localhost:80/imap/user@imaphost/blah/blub";
  u = [NSURL URLWithString:s];
  NSLog(@"compare:\n  str: %@\n  url: %@", s, u);
  
  s = @"http://localhost/imap/user@imaphost/blah/blub";
  u = [NSURL URLWithString:s];
  NSLog(@"compare:\n  str: %@\n  url: %@", s, u);
}

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  test();

  [pool release];
  exit(0);
  return 0;
}
