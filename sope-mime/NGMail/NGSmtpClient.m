/*
  Copyright (C) 2000-2007 SKYRIX Software AG

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

#include "NGSmtpClient.h"
#include "NGSmtpSupport.h"
#include "NGSmtpReplyCodes.h"
#include "common.h"

//
// Useful extension that comes from Pantomime which is also
// released under the LGPL.
//
@interface NSMutableData (DataCleanupExtension)

- (NSRange) rangeOfCString: (const char *) theCString;
- (NSRange) rangeOfCString: (const char *) theCString
		  options: (unsigned int) theOptions
		    range: (NSRange) theRange;
@end

@implementation NSMutableData (DataCleanupExtension)

- (NSRange) rangeOfCString: (const char *) theCString
{
  return [self rangeOfCString: theCString
	       options: 0
	       range: NSMakeRange(0,[self length])];
}

-(NSRange) rangeOfCString: (const char *) theCString
		  options: (unsigned int) theOptions
		    range: (NSRange) theRange
{
  const char *b, *bytes;
  int i, len, slen;
  
  if (!theCString)
    {
      return NSMakeRange(NSNotFound,0);
    }
  
  bytes = [self bytes];
  len = [self length];
  slen = strlen(theCString);
  
  b = bytes;
  
  if (len > theRange.location + theRange.length)
    {
      len = theRange.location + theRange.length;
    }

  if (theOptions == NSCaseInsensitiveSearch)
    {
      i = theRange.location;
      b += i;
      
      for (; i <= len-slen; i++, b++)
	{
	  if (!strncasecmp(theCString,b,slen))
	    {
	      return NSMakeRange(i,slen);
	    }
	}
    }
  else
    {
      i = theRange.location;
      b += i;
      
      for (; i <= len-slen; i++, b++)
	{
	  if (!memcmp(theCString,b,slen))
	    {
	      return NSMakeRange(i,slen);
	    }
	}
    }
  
  return NSMakeRange(NSNotFound,0);
}

@end

@interface NGSmtpClient(PrivateMethods)
- (void)_fetchExtensionInfo;
@end

@implementation NGSmtpClient

+ (int)version {
  return 2;
}

+ (id)smtpClient {
  NGActiveSocket *s;
  s = [NGActiveSocket socketInDomain:[NGInternetSocketDomain domain]];
  return [[[self alloc] initWithSocket:s] autorelease];
}

- (id)init {
  NSLog(@"%@: init not supported, use initWithSocket: ..", self);
  [self release];
  return nil;
}

- (id)initWithSocket:(id<NGActiveSocket>)_socket { // designated initializer
  if ((self = [super init])) {
    self->socket = [_socket retain];
    NSAssert(self->socket, @"invalid socket parameter");

    [self setDebuggingEnabled:YES];

    self->connection = 
      [(NGBufferedStream *)[NGBufferedStream alloc] initWithSource:_socket];
    self->text = 
      [(NGCTextStream *)[NGCTextStream alloc] initWithSource:self->connection];

    self->state = [self->socket isConnected]
      ? NGSmtpState_connected
      : NGSmtpState_unconnected;
  }
  return self;
}

- (void)dealloc {
  [self->text       release];
  [self->connection release];
  [self->socket     release];
  [super dealloc];
}

// accessors

- (id<NGActiveSocket>)socket {
  return self->socket;
}

- (NGSmtpState)state {
  return self->state;
}

- (void)setDebuggingEnabled:(BOOL)_flag {
  self->isDebuggingEnabled = _flag;
}
- (BOOL)isDebuggingEnabled {
  return self->isDebuggingEnabled;
}

// connection

- (BOOL)connectToHost:(id)_host {
  return [self connectToAddress:
                 [NGInternetSocketAddress addressWithService:@"smtp"
                                          onHost:_host protocol:@"tcp"]];
}

- (BOOL)connectToAddress:(id<NGSocketAddress>)_address {
  NGSmtpResponse *greeting = nil;

  [self requireState:NGSmtpState_unconnected];
  
  if (self->isDebuggingEnabled)
    [NGTextErr writeFormat:@"C: connect to %@\n", _address];
  
  [self->socket connectToAddress:_address];

  // receive greetings from server
  greeting = [self receiveReply];
  if (self->isDebuggingEnabled)
    [NGTextErr writeFormat:@"S: %@\n", greeting];

  if ([greeting isPositive]) {
    [self gotoState:NGSmtpState_connected];
    [self _fetchExtensionInfo];

    if (self->isDebuggingEnabled) {
      if (self->extensions.hasPipelining)
        [NGTextErr writeFormat:@"S: pipelining extension supported.\n"];
      if (self->extensions.hasSize)
        [NGTextErr writeFormat:@"S: size extension supported.\n"];
      if (self->extensions.hasHelp)
        [NGTextErr writeFormat:@"S: help extension supported.\n"];
      if (self->extensions.hasExpand)
        [NGTextErr writeFormat:@"S: expand extension supported.\n"];
    }
    return YES;
  }
  else {
    [self disconnect];
    return NO;
  }
}

- (void)disconnect {
  [text   flush];
  [socket close];
  [self gotoState:NGSmtpState_unconnected];
}

// state

- (void)requireState:(NGSmtpState)_state {
  if (_state != [self state]) {
    [NSException raise:@"SMTPException"
                 format:@"require state %i, now in %i", _state, [self state]];
  }
}
- (void)denyState:(NGSmtpState)_state {
  if ([self state] == _state) {
    [NSException raise:@"SMTPException"
                 format:@"not allowed in state %i", [self state]];
  }
}

- (void)gotoState:(NGSmtpState)_state {
  self->state = _state;
}

- (BOOL)isTransactionInProgress {
  return (self->state == NGSmtpState_TRANSACTION);
}
- (void)abortTransaction {
  [self gotoState:NGSmtpState_connected];
}

// replies

- (NGSmtpResponse *)receiveReply {
  NSMutableString *desc = nil;
  NSString        *line = nil;
  NGSmtpReplyCode code  = -1;

  line = [self->text readLineAsString];
  if ([line length] < 4) {
    NSLog(@"SMTP: reply has invalid format (%@)", line);
    return nil;
  }
  code = [[line substringToIndex:3] intValue];
  //if (self->isDebuggingEnabled)
  //  [NGTextErr writeFormat:@"S: reply with code %i follows ..\n", code];

  desc = [NSMutableString stringWithCapacity:[line length]];
  while ([line characterAtIndex:3] == '-') {
    if ([line length] < 4) {
      NSLog(@"SMTP: reply has invalid format (text=%@, line=%@)", desc, line);
      break;
    }
    [desc appendString:[line substringFromIndex:4]];
    [desc appendString:@"\n"];
    line = [self->text readLineAsString];
  }
  if ([line length] >= 4)
    [desc appendString:[line substringFromIndex:4]];

  return [NGSmtpResponse responseWithCode:code text:desc];
}

// commands

- (NGSmtpResponse *)sendCommand:(NSString *)_command {
  if (self->isDebuggingEnabled) {
    [NGTextOut writeFormat:@"C: %@\n", _command];
    [NGTextOut flush];
  }
  
  [text writeString:_command];
  [text writeString:@"\r\n"];
  [text flush];
  return [self receiveReply];
}
- (NGSmtpResponse *)sendCommand:(NSString *)_command argument:(NSString *)_argument {
  if (self->isDebuggingEnabled) {
    [NGTextOut writeFormat:@"C: %@ %@\n", _command, _argument];
    [NGTextOut flush];
  }
  
  [text writeString:_command];
  [text writeString:@" "];
  [text writeString:_argument];
  [text writeString:@"\r\n"];
  [text flush];
  return [self receiveReply];
}

// service commands

- (void)_fetchExtensionInfo {
  NGSmtpResponse *reply = nil;
  NSString       *hostName = nil;
  
  hostName = [(NGInternetSocketAddress *)[self->socket localAddress] hostName];

  reply = [self sendCommand:@"EHLO" argument:hostName];
  if ([reply code] == NGSmtpActionCompleted) {
    NSEnumerator *lines = [[[reply text] componentsSeparatedByString:@"\n"]
                                   objectEnumerator];
    NSString     *line = nil;

    if (self->isDebuggingEnabled) [NGTextErr writeFormat:@"S: %@\n", reply];

    while ((line = [lines nextObject])) {
      if ([line hasPrefix:@"EXPN"])
        self->extensions.hasExpand = YES;
      else if ([line hasPrefix:@"SIZE"])
        self->extensions.hasSize = YES;
      else if ([line hasPrefix:@"PIPELINING"])
        self->extensions.hasPipelining = YES;
      else if ([line hasPrefix:@"HELP"])
        self->extensions.hasHelp = YES;
    }
    lines = nil;
  }
  else {
    if (self->isDebuggingEnabled) {
      [NGTextErr writeFormat:@"S: %@\n", reply];
      [NGTextErr writeFormat:@" .. could not get extension info.\n"];
    }
  }
}

- (BOOL)_simpleServiceCommand:(NSString *)_command expectCode:(NGSmtpReplyCode)_code {
  NGSmtpResponse *reply = nil;

  [self denyState:NGSmtpState_unconnected];

  reply = [self sendCommand:_command];
  if (self->isDebuggingEnabled) [NGTextErr writeFormat:@"S: %@\n", reply];
  if ([reply isPositive]) {
    if ([reply code] != _code)
      NSLog(@"SMTP(%@): expected reply code %i, got code %i ..",
            _command, _code, [reply code]);
    return YES;
  }
  return NO;
}

- (BOOL)quit {
  NGSmtpResponse *reply = nil;

  [self denyState:NGSmtpState_unconnected];
  
  reply = [self sendCommand:@"QUIT"];
  if (self->isDebuggingEnabled) [NGTextErr writeFormat:@"S: %@\n", reply];
  if ([reply isPositive]) {
    unsigned int waitBytes = 0;
    
    if ([reply code] == NGSmtpServiceClosingChannel) {
      // wait for connection close ..
      while ([self->connection readByte] != -1)
        waitBytes++;
    }
    else
      NSLog(@"SMTP(QUIT): unexpected reply code (%i), disconnecting ..", [reply code]);
    return YES;
  }
  return NO;
}

- (BOOL)helloWithHostname:(NSString *)_host {
  NGSmtpResponse *reply = nil;

  [self denyState:NGSmtpState_unconnected];
  
  reply = [self sendCommand:@"HELO" argument:_host];
  if (self->isDebuggingEnabled) [NGTextErr writeFormat:@"S: %@\n", reply];
  if ([reply isPositive]) {
    if ([reply code] != NGSmtpActionCompleted) {
      NSLog(@"SMTP(HELO): expected reply code %i, got code %i ..",
            NGSmtpActionCompleted, [reply code]);
    }
    return YES;
  }
  return NO;
}
- (BOOL)hello {
  NSString *hostName = nil;
  hostName = [(NGInternetSocketAddress *)[self->socket localAddress] hostName];
  return [self helloWithHostname:hostName];
}

- (BOOL)noop {
  return [self _simpleServiceCommand:@"NOOP" expectCode:NGSmtpActionCompleted];
}

- (BOOL)reset {
  if ([self _simpleServiceCommand:@"RSET" expectCode:NGSmtpActionCompleted]) {
    if ([self isTransactionInProgress])
      [self abortTransaction];
    return YES;
  }
  else
    return NO;
}

- (NSString *)help {
  NGSmtpResponse *reply = nil;

  [self denyState:NGSmtpState_unconnected];
  
  reply = [self sendCommand:@"HELP"];
  if (self->isDebuggingEnabled) [NGTextErr writeFormat:@"S: %@\n", reply];
  if ([reply isPositive]) {
    if ([reply code] != NGSmtpHelpMessage) {
      NSLog(@"SMTP(HELP): expected reply code %i, got code %i ..",
            NGSmtpHelpMessage, [reply code]);
    }
    return [reply text];
  }
  return nil;
}
- (NSString *)helpForTopic:(NSString *)_topic {
  NGSmtpResponse *reply = nil;
  [self denyState:NGSmtpState_unconnected];
  
  reply = [self sendCommand:@"HELP" argument:_topic];
  if (self->isDebuggingEnabled) [NGTextErr writeFormat:@"S: %@\n", reply];
  if ([reply isPositive]) {
    if ([reply code] != NGSmtpHelpMessage) {
      NSLog(@"SMTP(HELP): expected reply code %i, got code %i ..",
            NGSmtpHelpMessage, [reply code]);
    }
    return [reply text];
  }
  return nil;
}

- (BOOL)verifyAddress:(id)_address {
  NGSmtpResponse *reply = nil;
  [self denyState:NGSmtpState_unconnected];

  reply = [self sendCommand:@"VRFY" argument:[_address stringValue]];
  if (self->isDebuggingEnabled) [NGTextErr writeFormat:@"S: %@\n", reply];
  if ([reply isPositive]) {
    if ([reply code] != NGSmtpActionCompleted) {
      NSLog(@"SMTP(VRFY): expected reply code %i, got code %i ..",
            NGSmtpActionCompleted, [reply code]);
    }
    return YES;
  }
  else if ([reply code] == NGSmtpMailboxNotFound) {
    return NO;
  }
  else {
    NSLog(@"SMTP(VRFY): expected positive or 550 reply code, got code %i ..", [reply code]);
    return NO;
  }
}

// transaction commands

- (NSString *) _sanitizeAddress: (NSString *) address
{
  NSString *saneAddress;

  if ([address hasPrefix: @"<"])
    saneAddress = address;
  else
    saneAddress = [NSString stringWithFormat: @"<%@>", address];

  return saneAddress;
}

- (BOOL)mailFrom:(id)_sender {
  NGSmtpResponse *reply;
  NSString       *sender;

  [self requireState:NGSmtpState_connected];

  sender = [self _sanitizeAddress: [_sender stringValue]];
  reply  = [self sendCommand: @"MAIL"
                    argument: [@"FROM:" stringByAppendingString: sender]];
  if ([reply isPositive]) {
    if ([reply code] != NGSmtpActionCompleted) {
      NSLog(@"SMTP(MAIL FROM): expected reply code %i, got code %i ..",
            NGSmtpActionCompleted, [reply code]);
    }
    [self gotoState:NGSmtpState_TRANSACTION];
    return YES;
  }
  return NO;
}

- (BOOL)recipientTo:(id)_receiver {
  NGSmtpResponse *reply = nil;
  NSString       *rcpt  = nil;
  
  [self requireState:NGSmtpState_TRANSACTION];

  rcpt  = [self _sanitizeAddress: [_receiver stringValue]];
  reply = [self sendCommand: @"RCPT"
                   argument: [@"TO:" stringByAppendingString: rcpt]];
  if ([reply isPositive]) {
    if ([reply code] != NGSmtpActionCompleted) {
      NSLog(@"SMTP(RCPT TO): expected reply code %i, got code %i ..",
            NGSmtpActionCompleted, [reply code]);
    }
    return YES;
  }
  return NO;
}

- (BOOL)sendData:(NSData *)_data {
  NGSmtpResponse *reply = nil;
  NSMutableData *cleaned_data;
  NSRange r1;
  
  const char *bytes;
  char *mbytes;
  int len, mlen;

  [self requireState:NGSmtpState_TRANSACTION];

  reply = [self sendCommand:@"DATA"];
  if (self->isDebuggingEnabled) [NGTextErr writeFormat:@"S: %@\n", reply];
  if (([reply code] >= 300) && ([reply code] < 400)) {
    if ([reply code] != NGSmtpStartMailInput) {
      NSLog(@"SMTP(DATA): expected reply code %i, got code %i ..",
            NGSmtpStartMailInput, [reply code]);
    }
    [self->text flush];

    //
    // SOPE sucks in many ways and that is one of them. The headers are actually
    // correctly encoded (trailing \r\n is inserted) but not the base64 encoded
    // data since it uses SOPE's dataByEncodingBase64 function which says:
    //
    // NGBase64Coding.h:- (NSData *)dataByEncodingBase64; /* Note: inserts '\n' every 72 chars */
    //
    len = [_data length];
    mlen = 0;

    cleaned_data = [NSMutableData dataWithLength: len*2];

    bytes = [_data bytes];
    mbytes = [cleaned_data mutableBytes];

    while (len > 0)
      {
	if (*bytes == '\n' && *(bytes-1) != '\r' && mlen > 0)
	  {
	    *mbytes = '\r';
	    mbytes++;
	    mlen++;
	  }
  
	  *mbytes = *bytes;
	  mbytes++; bytes++;
	  len--;
	  mlen++;
      }

    [cleaned_data setLength: mlen];

    //
    // According to RFC 2821 section 4.5.2, we must check for the character
    // sequence "<CRLF>.<CRLF>"; any occurrence have its period duplicated
    // to avoid data transparency.
    //
    r1 = [cleaned_data rangeOfCString: "\r\n."];
    
    while (r1.location != NSNotFound)
      {
	[cleaned_data replaceBytesInRange: r1  withBytes: "\r\n.."  length: 4];
	
	r1 = [cleaned_data rangeOfCString: "\r\n."
			   options: 0 
			   range: NSMakeRange(NSMaxRange(r1)+1, [cleaned_data length]-NSMaxRange(r1)-1)];
      }
    
    if (self->isDebuggingEnabled)
      [NGTextErr writeFormat:@"C: data(%i bytes) ..\n", [cleaned_data length]];
    
    [self->connection safeWriteBytes:[cleaned_data bytes] count:[cleaned_data length]];
    [self->connection safeWriteBytes:"\r\n.\r\n" count:5];
    [self->connection flush];

    reply = [self receiveReply];
    if (self->isDebuggingEnabled) [NGTextErr writeFormat:@"S: %@\n", reply];
    if ([reply isPositive]) {
      [self gotoState:NGSmtpState_connected];
      return YES;
    }
    else {
      NSLog(@"SMTP(DATA): mail input failed, got code %i ..", [reply code]);
    }
  }
  return NO;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<SMTP-Client[0x%p]: socket=%@>",
                     self, [self socket]];
}

@end /* NGSmtpClient */
