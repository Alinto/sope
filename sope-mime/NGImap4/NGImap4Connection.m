/*
  Copyright (C) 2004-2007 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "NGImap4Connection.h"
#include "NGImap4MailboxInfo.h"
#include "NGImap4Client.h"
#include "NGImap4Functions.h"
#include "NSString+Imap4.h"
#include "imCommon.h"

@interface NGImap4Connection (private)

- (void) _mergeDict: (NSDictionary *) source
               into: (NSMutableDictionary *) target;

- (void) _mergeNGHashMap: (NGMutableHashMap *) source
                    into: (NGMutableHashMap *) target;

@end

@implementation NGImap4Connection

static BOOL     debugOn         = NO;
static BOOL     debugCache      = NO;
static BOOL     debugKeys       = NO;
static BOOL     alwaysSelect    = NO;
static BOOL     onlyFetchInbox  = NO;
static NSString *imap4Separator = nil;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  debugOn      = [ud boolForKey:@"NGImap4ConnectionDebugEnabled"];
  debugCache   = [ud boolForKey:@"NGImap4ConnectionCacheDebugEnabled"];
  debugKeys    = [ud boolForKey:@"NGImap4ConnectionFolderDebugEnabled"];
  alwaysSelect = [ud boolForKey:@"NGImap4ConnectionAlwaysSelect"];
  
  //if (debugOn)    NSLog(@"Note: NGImap4ConnectionDebugEnabled is enabled!");
  //if (alwaysSelect)
  //  NSLog(@"WARNING: 'NGImap4ConnectionAlwaysSelect' enabled (slow down)");

  imap4Separator = 
    [[ud stringForKey:@"NGImap4ConnectionStringSeparator"] copy];
  if (![imap4Separator isNotEmpty])
    imap4Separator = @"/";
  //NSLog(@"Note(NGImap4Connection): using '%@' as the IMAP4 folder separator.", 
  //	imap4Separator);
}

- (id)initWithClient:(NGImap4Client *)_client password:(NSString *)_pwd {
  if (_client == nil || _pwd == nil) {
    [self release];
    return nil;
  }
  
  if ((self = [super init])) {
    self->client   = [_client retain];
    self->password = [_pwd    copy];

    self->creationTime = [[NSDate alloc] init];
    
    // TODO: retrieve from IMAP4 instead of using a default
    self->separator = [imap4Separator copy];
    self->subfolders = [NSMutableDictionary new];
    self->enabledExtensions = [NSMutableDictionary new];
  }
  return self;
}
- (id)init {
  return [self initWithClient:nil password:nil];
}

- (void)dealloc {
  [self->separator       release];
  [self->urlToRights     release];
  [self->cachedUIDs      release];
  [self->uidFolderURL    release];
  [self->uidSortOrdering release];
  [self->creationTime    release];
  [self->subfolders      release];
  [self->password        release];
  [self->client          release];
  [self->enabledExtensions release];
  [super dealloc];
}

/* accessors */

- (NGImap4Client *)client {
  return self->client;
}
- (BOOL)isValidPassword:(NSString *)_pwd {
  return [self->password isEqualToString:_pwd];
}

- (NSDate *)creationTime {
  return self->creationTime;
}

- (void)cacheHierarchyResults:(NSDictionary *)_hierarchy
  forURL:(NSURL *)_url
{
  [self->subfolders setObject:_hierarchy forKey:[_url absoluteString]];
}
- (NSDictionary *)cachedHierarchyResultsForURL:(NSURL *)_url {
  return [self->subfolders objectForKey:[_url absoluteString]];
}
- (void)flushFolderHierarchyCache {
  [self->subfolders  release]; self->subfolders  = [NSMutableDictionary new];
  [self->urlToRights release]; self->urlToRights = nil;
}

/* rights */

- (NSString *)cachedMyRightsForURL:(NSURL *)_url {
  return (_url != nil) ? [self->urlToRights objectForKey:_url] : nil;
}
- (void)cacheMyRights:(NSString *)_rights forURL:(NSURL *)_url {
  if (self->urlToRights == nil)
    self->urlToRights = [[NSMutableDictionary alloc] initWithCapacity:8];
  [self->urlToRights setObject:_rights forKey:_url];
}

/* UIDs */

- (id)cachedUIDsForURL:(NSURL *)_url qualifier:(id)_q sortOrdering:(id)_so {
  if (_q != nil)
    return nil;
  if (![_so isEqual:self->uidSortOrdering])
    return nil;
  if (![self->uidFolderURL isEqual:_url])
    return nil;
  
  return self->cachedUIDs;
}

- (void)cacheUIDs:(NSArray *)_uids forURL:(NSURL *)_url
  qualifier:(id)_q sortOrdering:(id)_so
{
  if (_q != nil)
    return;

  ASSIGNCOPY(self->uidSortOrdering, _so);
  ASSIGNCOPY(self->uidFolderURL,    _url);
  ASSIGNCOPY(self->cachedUIDs,      _uids);
}

- (void)flushMailCaches {
  ASSIGN(self->uidSortOrdering, nil);
  ASSIGN(self->uidFolderURL,    nil);
  ASSIGN(self->cachedUIDs,      nil);
}

/* errors */

- (NSException *)errorCouldNotSelectURL:(NSURL *)_url {
  NSException  *e;
  NSDictionary *ui;
  NSString *r;
  
  r = [_url isNotNull]
    ? [@"Could not select IMAP4 folder: " stringByAppendingString:
	  [_url absoluteString]]
    : (NSString *)@"Could not select IMAP4 folder!";

  ui = [[NSDictionary alloc] initWithObjectsAndKeys:
			       [NSNumber numberWithInt:404], @"http-status",
			       _url, @"url",
			     nil];
  
  e = [NSException exceptionWithName:@"NGImap4Exception"
		   reason:r userInfo:ui];
  [ui release]; ui = nil;
  return e;
}

- (NSException *)errorForResult:(NSDictionary *)_result text:(NSString *)_txt {
  NSDictionary *ui;
  NSString *r;
  int      status;
  
  if ([[_result valueForKey:@"result"] boolValue])
    return nil; /* everything went fine! */
  
  if ((r = [_result valueForKey:@"reason"]) != nil)
    r = [[_txt stringByAppendingString:@": "] stringByAppendingString:r];
  else
    r = _txt;
  
  if ([r isEqualToString:@"Permission denied"]) {
    /* different for each server?, no error codes in IMAP4 ... */
    status = 403 /* Forbidden */;
  }
  else
    status = 500 /* internal server error */;
  
  ui = [NSDictionary dictionaryWithObjectsAndKeys:
		       [NSNumber numberWithInt:status], @"http-status",
		       _result, @"rawResult",
		     nil];
  
  return [NSException exceptionWithName:@"NGImap4Exception"
		      reason:r userInfo:ui];
}

/* extensions methods */
- (NSException *)enableExtensions:(NSArray *)_extensions {
  NSMutableArray *extensionsToEnable;
  NSString *s;

  int i, count;

  extensionsToEnable = [NSMutableArray arrayWithArray: _extensions];
  count = [extensionsToEnable count];

  /* we don't enable extensions that have already been enabled for 
     this particular connection */
  for (i = count-1; i >= 0; i--)
    {
      s = [extensionsToEnable objectAtIndex: i];
      if ([enabledExtensions objectForKey: s])
	[extensionsToEnable removeObjectAtIndex: i];
      else
	[enabledExtensions setObject: [NSNumber numberWithBool: YES]
			      forKey: s];
    }

  if ([extensionsToEnable count])
    {
      NSDictionary *result;
      
      result = [self->client enable: _extensions];
      if (![[result valueForKey:@"result"] boolValue]) {
	return (id)[self errorForResult:result 
				   text:@"Failed to enable requested extension"];
      }
    }
      
  return nil;
}


/* IMAP4 path/url processing methods */

NSArray *SOGoMailGetDirectChildren(NSArray *_array, NSString *_fn) {
  /*
    Scans string '_array' for strings which start with the string in '_fn'.
    Then split on '/'.
  */
  NSMutableArray *ma;
  unsigned i, count, prefixlen;
  
  count = [_array count];
  
  // TODO: somehow results are different on OSX
  // we should investigate and test all Foundation libraries and document the
  // differences
#if __APPLE__ 
  prefixlen = [_fn isEqualToString:@""] ? 0 : [_fn length] + 1;
#else
  prefixlen = [_fn isEqualToString:@"/"] ? 1 : [_fn length] + 1;
#endif
  ma = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    NSString *p;
    
    p = [_array objectAtIndex:i];
    if ([p length] <= prefixlen)
      continue;
    if (prefixlen != 0 && ![p hasPrefix:_fn])
      continue;
    
    /* cut of common part */
    p = [p substringFromIndex:prefixlen];
    
    /* check whether the path is a sub-subfolder path */
    if ([p rangeOfString:@"/"].length > 0)
      continue;
    
    [ma addObject:p];
  }
  
  [ma sortUsingSelector:@selector(compare:)];
  return ma;
}

- (NSArray *)extractSubfoldersForURL:(NSURL *)_url
  fromResultSet:(NSDictionary *)_result
{
  NSString     *folderName;
  NSDictionary *result;
  NSArray      *names;
  NSArray      *flags;
  
  /* Note: the result is normalized, that is, it contains / as the separator */
  folderName = [_url path];
#if __APPLE__ 
  /* normalized results already have the / in front on libFoundation?! */
  if ([folderName hasPrefix:@"/"]) 
    folderName = [folderName substringFromIndex:1];
#endif
  
  result = [_result valueForKey:@"list"];
  
  /* Cyrus already tells us whether we need to check for children */
  flags = [result objectForKey:folderName];
  if ([flags containsObject:@"hasnochildren"]) {
    if (debugKeys) {
      [self logWithFormat:@"%s: folder %@ has no children.", 
	      __PRETTY_FUNCTION__,folderName];
    }
    return nil;
  }
  if ([flags containsObject:@"noinferiors"]) {
    if (debugKeys) {
      [self logWithFormat:@"%s: folder %@ cannot contain children.", 
	      __PRETTY_FUNCTION__,folderName];
    }
    return nil;
  }
  
  if (debugKeys) {
    [self logWithFormat:@"%s: all keys %@: %@",
	  __PRETTY_FUNCTION__, folderName, 
	  [[result allKeys] componentsJoinedByString:@", "]];
  }
  
  names = SOGoMailGetDirectChildren([result allKeys], folderName);
  if (debugKeys) {
    [self logWithFormat:
	    @"%s: subfolders of '%@': %@", __PRETTY_FUNCTION__, folderName, 
	    [names componentsJoinedByString:@","]];
  }
  return names;
}

- (NSString *)imap4Separator {
  return self->separator;
}

- (NSString *)imap4FolderNameForURL:(NSURL *)_url removeFileName:(BOOL)_delfn {
  /* a bit hackish, but should be OK */
  NSString *folderName;
  NSArray  *names;

  if (_url == nil)
    return nil;
  
  folderName = [_url path];
  if (![folderName isNotEmpty])
    return nil;
  if ([folderName characterAtIndex:0] == '/')
    folderName = [folderName substringFromIndex:1];
  if ([folderName hasSuffix: @"/"])
    folderName = [folderName substringToIndex:[folderName length] - 1];
  
  if (_delfn) folderName = [folderName stringByDeletingLastPathComponent];
  
  if ([[self imap4Separator] isEqualToString:@"/"])
    return folderName;
  
  names = [folderName componentsSeparatedByString: @"/"];
  return [names componentsJoinedByString:[self imap4Separator]];
}
- (NSString *)imap4FolderNameForURL:(NSURL *)_url {
  return [self imap4FolderNameForURL:_url removeFileName:NO];
}

- (NSArray *)extractFoldersFromResultSet:(NSDictionary *)_result {
  /* Note: the result is normalized, that is, it contains / as the separator */
  return [[_result valueForKey:@"list"] allKeys];
}

/* folder selections */

- (BOOL)selectFolder:(id)_url {
  NSDictionary *result;
  NSString     *newFolder;
  
  newFolder = [_url isKindOfClass:[NSURL class]]
    ? [self imap4FolderNameForURL:_url]
    : (NSString *)_url;
  
  if (!alwaysSelect) {
    if ([[[self client] selectedFolderName] isEqualToString:newFolder])
      return YES;
  }
  
  result = [[self client] select:newFolder];
  if (![[result valueForKey:@"result"] boolValue]) {
    [self errorWithFormat:@"could not select URL: %@: %@", _url, result];
    return NO;
  }

  return YES;
}

- (BOOL)isPermissionDeniedResult:(id)_result {
  if ([[_result valueForKey:@"result"] intValue] != 0)
    return NO;
  
  return [[_result valueForKey:@"reason"] 
	           isEqualToString:@"Permission denied"];
}

/* folder operations */

- (NSDictionary *)primaryFetchMailboxHierarchyForURL:(NSURL *)_url
  onlySubscribedFolders:(BOOL) subscribedFoldersOnly
{
  NSDictionary *result;
  NSString *prefix;
  
  if ((result = [self cachedHierarchyResultsForURL:_url]) != nil)
    {
      if (debugCache) [self logWithFormat: @"primaryFetchMailboxHierarchyForURL - cache hit for URL: %@", _url];
      return [result isNotNull] ? result : (NSDictionary *)nil;
    }
  
  if (debugCache) [self logWithFormat: @"primaryFetchMailboxHierarchyForURL - cache miss for URL: %@", _url];

  prefix = [_url path];
  if ([prefix hasPrefix: @"/"])
    prefix = [prefix substringFromIndex:1];
  if (subscribedFoldersOnly)
    result = [[self client] lsub:(onlyFetchInbox ? @"INBOX" : prefix)
			    pattern:@"*"];
  else
    result = [[self client] list:(onlyFetchInbox ? @"INBOX" : prefix)
			    pattern:@"*"];
  if (![[result valueForKey:@"result"] boolValue]) {
    [self errorWithFormat:@"Could not list mailbox hierarchy!"];
    return nil;
  }

  /* cache results */
  
  if ([result isNotNull]) {
    [self cacheHierarchyResults:result forURL:_url];
    if (debugCache) {
      [self logWithFormat:@"cached results: 0x%p(%d)", 
	      result, [result count]];
    }
  }
  return result;
}

- (NSDictionary *)primaryFetchMailboxHierarchyForURL:(NSURL *)_url
{
  return [self primaryFetchMailboxHierarchyForURL: _url onlySubscribedFolders: NO];
}

- (NSArray *)allFoldersForURL:(NSURL *)_url
	onlySubscribedFolders:(BOOL)_subscribedFoldersOnly
{
  NSDictionary *result;

  if ((result = [self primaryFetchMailboxHierarchyForURL:_url
		      onlySubscribedFolders:_subscribedFoldersOnly]) == nil)
    return nil;
  if ([result isKindOfClass:[NSException class]]) {
    [self errorWithFormat:@"failed to retrieve hierarchy: %@", result];
    return nil;
  }
  
  return [self extractFoldersFromResultSet:result];
}

- (NSArray *)allFoldersForURL:(NSURL *)_url
{
  return [self allFoldersForURL: _url onlySubscribedFolders: NO];
}

- (NSArray *)subfoldersForURL:(NSURL *)_url
  onlySubscribedFolders:(BOOL)_subscribedFoldersOnly
{
  NSDictionary *result;
  NSString *baseFolder;

  if ((result = [self cachedHierarchyResultsForURL:_url]) != nil)
    {
      if (debugCache) [self errorWithFormat: @"subfoldersForURL - cache hit for URL: %@", _url];
      return [self extractSubfoldersForURL:_url fromResultSet: result];
    }

  if (debugCache) [self errorWithFormat: @"subfoldersForURL - cache miss for URL: %@", _url];
  
  baseFolder = [self imap4FolderNameForURL:_url removeFileName:NO];
  if (_subscribedFoldersOnly)
    result = [[self client] lsub:baseFolder pattern:@"%"];
  else
    result = [[self client] list:baseFolder pattern:@"%"];
  if (![[result valueForKey:@"result"] boolValue]) {
    [self errorWithFormat:@"Could not list mailbox hierarchy!"];
    return nil;
  }

  if ([result isNotNull])
    [self cacheHierarchyResults:result forURL:_url];

  return [self extractSubfoldersForURL:_url fromResultSet: result];
}

- (NSArray *)subfoldersForURL:(NSURL *)_url {
  return [self subfoldersForURL:_url onlySubscribedFolders: NO];
}

/* message operations */

- (NSArray *)fetchUIDsInURL:(NSURL *)_url
                  qualifier:(id)_qualifier
               sortOrdering:(id)_so
{
  /* 
     sortOrdering can be an NSString, an EOSortOrdering or an array of EOS.
  */
  NSDictionary *result;
  NSArray      *uids;

  /* check cache */
  
  uids = [self cachedUIDsForURL:_url qualifier:_qualifier sortOrdering:_so];
  if (uids != nil) {
    if (debugCache) [self logWithFormat:@"reusing uid cache!"];
    return [uids isNotNull] ? uids : (NSArray *)nil;
  }
  
  /* select folder and fetch */
  
  if (![self selectFolder:_url])
    return nil;
  
  result = [[self client] sort:_so qualifier:_qualifier encoding:@"UTF-8"];
  if (![[result valueForKey:@"result"] boolValue]) {
    [self errorWithFormat:@"could not sort contents of URL: %@", _url];
    return nil;
  }
  
  uids = [result valueForKey:@"sort"];
  if (![uids isNotNull]) {
    [self errorWithFormat:@"got no UIDs for URL: %@: %@", _url, result];
    return nil;
  }
  
  /* cache */
  
  [self cacheUIDs:uids forURL:_url qualifier:_qualifier sortOrdering:_so];
  return uids;
}

/**
 * Fetch a threaded view of the folder and sort the root messages.
 * @param _url the URL of the IMAP folder
 * @param _qualifier a EOQualifier defining a search constraint
 * @param _so either an NSString, an EOSortOrdering or an array of EOSortOrdering
 * @return a threaded view of the messages UIDs using interleaved arrays.
 */
- (NSArray *)fetchThreadedUIDsInURL:(NSURL *)_url
                          qualifier:(id)_qualifier
                       sortOrdering:(id)_so
{
  NSDictionary *result;
  NSArray *uids;
  NSMutableArray *sortedThreads;
  NSMutableDictionary *threads;
  NSEnumerator *threadsEnum, *threadEnum;
  id rootThread, thread;
  unsigned int i;

  // Check cache
  
  uids = [self cachedUIDsForURL:_url qualifier:_qualifier sortOrdering:_so];
  if (uids != nil) {
    if (debugCache) [self logWithFormat:@"reusing uid cache!"];
    return [uids isNotNull] ? uids : (NSArray *)nil;
  }
  
  // Select folder and fetch
  
  if (![self selectFolder:_url])
    return nil;
  
  result = [[self client] threadBySubject: NO charset: @"UTF-8" qualifier: _qualifier]; 
  if ([[result valueForKey:@"result"] boolValue])
    {
      // Sort the threads in two steps :
      
      // 1. Build a dictionary with the root threads

      uids = [result valueForKey: @"thread"];
      threads = [NSMutableDictionary dictionaryWithCapacity: [uids count]];
      threadsEnum = [uids objectEnumerator];
      i = 0;
      while ((rootThread = [threadsEnum nextObject]))
        {
          thread = rootThread;
          while ([thread respondsToSelector: @selector(objectEnumerator)])
            {
              threadEnum = [thread objectEnumerator];
              thread = [threadEnum nextObject];
            }
          [threads setObject: rootThread forKey: thread];
        }

      // 2. Sort the threads based on an IMAP SORT

      uids = [self fetchUIDsInURL: _url qualifier: _qualifier sortOrdering: _so];
      sortedThreads = [NSMutableArray arrayWithCapacity: [threads count]];
      for (i = 0; i < [uids count]; i++)
        {
          thread = [threads objectForKey: [uids objectAtIndex: i]];
          if (thread)
            [sortedThreads addObject: thread];
        }

      uids = sortedThreads;
    }
  else
    {
      // No THREAD support; rollback to a simple SORT
      [self warnWithFormat: @"No THREAD support for %@", _url];
      uids = [self fetchUIDsInURL: _url qualifier: _qualifier sortOrdering: _so];
    }

  if (![uids isNotNull])
    {
      [self errorWithFormat: @"got no UIDs for URL: %@: %@", _url, result];
      return nil;
    }

  // Update cache

  [self cacheUIDs:uids forURL:_url qualifier:_qualifier sortOrdering:_so];
  return uids;
}

- (NSArray *) fetchUIDs: (NSArray *) _uids
                  inURL: (NSURL *) _url
                  parts: (NSArray *) _parts
{
  // currently returns a dict?!
  /*
    Allowed fetch keys:
      UID
      BODY.PEEK[<section>]<<partial>>
      BODY            [this is the bodystructure, supported]
      BODYSTRUCTURE   [not supported yet!]
      ENVELOPE        [this is a parsed header, but does not include type]
      FLAGS
      INTERNALDATE
      RFC822
      RFC822.HEADER
      RFC822.SIZE
      RFC822.TEXT
  */
  NSMutableDictionary *result = nil;
  NSUInteger i, total, step = 1000;

  if (_uids == nil || [_uids count] == 0)
    return nil;

  /* select folder */

  if (![self selectFolder:_url])
    return nil;

  /* fetch parts */

  total = [_uids count];
  for (i = 0; i < total; i += step) {
    NSRange range;
    NSArray *partial_uids;
    NSDictionary *partial_result;

    range = NSMakeRange(i, (i + step) > total ? (total - i) : step);
    partial_uids = [_uids subarrayWithRange: range];

    /* We will only fetch "step" uids each time */
    partial_result = [[self client] fetchUids:partial_uids parts:_parts];

    if (![[partial_result valueForKey:@"result"] boolValue]) {
      [self errorWithFormat: @"Error fetching %u uids for url: %@",
                             total, _url];
      return nil;
    }

    if (result == nil) {
      /* First iteration, first result */
      result = [[partial_result mutableCopy] autorelease];
    } else {
      /* Merge partial_result into previous result */
      [self _mergeDict: partial_result into: result];
    }
  }

  return (id)result;
}


- (void) _mergeDict: (NSDictionary *) source
               into: (NSMutableDictionary *) target
{
  NSEnumerator *keyEnumerator;
  id key;

  keyEnumerator = [source keyEnumerator];
  
  while ((key = [keyEnumerator nextObject])) {
    id obj, current_obj;

    current_obj = [target objectForKey: key];
    if (current_obj == nil) {
      /* This should never happen but just in case... */
      [self errorWithFormat: @"Error merging fetchUids results: "
                             @"nonexistent key %@ on current target", key];
      continue;
    }

    obj = [source objectForKey: key];
    if ([obj isKindOfClass: [NSArray class]]) {
      NSArray *data, *current_data, *new_data;
      data = obj;
      current_data = current_obj;
      new_data = [current_data arrayByAddingObjectsFromArray: data];
      [target setObject: new_data forKey: key];
    } else if ([obj isKindOfClass: [NGMutableHashMap class]]) {
      [self _mergeNGHashMap: obj into: current_obj];
    } else if ([obj isKindOfClass: [NSNumber class]]) {
      if (obj != current_obj) {
        [self errorWithFormat: @"Error merging fetchUids results: "
                               @"incorrect value for key %@: %@ != %@",
                               key, obj, current_obj];
      }
    } else {
      [self errorWithFormat: @"Error merging fetchUids results: "
                             @"ignored %@ (%@) key", key, [key class]];
    }
  }
}

- (void) _mergeNGHashMap: (NGMutableHashMap *) source
                    into: (NGMutableHashMap *) target
{
  NSEnumerator *keyEnumerator;
  id key;

  keyEnumerator = [source keyEnumerator];
  
  while ((key = [keyEnumerator nextObject])) {
    NSArray *obj, *current_obj;

    current_obj = [target objectsForKey: key];
    if (current_obj == nil) {
      /* This should never happen but just in case... */
      [self errorWithFormat: @"Error merging fetchUids results: "
                             @"nonexistent key %@ on current target", key];
      continue;
    }

    if ([current_obj count] == 1) {
      /* Merge only results, that means fields with more than 1 object */
      continue;
    }

    obj = [source objectsForKey: key];
    [target addObjects: obj forKey: key];
  }
}

- (id)fetchURL:(NSURL *)_url parts:(NSArray *)_parts {
  // currently returns a dict
  NSDictionary *result;
  NSString *uid;
  
  if (![_url isNotNull]) return nil;
  
  /* select folder */

  uid = [self imap4FolderNameForURL:_url removeFileName:YES];
  if (![self selectFolder:uid])
    return nil;
  
  /* fetch parts */
  
  uid = [[_url path] lastPathComponent];
  
  result = [client fetchUids:[NSArray arrayWithObject:uid] parts:_parts];
  if (![[result valueForKey:@"result"] boolValue]) {
    [self errorWithFormat:@"could not fetch url: %@", _url];
    return nil;
  }
  //[self logWithFormat:@"RESULT: %@", result];
  return (id)result;
}

- (NSData *)fetchContentOfBodyPart:(NSString *)_partId atURL:(NSURL *)_url {
  return [self fetchContentOfBodyPart:_partId atURL:_url withPeek: NO];
}

- (NSData *)fetchContentOfBodyPart:(NSString *)_partId atURL:(NSURL *)_url
                          withPeek:(BOOL)_withPeek {
  NSString *key;
  NSArray  *parts;
  id result, body;
  NSUInteger count, max;
  
  if (_partId == nil) return nil;

  key = [NSString stringWithFormat: @"body%@[%@]",
                  _withPeek ? @".peek" : @"", _partId];
  parts = [NSArray arrayWithObject:key];
  
  /* fetch */
  
  result = [self fetchURL:_url parts:parts];
  
  /* process results */
  
  result = [(NSDictionary *)result objectForKey:@"fetch"];
  if (![result isNotEmpty]) { /* did not find part */
    [self errorWithFormat:@"did not find part: %@", _partId];
    return nil;
  }
  
  max = [result count];
  body = nil;

  /* no matter whether peek was used or not, the resulting key seems to always
     be "body[xxx]" */
  key = [NSString stringWithFormat: @"body[%@]", _partId];
  for (count = 0; !body && count < max; count++) {
    body = [[result objectAtIndex:count] objectForKey:key];
  }
  if (body == nil) {
    [self errorWithFormat:@"did not find body in response: %@", result];
    return nil;
  }
  
  if ((result = [(NSDictionary *)body objectForKey:@"data"]) == nil) {
    [self errorWithFormat:@"did not find data in body: %@", body];
    return nil;
  }

  return result;
}

/* message flags */

- (NSException *)addOrRemove:(BOOL)_flag flags:(id)_f toURL:(NSURL *)_url {
  id result;
  
  if (![_url isNotNull]) return nil;
  if (![_f   isNotNull]) return nil;
  
  if (![_f isKindOfClass:[NSArray class]])
    _f = [NSArray arrayWithObjects:&_f count:1];
  
  /* select folder */
  
  result = [self imap4FolderNameForURL:_url removeFileName:YES];
  if (![self selectFolder:result])
    return [self errorCouldNotSelectURL:_url];
  
  /* store flags */
  
  result = [[self client] storeUid:[[[_url path] lastPathComponent] intValue]
			  add:[NSNumber numberWithBool:_flag]
			  flags:_f];
  if (![[result valueForKey:@"result"] boolValue]) {
    return [self errorForResult:result 
		 text:@"Failed to change flags of IMAP4 message"];
  }
  /* result contains 'fetch' key with the current flags */
  return nil;
}
- (NSException *)addFlags:(id)_f toURL:(NSURL *)_u {
  return [self addOrRemove:YES flags:_f toURL:_u];
}
- (NSException *)removeFlags:(id)_f toURL:(NSURL *)_u {
  return [self addOrRemove:NO flags:_f toURL:_u];
}

- (NSException *)markURLDeleted:(NSURL *)_url {
  return [self addOrRemove:YES flags:@"Deleted" toURL:_url];
}

- (NSException *)addFlags:(id)_f toAllMessagesInURL:(NSURL *)_url {
  id result;
  
  if (![_url isNotNull]) return nil;
  if (![_f   isNotNull]) return nil;

  if (![_f isKindOfClass:[NSArray class]])
    _f = [NSArray arrayWithObjects:&_f count:1];
  
  /* select folder */
  
  if (![self selectFolder:[self imap4FolderNameForURL:_url]])
    return [self errorCouldNotSelectURL:_url];
    
  /* store flags */
  
  result = [[self client] storeFlags:_f forUIDs:@"1:*" addOrRemove:YES];
  if (![[result valueForKey:@"result"] boolValue]) {
    return [self errorForResult:result 
		 text:@"Failed to change flags of IMAP4 message"];
  }
  
  return nil;
}

/* posting new data */

- (NSException *)postData:(NSData *)_data flags:(id)_f
  toFolderURL:(NSURL *)_url
{
  id result;
  
  if (![_url isNotNull]) return nil;
  if (![_f   isNotNull]) _f = [NSArray array];
  
  if (![_f isKindOfClass:[NSArray class]])
    _f = [NSArray arrayWithObjects:&_f count:1];
  
  result = [[self client] append:_data 
			  toFolder:[self imap4FolderNameForURL:_url]
			  withFlags:_f];
  if (![[result valueForKey:@"result"] boolValue])
    return [self errorForResult:result text:@"Failed to store message"];
  
  /* result contains 'fetch' key with the current flags */
  
  // TODO: need to flush any caches?
  return nil;
}

/* operations */

- (NSException *)expungeAtURL:(NSURL *)_url {
  NSString *p;
  id result;
  
  /* select folder */
  
  p = [self imap4FolderNameForURL:_url removeFileName:NO];
  if (![self selectFolder:p])
    return [self errorCouldNotSelectURL:_url];
  
  /* expunge */
  
  result = [[self client] expunge];

  if (![[result valueForKey:@"result"] boolValue]) {
    [self errorWithFormat:@"could not expunge url: %@", _url];
    return nil;
  }
  //[self logWithFormat:@"RESULT: %@", result];
  return nil;
}

/* copying and moving */

- (NSException *)copyMailURL:(NSURL *)_srcurl toFolderURL:(NSURL *)_desturl {
  NSString *srcname, *destname;
  unsigned uid;
  id result;
  
  /* names */
  
  srcname  = [self imap4FolderNameForURL:_srcurl removeFileName:YES];
  uid      = [[[_srcurl path] lastPathComponent] unsignedIntValue];
  destname = [self imap4FolderNameForURL:_desturl];
  
  /* select source folder */
  
  if (![self selectFolder:srcname])
    return [self errorCouldNotSelectURL:_srcurl];
  
  /* copy */
  
  result = [[self client] copyUid:uid toFolder:destname];
  if (![[result valueForKey:@"result"] boolValue])
    return [self errorForResult:result text:@"Copy operation failed"];
  
  // TODO: need to flush some caches?
  
  return nil;
}

/* managing folders */

- (BOOL)doesMailboxExistAtURL:(NSURL *)_url {
  NSString *folderName;
  BOOL found;
  id result;

  folderName = [self imap4FolderNameForURL:_url];
  if ([[[self->client selectedFolderName] stringByDecodingImap4FolderName]
        isEqualToString:folderName])
    found = YES;
  else {    
    /* check in hierarchy cache */
    found = ([self cachedHierarchyResultsForURL: _url] != nil);

    if (!found) {
      if (debugCache) [self errorWithFormat: @"doesMailboxExistAtURL - cache miss for URL: %@", _url];

      /* check using IMAP4 select */
      // TODO: we should probably just fetch the whole hierarchy?
      
      result = [self->client status: folderName
                    flags: [NSArray arrayWithObject: @"UIDVALIDITY"]];

      found = ([[result valueForKey: @"result"] boolValue]);
      
    } else if (debugCache)
      [self errorWithFormat: @"doesMailboxExistAtURL - cache hit for URL: %@", _url];
  }

  return found;
}

- (id)infoForMailboxAtURL:(NSURL *)_url {
  NGImap4MailboxInfo *info;
  NSString        *folderName;
  id result;

  folderName = [self imap4FolderNameForURL:_url];
  result     = [[self client] select:folderName];
  if (![[result valueForKey:@"result"] boolValue])
    return [self errorCouldNotSelectURL:_url];
  
  info = [[NGImap4MailboxInfo alloc] initWithURL:_url folderName:folderName
				     selectDictionary:result];
  return [info autorelease];
}

- (NSException *)createMailbox:(NSString *)_mailbox atURL:(NSURL *)_url {
  NSString *newPath;
  id       result;
  
  /* construct path */
  
  newPath = [self imap4FolderNameForURL:_url];
  if ([newPath length])
    newPath = [newPath stringByAppendingString:[self imap4Separator]];
  newPath = [newPath stringByAppendingString:_mailbox];
  
  /* create */
  
  result = [[self client] create:newPath];
  if (![[result valueForKey:@"result"] boolValue])
    return [self errorForResult:result text:@"Failed to create folder"];
  
  [self flushFolderHierarchyCache];
  // [self debugWithFormat:@"created mailbox: %@: %@", newPath, result];
  return nil;
}

- (NSException *)deleteMailboxAtURL:(NSURL *)_url {
  NSString *path;
  id       result;

  /* delete */
  
  path   = [self imap4FolderNameForURL:_url];
  result = [[self client] delete:path];
  if (![[result valueForKey:@"result"] boolValue])
    return [self errorForResult:result text:@"Failed to delete folder"];
  
  [self flushFolderHierarchyCache];
#if 0
  [self debugWithFormat:@"delete mailbox %@: %@", _url, result];
#endif
  return nil;
}

- (NSException *)moveMailboxAtURL:(NSURL *)_srcurl toURL:(NSURL *)_desturl {
  NSString *srcname, *destname;
  id result;
  
  /* rename */
  
  srcname  = [self imap4FolderNameForURL:_srcurl];
  destname = [self imap4FolderNameForURL:_desturl];
  
  result = [[self client] rename:srcname to:destname];
  if (![[result valueForKey:@"result"] boolValue])
    return [self errorForResult:result text:@"Failed to move folder"];
  
  [self flushFolderHierarchyCache];
#if 0
  [self debugWithFormat:@"renamed mailbox %@: %@", _srcurl, result];
#endif
  return nil;
}

/* ACLs */

- (NSDictionary *)aclForMailboxAtURL:(NSURL *)_url {
  /*
    Returns a mapping of uid => permission strings, eg:
      guizmo.g = lrs;
      root     = lrswipcda;
  */
  NSString *folderName;
  id       result;
  
  folderName = [self imap4FolderNameForURL:_url];
  result     = [[self client] getACL:folderName];
  if (![[result valueForKey:@"result"] boolValue]) {
    return (id)[self errorForResult:result
		     text:@"Failed to get ACL of folder"];
  }
  
  return [result valueForKey:@"acl"];
}

- (NSString *)myRightsForMailboxAtURL:(NSURL *)_url {
  NSString *folderName;
  id       result;
  
  /* check cache */
  
  if ((result = [self cachedMyRightsForURL:_url]) != nil)
    return result;

  /* run IMAP4 op */
  
  folderName = [self imap4FolderNameForURL:_url];
  result     = [[self client] myRights:folderName];
  if (![[result valueForKey:@"result"] boolValue]) {
    return (id)[self errorForResult:result 
		     text:@"Failed to get myrights on folder"];
  }
  
  /* cache results */
  
  if ((result = [result valueForKey:@"myrights"]) != nil)
    [self cacheMyRights:result forURL:_url];
  return result;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  [ms appendFormat:@" client=0x%p", self->client];
  if ([self->password isNotEmpty])
    [ms appendString:@" pwd"];
  
  [ms appendFormat:@" created=%@", self->creationTime];
  
  if (self->subfolders != nil)
    [ms appendFormat:@" #cached-folders=%d", (int)[self->subfolders count]];
  
  if (self->cachedUIDs != nil)
    [ms appendFormat:@" #cached-uids=%d", (int)[self->cachedUIDs count]];
  
  [ms appendString:@">"];
  return ms;
}

@end /* NGImap4Connection */
