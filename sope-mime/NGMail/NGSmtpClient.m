/*
  Copyright (C) 2000-2007 SKYRIX Software AG
  Copyright (C) 2020      Nicolas Höft

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
#include <NGStreams/NGActiveSSLSocket.h>

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
- (void) _fetchExtensionInfo;
- (id) _openSocket;
- (BOOL) _startTLS;
@end

@implementation NGSmtpClient

- (BOOL)useSSL {
  return self->useSSL;
}

- (BOOL)useStartTLS {
  return self->useStartTLS;
}


+ (id) clientWithURL: (NSURL *)_url; {
  return [[(NGSmtpClient *)[self alloc] initWithURL:_url] autorelease];
}

- (id)init {
  NSLog(@"%@: init not supported, use initWithSocket: ..", self);
  [self release];
  return nil;
}

- (id)initWithSocket:(id<NGActiveSocket>)_socket { // designated initializer
  if ((self = [super init])) {
    BOOL debug;
    self->socket = [_socket retain];
    NSAssert(self->socket, @"invalid socket parameter");

    debug = [[NSUserDefaults standardUserDefaults]
                boolForKey:@"SMTPDebugEnabled"];
    [self setDebuggingEnabled: debug];

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

- (id)initWithURL:(NSURL *)_url {
  NGInternetSocketAddress *a;
  int port;
  NSDictionary *queryComponents = [_url queryComponents];
  NSString *value;

  self->useSSL = [[_url scheme] isEqualToString:@"smtps"];
  if (self->useSSL && NSClassFromString(@"NGActiveSSLSocket") == nil) {
    [self logWithFormat:
            @"no SSL support available, cannot connect: %@", _url];
    [self release];
    return nil;
  }

  value = [queryComponents valueForKey: @"tls"];
  if (value && [value isEqualToString: @"YES"])
    self->useStartTLS = YES;
  else
    self->useStartTLS = NO;

  if ((port = [[_url port] intValue]) == 0) {
    if (self->useSSL && !self->useStartTLS)
      port = 465;
    else
      port = 25;
  }
  tlsVerifyMode = TLSVerifyDefault;
  value = [queryComponents valueForKey: @"tlsVerifyMode"];
  if (value) {
    if ([value isEqualToString: @"allowInsecureLocalhost"]) {
      tlsVerifyMode = TLSVerifyAllowInsecureLocalhost;
    } else if ([value isEqualToString: @"none"]) {
      tlsVerifyMode = TLSVerifyNone;
    }
  }

  a = [NGInternetSocketAddress addressWithPort:port
                                onHost:[_url host]];
  self = [self initWithAddress:a];

  return self;
}

- (id)initWithAddress:(id<NGSocketAddress>)_address { /* designated init */
  if ((self = [super init])) {
    BOOL debug;
    [self gotoState:NGSmtpState_unconnected];

    self->address = [_address retain];

    debug = [[NSUserDefaults standardUserDefaults]
                boolForKey:@"SMTPDebugEnabled"];
    [self setDebuggingEnabled: debug];
  }
  return self;
}

- (void)dealloc {
  [self->text       release];
  [self->connection release];
  [self->socket     release];
  [self->previous_socket release];
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

- (id)_openSocket {
  id sock;
  BOOL sslSocket = [self useSSL] && ![self useStartTLS];

  NS_DURING {
    if (sslSocket) {
      sock = [NGActiveSSLSocket socketConnectedToAddress:self->address
                                          withVerifyMode: tlsVerifyMode];
    } else {
      sock = [NGActiveSocket socketConnectedToAddress:self->address];
    }
  }
  NS_HANDLER {
    sock = nil;
  }
  NS_ENDHANDLER;

  return sock;
}


- (BOOL)connect {
  NGSmtpResponse *greeting = nil;

  [self requireState:NGSmtpState_unconnected];

  if (self->isDebuggingEnabled)
    [NGTextErr writeFormat:@"C: connect to %@\n", self->address];

  if ((self->socket = [[self _openSocket] retain]) == nil)
    return NO;

  self->connection =
      [(NGBufferedStream *)[NGBufferedStream alloc] initWithSource:self->socket];
  self->text =
      [(NGCTextStream *)[NGCTextStream alloc] initWithSource:self->connection];

  self->state = [self->socket isConnected]
      ? NGSmtpState_connected
      : NGSmtpState_unconnected;

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
      if (self->extensions.hasAuthPlain)
        [NGTextErr writeFormat:@"S: plain auth extension supported.\n"];
      if (self->extensions.hasStartTls)
        [NGTextErr writeFormat:@"S: starttls extension supported.\n"];
    }

    if ([self useStartTLS]) {
      if (!self->extensions.hasStartTls) {
        [NSException raise:@"SMTPException"
                 format:@"Server does not support STARTTLS"];
        return NO;
      }
      if ([self _startTLS]) {
        // after performing STARTTLS, we have to fetch the supported
        // extensions again, supported AUTH mechanism may now
        // have changed
        [self _fetchExtensionInfo];
        return YES;
      }
      [self disconnect];
      return NO;
    }

    return YES;
  }
  else {
    [self disconnect];
    return NO;
  }
}

- (BOOL) _startTLS {
  Class socketClass;
  NGSmtpResponse *reply;
  id tlsSocket;

  if (!self->extensions.hasStartTls) {
    NSLog(@"SMTP: TLS not supported by client");
    return NO;
  }

  socketClass = NSClassFromString(@"NGActiveSSLSocket");
  if (!socketClass) {
    NSLog(@"SMTP: TLS not supported by client");
    return NO;
  }

  reply = [self sendCommand: @"STARTTLS"];
  if ([reply code] != NGSmtpServiceReady) {
    NSLog(@"SMTP: unexpected response from STARTTLS command (%d)", [reply code]);
    return NO;
  }

  tlsSocket = [[NGActiveSSLSocket alloc] initWithConnectedActiveSocket: (NGActiveSocket *)self->socket
          withVerifyMode: tlsVerifyMode];

  if (![tlsSocket startTLS]) {
    NSLog(@"SMTP: unable to perform STARTTLS on socket");
    return NO;
  }

  // the TLS socket is on top of the connection we
  // opened before, so we have to keep it
  self->previous_socket = self->socket;
  self->socket = tlsSocket;
  // redirect the connection and text objects
  // to the new socket
  [self->text release];
  [self->connection release];
  self->connection = [(NGBufferedStream *)[NGBufferedStream alloc] initWithSource: self->socket];
  self->text = [(NGCTextStream *)[NGCTextStream alloc] initWithSource: self->connection];
  NSLog(@"SMTP: STARTTLS successfully performed");
  return YES;
}

- (void)disconnect {
  [text   flush];
  [previous_socket close];
  [socket close];
  [self gotoState:NGSmtpState_unconnected];
}

// authentication
- (BOOL) authenticateUser: (NSString *) username
                  withPassword: (NSString *) password
                    withMethod: (NSString *) method
{
  BOOL rc;

  if (self->extensions.hasAuthPlain && [username length] > 0) {
    char *buffer;
    const char *utf8Username, *utf8Password;
    size_t buflen, lenUsername, lenPassword;
    NSString *authString;
    NGSmtpResponse *reply;

    if(!method)
      method = @"PLAIN";
    
    if([method isEqualToString: @"xoauth2"])
    {
      NSString *oauth2Password, *oauth2Username;
      oauth2Username = [NSString stringWithFormat: @"user=%@", username];
      oauth2Password = [NSString stringWithFormat: @"auth=Bearer %@", password];
      utf8Username = [oauth2Username UTF8String];
      utf8Password = [oauth2Password UTF8String];

      lenUsername = strlen(utf8Username);
      lenPassword = strlen(utf8Password);
      buflen = lenUsername + lenPassword + 3;
      buffer = malloc (sizeof (char) * (buflen + 1));
      sprintf (buffer, "%s%c%s%c%c", utf8Username, 1, utf8Password, 1, 1);
      authString = [[NSData dataWithBytesNoCopy: buffer
                                         length: buflen
                                   freeWhenDone: YES] stringByEncodingBase64];
    }
    else
    {
      utf8Username = [username UTF8String];
      utf8Password = [password UTF8String];
      if (!utf8Password)
        utf8Password = 0;

      lenUsername = strlen (utf8Username);
      lenPassword = strlen (utf8Password);
      buflen = lenUsername * 2 + lenPassword + 2;
      buffer = malloc (sizeof (char) * (buflen + 1));
      sprintf (buffer, "%s%c%s%c%s", utf8Username, 0, utf8Username, 0, utf8Password);
      authString = [[NSData dataWithBytesNoCopy: buffer
                                         length: buflen
                                   freeWhenDone: YES] stringByEncodingBase64];
    }

    authString = [authString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    reply = [self sendCommand: [NSString stringWithFormat:@"AUTH %@", method]];

    if ([reply code] == NGSmtpServerChallenge)
    {
      reply = [self sendCommand: authString];
    }

    rc = ([reply code] == NGSmtpAuthenticationSuccess);
  }
  else {
    rc = NO;
  }

  return rc;
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
  if([line length] == 3) {
    //Invalid but can happen with some smtp server that does not follow correctly the smtp specs
    //and only send the code number instead of the code + a space.
    code = [[line substringToIndex:3] intValue];
    if(code == 0)
    {
      NSLog(@"SMTP: reply has invalid format and is not a code of 3 chars (%@)", line);
      return nil;
    }
    desc = [NSMutableString stringWithCapacity:[line length]];
    return [NGSmtpResponse responseWithCode:code text:desc];
  }

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
  NGActiveSocket* sock;
  NGInternetSocketAddress* sockAddr;

  if (previous_socket) {
    sock = self->previous_socket;
  } else {
    sock = self->socket;
  }

  sockAddr = (NGInternetSocketAddress *)[sock localAddress];
  if ([sockAddr isIPv6] && [[sockAddr hostName] isEqualToString: [sockAddr address]]) {
    hostName = [NSString stringWithFormat:@"[IPv6:%@]", [sockAddr address]];
  }
  else {
    hostName = [sockAddr hostName];
  }

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
      else if (([line hasPrefix:@"STARTTLS"]))
        self->extensions.hasStartTls = YES;
      // We skip "AUTH=PLAIN ..." here, as it's redundant with "AUTH PLAIN ..." and will
      // break things on components splitting
      else if ([line hasPrefix:@"AUTH "]) {
        NSArray *methods;
        methods = [line componentsSeparatedByString: @" "];
        self->extensions.hasAuthPlain = [methods containsObject: @"PLAIN"];
      }
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

- (NSString *) _sanitizeAddress: (NSString *) _address
{
  NSString *saneAddress;

  if ([_address hasPrefix: @"<"])
    saneAddress = _address;
  else
    saneAddress = [NSString stringWithFormat: @"<%@>", _address];

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
  else if ([[reply text] length])
    {
      NSLog(@"SMTP(MAIL FROM) error: %@", [reply text]);
      [NSException raise: @"SMTPException"
                  format: @"%@",
                  [reply text]];
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
  else if ([[reply text] length])
    { 
      NSString* smtpError = [reply text];
      NSLog(@"SMTP(RCPT TO) error: %@", smtpError);
      if(![smtpError containsString:rcpt])
      {
        smtpError = [NSString stringWithFormat: @"%@ - %@", smtpError, rcpt];
      }
      [NSException raise: @"SMTPException"
                  format: @"%@",
                  smtpError];
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
  if ([[reply text] length])
    {
      NSLog(@"SMTP(DATA) error: %@", [reply text]);
      [NSException raise: @"SMTPException"
                  format: @"%@",
                  [reply text]];
    }
  return NO;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<SMTP-Client[0x%p]: socket=%@>",
                     self, [self socket]];
}

@end /* NGSmtpClient */
