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
#include <NGExtensions/NGObjCRuntime.h>
#include <objc/objc.h>

#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY
#  include <NGExtensions/NGObjectMacros.h>
#endif

#if APPLE_RUNTIME
#  include <objc/objc-class.h>
#  ifndef sel_get_name
#    define sel_get_name sel_getName
#  endif
#endif

static void myPrint(id self, SEL _cmd, int arg) {
  NSLog(@"%s: self=%@, _cmd=%@, arg=%i", 
	__PRETTY_FUNCTION__,
	self, NSStringFromSelector(_cmd), arg);
}

@interface NSObject(MyPrint)
+ (void)myPrint:(int)i;
- (void)myPrint:(int)i;
@end

@interface TestSubclassing : NSObject
+ (void)run;
@end

@implementation TestSubclassing

- (void)printPreInfo {
  NSLog(@"mt: %s", [NSWillBecomeMultiThreadedNotification cString]);

  NSLog(@"class NSObject:  size=%d", [NSObject  instanceSize]);
  NSLog(@"class NSString:  size=%d", [NSString  instanceSize]);
  NSLog(@"class NSRunLoop: size=%d", [NSRunLoop instanceSize]);
}

- (void)testNSObjectSubclassing {
  Class c;
  id    o;

  /* subclass NSObject */
  
  c = [NSObject subclass:@"MyObject"
                ivars:@"blah", @"@", @"blub", @"c", @"blab", @"s", nil];
  
  printf("MyObject is 0x%p\n", (unsigned)c);
  printf("MyObject name is %s\n", c->name);
  printf("MyObject super-name is %s\n", c->super_class->name);
  
  NSLog(@"MyObject: %@", c);
  o = [[c alloc] init];
  NSLog(@"MyObject-instance: %@", o);
  [o release]; o = nil;
}

- (void)testInstanceAddMethods {
  Class c;
  id    o;
  
  c = NSClassFromString(@"MyObject");
  o = [[c alloc] init];
  NSLog(@"MyObject-instance: %@", o);

  NSLog(@" new instance respondsto 'myPrint:': %s",
        [o respondsToSelector:@selector(myPrint:)] ? "yes" : "no");

  NSLog(@" adding selector 'myPrint:' ...");
  
  [c addMethods:@selector(myPrint:), @"v@:i", myPrint, nil];
  NSLog(@" instance respondsto 'myPrint' after add: %s",
        [o respondsToSelector:@selector(myPrint:)] ? "yes" : "no");

  NSLog(@" call 'myPrint:14':");
  [o myPrint:14];
  
  [o release]; o = nil;
}

- (void)testClassAddMethods {
  Class c;
  
  c = NSClassFromString(@"MyObject");

  NSLog(@" class respondsto 'myPrint': %s",
        [c respondsToSelector:@selector(myPrint:)] ? "yes" : "no");
  
  NSLog(@" adding selector 'myPrint:' ...");
  [c addClassMethods:@selector(myPrint:), @"v@:i", myPrint, nil];
  
  NSLog(@" class respondsto 'myPrint' after add: %s",
        [c respondsToSelector:@selector(myPrint:)] ? "yes" : "no");

  NSLog(@" call 'myPrint:42':");
  [c myPrint:42];
}

- (void)testNSRunLoopSubclassing {
  Class c;
  
  c = [NSRunLoop subclass:@"MyRunLoop"
                 ivars:@"blah", @"@", @"blub", @"c", @"blab", @"s", nil];

  printf("MyRunLoop is 0x%p\n", (unsigned int)c);
  printf("MyRunLoop name is %s\n", c->name);
  printf("MyRunLoop super-name is %s\n", c->super_class->name);
  
  NSLog(@"MyRunLoop: %@", c);
  NSLog(@"MyRunLoop-instance: %@", [[c alloc] init]);
  NSLog(@"MyRunLoop ivars: class=%@ all=%@",
        [c instanceVariableNames], [c allInstanceVariableNames]);
  NSLog(@"  signature of blub: %@",
        [c signatureOfInstanceVariableWithName:@"blub"]);
}

- (void)run {
  [self printPreInfo];
  [self testNSObjectSubclassing];
  [self testInstanceAddMethods];
  [self testClassAddMethods];
  [self testNSRunLoopSubclassing];
}

+ (void)run {
  [[[[self alloc] init] autorelease] run];
}

@end /* TestSubclassing */

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  
  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  [TestSubclassing run];
  
  [pool release];
  return 0;
}
