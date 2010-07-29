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
#include <NGStreams/NGStreams.h>
#include <NGStreams/NGNet.h>

@interface TestSock : NSObject
- (void)runSMTPTest:(NSString *)sockClassName:(NSString *)host:(int)port;
- (void)runHTTPTest:(NSString *)sockClassName:(NSString *)host:(int)port;
- (void)runIMAP4Test:(NSString *)sockClassName:(NSString *)host:(int)port;
@end

@interface SockTest : NSObject
{
  id    address;
  Class socketClass;

  NGActiveSocket *socket;
  NGCTextStream  *txt;
}

+ (id)test:(NSString *)sockClassName:(NSString *)host:(int)port;

@end

@implementation SockTest

- (id)init:(NSString *)sockClassName:(NSString *)host:(int)port {
  if ((self = [super init])) {
    self->address = 
      [[NGInternetSocketAddress addressWithPort:port onHost:host] retain];
    NSLog(@"addr: %@", self->address);
    
    if ((self->socketClass = NSClassFromString(sockClassName)) == Nil) {
      [self logWithFormat:@"did not find socket class %@", sockClassName];
      [self release];
    }
  }
  return self;
}

+ (id)test:(NSString *)_s:(NSString *)host:(int)port {
  return [[[self alloc] init:_s:host:port] autorelease];
}

- (void)dealloc {
  [self->address release];
  [super dealloc];
}

/* tests */

- (void)runSMTPTest {
  [self->txt writeString:@"HELO imap\r\n"];
  NSLog(@"read: %@", [self->txt readLineAsString]);
}

- (void)_readHTTP {
  NSString *s;
  BOOL isRespLine = YES;
  BOOL isHeader   = NO;
  BOOL hasContent = YES;

  while ((s = [txt readLineAsString])) {
    if (isRespLine) {
      isRespLine = NO;
      isHeader   = YES;
      NSLog(@"SR: %@", s);
    }
    else if (isHeader) {
      if ([s length] == 0) {
	isHeader = NO;
	if (!hasContent) break;
      }
      else {
	NSLog(@"SH: %@", s);
	
	s = [s lowercaseString];
	if ([s hasPrefix:@"content-length:"]) {
	  s = [s substringFromIndex:[@"content-length:" length]];
	  s = [s stringByTrimmingSpaces];
	  //NSLog(@"content-length: %i", [s intValue]);
	  hasContent = [s intValue] != 0;
	}
      }
    }
    else {
      NSLog(@"SB: %@ (len=%u)", s, [s length]);
    }
  }
}

- (void)runHTTPTest {
  NSString *s;
  
  if ((s = [[NSUserDefaults standardUserDefaults] stringForKey:@"url"])==nil)
    s = @"/";
  
  NSLog(@"C: GET %@ HTTP/1.0", s);
  [txt writeFormat:@"GET %@ HTTP/1.0\r\n\r\n", s];
  
  [self _readHTTP];
}

- (void)runXmlRpcTest {
  NSString *s;
  
  if ((s = [[NSUserDefaults standardUserDefaults] stringForKey:@"url"])==nil)
    s = @"/RPC2";
  
  NSLog(@"C: GET %@ HTTP/1.0", s);
  [txt writeFormat:@"POST %@ HTTP/1.0\r\n", s];
  [txt writeString:@"content-type: text/xml\r\n"];
  [txt writeString:@"\r\n"];
  [txt writeString:@"<?xml version=\"1.0\"?>\n"];
  [txt writeString:@"<methodCall>\n"];
  [txt writeString:@"<methodName>system.listMethods</methodName>\n"];
  [txt writeString:@"<params>\n"];
  [txt writeString:@"</params>\n"];
  [txt writeString:@"</methodCall>\n"];
  
  [self _readHTTP];
}

- (void)runIMAP4Test {
  NSString *s;
  
  NSLog(@"reading IMAP server hello ...");
  s = [self->txt readLineAsString];
  NSLog(@"S: %@", s);
}

/* common stuff */

- (void)setUp {
  self->socket = 
    [[self->socketClass socketConnectedToAddress:self->address] retain];
  self->txt = 
    [[NGCTextStream textStreamWithSource:self->socket] retain];
}
- (void)tearDown {
  [self->txt    close];
  [self->txt    release];
  [self->socket release];
}

- (void)handleException:(NSException *)_e {
  [self logWithFormat:@"FAIL: %@", _e];
}

- (void)runTest:(NSString *)_name {
  NSAutoreleasePool *pool;
  SEL s;
  
  pool = [[NSAutoreleasePool alloc] init];

  NSLog(@"-------------------- RUN: %@", _name);
  
  s = NSSelectorFromString([NSString stringWithFormat:@"run%@Test", _name]);
  
  [self setUp];
  
  NS_DURING
    [self performSelector:s];
  NS_HANDLER
    [self handleException:localException];
  NS_ENDHANDLER;

  NS_DURING
    [self tearDown];
  NS_HANDLER
    ;
  NS_ENDHANDLER;
  
  NSLog(@"-------------------- DONE: %@\n", _name);
  [pool release];
}

@end /* SockTest */


@implementation TestSock

- (void)runSMTPTest:(NSString *)sockClassName:(NSString *)host:(int)port {
  [[SockTest test:sockClassName:host:port] runTest:@"SMTP"];
}

- (void)runHTTPTest:(NSString *)sockClassName:(NSString *)host:(int)port {
  [[SockTest test:sockClassName:host:port] runTest:@"HTTP"];
}

- (void)runIMAP4Test:(NSString *)sockClassName:(NSString *)host:(int)port {
  [[SockTest test:sockClassName:host:port] runTest:@"IMAP4"];
}

@end /* TestSock */

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  TestSock *sock;
  
  pool = [[NSAutoreleasePool alloc] init];

#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  sock = [[TestSock alloc] init];
  
#if 0  
  [sock runSMTPTest:@"NGActiveSocket":@"imap.mdlink.de":25];
  [sock runSMTPTest:@"NGActiveSocket":@"skyrix.in.skyrix.com":25];

  [sock runHTTPTest:@"NGActiveSocket":@"www.skyrix.de":80];
  [sock runHTTPTest:@"NGActiveSSLSocket":@"skyrix.in.skyrix.com":443];

  [sock runIMAP4Test:@"NGActiveSSLSocket":@"skyrix.in.skyrix.com":993];

  [sock runHTTPTest:@"NGActiveSSLSocket":@"localhost":505];
#endif
  
  [[SockTest test:@"NGActiveSSLSocket":@"localhost":505] runTest:@"XmlRpc"];
  
  [pool release];
  return 0;
}
