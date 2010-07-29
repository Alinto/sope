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

#ifndef __NGMail_NGPop3Client_H__
#define __NGMail_NGPop3Client_H__

#import <Foundation/NSObject.h>
#include <NGStreams/NGStreams.h>
#include <NGStreams/NGSocketProtocols.h>

@class NSString, NSData;
@class NGBufferedStream;
@class NGMimeMessage;

typedef enum {
  NGPop3State_unconnected = 1,
  NGPop3State_AUTHORIZATION,
  NGPop3State_TRANSACTION,
  NGPop3State_UPDATE
} NGPop3State;

@class NGPop3Response, NGPop3MessageInfo;

@interface NGPop3Client : NSObject
{
@protected
  id<NGActiveSocket>       socket;
  NGBufferedStream         *connection;
  id<NGExtendedTextStream> text;

  NGPop3State    state;
  NGPop3Response *lastResponse;
  BOOL isDebuggingEnabled;
}

+ (id)pop3Client;
- (id)initWithSocket:(id<NGActiveSocket>)_socket; // designated initializer

/* accessors */

- (id<NGActiveSocket>)socket;
- (NGPop3State)state;
- (NGPop3Response *)lastResponse;

- (void)setDebuggingEnabled:(BOOL)_flag;
- (BOOL)isDebuggingEnabled;

/* connection */

- (BOOL)connectToHost:(id)_host;
- (BOOL)connectToAddress:(id<NGSocketAddress>)_address;
- (void)disconnect;

/* state */

- (void)requireState:(NGPop3State)_state;
- (void)gotoState:(NGPop3State)_state;

/* commands */

- (NGPop3Response *)sendCommand:(NSString *)_command;
- (NGPop3Response *)sendCommand:(NSString *)_command argument:(NSString *)arg;
- (NGPop3Response *)sendCommand:(NSString *)_command intArgument:(int)_arg;

/* service commands */

- (BOOL)login:(NSString *)_user password:(NSString *)_passwd;
- (BOOL)quit;

- (BOOL)statMailDropCount:(int *)_count size:(int *)_size;
- (NGPop3MessageInfo *)listMessage:(int)_messageNumber;
- (NSEnumerator *)listMessages;
- (NSData *)retrieveMessage:(int)_msgNumber;
- (BOOL)deleteMessage:(int)_msgNumber;
- (BOOL)noop;
- (BOOL)reset;

/* optional service commands */

- (NSData *)retrieveMessage:(int)_msgNumber bodyLineCount:(int)_numberOfLines;
- (NSDictionary *)uniqueIdMappings;
- (NSString *)uniqueIdOfMessage:(int)_msgNumber;

/* MIME support */

- (NSEnumerator *)messageEnumerator;
- (NGMimeMessage *)messageWithNumber:(int)_messageNumber;

@end

#endif /* __NGMail_NGPop3Client_H__ */
