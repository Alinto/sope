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

#include "NGPop3Client.h"
#include "NGPop3Support.h"
#include "NGMimeMessageParser.h"
#include "NGMimeMessage.h"
#include "common.h"

@implementation NGPop3Client

+ (int)version {
  return 2;
}

+ (id)pop3Client {
  NGActiveSocket *s;
  
  s = [NGActiveSocket socketInDomain:[NGInternetSocketDomain domain]];
  return [[[self alloc] initWithSocket:s] autorelease];
}

- (id)init {
  NSLog(@"%@: init not supported, use initWithSocket: ..", self);
  [self release];
  return nil;
}

- (id)initWithSocket:(id<NGActiveSocket>)_socket {
  if ((self = [super init])) {
    self->socket = [_socket retain];
    NSAssert(self->socket, @"invalid socket parameter");
    
    self->connection = 
      [(NGBufferedStream *)[NGBufferedStream alloc] initWithSource:_socket];
    self->text = 
      [(NGCTextStream *)[NGCTextStream alloc] initWithSource:self->connection];
    
    self->state = [self->socket isConnected]
      ? NGPop3State_AUTHORIZATION
      : NGPop3State_unconnected;
  }
  return self;
}

- (void)dealloc {
  [self->text         release];
  [self->connection   release];
  [self->socket       release];
  [self->lastResponse release];
  [super dealloc];
}

/* accessors */

- (id<NGActiveSocket>)socket {
  return self->socket;
}

- (NGPop3State)state {
  return self->state;
}

- (NGPop3Response *)lastResponse {
  return self->lastResponse;
}

- (void)setDebuggingEnabled:(BOOL)_flag {
  self->isDebuggingEnabled = _flag;
}
- (BOOL)isDebuggingEnabled {
  return self->isDebuggingEnabled;
}

/* connection */

- (BOOL)connectToAddress:(id<NGSocketAddress>)_address {
  NSString *greeting = nil;

  [self requireState:NGPop3State_unconnected];
  
  [self->socket connectToAddress:_address];

  // receive greeting from server
  greeting = [self->text readLineAsString];
  if (self->isDebuggingEnabled)
    [NGTextErr writeFormat:@"S: %@\n", greeting];

  // is it a welcome ?
  if (![greeting hasPrefix:@"+OK"])
    return NO;

  // we are welcome, need to authorize
  [self gotoState:NGPop3State_AUTHORIZATION];

  return YES;
}
- (BOOL)connectToHost:(id)_host {
  return [self connectToAddress:[NGInternetSocketAddress addressWithService:@"pop3"
                                                         onHost:_host
                                                         protocol:@"tcp"]];
}

- (void)disconnect {
  [text   flush];
  [socket close];
  [self   gotoState:NGPop3State_unconnected];
}

/* commands */

- (NGPop3Response *)receiveSimpleReply {
  NSString *line = [self->text readLineAsString];

  if (line) {
    NGPop3Response *response = [NGPop3Response responseWithLine:line];
    ASSIGN(self->lastResponse, response);
  }
  else {
    [self->lastResponse release];
    self->lastResponse = nil;
  }
  return self->lastResponse;
}

- (BOOL)receiveMultilineReply:(NSMutableData *)_data {
  enum {
    NGPop3_begin,
    NGPop3_foundCR,
    NGPop3_foundCRLF,
    NGPop3_foundCRLFP,
    NGPop3_done
  } pState = NGPop3_begin;
  void (*addBytes)(id self, SEL _cmd, void *buffer, unsigned int _bufLen);
  int c;

  addBytes = (void*)[_data methodForSelector:@selector(appendBytes:length:)];

  do {
    c = [self->connection readByte];
    if (c == -1) {
      NSLog(@"ERROR: connection was shut down ..");
      break;
    }

    /*
    if (c >= 32) printf("%i '%c'\n", c, c);
    else         printf("%i\n", c);
    */
    
    NSAssert((c >= 0) && (c <= 255), @"invalid byte read ..");

    if (pState == NGPop3_foundCRLFP) {
      if (c == '\r') { // CR LF . CR
        addBytes(_data, @selector(appendBytes:length:), "\r\n", 2);
        c = [self->connection readByte];
        if (c == '\n') {
          pState = NGPop3_done;
        }
        else {
          char c8 = c;
          NSLog(@"WARNING: found strange sequence: 'CR LF . CR 0x%x'", c);
          addBytes(_data, @selector(appendBytes:length:), ".\r", 2);
          addBytes(_data, @selector(appendBytes:length:), &c8, 1);
          pState = NGPop3_begin;
        }
      }
      else if (c == '\n') { // CR LF . LF
        NSLog(@"WARNING: found strange sequence: 'CR LF . LF'");
        addBytes(_data, @selector(appendBytes:length:), "\r\n.\n", 4);
        pState = NGPop3_begin;
      }
      else { // CR LF . (.|other)
        char c8 = c;
        if (c != '.')
          NSLog(@"WARNING: expected '\\r\\n.\\r' or '\\r\\n..', got '\\r\\n.%c'", c);
        addBytes(_data, @selector(appendBytes:length:), "\r\n", 2);
        addBytes(_data, @selector(appendBytes:length:), &c8, 1);
        pState = NGPop3_begin;
        continue;
      }
    }
    else if (pState == NGPop3_foundCRLF) {
      if (c == '.') { // found: CR LF .
        pState = NGPop3_foundCRLFP;
        continue;
      }
      else if (c == '\r') {
        addBytes(_data, @selector(appendBytes:length:), "\r\n", 2);
        pState = NGPop3_foundCR;
        continue;
      }
      else {
        char c8 = c;
        addBytes(_data, @selector(appendBytes:length:), "\r\n", 2);
        addBytes(_data, @selector(appendBytes:length:), &c8, 1);
        pState = NGPop3_begin;
      }
    }
    else if (pState == NGPop3_foundCR) {
      if (c == '\n') { // found CR LF
        pState = NGPop3_foundCRLF;
        continue;
      }
      else {
        char c8 = c;
        addBytes(_data, @selector(appendBytes:length:), "\r", 1);
        addBytes(_data, @selector(appendBytes:length:), &c8, 1);
        pState = NGPop3_begin;
      }
    }
    else if (c == '\r') {
      pState = NGPop3_foundCR;
      continue;
    }
    /*
    else if (c == '\n') {
      NSLog(@"WARNING: found LF without leading CR ..");
      pState = NGPop3_foundCRLF;
      continue;
      }*/
    else {
      char c8 = c;
      addBytes(_data, @selector(appendBytes:length:), &c8, 1);
    }
  }
  while(pState != NGPop3_done);
  
  return (pState == NGPop3_done) ? YES : NO;
}

- (NGPop3Response *)sendCommand:(NSString *)_command {
  if (self->isDebuggingEnabled) {
    [NGTextOut writeFormat:@"C: %@\n", _command];
    [NGTextOut flush];
  }
  
  [text writeString:_command];
  [text writeString:@"\r\n"];
  [text flush];
  return [self receiveSimpleReply];
}

- (NGPop3Response *)sendCommand:(NSString *)_command argument:(NSString *)_argument {
  if (self->isDebuggingEnabled) {
    if (![_command isEqualToString:@"PASS"])
      [NGTextOut writeFormat:@"C: %@ %@\n", _command, _argument];
    else
      [NGTextOut writeFormat:@"C: PASS <hidden>\n"];
  }
  
  [text writeString:_command];
  [text writeFormat:@" %s\r\n", [_argument cString]];
  [text flush];
  return [self receiveSimpleReply];
}
- (NGPop3Response *)sendCommand:(NSString *)_command intArgument:(int)_argument {
  if (self->isDebuggingEnabled) {
    if (![_command isEqualToString:@"PASS"])
      [NGTextOut writeFormat:@"C: %@ %i\n", _command, _argument];
    else
      [NGTextOut writeFormat:@"C: PASS <hidden>\n"];
  }
  
  [text writeString:_command];
  [text writeFormat:@" %i\r\n", _argument];
  [text flush];
  return [self receiveSimpleReply];
}
- (NGPop3Response *)sendCommand:(NSString *)_command
  intArgument:(int)_arg1 intArgument:(int)_arg2 {

  if (self->isDebuggingEnabled) {
    if (![_command isEqualToString:@"PASS"])
      [NGTextOut writeFormat:@"C: %@ %i %i\n", _command, _arg1, _arg2];
    else
      [NGTextOut writeFormat:@"C: PASS <hidden>\n"];
  }
  
  [text writeString:_command];
  [text writeFormat:@" %i %i\r\n", _arg1, _arg2];
  [text flush];
  return [self receiveSimpleReply];
}

// state

- (void)requireState:(NGPop3State)_state {
  if (_state != [self state]) {
    [[[NGPop3StateException alloc]
       initWithClient:self
       requiredState:_state] raise];
  }
}

- (void)gotoState:(NGPop3State)_state {
  self->state = _state;
}

// service commands

- (BOOL)login:(NSString *)_user password:(NSString *)_passwd {
  NGPop3Response *reply = nil;

  [self requireState:NGPop3State_AUTHORIZATION];

  reply = [self sendCommand:@"USER" argument:_user];
  if ([reply isPositive]) {
    reply = [self sendCommand:@"PASS" argument:_passwd];
    if ([reply isPositive]) {
      [self gotoState:NGPop3State_TRANSACTION];
      return YES;
    }
  }
  NSLog(@"POP3 authorization of user %@ failed ..", _user);

  return NO;
}

- (BOOL)quit {
  NGPop3Response *reply = nil;

  reply = [self sendCommand:@"QUIT"];
  if ([reply isPositive]) {
    unsigned int waitBytes = 0;
    
    if (self->state == NGPop3State_TRANSACTION)
      self->state = NGPop3State_UPDATE;

    if (self->isDebuggingEnabled)
      [NGTextErr writeFormat:@"S: %@\n", [reply line]];

    // wait for connection close ..
    while ([self->connection readByte] != -1)
      waitBytes++;

    self->state = NGPop3State_unconnected;
  }
  return [reply isPositive];
}

- (BOOL)statMailDropCount:(int *)_count size:(int *)_size {
  NGPop3Response *reply = nil;
  [self requireState:NGPop3State_TRANSACTION];
  *_count = 0;
  *_size  = 0;

  reply = [self sendCommand:@"STAT"];

  if ([reply isPositive]) {
    const char *cstr = [[reply line] cString];

    while ((*cstr != '\0') && (*cstr != ' ')) cstr++;
    if (*cstr == '\0') return NO;
    cstr++;

    *_count = atoi(cstr);
    while ((*cstr != '\0') && (*cstr != ' ')) cstr++;
    if (*cstr == '\0') return NO;
    cstr++;
    
    *_size = atoi(cstr);
    return YES;
  }
  else
    return NO;
}

- (NGPop3MessageInfo *)listMessage:(int)_messageNumber {
  NGPop3Response *reply = nil;
  [self requireState:NGPop3State_TRANSACTION];

  reply = [self sendCommand:@"LIST" intArgument:_messageNumber];
  if ([reply isPositive]) {
    const char *cstr = index([[reply line] cString], ' ');

    if (cstr) {
      int msgNum;
      cstr++;
      msgNum = atoi(cstr);
      cstr = index(cstr, ' ') + 1;
      if (cstr > (char *)1) {
        NGPop3MessageInfo *info   = nil;
        int               msgSize = atoi(cstr);

        info = [NGPop3MessageInfo infoForMessage:msgNum size:msgSize client:self];
        return info;
      }
    }
    NSLog(@"ERROR: invalid reply line '%@' ..", [reply line]);
  }
  return nil;
}

- (NSEnumerator *)listMessages {
  NGPop3Response *reply = nil;
  [self requireState:NGPop3State_TRANSACTION];

  reply = [self sendCommand:@"LIST"];
  if ([reply isPositive]) {
    NSMutableArray *array = nil;
    NSString       *line  = nil;
    
    array = [NSMutableArray arrayWithCapacity:128];

    line = [self->text readLineAsString];
    while ((line != nil) && (![line isEqualToString:@"."])) {
      NGPop3MessageInfo *info = nil;
      const char        *cstr = (char *)[line cString];
      int               msgNum, msgSize;

      msgNum = atoi(cstr);
      cstr = index(cstr, ' ') + 1;
      if (cstr > (char *)1)
        msgSize = atoi(cstr);
      else {
        NSLog(@"WARNING(%s): invalid reply line '%@'", __PRETTY_FUNCTION__, line);
        msgSize = 0;
      }

      info = [NGPop3MessageInfo infoForMessage:msgNum size:msgSize client:self];

      if (info)
        [array addObject:info];
      else
        NSLog(@"ERROR: could not produce info for line '%@'", line);
      line = [self->text readLineAsString];
    }

    return [array objectEnumerator];
  }
  else
    return nil;
}

- (NSData *)retrieveMessage:(int)_msgNumber {
  NGPop3Response *reply = nil;
  [self requireState:NGPop3State_TRANSACTION];

  reply = [self sendCommand:@"RETR" intArgument:_msgNumber];
  if ([reply isPositive]) {
    NSMutableData *data = nil;
    const char    *cstr = index([[reply line] cString], ' ');
    unsigned msgSize = -1;

    if (cstr) {
      cstr++;
      msgSize = atoi(cstr);
      data = [NSMutableData dataWithCapacity:msgSize + 1];
    }
    else
      data = [NSMutableData dataWithCapacity:1024];

    if ([self receiveMultilineReply:data]) {
      if ((msgSize > 0) && ([data length] > msgSize)) {
        NSLog(@"data was longer than message size ..");
        //[data setLength:msgSize];
      }
      return data;
    }
  }
  return nil;
}

- (BOOL)deleteMessage:(int)_msgNumber {
  NGPop3Response *reply = nil;
  [self requireState:NGPop3State_TRANSACTION];

  reply = [self sendCommand:@"DELE" intArgument:_msgNumber];
  if ([reply isPositive]) {
    return YES;
  }
  return NO;
}

- (BOOL)noop {
  [self requireState:NGPop3State_TRANSACTION];
  return [[self sendCommand:@"NOOP"] isPositive];
}

- (BOOL)reset {
  [self requireState:NGPop3State_TRANSACTION];
  return [[self sendCommand:@"RSET"] isPositive];
}

// optional service commands

- (NSData *)retrieveMessage:(int)_msgNumber bodyLineCount:(int)_numberOfLines {
  NGPop3Response *reply = nil;
  [self requireState:NGPop3State_TRANSACTION];

  reply = [self sendCommand:@"TOP"
                intArgument:_msgNumber
                intArgument:_numberOfLines];
  if ([reply isPositive]) {
    NSMutableData *data = nil;
    const char    *cstr = index([[reply line] cString], ' ');
    int  msgSize = -1;

    if (cstr) {
      cstr++;
      msgSize = atoi(cstr);
    }
    data = [NSMutableData dataWithCapacity:1024];

    if ([self receiveMultilineReply:data])
      return data;
  }
  return nil;
}

- (NSDictionary *)uniqueIdMappings {
  NGPop3Response *reply = nil;
  [self requireState:NGPop3State_TRANSACTION];

  reply = [self sendCommand:@"UIDL"];
  if ([reply isPositive]) {
    NSMutableDictionary *dict = nil;
    NSString            *line  = nil;

    dict = [NSMutableDictionary dictionaryWithCapacity:256];

    line = [self->text readLineAsString];
    while ((line != nil) && (![line isEqualToString:@"."])) {
      const char *cstr = index([line cString], ' ');

      if (cstr) {
        int msgNum = atoi([line cString]);

        cstr++;
        [dict setObject:[NSString stringWithCString:cstr]
              forKey:[NSNumber numberWithInt:msgNum]];
      }
      else {
        NSLog(@"WARNING(%s): invalid reply line '%@'", __PRETTY_FUNCTION__, line);
      }
      line = [self->text readLineAsString];
    }

    return dict;
  }
  else
    return nil;
}

- (NSString *)uniqueIdOfMessage:(int)_messageNumber {
  NGPop3Response *reply = nil;
  [self requireState:NGPop3State_TRANSACTION];

  reply = [self sendCommand:@"UIDL" intArgument:_messageNumber];
  if ([reply isPositive]) {
    const char *cstr = index([[reply line] cString], ' ');

    if (cstr) { // found message number
      cstr = index(cstr + 1, ' ');
      if (cstr) { // found u-id
        cstr++;
        return [NSString stringWithCString:cstr];
      }
    }
    NSLog(@"ERROR: invalid reply line '%@' ..", [reply line]);
  }
  return nil;
}

/* MIME support */

- (NSEnumerator *)messageEnumerator {
  return [[[NGPop3MailDropEnumerator alloc]
              initWithMessageInfoEnumerator:[self listMessages]] autorelease];
}
- (NGMimeMessage *)messageWithNumber:(int)_messageNumber {
  NSData *msgData = [self retrieveMessage:_messageNumber];
  
  if (msgData) {
    NGDataStream        *msgStream;
    NGMimeMessageParser *parser;
    NGMimeMessage       *message;

    msgStream = [[NGDataStream alloc] initWithData:msgData];
    parser    = [[NGMimeMessageParser alloc] init];
    *(&message) = nil;

    NS_DURING
      message = (NGMimeMessage *)[parser parsePartFromStream:msgStream];
    NS_HANDLER
      message = nil;
    NS_ENDHANDLER;

    message = [message retain];

    [parser    release]; parser    = nil;
    [msgStream release]; msgStream = nil;
    msgData = nil;
    
    return [message autorelease];
  }
  else
    return nil;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<POP3Client[0x%p]: socket=%@>",
                     self, [self socket]];
}

@end /* NGPop3Client */
