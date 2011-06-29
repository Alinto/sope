/*
  Copyright (C) 2000-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess

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

#include <unistd.h>

#include "NGSieveClient.h"
#include "NGImap4Support.h"
#include "NGImap4ResponseParser.h"
#include "NSString+Imap4.h"
#include "imCommon.h"
#include <sys/time.h>

@interface NGSieveClient(Private)

- (NGHashMap *)processCommand:(id)_command;
- (NGHashMap *)processCommand:(id)_command logText:(id)_txt;

- (NSException *)sendCommand:(id)_command;
- (NSException *)sendCommand:(id)_command logText:(id)_txt;
- (NSException *)sendCommand:(id)_command logText:(id)_txt attempts:(int)_c;

- (NSMutableDictionary *)normalizeResponse:(NGHashMap *)_map;
- (NSMutableDictionary *)normalizeOpenConnectionResponse:(NGHashMap *)_map;
- (NSDictionary *)login;

/* parsing */

- (NSString *)readStringToCRLF;
- (NSString *)readString;

@end

/*
  An implementation of an Imap4 client
  
  A folder name always looks like an absolute filename (/inbox/blah)
  
  NOTE: Sieve is just the filtering language ...
  
  This should be ACAP?
    http://asg.web.cmu.edu/rfc/rfc2244.html

  ---snip---
"IMPLEMENTATION" "Cyrus timsieved v2.1.15-IPv6-Debian-2.1.15-0woody.1.0"
"SASL" "PLAIN"
"SIEVE" "fileinto reject envelope vacation imapflags notify subaddress relational regex"
"STARTTLS"
OK
  ---snap---
*/

@implementation NGSieveClient

static int      defaultSievePort   = 2000;
static NSNumber *YesNumber         = nil;
static NSNumber *NoNumber          = nil;
static BOOL     ProfileImapEnabled = NO;
static BOOL     LOG_PASSWORD       = NO;
static BOOL     debugImap4         = NO;

+ (void)initialize {
  static BOOL didInit = NO;
  NSUserDefaults *ud;
  if (didInit) return;
  didInit = YES;
  
  ud = [NSUserDefaults standardUserDefaults];
  LOG_PASSWORD       = [ud boolForKey:@"SieveLogPassword"];
  ProfileImapEnabled = [ud boolForKey:@"ProfileImapEnabled"];
  debugImap4         = [ud boolForKey:@"ImapDebugEnabled"];
  
  YesNumber = [[NSNumber numberWithBool:YES] retain];
  NoNumber  = [[NSNumber numberWithBool:NO] retain];
}

+ (id)clientWithURL:(id)_url {
  return [[(NGSieveClient *)[self alloc] initWithURL:_url] autorelease];
}

+ (id)clientWithAddress:(id<NGSocketAddress>)_address {
  NGSieveClient *client;
  
  client = [self alloc];
  return [[client initWithAddress:_address] autorelease];
}

+ (id)clientWithHost:(id)_host {
  return [[[self alloc] initWithHost:_host] autorelease];
}

- (id)initWithNSURL:(NSURL *)_url {
  NGInternetSocketAddress *a;
  int port;
  
  if ((port = [[_url port] intValue]) == 0)
    port = defaultSievePort;
  
  a = [NGInternetSocketAddress addressWithPort:port 
			       onHost:[_url host]];
  if ((self = [self initWithAddress:a])) {
    self->login    = [[_url user]     copy];
    self->password = [[_url password] copy];
  }
  return self;
}
- (id)initWithURL:(id)_url {
  if (_url == nil) {
    [self release];
    return nil;
  }
  
  if (![_url isKindOfClass:[NSURL class]])
    _url = [NSURL URLWithString:[_url stringValue]];
  
  return [self initWithNSURL:_url];
}

- (id)initWithHost:(id)_host {
  NGInternetSocketAddress *a;
  
  a = [NGInternetSocketAddress addressWithPort:defaultSievePort onHost:_host];
  return [self initWithAddress:a];
}

- (id)initWithAddress:(id<NGSocketAddress>)_address { // di
  if ((self = [super init])) {
    self->address = [_address retain];
    self->debug   = debugImap4;
  }
  return self;
}

- (void)dealloc {
  [self->lastException release];
  [self->address  release];
  [self->io       release];
  [self->socket   release];
  [self->parser   release];
  [self->authname release];
  [self->login    release];
  [self->password release];
  [super dealloc];
}

/* equality */

- (BOOL)isEqual:(id)_obj {
  if (_obj == self)
    return YES;
  if ([_obj isKindOfClass:[NGSieveClient class]])
    return [self isEqualToSieveClient:_obj];
  return NO;
}

- (BOOL)isEqualToSieveClient:(NGSieveClient *)_obj {
  if (_obj == self) return YES;
  if (_obj == nil)  return NO;
  return [[_obj address] isEqual:self->address];
}

/* accessors */

- (id<NGActiveSocket>)socket {
  return self->socket;
}

- (id<NGSocketAddress>)address {
  return self->address;
}

/* exceptions */

- (void)setLastException:(NSException *)_ex {
  ASSIGN(self->lastException, _ex);
}
- (NSException *)lastException {
  return self->lastException;
}
- (void)resetLastException {
  [self->lastException release];
  self->lastException = nil;
}

/* connection */

- (void)resetStreams {
  [self->socket release]; self->socket = nil;
  [self->io     release]; self->io     = nil;
  [self->parser release]; self->parser = nil;
}

- (NSDictionary *)openConnection {
  struct timeval tv;
  double         ti = 0.0;
  
  if (ProfileImapEnabled) {
    gettimeofday(&tv, NULL);
    ti =  (double)tv.tv_sec + ((double)tv.tv_usec / 1000000.0);
  }
  
  [self resetStreams];
  
  self->socket =
    [[NGActiveSocket socketConnectedToAddress:self->address] retain];
  if (self->socket == nil) {
    [self logWithFormat:@"ERROR: could not connect: %@", self->address];
    return nil;
  }

  self->io     = [NGBufferedStream alloc]; // keep gcc happy
  self->io     = [self->io initWithSource:(id)self->socket];
  self->parser = [[NGImap4ResponseParser alloc] initWithStream:self->socket];

  /* receive greeting from server without tag-id */

  if (ProfileImapEnabled) {
    gettimeofday(&tv, NULL);
    ti = (double)tv.tv_sec + ((double)tv.tv_usec / 1000000.0) - ti;
    fprintf(stderr, "[%s] <openConnection> : time needed: %4.4fs\n",
           __PRETTY_FUNCTION__, ti < 0.0 ? -1.0 : ti);    
  }
  return [self normalizeOpenConnectionResponse:
               [self->parser parseSieveResponse]];
}

- (NSNumber *)isConnected {
  /*
    Check whether stream is already open (could be closed due to a server
    timeout)
  */
  // TODO: why does that return an object?
  if (self->socket == nil)
    return [NSNumber numberWithBool:NO];
  
  return [NSNumber numberWithBool:[(NGActiveSocket *)self->socket isAlive]];
}

- (void)closeConnection {
  [self->socket close];
  [self->socket release]; self->socket = nil;
  [self->parser release]; self->parser = nil;
}

- (NSDictionary *)login:(NSString *)_login password:(NSString *)_passwd {
  return [self login: _login  authname: _login  password: _passwd];
}

- (NSDictionary *)login:(NSString *)_login authname:(NSString *)_authname password:(NSString *)_passwd {
  /* login with plaintext password authenticating */
  
  if ((_login == nil) || (_passwd == nil))
    return nil;
  
  [self->authname release]; self->authname = nil;
  [self->login    release]; self->login    = nil;
  [self->password release]; self->password = nil;
  
  self->authname = [_authname copy];
  self->login    = [_login  copy];
  self->password = [_passwd copy];
  return [self login];
}

- (void)reconnect {
  [self closeConnection];  
  [self openConnection];
  [self login];
}

- (NSDictionary *)login {
  NGHashMap *map  = nil;
  NSData    *auth;
  char      *buf;
  int       bufLen, logLen, authLen;
  
  if (![self->socket isConnected]) {
    NSDictionary *con;
    
    if ((con = [self openConnection]) == nil)
      return nil;
    if (![[con objectForKey:@"result"] boolValue])
      return con;
  }
  
  authLen = [self->authname lengthOfBytesUsingEncoding: NSUTF8StringEncoding];
  logLen = [self->login lengthOfBytesUsingEncoding: NSUTF8StringEncoding];
  bufLen = (logLen+authLen) + [self->password lengthOfBytesUsingEncoding: NSUTF8StringEncoding] +2;
  
  buf = calloc(bufLen + 2, sizeof(char));
  
  /*
    Format:
      authenticate-id
      authorize-id
      password
  */
  sprintf(buf, "%s %s %s", 
          [self->login cStringUsingEncoding:NSUTF8StringEncoding],
          [self->authname cStringUsingEncoding:NSUTF8StringEncoding],
          [self->password cStringUsingEncoding:NSUTF8StringEncoding]);
  
  buf[logLen] = '\0';
  buf[logLen+authLen + 1] = '\0';
  
  auth = [NSData dataWithBytesNoCopy:buf length:bufLen];
  auth = [auth dataByEncodingBase64WithLineLength:4096 /* 'unlimited' */];
  
  if (LOG_PASSWORD) {
    NSString *s;
    
    s = [NSString stringWithFormat:@"AUTHENTICATE \"PLAIN\" {%d+}\r\n%s",
                  [auth length], [auth bytes]];
    map = [self processCommand:s];
  }
  else {
    NSString *s;
    
    s = [NSString stringWithFormat:@"AUTHENTICATE \"PLAIN\" {%d+}\r\n%s",
                  [auth length], [auth bytes]];
    map = [self processCommand:s
                logText:@"AUTHENTICATE \"PLAIN\" {%d+}\r\nLOGIN:PASSWORD\r\n"];
  }

  if (map == nil) {
    [self logWithFormat:@"ERROR: got no result from command."];
    return nil;
  }
  
  return [self normalizeResponse:map];
}

/* logout from the connected host and close the connection */

- (NSDictionary *)logout {
  NGHashMap *map;

  map = [self processCommand:@"logout"]; // TODO: check for success!
  [self closeConnection];
  return [self normalizeResponse:map];
}

- (NSString *)getScript:(NSString *)_scriptName {
  NSException *ex;
  NSString *script, *s;
  
  s = [@"GETSCRIPT \"" stringByAppendingString:_scriptName];
  s = [s stringByAppendingString:@"\""];
  ex = [self sendCommand:s logText:s attempts:3];
  if (ex != nil) {
    [self logWithFormat:@"ERROR: could not get script: %@", ex];
    [self setLastException:ex];
    return nil;
  }
  
  /* read script string */
  
  if ((script = [[self readString] autorelease]) == nil)
    return nil;
  
  if ([script hasPrefix:@"O "] || [script hasPrefix:@"NO "]) {
    // TODO: not exactly correct, script could begin with this signature
    // Note: readString read 'NO ...', but the first char is consumed
    
    [self logWithFormat:@"ERROR: status line reports: '%@'", script];
    return nil;
  }
  
  NSLog(@"str: %@", script);
  
  /* read response code */
  
  if ((s = [self readStringToCRLF]) == nil) {
    [self logWithFormat:@"ERROR: could not parse status line."];
    return nil;
  }
  if (![s isNotEmpty]) { // remainder of previous string
    [s release];
    if ((s = [self readStringToCRLF]) == nil) {
      [self logWithFormat:@"ERROR: could not parse status line."];
      return nil;
    }
  }
  
  if (![s hasPrefix:@"OK"]) {
    [self logWithFormat:@"ERROR: status line reports: '%@'", s];
    [s release];
    return nil;
  }
  [s release];
  
  return script;
}

- (BOOL)isValidScriptName:(NSString *)_name {
  return [_name isNotEmpty];
}

- (NSDictionary *)putScript:(NSString *)_name script:(NSString *)_script {
  // TODO: script should be send in UTF-8!
  NGHashMap *map;
  NSString  *s;
  
  if (![self isValidScriptName:_name]) {
    [self logWithFormat:@"%s: missing script-name", __PRETTY_FUNCTION__];
    return nil;
  }
  if (![_script isNotEmpty]) {
    [self logWithFormat:@"%s: missing script", __PRETTY_FUNCTION__];
    return nil;
  }
  
  s = @"PUTSCRIPT \"";
  s = [s stringByAppendingString:_name];
  s = [s stringByAppendingString:@"\" "];
  s = [s stringByAppendingFormat:@"{%d+}\r\n%@",
         [_script lengthOfBytesUsingEncoding: NSUTF8StringEncoding],
         _script];
  map = [self processCommand:s];
  return [self normalizeResponse:map];
}

- (NSDictionary *)setActiveScript:(NSString *)_name {
  NGHashMap *map;
  
  if (!_name) {
    NSLog(@"%s: missing script-name", __PRETTY_FUNCTION__);
    return nil;
  }
  map = [self processCommand:
              [NSString stringWithFormat:@"SETACTIVE \"%@\"", _name]];
  return [self normalizeResponse:map];
}

- (NSDictionary *)deleteScript:(NSString *)_name {
  NGHashMap *map;
  NSString  *s;

  if (![self isValidScriptName:_name]) {
    NSLog(@"%s: missing script-name", __PRETTY_FUNCTION__);
    return nil;
  }
  
  s = [NSString stringWithFormat:@"DELETESCRIPT \"%@\"", _name];
  map = [self processCommand:s];
  return [self normalizeResponse:map];
}

- (NSDictionary *)listScripts {
  NSMutableDictionary *md;
  NSException *ex;
  NSString *line;
  
  ex = [self sendCommand:@"LISTSCRIPTS" logText:@"LISTSCRIPTS" attempts:3];
  if (ex != nil) {
    [self logWithFormat:@"ERROR: could not list scripts: %@", ex];
    [self setLastException:ex];
    return nil;
  }
  
  /* read response */
  
  md = [NSMutableDictionary dictionaryWithCapacity:16];
  while ((line = [self readStringToCRLF]) != nil) {
    if ([line hasPrefix:@"OK"])
      break;
    
    if ([line hasPrefix:@"NO"]) {
      md = nil;
      break;
    }
    
    if ([line hasPrefix:@"{"]) {
      [self logWithFormat:@"unsupported list response line: '%@'", line];
    }
    else if ([line hasPrefix:@"\""]) {
      NSString *s;
      NSRange  r;
      BOOL     isActive;
      
      s = [line substringFromIndex:1];
      r = [s rangeOfString:@"\""];
      
      if (r.length == 0) {
	[self logWithFormat:@"missing closing quote in line: '%@'", line];
	[line release]; line = nil;
	continue;
      }
      
      s = [s substringToIndex:r.location];
      isActive = [line rangeOfString:@"ACTIVE"].length == 0 ? NO : YES;
      
      [md setObject:isActive ? @"ACTIVE" : @"" forKey:s];
    }
    else {
      [self logWithFormat:@"unexpected list response line (%d): '%@'", 
	    [line length], line];
    }
    
    [line release]; line = nil;
  }
  
  [line release]; line = nil;
  
  return md;
}


- (NSMutableDictionary *)normalizeResponse:(NGHashMap *)_map {
  /*
    Filter for all responses
       result  : NSNumber (response result)
       exists  : NSNumber (number of exists mails in selectet folder
       recent  : NSNumber (number of recent mails in selectet folder
       expunge : NSArray  (message sequence number of expunged mails
                          in selectet folder)
  */
  id keys[3], values[3];
  NSParameterAssert(_map != nil);
  
  keys[0] = @"RawResponse"; values[0] = _map;
  keys[1] = @"result";
  values[1] = [[_map objectForKey:@"ok"] boolValue] ? YesNumber : NoNumber;
  return [NSMutableDictionary dictionaryWithObjects:values
                              forKeys:keys count:2];
}

- (NSMutableDictionary *)normalizeOpenConnectionResponse:(NGHashMap *)_map {
  /* filter for open connection */
  NSMutableDictionary *result;
  NSString *tmp;
  
  result = [self normalizeResponse:_map];
  
  if (![[[_map objectEnumeratorForKey:@"ok"] nextObject] boolValue])
    return result;

  if ((tmp = [_map objectForKey:@"implementation"]))
    [result setObject:tmp forKey:@"server"];
  if ((tmp = [_map objectForKey:@"sieve"]))
    [result setObject:tmp forKey:@"capabilities"];
  return result;
}

/* Private Methods */

- (BOOL)handleProcessException:(NSException *)_exception
  repetitionCount:(int)_cnt
{
  if (_cnt > 3) {
    [_exception raise];
    return NO;
  }
  
  if ([_exception isKindOfClass:[NGIOException class]]) {
    [self logWithFormat:
            @"WARNING: got exception try to restore connection: %@", 
            _exception];
    return YES;
  }
  if ([_exception isKindOfClass:[NGImap4ParserException class]]) {
    [self logWithFormat:
            @"WARNING: Got Parser-Exception try to restore connection: %@",
            _exception];
    return YES;
  }
  
  [_exception raise];
  return NO;
}

- (void)waitPriorReconnectWithRepetitionCount:(int)_cnt {
  unsigned timeout;
  
  timeout = _cnt * 4;
  [self logWithFormat:@"reconnect to %@, sleeping %d seconds ...",
          self->address, timeout];
  sleep(timeout);
  [self logWithFormat:@"reconnect ..."];
}

- (NGHashMap *)processCommand:(id)_command logText:(id)_txt {
  NGHashMap *map          = nil;
  BOOL      repeatCommand = NO;
  int       repeatCnt     = 0;
  struct timeval tv;
  double         ti = 0.0;
  
  if (ProfileImapEnabled) {
    gettimeofday(&tv, NULL);
    ti =  (double)tv.tv_sec + ((double)tv.tv_usec / 1000000.0);
    fprintf(stderr, "{");
  }
  do { /* TODO: shouldn't that be a while loop? */
    if (repeatCommand) {
      if (repeatCnt > 1)
        [self waitPriorReconnectWithRepetitionCount:repeatCnt];
      
      repeatCnt++;
      [self reconnect];
      repeatCommand = NO;
    }
    
    NS_DURING {
      NSException *ex;
      
      if ((ex = [self sendCommand:_command logText:_txt]) != nil) {
	repeatCommand = [self handleProcessException:ex 
			      repetitionCount:repeatCnt];
      }
      else
	map = [self->parser parseSieveResponse];
    }
    NS_HANDLER {
      repeatCommand = [self handleProcessException:localException
                            repetitionCount:repeatCnt];
    }
    NS_ENDHANDLER;    
  }
  while (repeatCommand);
  
  if (ProfileImapEnabled) {
    gettimeofday(&tv, NULL);
    ti = (double)tv.tv_sec + ((double)tv.tv_usec / 1000000.0) - ti;
    fprintf(stderr, "}[%s] <Send Command> : time needed: %4.4fs\n",
           __PRETTY_FUNCTION__, ti < 0.0 ? -1.0 : ti);    
  }
  
  return map;
}

- (NGHashMap *)processCommand:(id)_command {
  return [self processCommand:_command logText:_command];
}

- (NSException *)sendCommand:(id)_command logText:(id)_txt {
  NSString *command = nil;
  
  if ((command = _command) == nil) /* missing command */
    return nil; // TODO: return exception?
  
  /* log */

  if (self->debug) {
    if ([_txt isKindOfClass:[NSData class]]) {
      fprintf(stderr, "C: ");
      fwrite([_txt bytes], [_txt length], 1, stderr);
      fputc('\n', stderr);
    }
    else
      fprintf(stderr, "C: %s\n", [_txt cStringUsingEncoding:NSUTF8StringEncoding]);
  }

  /* write */
  
  if (![_command isKindOfClass:[NSData class]])
    _command = [command dataUsingEncoding:NSUTF8StringEncoding];
  
  if (![self->io safeWriteData:_command])
    return [self->io lastException];
  if (![self->io writeBytes:"\r\n" count:2])
    return [self->io lastException];
  if (![self->io flush])
    return [self->io lastException];
  
  return nil;
}

- (NSException *)sendCommand:(id)_command {
  return [self sendCommand:_command logText:_command];
}

- (NSException *)sendCommand:(id)_command logText:(id)_txt attempts:(int)_c {
  NSException *ex;
  BOOL tryAgain;
  int  repeatCnt;
  
  for (tryAgain = YES, repeatCnt = 0, ex = nil; tryAgain; repeatCnt++) {
    if (repeatCnt > 0) {
      if (repeatCnt > 1) /* one repeat goes without delay */
        [self waitPriorReconnectWithRepetitionCount:repeatCnt];
      [self reconnect];
      tryAgain = NO;
    }
    
    NS_DURING
      ex = [self sendCommand:_command logText:_txt];
    NS_HANDLER
      ex = [localException retain];
    NS_ENDHANDLER;
    
    if (ex == nil) /* everything is fine */
      break;
    
    if (repeatCnt > _c) /* reached max attempts */
      break;
    
    /* try again for certain exceptions */
    tryAgain = [self handleProcessException:ex repetitionCount:repeatCnt];
  }
  
  return ex;
}

/* low level */

- (int)readByte {
  unsigned char c;
  
  if (![self->io readBytes:&c count:1]) {
    [self setLastException:[self->io lastException]];
    return -1;
  }
  return c;
}

- (NSString *)readLiteral {
  /* 
     Assumes 1st char is consumed, returns a retained string.
     
     Parses: "{" number [ "+" ] "}" CRLF *OCTET
  */
  unsigned char countBuf[16];
  int      i;
  unsigned byteCount;
  unsigned char *octets;
  
  /* read count */
  
  for (i = 0; i < 14; i++) {
    int c;
    
    if ((c = [self readByte]) == -1)
      return nil;
    if (c == '}')
      break;
    
    countBuf[i] = c;
  }
  countBuf[i] = '\0';
  byteCount = i > 0 ? atoi((char *)countBuf) : 0;
  
  /* read CRLF */
  
  i = [self readByte];
  if (i != '\n') {
    if (i == '\r' && i != -1)
      i = [self readByte];
    if (i == -1)
      return nil;
  }
  
  /* read octet */
  
  if (byteCount == 0)
    return @"";
  
  octets = malloc(byteCount + 4);
  if (![self->io safeReadBytes:octets count:byteCount]) {
    [self setLastException:[self->io lastException]];
    return nil;
  }
  octets[byteCount] = '\0';
  
  return [[NSString alloc] initWithUTF8String:(char *)octets];
}

- (NSString *)readQuoted {
  /* 
     assumes 1st char is consumed, returns a retained string

     Note: quoted strings are limited to 1KB!
  */
  unsigned char buf[1032];
  int i, c;
  
  i = 0;
  do {
    c      = [self readByte];
    buf[i] = c;
    i++;
  }
  while ((c != -1) && (c != '"'));
  buf[i] = '\0';
  
  if (c == -1)
    return nil;
  
  return [[NSString alloc] initWithUTF8String:(char *)buf];
}

- (NSString *)readStringToCRLF {
  unsigned char buf[1032];
  int i, c;
  
  i = 0;
  do {
    c = [self readByte];
    if (c == '\n' || c == '\r')
      break;
    
    buf[i] = c;
    i++;
  }
  while ((c != -1) && (c != '\r') && (c != '\n') && (i < 1024));
  buf[i] = '\0';
  
  if (c == -1)
    return nil;
  
  /* consume CRLF */
  if (c == '\r') {
    if ((c = [self readByte]) != '\n') {
      if (c == -1)
	return nil;
      [self logWithFormat:@"WARNING(%s): expected LF after CR, got: '%c'",
	      __PRETTY_FUNCTION__, c];
      return nil;
    }
  }
  
  return [[NSString alloc] initWithUTF8String:(char *)buf];
}

- (NSString *)readString {
  /* Note: returns a retained string */
  int c1;
  
  if ((c1 = [self readByte]) == -1)
    return nil;
  
  if (c1 == '"')
    return [self readQuoted];
  if (c1 == '{')
    return [self readLiteral];

  // Note: this does not return the first char!
  return [self readStringToCRLF];
}

- (NSString *)readSieveName {
  return [self readString];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  if (self->socket != nil)
    [ms appendFormat:@" socket=%@", [self socket]];
  else
    [ms appendFormat:@" address=%@", self->address];

  [ms appendString:@">"];
  return ms;
}

@end /* NGSieveClient */
