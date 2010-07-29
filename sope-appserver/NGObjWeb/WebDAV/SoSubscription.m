/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#include "SoSubscription.h"
#include <NGStreams/NGDatagramPacket.h>
#include <NGStreams/NGDatagramSocket.h>
#include <NGStreams/NGInternetSocketAddress.h>
#include <NGStreams/NGInternetSocketDomain.h>
#include "common.h"

@implementation SoSubscription

static BOOL debugOn = YES;

- (id)initWithID:(NSString *)_sid
  url:(NSURL *)_url observer:(NSURL *)_callback
  type:(NSString *)_type delay:(NSTimeInterval)_delay
  lifetime:(NSTimeInterval)_lifetime
{
  if ((self = [super init])) {
    self->subscriptionType = [_type copy];
    self->sid      = [_sid      copy];
    self->object   = [_url      retain];
    self->observer = [_callback retain];
    self->lifetime = _lifetime;
    self->delay    = _delay;
    
    self->expireDate = [[NSDate alloc] initWithTimeIntervalSinceNow:_lifetime];
  }
  return self;
}
- (id)init {
  [self release];
  return nil;
}

- (void)dealloc {
  [self->sid        release];
  [self->object     release];
  [self->observer   release];
  [self->expireDate release];
  [self->subscriptionType release];
  [super dealloc];
}

/* accessors */

- (NSDate *)expirationDate {
  return self->expireDate;
}
- (NSString *)subscriptionID {
  return self->sid;
}

- (BOOL)hasEventsPending {
  return self->pending > 0 ? YES : NO;
}

/* operations */

- (void)resetEvents {
  self->pending = 0;
}

- (BOOL)isValidForURL:(NSURL *)_url {
  return YES;
}

- (BOOL)isExpired {
  NSDate *now;
  
  if (self->expireDate == nil) 
    return NO;
  
  now = [NSDate date];
  return [now timeIntervalSince1970] > [self->expireDate timeIntervalSince1970]
    ? YES : NO;
}

- (BOOL)renewSubscription {
  [self->expireDate release]; 
  self->expireDate = nil;
  
  self->expireDate =
    [[NSDate alloc] initWithTimeIntervalSinceNow:self->lifetime];
  return YES;
}

/* send-notify */

- (BOOL)sendNotification {
  static NGDatagramSocket *socket = nil;
  NGInternetSocketAddress *address;
  NGDatagramPacket *packet;
  NSMutableString  *ms;
  NSData           *data;
  
  [self debugWithFormat:@"sending notification ..."];
  
  /* construct HTTP-over-UDP request */
  
  ms = [NSMutableString stringWithCapacity:16];
  [ms appendString:@"NOTIFY "];
  [ms appendString:[self->observer absoluteString]];
  [ms appendString:@" HTTP/1.1\r\n"];
  [ms appendString:@"Subscription-id: "];
  [ms appendString:self->sid];
  [ms appendString:@"\r\n"];
  
  /* send packet */
  
  data    = [ms dataUsingEncoding:NSUTF8StringEncoding];
  packet  = (NGDatagramPacket *)[NGDatagramPacket packetWithData:data];
  address = [NGInternetSocketAddress addressWithPort:
                                       [[self->observer port] intValue]
                                     onHost:
                                       [self->observer host]];
  
  if (socket == nil) {
    socket = [[NGDatagramSocket alloc] initWithDomain:
                                         [NGInternetSocketDomain domain]];
  }
  [packet setReceiver:address];
  
  self->pending++;
  
  return [socket sendPacket:packet timeout:3.0];
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* SoSubscription */
