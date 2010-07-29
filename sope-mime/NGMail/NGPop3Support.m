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

#include "NGPop3Support.h"
#include "NGPop3Client.h"
#include "common.h"

@implementation NGPop3Response

+ (int)version {
  return 2;
}

- (id)initWithLine:(NSString *)_line {
  if ((self = [super init])) {
    self->line = [_line copy];
  }
  return self;
}

- (void)dealloc {
  [self->line release];
  [super dealloc];
}

+ (id)responseWithLine:(NSString *)_line {
  return [[[self alloc] initWithLine:_line] autorelease];
}

/* accessors */

- (BOOL)isPositive {
  return [self->line hasPrefix:@"+OK"];
}
- (NSString *)line {
  return self->line;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<Pop3Reply[0x%p]: positive=%s line=%@>",
                     self,
                     [self isPositive] ? "YES" : "NO",
                     [self line]];
}

@end /* NGPop3Response */

@implementation NGPop3MessageInfo

+ (int)version {
  return 2;
}

- (id)initWithNumber:(int)_num size:(int)_size client:(NGPop3Client *)_client{
  if ((self = [super init])) {
    self->messageNumber = _num;
    self->messageSize   = _size;
    self->client        = [_client retain];
  }
  return self;
}

+ (id)infoForMessage:(int)_num size:(int)_size client:(NGPop3Client *)_client {
  return [[[self alloc] initWithNumber:_num size:_size client:_client] autorelease];
}

- (void)dealloc {
  [self->client release];
  [super dealloc];
}

/* accessors */

- (int)messageNumber {
  return self->messageNumber;
}

- (int)size {
  return self->messageSize;
}

- (NGPop3Client *)pop3Client {
  return self->client;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<Pop3MsgInfo[0x%p]: number=%i size=%i>",
                     self, [self messageNumber], [self size]];
}

@end /* NGPop3Response */

@implementation NGPop3MailDropEnumerator

+ (int)version {
  return 2;
}

- (id)initWithMessageInfoEnumerator:(NSEnumerator *)_infos {
  self->msgInfos = [_infos retain];
  return self;
}

- (void)dealloc {
  [self->msgInfos release];
  [super dealloc];
}

- (id)nextObject {
  NGPop3MessageInfo *info    = [self->msgInfos nextObject];
  NGMimeMessage     *message = nil;

  if (info != nil) {
    message = [[info pop3Client] messageWithNumber:[info messageNumber]];
    if (message == nil) {
      NSLog(@"ERROR: could not retrieve message %i, skipping", [info messageNumber]);
      message = [self nextObject];
    }
  }
  return message;
}

@end /* NGPop3MailDropEnumerator */

// ******************** Exceptions ********************

@implementation NGPop3Exception

+ (int)version {
  return 2;
}

@end /* NGPop3Exception */

@implementation NGPop3StateException

+ (int)version {
  return 2;
}

- (id)init {
  return [self initWithClient:nil requiredState:0];
}

- (id)initWithClient:(NGPop3Client *)_client requiredState:(NGPop3State)_state {
  NSString *stateString = nil;

  switch(_state) {
    case NGPop3State_unconnected:   stateString = @"unconnected";   break;
    case NGPop3State_AUTHORIZATION: stateString = @"AUTHORIZATION"; break;
    case NGPop3State_TRANSACTION:   stateString = @"TRANSACTION";   break;
    case NGPop3State_UPDATE:        stateString = @"UPDATE";        break;
    default:
      stateString = @"unknown";
      break;
  }
  
  if ((self = [super initWithFormat:@"operation can only perform in state %@",
                     stateString])) {
    self->requiredState = _state;
  }
  return self;
}

// accessors

- (NGPop3State)requiredState {
  return self->requiredState;
}

@end /* NGPop3StateException */
