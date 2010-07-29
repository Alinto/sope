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

#ifndef __NGMail_NGSmtpClient_H__
#define __NGMail_NGSmtpClient_H__

#import <Foundation/NSObject.h>
#import <NGStreams/NGStreams.h>
#import <NGStreams/NGSocketProtocols.h>

@class NSString;
@class NGSmtpResponse;

/*
  RFC 821 - SMTP

  This class implements the Simple Mail Transfer Protocol as specified in RFC821.
*/

typedef enum {
  NGSmtpState_unconnected = 1,
  NGSmtpState_connected,
  NGSmtpState_TRANSACTION
} NGSmtpState;

@interface NGSmtpClient : NSObject
{
@protected
  id<NGActiveSocket>       socket;
  NGBufferedStream         *connection;
  id<NGExtendedTextStream> text;

  NGSmtpState state;
  BOOL isDebuggingEnabled;

  struct {
    BOOL hasExpand:1;
    BOOL hasSize:1;
    BOOL hasHelp:1;
    BOOL hasPipelining;
  } extensions;
}

+ (id)smtpClient;
- (id)initWithSocket:(id<NGActiveSocket>)_socket; // designated initializer

// accessors

- (id<NGActiveSocket>)socket;
- (NGSmtpState)state;

- (void)setDebuggingEnabled:(BOOL)_flag;
- (BOOL)isDebuggingEnabled;

// connection

- (BOOL)connectToHost:(id)_host;
- (BOOL)connectToAddress:(id<NGSocketAddress>)_address;
- (void)disconnect;

// state

- (void)requireState:(NGSmtpState)_state;
- (void)denyState:(NGSmtpState)_state;
- (void)gotoState:(NGSmtpState)_state;

// replies

- (NGSmtpResponse *)receiveReply;

// commands

- (NGSmtpResponse *)sendCommand:(NSString *)_command;
- (NGSmtpResponse *)sendCommand:(NSString *)_command argument:(NSString *)arg;

// service commands

- (BOOL)quit;
- (BOOL)helloWithHostname:(NSString *)_host;
- (BOOL)hello;
- (BOOL)noop;
- (BOOL)reset;

- (NSString *)help;
- (NSString *)helpForTopic:(NSString *)_topic;

- (BOOL)verifyAddress:(id)_address;

// transaction commands

- (BOOL)mailFrom:(id)_sender;
- (BOOL)recipientTo:(id)_receiver;
- (BOOL)sendData:(NSData *)_data;

@end

#endif /* __NGMail_NGSmtpClient_H__ */
