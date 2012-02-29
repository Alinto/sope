/*
  Copyright (C) 2000-2007 SKYRIX Software AG
  Copyright (C) 2007-2011 Inverse inc.

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
#include <fcntl.h>

#include "NGImap4Client.h"
#include "NGImap4Context.h"
#include "NGImap4Support.h"
#include "NGImap4Envelope.h"
#include "NGImap4EnvelopeAddress.h"
#include "NGImap4Functions.h"
#include "NGImap4ResponseParser.h"
#include "NGImap4ResponseNormalizer.h"
#include "NGImap4ServerGlobalID.h"
#include "NSString+Imap4.h"
#include "imCommon.h"
#include <sys/time.h>
#include "imTimeMacros.h"

#include <NGStreams/NGSocket.h>
#include <NGStreams/NGActiveSSLSocket.h>


@interface EOQualifier(IMAPAdditions)
- (NSString *)imap4SearchString;
@end

@interface EOSortOrdering(IMAPAdditions)
- (NSString *)imap4SortString;
@end

@interface NSArray(IMAPAdditions)
- (NSString *)imap4SortStringForSortOrderings;
@end

@interface NGImap4Client(ConnectionRegistration)

- (void)removeFromConnectionRegister;
- (void)registerConnection;
- (NGCTextStream *)textStream;

@end /* NGImap4Client(ConnectionRegistration); */

// #if GNUSTEP_BASE_LIBRARY
// /* FIXME: TODO: move someplace better (hh: NGExtensions...) */
// @implementation NSException(setUserInfo)

// - (id)setUserInfo:(NSDictionary *)_userInfo {
//   ASSIGN(self->_e_info, _userInfo);
//   return self;
// }

// @end /* NSException(setUserInfo) */
// #endif

@interface NGImap4Client(Private)

- (NSString *)_folder2ImapFolder:(NSString *)_folder;

- (NGHashMap *)processCommand:(NSString *)_command;
- (NGHashMap *)processCommand:(NSString *)_command withTag:(BOOL)_tag;
- (NGHashMap *)processCommand:(NSString *)_command withTag:(BOOL)_tag
  withNotification:(BOOL)_notification;
- (NGHashMap *)processCommand:(NSString *)_command logText:(NSString *)_txt;

- (void)sendCommand:(NSString *)_command;
- (void)sendCommand:(NSString *)_command withTag:(BOOL)_tag;
- (void)sendCommand:(NSString *)_command withTag:(BOOL)_tag
        logText:(NSString *)_txt;

- (void)sendResponseNotification:(NGHashMap *)map;

- (NSDictionary *)login;

- (NSDictionary *) _sopeSORT: (id)_sortSpec  qualifier:(EOQualifier *)_qual  encoding:(NSString *)_encoding;

@end

/*
  An implementation of an Imap4 client
  
  A folder name always looks like an absolute filename (/inbox/doof) 
*/

@implementation NGImap4Client

// TODO: replace?
static inline NSArray *_flags2ImapFlags(NGImap4Client *, NSArray *);

static NSNumber *YesNumber     = nil;
static NSNumber *NoNumber      = nil;

static id           *ImapClients       = NULL;
static unsigned int CountClient        = 0;
static unsigned int MaxImapClients     = 0;
static int          ProfileImapEnabled = -1;
static int          LogImapEnabled     = -1;
static int          PreventExceptions  = -1;
static BOOL         fetchDebug         = NO;
static BOOL         ImapDebugEnabled   = NO;
static NSArray      *Imap4SystemFlags  = nil;

static NSMutableDictionary *capabilities;
static NSMutableDictionary *namespaces;

- (BOOL)useSSL {
  return self->useSSL;
}

- (BOOL)useTLS {
  return self->useTLS;
}

+ (int)version {
  return 2;
}
+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;
  
  PreventExceptions  = [ud boolForKey:@"ImapPreventConnectionExceptions"]?1:0;
  LogImapEnabled     = [ud boolForKey:@"ImapLogEnabled"]?1:0;
  ProfileImapEnabled = [ud boolForKey:@"ProfileImapEnabled"]?1:0;
  ImapDebugEnabled   = [ud boolForKey:@"ImapDebugEnabled"];
  
  YesNumber = [[NSNumber numberWithBool:YES] retain];
  NoNumber  = [[NSNumber numberWithBool:NO]  retain];
  
  if (MaxImapClients < 1) {
    MaxImapClients = [ud integerForKey:@"NGImapMaxConnectionCount"];
    if (MaxImapClients < 1) MaxImapClients = 50;
  }
  if (ImapClients == NULL)
    ImapClients = calloc(MaxImapClients + 2, sizeof(id));

  Imap4SystemFlags = [[NSArray alloc] initWithObjects: @"seen", @"answered",
				      @"deleted", @"draft", nil];

  capabilities = [[NSMutableDictionary alloc] init];
  namespaces = [[NSMutableDictionary alloc] init];
}

/* constructors */

+ (id)clientWithURL:(NSURL *)_url {
  return [[(NGImap4Client *)[self alloc] initWithURL:_url] autorelease];
}
+ (id)clientWithAddress:(id<NGSocketAddress>)_address {
  return
    [[(NGImap4Client *)[self alloc] initWithAddress:_address] autorelease];
}

+ (id)clientWithHost:(id)_host {
  return [[[self alloc] initWithHost:_host] autorelease];
}

- (id)initWithHost:(id)_host {
  NGInternetSocketAddress *a;
  
  a = [NGInternetSocketAddress addressWithPort:143 onHost:_host];
  return [self initWithAddress:a];
}
- (id)initWithURL:(NSURL *)_url {
  NGInternetSocketAddress *a;
  int port;
  id  tmp;
  
  if ((self->useSSL = [[_url scheme] isEqualToString:@"imaps"])) {
    if (NSClassFromString(@"NGActiveSSLSocket") == nil) {
      [self logWithFormat:
            @"no SSL support available, cannot connect: %@", _url];
      [self release];
      return nil;
    }
  }
  if ((tmp = [_url port])) {
    port = [tmp intValue];
    if (port <= 0) port = self->useSSL ? 993 : 143;
  }
  else
    port = self->useSSL ? 993 : 143;

  if ([[_url query] isEqualToString:@"tls=YES"]) {
    self->useTLS = YES;

    if ([tmp intValue] <= 0)
      port = 143;
  }
  
  self->login    = [[_url user]     copy];
  self->password = [[_url password] copy];
  
  a = [NGInternetSocketAddress addressWithPort:port onHost:[_url host]];
  return [self initWithAddress:a];
}

- (id)initWithAddress:(id<NGSocketAddress>)_address { /* designated init */
  if ((self = [super init])) {
    self->address          = [_address retain];
    self->debug            = ImapDebugEnabled;
    self->responseReceiver = [[NSMutableArray alloc] initWithCapacity:128];
    self->normer = [[NGImap4ResponseNormalizer alloc] initWithClient:self];
    self->loggedIn	   = NO;
    self->context	   = nil;
    self->useUTF8          = YES;
  }
  return self;
}

- (void)dealloc {
  if (self->loggedIn) [self logout];
  [self removeFromConnectionRegister];
  [self->enabledExtensions release];
  [self->normer           release];
  [self->text             release];
  [self->address          release];
  [self->socket           release];
  [self->previous_socket  release];
  [self->parser           release];
  [self->responseReceiver release];
  [self->login            release];
  [self->password         release];
  [self->selectedFolder   release];
  [self->delimiter        release];
  [self->serverGID        release];
  
  self->context = nil; /* not retained */
  [super dealloc];
}

/* equality (required for adding clients to Foundation sets) */

- (BOOL)isEqual:(id)_obj {
  if (_obj == self)
    return YES;
  
  if ([_obj isKindOfClass:[NGImap4Client class]])
    return [self isEqualToClient:_obj];
  
  return NO;
}

- (BOOL)isEqualToClient:(NGImap4Client *)_obj {
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

- (NSString *)delimiter {
  return self->delimiter;
}

- (EOGlobalID *)serverGlobalID {
  NGInternetSocketAddress *is;
  
  if (self->serverGID)
    return self->serverGID;
  
  is = (id)[self address];
  
  self->serverGID = [[NGImap4ServerGlobalID alloc]
		      initWithHostname:[is hostName]
		      port:[is port]
		      login:self->login];
  return self->serverGID;
}

- (NSString *)selectedFolderName {
  return self->selectedFolder;
}

/* connection */

- (id)_openSocket {
  Class socketClass = Nil;
  id sock;

  socketClass = [NGActiveSocket class];
  
  if ([self useSSL] && ![self useTLS])
    socketClass = NSClassFromString(@"NGActiveSSLSocket");
  
  NS_DURING {
      sock = [socketClass socketConnectedToAddress:self->address];
  }
  NS_HANDLER {
    [self->context setLastException:localException];
    sock = nil;
  }
  NS_ENDHANDLER;
  
  return sock;
}

- (NSDictionary *)_receiveServerGreetingWithoutTagId {
  NSDictionary *res = nil;
  
  NS_DURING {
    NSException *e;
    NGHashMap *hm;
    
    hm = [self->parser parseResponseForTagId:-1 exception:&e];
    [e raise];
    res = [self->normer normalizeOpenConnectionResponse:hm];

    // If using Courier, we disable UTF-8
    if ([[res objectForKey:@"serverKind"] isEqual: @"courier"])
      self->useUTF8 = NO;
    
    // If we're using TLS, we start it here
    if ([self useTLS])
      {
	Class socketClass;
	NSDictionary *d;


	d = [self->normer normalizeResponse:[self processCommand: @"STARTTLS"]];
	socketClass = NSClassFromString(@"NGActiveSSLSocket");

	if ([[d valueForKey:@"result"] boolValue] && socketClass)
	  {
	    int oldopts;
	    id o;

	    o = [[socketClass alloc] initWithDomain: [self->address domain]];
	    [o setFileDescriptor: [(NGSocket*)self->socket fileDescriptor]];
	    
	    // We remove the NON-BLOCKING I/O flag on the file descriptor, otherwise
	    // SOPE will break on SSL-sockets.
	    oldopts = fcntl([(NGSocket*)self->socket fileDescriptor], F_GETFL, 0);
	    fcntl([(NGSocket*)self->socket fileDescriptor], F_SETFL, oldopts & !O_NONBLOCK);
	    
	    if ([o startTLS])
	      {
		NGBufferedStream *buffer;
		
		// We keep a reference to our previous instance of NGActiveSocket as
		// it's still being used. NGActiveSSLSocket's read/write methods are
		// being used but the rest is coming of directly from NGActiveSocket
		self->previous_socket = self->socket;
		self->socket = o;
		[self->text release];
		[self->parser release];
		
		buffer = [(NGBufferedStream *)[NGBufferedStream alloc] initWithSource: self->socket];
		self->text = [(NGCTextStream *)[NGCTextStream alloc] initWithSource: buffer];
		[buffer release];
		buffer = nil;
		
		self->parser = [[NGImap4ResponseParser alloc] initWithStream: self->socket];
		[self logWithFormat:@"TLS started successfully."];
	      }
	    else
	      [self logWithFormat:@"Could not start TLS."];
	  }
	else
	  [self logWithFormat:@"Could not start TLS."];
      }
  }
  NS_HANDLER
    [self->context setLastException:localException];
  NS_ENDHANDLER;
  
  if (!_checkResult(self->context, res, __PRETTY_FUNCTION__))
    return nil;

  return res;
}

- (NSDictionary *)_openConnection {
  /* open connection as configured */
  NGBufferedStream *buffer;
  struct timeval tv;
  double         ti = 0.0;
  
  if (ProfileImapEnabled == 1) {
    gettimeofday(&tv, NULL);
    ti =  (double)tv.tv_sec + ((double)tv.tv_usec / 1000000.0);
  }
  [self->socket release]; self->socket = nil;
  [self->previous_socket release]; self->previous_socket = nil;
  [self->parser release]; self->parser = nil;
  [self->text   release]; self->text   = nil;
  
  [self->context resetLastException];

  if ((self->socket = [[self _openSocket] retain]) == nil)
    return nil;
  if ([self->context lastException])
    return nil;
  
  buffer     = 
    [(NGBufferedStream *)[NGBufferedStream alloc] initWithSource:self->socket];
  self->text = [(NGCTextStream *)[NGCTextStream alloc] initWithSource:buffer];
  [buffer release]; buffer = nil;
  
  self->parser = [[NGImap4ResponseParser alloc] initWithStream:self->socket];
  self->tagId  = 0;
  
  if (ProfileImapEnabled == 1) {
    gettimeofday(&tv, NULL);
    ti = (double)tv.tv_sec + ((double)tv.tv_usec / 1000000.0) - ti;
    fprintf(stderr, "[%s] <openConnection> : time needed: %4.4fs\n",
           __PRETTY_FUNCTION__, ti < 0.0 ? -1.0 : ti);    
  }

  self->enabledExtensions = [[NSMutableArray alloc] init];

  [self registerConnection];
  [self->context resetLastException];
  
  return [self _receiveServerGreetingWithoutTagId];
}

- (NSDictionary *)openConnection {
  return [self _openConnection];
}

- (NSNumber *)isConnected {
  // TODO: why is that an NSNummber?
  /* 
     Check whether stream is already open (could be closed because 
     server-timeout) 
  */
  return (self->socket == nil)
    ? NoNumber 
    : ([(NGActiveSocket *)self->socket isAlive] ? YesNumber : NoNumber);
}

- (NSException *)_handleTextReleaseException:(NSException *)_ex {
  [self logWithFormat:@"got exception during stream dealloc: %@", _ex];
  return nil;
}
- (NSException *)_handleSocketCloseException:(NSException *)_ex {
  [self logWithFormat:@"got exception during socket close: %@", _ex];
  return nil;
}
- (NSException *)_handleSocketReleaseException:(NSException *)_ex {
  [self logWithFormat:@"got exception during socket deallocation: %@", _ex];
  return nil;
}
- (void)closeConnection {
  /* close a connection */
  
  // TODO: this is a bit weird, probably because of the flush
  //       maybe just call -close on the text stream?
  NS_DURING
    [self->text release]; 
  NS_HANDLER
    [[self _handleTextReleaseException:localException] raise];
  NS_ENDHANDLER;
  self->text = nil;
  
  NS_DURING
    [self->socket close];
    [self->previous_socket close];
  NS_HANDLER
    [[self _handleSocketCloseException:localException] raise];
  NS_ENDHANDLER;
  
  NS_DURING
    [self->socket release];
    [self->previous_socket release];
  NS_HANDLER
    [[self _handleSocketReleaseException:localException] raise];
  NS_ENDHANDLER;
  self->socket = nil;
  self->previous_socket = nil;   
  
  [self->parser    release]; self->parser    = nil;
  [self->delimiter release]; self->delimiter = nil;
  [self->enabledExtensions release]; self->enabledExtensions = nil;

  [self removeFromConnectionRegister];
}

// ResponseNotifications

- (void)registerForResponseNotification:(id<NGImap4ResponseReceiver>)_obj {
  [self->responseReceiver addObject:[NSValue valueWithNonretainedObject:_obj]];
}

- (void)removeFromResponseNotification:(id<NGImap4ResponseReceiver>)_obj {
  [self->responseReceiver removeObject:
       [NSValue valueWithNonretainedObject:_obj]];
}

- (void)sendResponseNotification:(NGHashMap *)_map {
  NSValue                     *val;
  id<NGImap4ResponseReceiver> obj;
  NSEnumerator                *enumerator;
  NSDictionary                *resp;

  resp       = [self->normer normalizeResponse:_map];
  enumerator = [self->responseReceiver objectEnumerator];

  while ((val = [enumerator nextObject])) {
    obj = [val nonretainedObjectValue];
    [obj responseNotificationFrom:self response:resp];
  }
}

/* commands */

- (NSDictionary *)login:(NSString *)_login password:(NSString *)_passwd {
  /* login with plaintext password authenticating */

  if ((_login == nil) || (_passwd == nil))
    return nil;

  [self->login     release]; self->login    = nil;
  [self->password  release]; self->password = nil;
  [self->serverGID release]; self->serverGID = nil;
  
  self->login    = [_login copy];
  self->password = [_passwd copy];
  
  return [self login];
}

- (void)reconnect {
  NSArray *extensions;

  if ([self->context lastException] != nil)
    return;

  extensions = self->enabledExtensions;
  [extensions retain];

  [self closeConnection];
  self->tagId = 0;
  [self openConnection];

  if ([self->context lastException] != nil)
    return;
  
  [self login];

  if (self->loggedIn && [extensions count] > 0) {
    [self enable: extensions];
  }
  [extensions autorelease];
}

- (NSDictionary *)login {
  /*
    On failure returns a dictionary with those keys:
      'result'      - a boolean => false
      'reason'      - reason why login failed
      'RawResponse' - the raw IMAP4 response
    On success:
      'result'      - a boolean => true
      'expunge'     - an array (containing what?)
      'RawResponse' - the raw IMAP4 response
  */
  NSDictionary *response;
  NGHashMap *map;
  NSString  *s;
  NSUInteger plength;

  if (self->isLogin)
    return nil;
  
  self->isLogin = YES;

  if (self->useUTF8)
    plength = [self->password lengthOfBytesUsingEncoding: NSUTF8StringEncoding];
  else
    plength = [self->password length];

  if (plength > 0)
    s = [NSString stringWithFormat:@"login \"%@\" {%d}",
		  self->login, plength];
  else
    s = [NSString stringWithFormat:@"login \"%@\" \"\"", self->login];

  map = [self processCommand: s
                     withTag: YES
            withNotification: NO];
  
  if (plength > 0 && [[map objectForKey:@"ContinuationResponse"] boolValue])
    map = [self processCommand:self->password withTag:NO];
  
  if (self->selectedFolder != nil)
    [self select:self->selectedFolder];
  
  self->isLogin = NO;
  
  response = [self->normer normalizeResponse:map];

  self->loggedIn = [[response valueForKey:@"result"] boolValue];

  return response;
}

- (NSDictionary *)logout {
  /* logout from the connected host and close the connection */
  NGHashMap *map;

  map = [self processCommand:@"logout"];
  [self closeConnection];
  [self->selectedFolder release]; self->selectedFolder = nil;
  self->loggedIn = NO;
  
  return [self->normer normalizeResponse:map];
}

/* Authenticated State */

- (NSDictionary *)list:(NSString *)_folder pattern:(NSString *)_pattern {
  /*
    The method build statements like 'LIST "_folder" "_pattern"'.
    The Cyrus IMAP4 v1.5.14 server ignores the given folder.
    Instead of you should use the pattern to get the expected result.
    If folder is NIL it would be set to empty string ''.
    If pattern is NIL it would be set to ''.

    The result dict contains the following keys:
      'result'      - a boolean
      'list'        - a dictionary (key is folder name, value is flags)
      'RawResponse' - the raw IMAP4 response
  */
  NSAutoreleasePool *pool;
  NGHashMap         *map;
  NSDictionary      *result;
  NSString *s, *prefix;
  
  pool = [[NSAutoreleasePool alloc] init];
  
  if (_folder  == nil) _folder  = @"";
  if (_pattern == nil) _pattern = @"";
  
  if ([_folder isNotEmpty]) {
    if ((_folder = [self _folder2ImapFolder:_folder]) == nil)
      return nil;
  }
  

  if ([_pattern isNotEmpty])
    if (!(_pattern = [self _folder2ImapFolder:_pattern]))
      return nil;
  
  if ([_folder length] > 0)
    prefix = [NSString stringWithFormat: @"%@%@",
                       SaneFolderName(_folder), self->delimiter];
  else
    prefix = @"";
  s = [NSString stringWithFormat:@"LIST \"\" \"%@%@\"", prefix, _pattern];
  map = [self processCommand:s];
  
  if (self->delimiter == nil) {
    NSDictionary *rdel;
    
    rdel = [[map objectEnumeratorForKey:@"list"] nextObject];
    self->delimiter = [[rdel objectForKey:@"delimiter"] copy];
  }
  
  result = [[self->normer normalizeListResponse:map] copy];
  [pool release];
  return [result autorelease];
}

- (NSDictionary *)capability {
  NSDictionary *result;
  id capres;
  
  result = [capabilities objectForKey: [self->address description]];

  if (!result)
    {
      capres = [self processCommand:@"capability"];
      result = [self->normer normalizeCapabilityResponse:capres];
  
      if (result)
	[capabilities setObject:  result  forKey: [self->address description]];
    }
  return result;
}

- (NSDictionary *)enable:(NSArray *)_extensions {
  NSDictionary *result;
  NSString *cmd;

  cmd = [NSString stringWithFormat:@"ENABLE %@", [_extensions componentsJoinedByString: @" "]];
  result = [self->normer normalizeResponse:[self processCommand:cmd]];
  if ([[result valueForKey:@"result"] boolValue]) {
    [enabledExtensions removeObjectsInArray: _extensions];
    [enabledExtensions addObjectsFromArray: _extensions];
  }
  
  return result;
}

- (NSDictionary *)namespace {
  NSArray *capabilities;
  NGHashMap *namesres;
  id namespace;

  namespace = [namespaces objectForKey: [self->address description]];
  if (!namespace) {
    capabilities = [[self capability] objectForKey: @"capability"];
    if ([capabilities containsObject: @"namespace"]) {
      namesres = [self processCommand: @"namespace"];
      namespace = [self->normer normalizeNamespaceResponse:namesres];
    }
    else
      namespace = [NSNull null];
    [namespaces setObject: namespace forKey: [self->address description]];
  }

  return ([namespace isKindOfClass: [NSNull class]] ? nil : namespace);
}

- (NSDictionary *)lsub:(NSString *)_folder pattern:(NSString *)_pattern {
  /*
    The method build statements like 'LSUB "_folder" "_pattern"'.
    The returnvalue is the same like the list:pattern: method
  */
  NGHashMap *map;
  NSString  *s, *prefix;

  if (_folder == nil)
    _folder = @"";

  if ([_folder isNotEmpty]) {
    if ((_folder = [self _folder2ImapFolder:_folder]) == nil)
      return nil;
  }
  if (_pattern == nil)
    _pattern = @"";

  if ([_pattern isNotEmpty]) {
    if ((_pattern = [self _folder2ImapFolder:_pattern]) == nil)
      return nil;
  }
  
  if ([_folder length] > 0)
    prefix = [NSString stringWithFormat: @"%@%@", SaneFolderName(_folder), self->delimiter];
  else
    prefix = @"";
  s = [NSString stringWithFormat:@"LSUB \"\" \"%@%@\"", prefix, _pattern];
  map = [self processCommand:s];

  if (self->delimiter == nil) {
    NSDictionary *rdel;
    
    rdel = [[map objectEnumeratorForKey:@"LIST"] nextObject];
    self->delimiter = [[rdel objectForKey:@"delimiter"] copy];
  }
  return [self->normer normalizeListResponse:map];
}

- (NSDictionary *)select:(NSString *)_folder {
  /*
    Select a folder (required for a lot of methods).
    eg: 'SELECT "INBOX"'
    
    The result dict contains the following keys:
      'result'      - a boolean
      'access'      - string           (eg "READ-WRITE")
      'exists'      - number?          (eg 1)
      'recent'      - number?          (eg 0)
      'expunge'     - array            (of what?)
      'flags'       - array of strings (eg (answered,flagged,draft,seen);
      'RawResponse' - the raw IMAP4 response
   */
  NSString *s, *newFolder;

  if (![_folder isNotEmpty])
    return nil;
  if ((_folder = [self _folder2ImapFolder:_folder]) == nil)
    return nil;

  newFolder = [NSString stringWithString: _folder];
  ASSIGN (self->selectedFolder, newFolder);

  s = [NSString stringWithFormat:@"select \"%@\"", SaneFolderName(self->selectedFolder)];
  return [self->normer normalizeSelectResponse:[self processCommand:s]];
}

- (NSDictionary *)unselect {
  [self->selectedFolder release]; self->selectedFolder = nil;
  return [self->normer normalizeResponse:[self processCommand:@"unselect"]];
}

- (NSDictionary *)status:(NSString *)_folder flags:(NSArray *)_flags {
  NSString *cmd;
  
  if (_folder == nil)
    return nil;
  if ((_flags == nil) || ([_flags count] == 0))
    return nil;
  if ((_folder = [self _folder2ImapFolder:_folder]) == nil)
    return nil;
  
  cmd     = [NSString stringWithFormat:@"status \"%@\" (%@)",
                      SaneFolderName(_folder), [_flags componentsJoinedByString:@" "]];
  return [self->normer normalizeStatusResponse:[self processCommand:cmd]];
}

- (NSDictionary *)noop {
  // at any state
  return [self->normer normalizeResponse:[self processCommand:@"noop"]];
}

- (NSDictionary *)rename:(NSString *)_folder to:(NSString *)_newName {
  NSString *cmd;
  
  if ((_folder = [self _folder2ImapFolder:_folder]) == nil)
    return nil;
  if ((_newName = [self _folder2ImapFolder:_newName]) == nil)
    return nil;
  
  cmd = [NSString stringWithFormat:@"rename \"%@\" \"%@\"",
                  SaneFolderName(_folder), SaneFolderName(_newName)];
  
  return [self->normer normalizeResponse:[self processCommand:cmd]];
}

- (NSDictionary *)_performCommand:(NSString *)_op onFolder:(NSString *)_fname {
  NSString *command;

  if ((_fname = [self _folder2ImapFolder:_fname]) == nil)
    return nil;

  // eg: 'delete "blah"'
  command = [NSString stringWithFormat:@"%@ \"%@\"", _op, SaneFolderName(_fname)];

  return [self->normer normalizeResponse:[self processCommand:command]];
}

- (NSDictionary *)delete:(NSString *)_name {
  if ([self->selectedFolder isEqualToString:_name]) {
    [self unselect];
  }
  return [self _performCommand:@"delete" onFolder:_name];
}
- (NSDictionary *)create:(NSString *)_name {
  return [self _performCommand:@"create" onFolder:_name];
}
- (NSDictionary *)subscribe:(NSString *)_name {
  return [self _performCommand:@"subscribe" onFolder:_name];
}
- (NSDictionary *)unsubscribe:(NSString *)_name {
  return [self _performCommand:@"unsubscribe" onFolder:_name];
}

- (NSDictionary *)expunge {
  return [self->normer normalizeResponse:[self processCommand:@"expunge"]];
}

- (NSString *)_uidsJoinedForFetchCmd:(NSArray *)_uids {
  return [_uids componentsJoinedByString:@","];
}
- (NSString *)_partsJoinedForFetchCmd:(NSArray *)_parts {
  return [_parts componentsJoinedByString:@" "];
}

- (NSDictionary *)fetchUids:(NSArray *)_uids parts:(NSArray *)_parts {
  /*
    eg: 'UID FETCH 1189,1325,1326 ([TODO])'
  */
  NSAutoreleasePool *pool;
  NSString          *cmd;
  NSDictionary      *result;
  NSString          *uidsStr, *partsStr;
  id fetchres;
  
  pool = [[NSAutoreleasePool alloc] init];
  
  uidsStr  = [self _uidsJoinedForFetchCmd:_uids];
  partsStr = [self _partsJoinedForFetchCmd:_parts];
  cmd  = [NSString stringWithFormat:@"uid fetch %@ (%@)", uidsStr, partsStr];
  
  fetchres = [self processCommand:cmd];
  result   = [[self->normer normalizeFetchResponse:fetchres] retain];
  [pool release];
  
  return [result autorelease];
}

- (NSDictionary *)fetchUid:(unsigned)_uid parts:(NSArray *)_parts {
  // TODO: describe what exactly this can return!
  NSAutoreleasePool *pool;
  NSString          *cmd;
  NSDictionary      *result;
  id fetchres;
  
  pool   = [[NSAutoreleasePool alloc] init];
  cmd    = [NSString stringWithFormat:@"uid fetch %d (%@)", _uid,
                     [self _partsJoinedForFetchCmd:_parts]];
  fetchres = [self processCommand:cmd];
  result   = [[self->normer normalizeFetchResponse:fetchres] retain];
  
  [pool release];
  return [result autorelease];
}

- (NSDictionary *)fetchFrom:(unsigned)_from to:(unsigned)_to
  parts:(NSArray *)_parts
{
  // TODO: optimize
  NSAutoreleasePool *pool;
  NSMutableString   *cmd;
  NSDictionary      *result; 
  NGHashMap         *rawResult;
 
  if (_to == 0)
    return [self noop];
  
  if (_from == 0)
    _from = 1;

  pool = [[NSAutoreleasePool alloc] init];
  {
    unsigned i, count;
    
    cmd = [NSMutableString stringWithCapacity:256];
    [cmd appendString:@"fetch "];
    [cmd appendFormat:@"%d:%d (", _from, _to];
    for (i = 0, count = [_parts count]; i < count; i++) {
      if (i != 0) [cmd appendString:@" "];
      [cmd appendString:[_parts objectAtIndex:i]];
    }
    [cmd appendString:@")"];
    
    if (fetchDebug) NSLog(@"%s: process: %@", __PRETTY_FUNCTION__, cmd);
    rawResult = [self processCommand:cmd];
    /*
      RawResult is a dict containing keys:
        ResponseResult: dict    eg: {descripted=Completed;result=ok;tagId=8;}
	fetch:          array of record dicts (eg "rfc822.header" key)
    */
    
    if (fetchDebug) NSLog(@"%s: normalize: %@", __PRETTY_FUNCTION__,rawResult);
    result = [[self->normer normalizeFetchResponse:rawResult] retain];
    if (fetchDebug) NSLog(@"%s: normalized: %@", __PRETTY_FUNCTION__, result);
  }
  [pool release];
  if (fetchDebug) NSLog(@"%s: pool done.", __PRETTY_FUNCTION__);
  return [result autorelease];
}

- (NSDictionary *)fetchVanished:(uint64_t)_modseq
{
  NSAutoreleasePool *pool;
  NSString          *cmd;
  NSDictionary      *result;
  id fetchres;
  
  pool = [[NSAutoreleasePool alloc] init];
  
  cmd  = [NSString stringWithFormat:
                     @"UID FETCH 1:* (UID) (CHANGEDSINCE %llu VANISHED)",
                   _modseq];
  fetchres = [self processCommand:cmd];
  result   = [[self->normer normalizeFetchResponse:fetchres] retain];
  [pool release];
  
  return [result autorelease];
}

- (NSDictionary *)storeUid:(unsigned)_uid add:(NSNumber *)_add
  flags:(NSArray *)_flags
{
  NSString *icmd, *iflags;
  
  iflags = [_flags2ImapFlags(self, _flags) componentsJoinedByString:@" "];
  icmd   = [NSString stringWithFormat:@"uid store %d %cFLAGS (%@)",
                     _uid, [_add boolValue] ? '+' : '-',
                     iflags];
  return [self->normer normalizeResponse:[self processCommand:icmd]];
}

- (NSDictionary *)storeFrom:(unsigned)_from to:(unsigned)_to
  add:(NSNumber *)_add
  flags:(NSArray *)_flags
{
  NSString *cmd;
  NSString *flagstr;

  if (_to == 0)
    return [self noop];
  if (_from == 0)
    _from = 1;

  flagstr = [_flags2ImapFlags(self, _flags) componentsJoinedByString:@" "];
  cmd = [NSString stringWithFormat:@"store %d:%d %cFLAGS (%@)",
		    _from, _to, [_add boolValue] ? '+' : '-', flagstr];
  
  return [self->normer normalizeResponse:[self processCommand:cmd]];
}

- (NSDictionary *)storeFlags:(NSArray *)_flags forUIDs:(id)_uids
  addOrRemove:(BOOL)_flag
{
  NSString *cmd;
  NSString *flagstr;
  NSString *seqstr;
  
  if ([_uids isKindOfClass:[NSArray class]]) {
    // TODO: improve by using ranges, eg 1:5 instead of 1,2,3,4,5
    _uids  = [_uids valueForKey:@"stringValue"];
    seqstr = [_uids componentsJoinedByString:@","];
  }
  else
    seqstr = [_uids stringValue];
  
  flagstr = [_flags2ImapFlags(self, _flags) componentsJoinedByString:@" "];
  cmd = [NSString stringWithFormat:@"UID STORE %@ %cFLAGS (%@)",
		    seqstr, _flag ? '+' : '-', flagstr];
  
  return [self->normer normalizeResponse:[self processCommand:cmd]];
}

- (NSDictionary *)copyFrom:(unsigned)_from to:(unsigned)_to
  toFolder:(NSString *)_folder
{
  NSString *cmd;

  if (_to == 0)
    return [self noop];
  if (_from == 0)
    _from = 1;
  if ((_folder = [self _folder2ImapFolder:_folder]) == nil)
    return nil;
  
  cmd = [NSString stringWithFormat:@"copy %d:%d \"%@\"", _from, _to, _folder];
  return [self->normer normalizeResponse:[self processCommand:cmd]];
}

- (NSDictionary *)copyUid:(unsigned)_uid toFolder:(NSString *)_folder {
  NSString *cmd;
  
  if ((_folder = [self _folder2ImapFolder:_folder]) == nil)
    return nil;
  
  cmd = [NSString stringWithFormat:@"uid copy %d \"%@\"", _uid, _folder];
  
  return [self->normer normalizeResponse:[self processCommand:cmd]];
}
- (NSDictionary *)copyUids:(NSArray *)_uids toFolder:(NSString *)_folder {
  NSString *cmd;
  
  if ((_folder = [self _folder2ImapFolder:_folder]) == nil)
    return nil;
  
  cmd = [NSString stringWithFormat:@"uid copy %@ \"%@\"", 
		  [_uids componentsJoinedByString:@","], _folder];
  
  return [self->normer normalizeResponse:[self processCommand:cmd]];
}

- (NSDictionary *)getQuotaRoot:(NSString *)_folder {
  NSString *cmd;

  if ((_folder = [self _folder2ImapFolder:_folder]) == nil)
    return nil;
  
  cmd = [NSString stringWithFormat:@"getquotaroot \"%@\"", _folder];
  return [self->normer normalizeQuotaResponse:[self processCommand:cmd]];
}

- (NSDictionary *)append:(NSData *)_message toFolder:(NSString *)_folder
  withFlags:(NSArray *)_flags
{
  NSArray   *flags;
  NGHashMap *result;
  NSString  *message, *icmd;
  char       *new;
  const char *old;
  int         cntOld   = 0;
  int         cntNew   = 0;
  int         len      = 0;

  flags   = _flags2ImapFlags(self, _flags);
  if ((_folder = [self _folder2ImapFolder:_folder]) == nil)
    return nil;
  
  /* Remove bare newlines */
  old = [_message bytes];
  len = [_message length];

  new = calloc(len * 2 + 4, sizeof(char));

  while (cntOld < (len - 1)) {
    if (old[cntOld] == '\n') {
      new[cntNew] = '\r'; cntNew++;
      new[cntNew] = '\n'; cntNew++;
    }
    else if (old[cntOld] != '\r') {
      new[cntNew] = old[cntOld]; cntNew++;
    }
    cntOld++;
  }
  if (old[cntOld] == '\n') {
    new[cntNew] = '\r'; cntNew++;
    new[cntNew] = '\n'; cntNew++;
  }
  else if (old[cntOld] != '\r') {
    new[cntNew] = old[cntOld]; cntNew++;
  }

  // TODO: fix this junk, do not treat the message as a string, its NSData
  message = [[NSString alloc] initWithBytes: new
                                     length: cntNew
                                   encoding: NSISOLatin1StringEncoding];
  if (new != NULL) free(new); new = NULL;

  icmd = [NSString stringWithFormat:@"append \"%@\" (%@) {%d}",
                     _folder,
                     [flags componentsJoinedByString:@" "],
                     cntNew];
  result = [self processCommand:icmd
                 withTag:YES withNotification:NO];
  
  // TODO: explain that
  if ([[result objectForKey:@"ContinuationResponse"] boolValue])
    result = [self processCommand:message withTag:NO];

  [message release]; message = nil;

  return [self->normer normalizeResponse:result];
}

- (void)_handleSearchExprIssue:(NSString *)reason qualifier:(EOQualifier *)_q {
  NSString     *descr;
  NSException  *exception = nil;                                             
  NSDictionary *ui;
  
  if (PreventExceptions != 0)
    return;
  
  if (_q == nil) _q = (id)[NSNull null];                
  
  descr = @"Could not process qualifier for imap search "; 
  descr = [descr stringByAppendingString:reason];           
  
  ui = [NSDictionary dictionaryWithObject:_q forKey:@"qualifier"];
  exception
    = [NGImap4SearchException exceptionWithName: @"NGImap4SearchException"
			      reason: descr
			      userInfo: ui];
  [self->context setLastException:exception];
}

- (NSString *)_searchExprForQual:(EOQualifier *)_qualifier {
  /*
    samples:
      ' ALL'
      ' SINCE 1-Feb-1994'
      ' TEXT "why SOPE rocks"'
  */
  id result;
  
  if (_qualifier == nil)
    return @" ALL";
  
  result = [_qualifier imap4SearchString];
  if ([result isKindOfClass:[NSException class]]) {
    [self _handleSearchExprIssue:[(NSException *)result reason]
          qualifier:_qualifier];
    return nil;
  }
  return [@" " stringByAppendingString:result];
}

- (NSDictionary *)threadBySubject: (BOOL)_bySubject
                          charset: (NSString *)_charSet
                        qualifier: (EOQualifier *)_qual
{
  /*
    http://www.ietf.org/proceedings/03mar/I-D/draft-ietf-imapext-thread-12.txt

    Returns an array of uids in sort order.

    Parameters:
      _bySubject - if yes, use "REFERENCES" else "ORDEREDSUBJECT"
      _charSet   - default: "UTF-8"
    
    Generates:
      UID THREAD REFERENCES|ORDEREDSUBJECT UTF-8 ALL
  */
  NSString *threadStr;
  NSString *threadAlg;
  NSArray *capa;
  
  threadAlg = (_bySubject) ? @"ORDEREDSUBJECT" : @"REFERENCES";
  
  if (![_charSet isNotEmpty])
    _charSet = @"UTF-8";

  // Verify server capablities
  capa = [[self capability] objectForKey: @"capability"];
  if ([capa indexOfObject: [NSString stringWithFormat: @"thread=%@", [threadAlg lowercaseString]]] == NSNotFound)
    {
      [self logWithFormat: @"WARNING: No support for THREAD %@ for %@", threadAlg, [self->address description]];
      threadAlg = (_bySubject) ? @"REFERENCES" : @"ORDEREDSUBJECT";        
      if ([capa indexOfObject: [NSString stringWithFormat: @"thread=%@", [threadAlg lowercaseString]]] == NSNotFound)
        {
          [self errorWithFormat: @"No support for THREAD %@ for %@", threadAlg, [self->address description]];
          return nil;
        }
    }
  
  threadStr = [NSString stringWithFormat:@"UID THREAD %@ %@ (%@)",
                        threadAlg, _charSet,
               [[self _searchExprForQual: _qual] substringFromIndex: 1]];
  
  return [self->normer normalizeThreadResponse:
                          [self processCommand: threadStr]];
}

- (NSString *)_generateIMAP4SortOrdering:(EOSortOrdering *)_sortOrdering {
  // TODO: still called by anything?
  return [_sortOrdering imap4SortString];
}
- (NSString *)_generateIMAP4SortOrderings:(NSArray *)_sortOrderings {
  return [_sortOrderings imap4SortStringForSortOrderings];
}

- (NSDictionary *)primarySort:(NSString *)_sort
  qualifierString:(NSString *)_qualString
  encoding:(NSString *)_encoding
{
  /* 
     http://www.ietf.org/internet-drafts/draft-ietf-imapext-sort-17.txt
     
     The result dict contains the following keys:
      'result'      - a boolean
      'expunge'     - array            (of what?)
      'sort'        - array of uids in sort order
      'RawResponse' - the raw IMAP4 response
     
     Eg: UID SORT ( DATE REVERSE SUBJECT ) UTF-8 TODO
  */
  NSMutableString *sortStr;
  NSUserDefaults *ud;

  if (![_encoding   isNotNull]) _encoding   = @"UTF-8";
  if (![_qualString isNotNull]) _qualString = @" ALL";
  
  // Prior sending the SORT command, we make sure it really supports
  // SORT UTF-8. We could have received that no matter what is supported
  if (!self->useUTF8)
    _encoding = @"US-ASCII";

  // If we forced an encoding, we ignore everything and uses that
  ud = [NSUserDefaults standardUserDefaults];
  if ([ud stringForKey:@"ImapSortEncoding"])
    _encoding = [ud stringForKey:@"ImapSortEncoding"];

  sortStr = [NSMutableString stringWithCapacity:128];
  
  [sortStr appendString:@"UID SORT ("];
  if (_sort != nil) [sortStr appendString:_sort];
  [sortStr appendString:@") "];
  
  [sortStr appendString:_encoding];   /* eg 'UTF-8' or '' */
  
  /* Note: this is _space sensitive_! to many spaces lead to error! */
  [sortStr appendString:_qualString]; /* eg ' ALL' or ' TEXT "abc"' */
  
  return [self->normer normalizeSortResponse:[self processCommand:sortStr]];
}

- (NSDictionary *)sort:(id)_sortSpec qualifier:(EOQualifier *)_qual
  encoding:(NSString *)_encoding
{
  /* 
     http://www.ietf.org/internet-drafts/draft-ietf-imapext-sort-17.txt

     The _sortSpec can be:
     - a simple 'raw' IMAP4 sort string
     - an EOSortOrdering
     - an array of EOSortOrderings
     
     The result dict contains the following keys:
      'result'      - a boolean
      'expunge'     - array            (of what?)
      'sort'        - array of uids in sort order
      'RawResponse' - the raw IMAP4 response
    
     If no sortable key was found, the sort will run against 'DATE'.
     => TODO: this is inconsistent. If none are passed in, false will be
              returned
     
     Eg: UID SORT ( DATE REVERSE SUBJECT ) UTF-8 TODO
  */
  NSString *tmp;
  NSArray *capa;
  
  // We first check to see if our server supports IMAP SORT. If not
  // we'll sort ourself the results.
  capa = [[self capability] objectForKey: @"capability"];

  if ([capa indexOfObject: @"sort"] == NSNotFound)
    {
      return [self _sopeSORT: _sortSpec  qualifier: _qual  encoding: _encoding];
    }

  
  if ([_sortSpec isKindOfClass:[NSArray class]])
    tmp = [self _generateIMAP4SortOrderings:_sortSpec];
  else if ([_sortSpec isKindOfClass:[EOSortOrdering class]])
    tmp = [self _generateIMAP4SortOrdering:_sortSpec];
  else
    tmp = [_sortSpec stringValue];
  
  if (![tmp isNotEmpty]) { /* found no valid key use date sorting */
    [self logWithFormat:@"Note: no key found for sorting, using 'DATE': %@",
	    _sortSpec];
    tmp = @"DATE";
  }
  
  return [self primarySort: tmp 
	       qualifierString: [self _searchExprForQual:_qual]
	       encoding: _encoding];
}
- (NSDictionary *)sort:(NSArray *)_sortOrderings
  qualifier:(EOQualifier *)_qual
{
  return [self sort:_sortOrderings
	       qualifier:_qual
	       encoding: (self->useUTF8 ? @"UTF-8" : nil)];
}

- (NSDictionary *)searchWithQualifier:(EOQualifier *)_qualifier {
  NSString *s;
  
  s = [self _searchExprForQual:_qualifier];
  if (![s isNotEmpty]) {
    // TODO: should set last-exception?
    [self logWithFormat:@"ERROR(%s): could not process search qualifier: %@",
          __PRETTY_FUNCTION__, _qualifier];
    return nil;
  }
  
  s = [@"UID SEARCH" stringByAppendingString:s];
  return [self->normer normalizeSearchResponse:[self processCommand:s]];
}

/* ACLs */

- (NSDictionary *)getACL:(NSString *)_folder {
  NSString *cmd;

  if ((_folder = [self _folder2ImapFolder:_folder]) == nil)
    return nil;
  
  cmd = [NSString stringWithFormat:@"getacl \"%@\"", SaneFolderName(_folder)];
  return [self->normer normalizeGetACLResponse:[self processCommand:cmd]];
}

- (NSDictionary *)setACL:(NSString *)_folder rights:(NSString *)_r
  uid:(NSString *)_uid
{
  NSString *cmd;
  
  if ((_folder = [self _folder2ImapFolder:_folder]) == nil)
    return nil;
  
  cmd = [NSString stringWithFormat:@"setacl \"%@\" \"%@\" \"%@\"",
		  SaneFolderName(_folder), _uid, _r];
  return [self->normer normalizeResponse:[self processCommand:cmd]];
}

- (NSDictionary *)deleteACL:(NSString *)_folder uid:(NSString *)_uid {
  NSString *cmd;

  if ((_folder = [self _folder2ImapFolder:_folder]) == nil)
    return nil;
  
  cmd = [NSString stringWithFormat:@"deleteacl \"%@\" \"%@\"",
		  SaneFolderName(_folder), _uid];
  return [self->normer normalizeResponse:[self processCommand:cmd]];
}

- (NSDictionary *)listRights:(NSString *)_folder uid:(NSString *)_uid {
  NSString *cmd;

  if ((_folder = [self _folder2ImapFolder:_folder]) == nil)
    return nil;
  
  cmd = [NSString stringWithFormat:@"listrights \"%@\" \"%@\"",
		  SaneFolderName(_folder), _uid];
  return [self->normer normalizeListRightsResponse:[self processCommand:cmd]];
}

- (NSDictionary *)myRights:(NSString *)_folder {
  NSString *cmd;

  if ((_folder = [self _folder2ImapFolder:_folder]) == nil)
    return nil;
  
  cmd = [NSString stringWithFormat:@"myrights \"%@\"", SaneFolderName(_folder)];
  return [self->normer normalizeMyRightsResponse:[self processCommand:cmd]];
}

/* Private Methods */

- (NSDictionary *) _sopeSORT: (id)_sortSpec  qualifier:(EOQualifier *)_qual  encoding:(NSString *)_encoding {
  NSMutableDictionary *result;
  NSDictionary *d;
  NSCalendarDate *envDate;

  result = [NSMutableDictionary dictionary];
  [result setObject: [NSNumber numberWithBool: NO]  forKey: @"result"];

  // _sortSpec: [REVERSE] {DATE,FROM,SUBJECT}
  d = [self searchWithQualifier: _qual];
 
  if ((d = [d objectForKey: @"RawResponse"])) {
    NSMutableDictionary *dict;
    NSArray *a, *s_a;
    BOOL b;
    int i;

    a = [d objectForKey: @"search"];
    if ([a isNotEmpty]) {

      // If we are sorting by DATE or REVERSE DATE, we do NOT fetch all the body envelope
      // and we assume the server returns us the fetched UIDs in the right order.
      if ([_sortSpec caseInsensitiveCompare: @"DATE"] == NSOrderedSame || 
	  [_sortSpec caseInsensitiveCompare: @"REVERSE DATE"]  == NSOrderedSame) {
	s_a = a; 
      }
      else {
	d = [self fetchUids: a
		  parts: [NSArray arrayWithObjects: @"ENVELOPE",
				  @"RFC822.SIZE", nil]];
	a = [d objectForKey: @"fetch"];
	
	dict = [NSMutableDictionary dictionary];
	b = YES;
	
	for (i = 0; i < [a count]; i++) {
	  NGImap4Envelope *env;
	  id o, uid, s;
	  
	  o = [a objectAtIndex: i];
	  env = [o objectForKey: @"envelope"];
	  uid = [o objectForKey: @"uid"];
	  
	  if ([_sortSpec rangeOfString: @"SUBJECT"].length) {
	    s = [env subject];
	    if ([s isKindOfClass: [NSData class]])
	      s = [[[NSString alloc] initWithData: s  encoding: NSUTF8StringEncoding] autorelease];
	    
	    [dict setObject: (s != nil ? s : (id)@"")  forKey: uid];
	  }
	  else if ([_sortSpec rangeOfString: @"FROM"].length) {
	    s =  [[[env from] lastObject] email];
	    [dict setObject: (s != nil ? s : (id)@"")  forKey: uid];
	  }
	  else if ([_sortSpec rangeOfString: @"SIZE"].length) {
	    s = [o objectForKey: @"size"];
	    [dict setObject: (s != nil ? (NSNumber *)s : [NSNumber numberWithInt: 0])
		  forKey: uid];
	    b = NO;
	  }
	  else {
	    envDate = [env date];
	    if (!envDate)
	      envDate = [NSCalendarDate date];
	    [dict setObject: envDate forKey: uid];
          b = NO;
	  }
	}
	
	if (b)
	  s_a = [dict keysSortedByValueUsingSelector: @selector(caseInsensitiveCompare:)];
	else
	  s_a = [dict keysSortedByValueUsingSelector: @selector(compare:)];
      }

      if ([_sortSpec rangeOfString: @"REVERSE"].length)	{
        s_a = [[s_a reverseObjectEnumerator] allObjects];
      }
      
    }
    else {
      s_a = [NSArray array];
    }
    [result setObject: [NSNumber numberWithBool: YES]  forKey: @"result"];
    [result setObject: s_a  forKey: @"sort"];
  }

  return result;
}


- (NSException *)_processCommandParserException:(NSException *)_exception {
  [self logWithFormat:@"ERROR(%s): catched IMAP4 parser exception %@: %@",
	__PRETTY_FUNCTION__, [_exception name], [_exception reason]];
  [self closeConnection];
  [self->context setLastException:_exception];
  return nil;
}
- (NSException *)_processUnknownCommandParserException:(NSException *)_ex {
  [self logWithFormat:@"ERROR(%s): catched non-IMAP4 parsing exception %@: %@",
	__PRETTY_FUNCTION__, [_ex name], [_ex reason]];
  return nil;
}

- (NSException *)_handleShutdownDuringCommandException:(NSException *)_ex {
  [self logWithFormat:
	  @"ERROR(%s): IMAP4 socket was shut down by server %@: %@",
	  __PRETTY_FUNCTION__, [_ex name], [_ex reason]];
  [self closeConnection];
  [self->context setLastException:_ex];
  return nil;
}

- (BOOL)_isShutdownException:(NSException *)_ex {
  return [[_ex name] isEqualToString:@"NGSocketShutdownDuringReadException"];
}

- (BOOL)_isLoginCommand:(NSString *)_command {
  return [_command hasPrefix:@"login"];
}

- (NGHashMap *)processCommand:(NSString *)_command withTag:(BOOL)_tag
  withNotification:(BOOL)_notification logText:(NSString *)_txt
{
  NGHashMap    *map;
  BOOL         tryReconnect;
  int          reconnectCnt;
  NSException  *exception;

  struct timeval tv;
  double         ti = 0.0;

  if (ProfileImapEnabled == 1) {
    gettimeofday(&tv, NULL);
    ti =  (double)tv.tv_sec + ((double)tv.tv_usec / 1000000.0);
    fprintf(stderr, "{");
  }
  tryReconnect = NO;
  reconnectCnt = 0;
  map          = nil;
  exception    = nil;

  do {
    tryReconnect  = NO;
    [self->context resetLastException];
    NS_DURING {
      NSException *e = nil; // TODO: try to remove exception handler
      
      [self sendCommand:_command withTag:_tag logText:_txt];
      map = [self->parser parseResponseForTagId:self->tagId exception:&e];
      [e raise];
      tryReconnect = NO;
    }
    NS_HANDLER {
      if ([localException isKindOfClass:[NGImap4ParserException class]]) {
	[[self _processCommandParserException:localException] raise];
      }
      else if ([self _isShutdownException:localException]) {
	[[self _handleShutdownDuringCommandException:localException] raise];
      }
      else {
        [[self _processUnknownCommandParserException:localException] raise];
        if (reconnectCnt == 0) {
          if (![self _isLoginCommand:_command]) {
            reconnectCnt++;
            tryReconnect = YES;
            exception    = localException;
          }
        }
        else {
          [self closeConnection];
        }
	[self->context setLastException:localException];
      }
    }
    NS_ENDHANDLER;

    if (tryReconnect) {
      [self reconnect];
    }
    else if ([map objectForKey:@"bye"]
             && ![_command hasPrefix:@"logout"]
             && ![self _isLoginCommand:_command]) {
      if (reconnectCnt == 0) {
        reconnectCnt++;
        tryReconnect = YES;
        [self reconnect];
      }
    }
  } while (tryReconnect);

  if ([self->context lastException]) {
    if (exception) {
      [self->context setLastException:exception];
    }
    return nil;
  }
  if (_notification) [self sendResponseNotification:map];

  if (ProfileImapEnabled == 1) {
    gettimeofday(&tv, NULL);
    ti = (double)tv.tv_sec + ((double)tv.tv_usec / 1000000.0) - ti;
    fprintf(stderr, "}[%s] <Send Command [%s]> : time needed: %4.4fs\n",
           __PRETTY_FUNCTION__, [_command cString], ti < 0.0 ? -1.0 : ti);    
  }
  return map;
}

- (NGHashMap *)processCommand:(NSString *)_command withTag:(BOOL)_tag
  withNotification:(BOOL)_notification
{
  return [self processCommand:_command withTag:_tag
               withNotification:_notification
               logText:_command];
}

- (NGHashMap *)processCommand:(NSString *)_command withTag:(BOOL)_tag {
  return [self processCommand:_command withTag:_tag withNotification:YES
               logText:_command];
}

- (NGHashMap *)processCommand:(NSString *)_command {
  return [self processCommand:_command withTag:YES withNotification:YES
               logText:_command];
}

- (NGHashMap *)processCommand:(NSString *)_command logText:(NSString *)_txt {
  return [self processCommand:_command withTag:YES withNotification:YES
               logText:_txt];
}

- (void)sendCommand:(NSString *)_command withTag:(BOOL)_tag
  logText:(NSString *)_txt
{
  NSString      *command;
  NGCTextStream *txtStream;

  txtStream = [self textStream];

  if (_tag) {
    self->tagId++;

    command = [NSString stringWithFormat:@"%d %@", self->tagId, _command];
    if (self->debug) {
      _txt = [NSString stringWithFormat:@"%d %@", self->tagId, _txt];
    }
  }
  else
    command = _command;

  if (self->debug) {
      fprintf(stderr, "C[%p]: %s\n", self, [_txt cString]);
  }
  
  if (![txtStream writeString:command])
    [self->context setLastException:[txtStream lastException]];
  else if (![txtStream writeString:@"\r\n"])
    [self->context setLastException:[txtStream lastException]];
  else if (![txtStream flush])
    [self->context setLastException:[txtStream lastException]];
}
  
- (void)sendCommand:(NSString *)_command withTag:(BOOL)_tag {
  [self sendCommand:_command withTag:_tag logText:_command];
}

- (void)sendCommand:(NSString *)_command {
  [self sendCommand:_command withTag:YES logText:_command];
}

- (NSArray *)_flags2ImapFlags:(NSArray *)_flags {
  /* adds backslashes in front of the flags */
  NSEnumerator *enumerator;
  NSArray      *result;
  id           obj;
  id           *objs;
  unsigned     cnt;
  
  objs = calloc([_flags count] + 2, sizeof(id));
  cnt  = 0;
  enumerator = [_flags objectEnumerator];
  while ((obj = [enumerator nextObject])) {
    if ([Imap4SystemFlags containsObject: [obj lowercaseString]])
      objs[cnt] = [@"\\" stringByAppendingString:obj];
    else
      objs[cnt] = obj;
    cnt++;
  }
  result = [NSArray arrayWithObjects:objs count:cnt];
  if (objs != NULL) free(objs);
  return result;
}
static inline NSArray *_flags2ImapFlags(NGImap4Client *self, NSArray *_flags) {
  return [self _flags2ImapFlags:_flags];
}

- (NSString *)_folder2ImapFolder:(NSString *)_folder {
  NSArray *array;
  
  if (self->delimiter == nil) {
    NSDictionary *res;

    res = [self list:@"" pattern:@""];

    if (!_checkResult(self->context, res, __PRETTY_FUNCTION__))
      return nil;
  }

//   array = [_folder pathComponents];
  array = [_folder componentsSeparatedByString:@"/"];

  if ([array count]) {
    NSString *o;

    o = [array objectAtIndex:0];
    if ([o length] == 0)
      array = [array subarrayWithRange:NSMakeRange(1, [array count] - 1)];

    if ([array count]) {
      o = [array lastObject];
      if ([o length] == 0)
        array = [array subarrayWithRange:NSMakeRange(0, [array count] - 1)];
    }
  }
  return [[array componentsJoinedByString:self->delimiter]
           stringByEncodingImap4FolderName];
}

- (NSString *)_imapFolder2Folder:(NSString *)_folder {
  NSArray *array;
  
  array = [NSArray arrayWithObject:@""];

  if ([self delimiter] == nil) {
    NSDictionary *res;
    
    res = [self list:@"" pattern:@""]; // fill the delimiter ivar?
    if (!_checkResult(self->context, res, __PRETTY_FUNCTION__))
      return nil;
  }
  
  if ([_folder hasPrefix: self->delimiter])
    _folder = [_folder substringFromIndex: 1];
  if ([_folder hasSuffix: self->delimiter])
    _folder = [_folder substringToIndex: [_folder length] - 1];

  array = [array arrayByAddingObjectsFromArray:
                   [_folder componentsSeparatedByString:[self delimiter]]];

  return [[array componentsJoinedByString: @"/"]
           stringByDecodingImap4FolderName];
}

- (void)setContext:(NGImap4Context *)_ctx {
  self->context = _ctx;
}
- (NGImap4Context *)context {
  return self->context;
}

/* ConnectionRegistration */

- (void)removeFromConnectionRegister {
  unsigned cnt;
  
  for (cnt = 0; cnt < MaxImapClients; cnt++) {
    if (ImapClients[cnt] == self)
      ImapClients[cnt] = nil;
  }
}

- (void)registerConnection {
  int cnt;

  cnt =  CountClient % MaxImapClients;

  if (ImapClients[cnt]) {
    [(NGImap4Context *)ImapClients[cnt] closeConnection];
  }
  ImapClients[cnt] = self;
  CountClient++;
}

- (NGCTextStream *)textStream {
  if (self->text == nil) {
    if ([self->context lastException] == nil)
      [self reconnect];
  }
  return (NGCTextStream *)self->text;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  id tmp;

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  if (self->login != nil)
    [ms appendFormat:@" login=%@%s", self->login, self->password?"(pwd)":""];
  
  if ((tmp = [self socket]) != nil)
    [ms appendFormat:@" socket=%@", tmp];
  else if (self->address)
    [ms appendFormat:@" address=%@", self->address];
  
  [ms appendString:@">"];
  return ms;
}

@end /* NGImap4Client; */
