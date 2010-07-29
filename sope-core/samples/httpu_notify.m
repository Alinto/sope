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
#include <NGStreams/NGDatagramPacket.h>
#include <NGStreams/NGDatagramSocket.h>
#include <NGStreams/NGInternetSocketAddress.h>
#include <NGStreams/NGInternetSocketDomain.h>

static void run(void) {
  NSUserDefaults *ud;
  NSString *sid;
  NSURL    *observer;
  NGDatagramSocket *socket = nil;
  NGInternetSocketAddress *address;
  NGDatagramPacket *packet;
  NSMutableString  *ms;
  NSData           *data;
  
  ud  = [NSUserDefaults standardUserDefaults];
  sid      = [ud stringForKey:@"sid"];
  observer = [NSURL URLWithString:[ud stringForKey:@"url"]];
  
  if (observer  == nil) {
    NSLog(@"missing observer ! (use -url to specify one !)");
    exit(2);
  }
  
  /* construct HTTP-over-UDP request */
  
  ms = [NSMutableString stringWithCapacity:16];
  [ms appendString:@"NOTIFY "];
  [ms appendString:[observer absoluteString]];
  [ms appendString:@" HTTP/1.1\r\n"];
  
  /* notifications without sid are "teardown's" */
  if ([sid length] > 0) {
    [ms appendString:@"Subscription-id: "];
    [ms appendString:sid];
    [ms appendString:@"\r\n"];
  }
  
  /* send packet */
  
  data    = [ms dataUsingEncoding:NSUTF8StringEncoding];
  packet  = [NGDatagramPacket packetWithData:data];
  address = [NGInternetSocketAddress addressWithPort:
                                       [[observer port] intValue]
                                     onHost:
                                       [observer host]];
  
  socket = [[NGDatagramSocket alloc] initWithDomain:
                                       [NGInternetSocketDomain domain]];
  [packet setReceiver:address];
  
  if (![socket sendPacket:packet timeout:3.0]) {
    NSLog(@"could not send packet %@ on socket %@ !");
    exit(1);
  }
}

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  
  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  run();
  
  exit(0);
  return 0;
}
