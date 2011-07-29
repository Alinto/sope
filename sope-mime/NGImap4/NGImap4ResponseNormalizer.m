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

#include "NGImap4ResponseNormalizer.h"
#include "NGImap4Client.h"
#include "imCommon.h"

@interface NGImap4Client(UsedPrivates)
- (NSString *)delimiter;
- (NSString *)_imapFolder2Folder:(NSString *)_folder;
@end

@implementation NGImap4ResponseNormalizer

static __inline__ NSArray *
_imapFlags2Flags(NGImap4ResponseNormalizer *, NSArray *);

static NSDictionary *VersionPrefixDict = nil;

static NSNumber *YesNumber     = nil;
static NSNumber *NoNumber      = nil;
static Class    DictClass      = Nil;
static Class    StrClass       = Nil;
static int      LogImapEnabled = -1;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;
  
  YesNumber = [[NSNumber numberWithBool:YES] retain];
  NoNumber  = [[NSNumber numberWithBool:NO]  retain];
  
  DictClass      = [NSDictionary class];
  StrClass       = [NSString     class];
  LogImapEnabled = [ud boolForKey:@"ImapLogEnabled"]?1:0;

  /*
    cyrus   - * OK defiant Cyrus IMAP4 v2.0.16 server ready
    courier - * OK Courier-IMAP ready. Copyright 1998-2002 Double
                Precision, Inc.  See COPYING for distribution information.
  */
  if (VersionPrefixDict == nil) {
    VersionPrefixDict =
      [[DictClass alloc] initWithObjectsAndKeys:
			      @"cyrus imap4 v", @"cyrus",
                              @" imap4rev1 ",   @"washington", 
                              @"courier",       @"courier", nil];
  }
}

- (id)initWithClient:(NGImap4Client *)_client {
  if ((self = [super init])) {
    self->client = _client; /* non-retained */
  }
  return self;
}

/* primary */

- (NSMutableDictionary *)normalizeResponse:(NGHashMap *)_map {
  /*
    Filter for all responses
    result  : NSNumber (response result)
    exists  : NSNumber (number of exists mails in selected folder
    recent  : NSNumber (number of recent mails in selected folder
    expunge : NSArray  (message sequence number of expunged mails in selected 
                        folder)
  */
  NSMutableDictionary *result;
  id                  obj;
  NSDictionary        *respRes;
  
  if (_map == nil)
    return (id)[NSMutableDictionary dictionary];
  
  respRes = [[_map objectEnumeratorForKey:@"ResponseResult"] nextObject];
  result  = [NSMutableDictionary dictionaryWithCapacity:32];
  [result setObject:_map forKey:@"RawResponse"];
  
  if ((obj = [_map objectForKey:@"bye"])) {
    [result setObject:NoNumber forKey:@"result"];
    [result setObject:obj forKey:@"reason"];
    [self->client closeConnection];
    return result;
  }

  if ([[respRes objectForKey:@"result"] isEqual:@"ok"]) {
    [result setObject:YesNumber forKey:@"result"];
  }
  else {
    id tmp = nil;
    [result setObject:NoNumber forKey:@"result"];
    if ((tmp = [respRes objectForKey:@"description"]) != nil) {
      [result setObject:tmp forKey:@"reason"];
    }
    return result;
  }
  if ((obj = [[_map objectEnumeratorForKey:@"exists"] nextObject]) != nil) { // 
    [result setObject:obj forKey:@"exists"];
  }
  if ((obj = [[_map objectEnumeratorForKey:@"recent"] nextObject]) != nil) {
    [result setObject:obj forKey:@"recent"];
  }
  if ((obj = [_map objectsForKey:@"expunge"]) != nil)
    [result setObject:obj forKey:@"expunge"];
  
  return result;
}

- (NSDictionary *)normalizeSortResponse:(NGHashMap *)_map {
  /* filter for sort response (search  : NSArray (msn)) */
  id                  obj;
  NSMutableDictionary *result;

  result = [self normalizeResponse:_map];
  
  if ((obj = [[_map objectEnumeratorForKey:@"sort"] nextObject]) != nil)
    [result setObject:obj forKey:@"sort"];
  
  return result;
}

- (NSDictionary *)normalizeCapabilityResponse:(NGHashMap *)_map {
  /* filter for capability response: capability  : NSArray */
  id                  obj;
  NSMutableDictionary *result;

  result = [self normalizeResponse:_map];
  
  if ((obj = [[_map objectEnumeratorForKey:@"capability"] nextObject]))
    [result setObject:obj forKey:@"capability"];
  
  return result;
}

- (NSArray *)_normalizeNamespace:(NSArray *)_namespace {
  NSMutableArray *result;
  NSDictionary *currentNS;
  NSMutableDictionary *newNS;
  NSString *newPrefix;
  int count, max;

  max = [_namespace count];
  result = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++) {
    currentNS = [_namespace objectAtIndex: count];
    newNS = [currentNS mutableCopy];
    newPrefix = [self->client
                  _imapFolder2Folder: [currentNS objectForKey: @"prefix"]];
    [newNS setObject: newPrefix forKey: @"prefix"];
    [result addObject: newNS];
    [newNS release];
  }

  return result;
}

- (NSDictionary *)normalizeNamespaceResponse:(NGHashMap *)_map {
  NSMutableDictionary *result;
  NSDictionary *rawResponse;
  NSArray *namespace;

  result = [self normalizeResponse:_map];
  rawResponse = [result objectForKey: @"RawResponse"];
  namespace = [rawResponse objectForKey: @"personal"];
  if (namespace)
    [result setObject: [self _normalizeNamespace: namespace]
               forKey: @"personal"];
  namespace = [rawResponse objectForKey: @"other users"];
  if (namespace)
    [result setObject: [self _normalizeNamespace: namespace]
               forKey: @"other users"];
  namespace = [rawResponse objectForKey: @"shared"];
  if (namespace)
    [result setObject: [self _normalizeNamespace: namespace]
               forKey: @"shared"];

  return result;
}

- (NSDictionary *)normalizeThreadResponse:(NGHashMap *)_map {
  /* filter for thread response: thread  : NSArray (msn) */
  id                  obj;
  NSMutableDictionary *result;

  result = [self normalizeResponse:_map];
  
  if ((obj = [[_map objectEnumeratorForKey:@"thread"] nextObject]))
    [result setObject:obj forKey:@"thread"];
  
  return result;
}

- (NSDictionary *)normalizeSearchResponse:(NGHashMap *)_map {
  /* filter for search response: search  : NSArray (msn) */
  id                  obj;
  NSMutableDictionary *result;

  result = [self normalizeResponse:_map];
  
  if ((obj = [[_map objectEnumeratorForKey:@"search"] nextObject]))
    [result setObject:obj forKey:@"search"];
  
  return result;
}

- (NSDictionary *)normalizeSelectResponse:(NGHashMap *)_map {
  /*
    filter for select response
      flags  : NSArray
      unseen : NSNumber
      access  : NSString ([READ-WRITE], ... )
    
    Eg:
      17 select "INBOX"
      * FLAGS (\Answered \Flagged \Draft \Deleted \Seen)
      * OK [PERMANENTFLAGS (\Answered \Flagged \Draft \Deleted \Seen \*)]  
      * OK (seen state failure) Unable to preserve \Seen state: System I/O \
          error
      * 0 EXISTS
      * 0 RECENT
      * OK [UIDVALIDITY 1016867500]  
      * OK [UIDNEXT 18948]  
      * OK [NOMODSEQ] Sorry, modsequences have not been enabled on this \
          mailbox
      17 OK [READ-WRITE] Completed
  */
  NSDictionary        *obj;
  NSEnumerator        *enumerator;
  NSMutableDictionary *result;
  id flags;
  
  result = [self normalizeResponse:_map];
  
  if ((flags = [[_map objectEnumeratorForKey:@"flags"] nextObject]) != nil)
    [result setObject:_imapFlags2Flags(self, flags) forKey:@"flags"];
  
  // TODO: document the contents of this dictionary
  enumerator = [_map objectEnumeratorForKey:@"ok"];
  while ((obj = [enumerator nextObject]) != nil) {
    id o;
    
    if ([obj isKindOfClass:DictClass]) {
      if ((o = [obj  objectForKey:@"unseen"]))
        [result setObject:o forKey:@"unseen"];
    }
    else
      [self warnWithFormat:@"unexpected OK object: %@", obj];
  }
  
  enumerator = [_map objectEnumeratorForKey:@"no"];
  while ((obj = [enumerator nextObject]) != nil) {
    id o;
    
    // TODO: document this
    if ([obj isKindOfClass:DictClass]) {
      if ((o = [obj  objectForKey:@"ALERT"]) != nil)
        [result setObject:o forKey:@"alert"];
    }
    else // TODO: this looks wrong, its not safe that this is the ALERT result?
      [result setObject:obj forKey:@"alert"];
  }
  
  obj = [_map objectForKey:@"ResponseResult"];
  if ((obj = [obj objectForKey:@"flag"]))
    [result setObject:obj forKey:@"access"];
  
  return result;
}

- (NSDictionary *)normalizeStatusResponse:(NGHashMap *)_map {
  /*
    filter for status response
      messages  : NSNumber
      recent    : NSNumber
      unseen    : NSNumber
  */
  NSDictionary        *obj;
  NSMutableDictionary *result;
  id                  o;
  
  result = [self normalizeResponse:_map];
  
  obj = [[_map objectEnumeratorForKey:@"status"] nextObject];
  obj = [obj objectForKey:@"flags"];
  
  if ((o = [obj  objectForKey:@"messages"]) != nil)
    [result setObject:o forKey:@"messages"];
  
  if ((o = [obj  objectForKey:@"recent"]) != nil) {
    if ([result objectForKey:@"recent"] == nil)
      [result setObject:o forKey:@"recent"];
  }
  if ((o = [obj  objectForKey:@"unseen"]) != nil)
    [result setObject:o forKey:@"unseen"];
  
  return result;
}

/*
  filter for fetch response
    fetch : NSArray (fetch responses)
      'header'  - RFC822.HEADER and BODY[HEADER.FIELDS (...)]
      'text'    - RFC822.TEXT
      'size'    - SIZE
      'flags'   - FLAGS
      'uid'     - UID
      'msn'     - message sequence number
      'message' - RFC822
      'body'    - (dictionary with bodystructure)

  This walks over all 'fetch' responses in the map and adds a 'normalized'
  dictionary for each response to the 'fetch' key of the normalized response
  dictionary (as retrieved by 'normalizeResponse')
*/
- (NSDictionary *)normalizeFetchResponsePart:(id)obj {
    // TODO: shouldn't we use a specific object instead of NSDict for that?
    NSDictionary *entry;
    NSEnumerator *keyEnum;
    NSString     *key;
    NSString     *keys[9];
    id           values[9];
    unsigned     count;
    id (*objForKey)(id, SEL, id);
    
    /*
       Process one 'fetch' reponse dictionary, walk over each key of the 
       dict and check for a collection of known response keys.
    */
    count     = 0;
    keyEnum   = [obj keyEnumerator];    
    objForKey = (void *)[obj methodForSelector:@selector(objectForKey:)];
    
    // TODO: this should add some error handling wrt the count?
    // TODO: this could return multiple values for the same key?! => fix that
    while (((key = [keyEnum nextObject]) != nil) && (count < 9)) {
      unsigned klen;
      unichar  c;
      
      if ((klen = [key length]) < 3)
	continue;
      c = [key characterAtIndex:0];
      
      switch (c) {
      case 'b':
        /* Note: we check for _prefix_! eg body[1] is valid too */
	if (klen > 17 && [key hasPrefix:@"body[header.fields"]) {
	  keys[count]   = @"header";
	  values[count] = objForKey(obj, @selector(objectForKey:), key);
	  count++;
	}
	else if (klen > 3 && [key hasPrefix:@"body"]) {
	  keys[count]   = @"body";
	  values[count] = objForKey(obj, @selector(objectForKey:), key);
	  count++;
	}
	break;
      case 'e':
	if (klen == 8 && [key isEqualToString:@"envelope"]) {
	  keys[count]   = @"envelope";
	  values[count] = objForKey(obj, @selector(objectForKey:), key);
	  count++;
	}
	break;
      case 'f':
	if (klen == 5 && [key isEqualToString:@"flags"]) {
	  id rawFlags;
	  
	  rawFlags = objForKey(obj, @selector(objectForKey:), key);
	  keys[count]   = @"flags";
	  values[count] = _imapFlags2Flags(self, rawFlags);
	  count++;
	}
	break;
      case 'm':
	if (klen == 3 && [key isEqualToString:@"msn"]) {
	  keys[count]   = @"msn";
	  values[count] = objForKey(obj, @selector(objectForKey:), key);
	  count++;
	}
        else if (klen == 6 && [key isEqualToString:@"modseq"]) {
	  keys[count] = @"modseq";
	  values[count] = objForKey(obj, @selector(objectForKey:), key);
	  count++;
	}
	break;
      case 'r':
	if (klen == 6 && [key isEqualToString:@"rfc822"]) {
	  keys[count]   = @"message";
	  values[count] = objForKey(obj, @selector(objectForKey:), key);
	  count++;
	}
	else if (klen == 13 && [key isEqualToString:@"rfc822.header"]) {
	  keys[count]   = @"header";
	  values[count] = objForKey(obj, @selector(objectForKey:), key);
	  count++;
	}
	else if (klen == 11 && [key isEqualToString:@"rfc822.text"]) {
	  keys[count]   = @"text";
	  values[count] = objForKey(obj, @selector(objectForKey:), key);
	  count++;
	}
	else if (klen == 11 && [key isEqualToString:@"rfc822.size"]) {
	  keys[count]   = @"size";
	  values[count] = objForKey(obj, @selector(objectForKey:), key);
	  count++;
	}
	break;
      case 'u':
	if (klen == 3 && [key isEqualToString:@"uid"]) {
	  keys[count]   = @"uid";
	  values[count] = objForKey(obj, @selector(objectForKey:), key);
	  count++;
	}
	break;
      case 'v':
	if ([key isEqualToString:@"vanished"]) {
	  keys[count]   = key;
	  values[count] = objForKey(obj, @selector(objectForKey:), key);
	  count++;
	}
	break;
      }
    }
    
    /* create dictionary */
    
    entry = count > 0
      ? [[DictClass alloc] initWithObjects:values forKeys:keys count:count]
      : nil;
    
    return entry; /* returns retained object! */
}
- (NSDictionary *)normalizeFetchResponse:(NGHashMap *)_map {
  /*
    Raw Sample (Courier):
      C[0x8b4e754]: 27 uid fetch 635 (body)
      S[0x8c8b4e4]: * 627 FETCH (UID 635 BODY 
        ("text" "plain" ("charset" "iso-8859-1" "format" "flowed") 
        NIL NIL "8bit" 2474 51))
      S[0x8c8b4e4]: * 627 FETCH (FLAGS (\Seen))
      S[0x8c8b4e4]: 27 OK FETCH completed.
    - this results in two result records (one for UID and one for FLAGS)
      TODO: should we coalesce?

    Raw Sample (Cyrus):
      C[0x8c8ec64]: 14 uid fetch 20199 (body)
      S[0x8da46a4]: * 93 FETCH (UID 20199 BODY 
        ((("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL "signed data" "7BIT" 691 17)
          ("APPLICATION" "PKCS7-SIGNATURE" ("NAME" "smime.p7s") NIL 
           "signature" "BASE64" 2936) "SIGNED")
          ("TEXT" "PLAIN" ("CHARSET" "us-ascii") NIL NIL "7BIT" 146 4) 
          "MIXED"))
      S[0x8da46a4]: 14 OK Completed
    - UID key is mapped to 'uid'
    - BODY key is mapped to a nested body structure
    - MSN is added for the '93'? (TODO: make sure this is the case)

    Sample returns (not for the above code!):
      {
        // other message stuff
        fetch = (
          {
            header = < NSData containing the header >;
            size   = 3314;
            uid    = 20187;
            msn    = 72;
            flags  = ( answered, deleted, seen );
          },
          ... for each fetch message ...
        )
      }
  */
  NSMutableDictionary *result;
  id                  obj;
  NSEnumerator        *enumerator;
  NSMutableArray      *fetchResponseRecords, *fetchResponseVanishedRecords;

  // TODO: describe what the generic normalize does.
  //       Q: do we need to run this before the following section or can we
  //          call this method just before [result setObject:...] ? (I guess
  //          the latter, because 'result' is not accessed, but who knows
  //          about side effects in this JR cruft :-( )
  result = [self normalizeResponse:_map];
  
  fetchResponseRecords = [[NSMutableArray alloc] initWithCapacity:512];
  
  /* walk over each response tag which is keyed by 'fetch' in the hashmap */
  enumerator = [_map objectEnumeratorForKey:@"fetch"];
  while ((obj = [enumerator nextObject]) != nil) {
    NSDictionary *entry;
    
    if ((entry = [self normalizeFetchResponsePart:obj]) == nil)
      continue;
    
    [fetchResponseRecords addObject:entry];
    [entry release]; entry = nil;
  }

  /* make response array immutable and add to normalized result */
  obj = [fetchResponseRecords copy];
  [fetchResponseRecords release];
  [result setObject:obj forKey:@"fetch"];
  [obj release];
  
  /* walk over each response tag which is keyed by 'vanished' in the hashmap */
  fetchResponseVanishedRecords = [[NSMutableArray alloc] initWithCapacity:512];
  enumerator = [_map objectEnumeratorForKey:@"vanished"];
  while ((obj = [enumerator nextObject]) != nil) {
    [fetchResponseVanishedRecords addObjectsFromArray:obj];
  }

  /* add response array to normalized result */
  [result setObject:fetchResponseVanishedRecords forKey:@"vanished"];
  [fetchResponseVanishedRecords release];
  
  return [[result copy] autorelease];
}

- (NSDictionary *)normalizeQuotaResponse:(NGHashMap *)_map {
  /* filter for quota responses */
  NSMutableDictionary *result, *quotaRoot, *quota, *tmp;
  id                  obj;
  NSEnumerator        *enumerator;

  result     = [self normalizeResponse:_map];
  quotaRoot  = [_map objectForKey:@"quotaRoot"];
  quota      = [_map objectForKey:@"quota"];
  enumerator = [quotaRoot keyEnumerator];
  tmp        = [NSMutableDictionary dictionaryWithCapacity:[quota count]];
  
  while ((obj = [enumerator nextObject])) {
    NSString     *qRoot;
    NSDictionary *qDesc;

    qRoot = [quotaRoot objectForKey:obj];

    if (![qRoot isNotEmpty]) {
      if (LogImapEnabled) {
        [self logWithFormat:@"%s: missing quotaroot for %@",
              __PRETTY_FUNCTION__, obj];
      }
      continue;
    }
    qDesc = [quota objectForKey:qRoot];

    if ([qDesc count] == 0) {
      if (LogImapEnabled) {
        [self logWithFormat:@"%s: missing quota description for"
              @" folder %@ root %@",
              __PRETTY_FUNCTION__, obj, qRoot];
      }
      continue;
    }
    [tmp setObject:qDesc forKey:[self->client _imapFolder2Folder:obj]];
  }
  [result setObject:tmp forKey:@"quotas"];
  return [[result copy] autorelease];
}


/*
** filter for open connection
*/

- (NSDictionary *)normalizeOpenConnectionResponse:(NGHashMap *)_map {
  NSMutableDictionary *result;
  id obj;

  result = [self normalizeResponse:_map];
  
  obj = [[_map objectEnumeratorForKey:@"ok"] nextObject];
  if (obj == nil) {
    [result setObject:NoNumber forKey:@"result"];
    return result;
  }
  
  if ([obj isKindOfClass:DictClass])
    obj = [(NSDictionary *)obj objectForKey:@"comment"];

  if ([obj isKindOfClass:StrClass]) {
    NSEnumerator *enumerator;
    id           key;
    NSString     *lowServer;
    
    [result setObject:obj forKey:@"server"];
    
    enumerator = [VersionPrefixDict keyEnumerator];
    lowServer  = [obj lowercaseString];

    while ((key = [enumerator nextObject])) {
      NSString *pref;
      NSArray  *vers;
      NSRange  r;
        
      pref  = [VersionPrefixDict objectForKey:key];
      r     = [lowServer rangeOfString:pref];
      
      if (r.length == 0) continue;
        
      [result setObject:key forKey:@"serverKind"];
      if (![key isEqualToString:@"cyrus"])
        continue;
        
      /* cyrus server, collect version */
        
      vers = [[lowServer substringFromIndex:(r.location + [pref length])]
                         componentsSeparatedByString:@"."];
      
      if ([vers count] > 2) {
        NSNumber *n;
          
        n = [NSNumber numberWithInt:[[vers objectAtIndex:0] intValue]];
        [result setObject:n forKey:@"version"];

        n = [NSNumber numberWithInt:[[vers objectAtIndex:1] intValue]];
        [result setObject:n forKey:@"subversion"];
          
        n = [NSNumber numberWithInt:[[vers objectAtIndex:2] intValue]];
        [result setObject:n forKey:@"tag"];
      }
      break;
    }
  }
  [result setObject:YesNumber forKey:@"result"];
  
  return result;
}

/*
** filter for list
**       list : NSDictionary (folder name as key and flags as value)
*/

- (NSDictionary *)normalizeListResponse:(NGHashMap *)_map {
  NSMutableDictionary *result;
  id                  obj;
  NSAutoreleasePool   *pool;
  NSDictionary        *rr;
  
  pool   = [[NSAutoreleasePool alloc] init];
  result = [self normalizeResponse:_map];
  
  if ((obj = [_map objectsForKey:@"list"]) != nil) {
    NSEnumerator        *enumerator;
    NSDictionary        *o;
    NSMutableDictionary *folder;
    
    enumerator = [obj objectEnumerator];
    folder     = [[NSMutableDictionary alloc] init];
    
    while ((o = [enumerator nextObject])) {
      [folder setObject:_imapFlags2Flags(self, [o objectForKey:@"flags"])
              forKey:[self->client _imapFolder2Folder:[o objectForKey:@"folderName"]]];
    }
    
    {
      NSDictionary *f;
      
      f = [folder copy];
      [result setObject:f forKey:@"list"];
      [f release];      f      = nil;
      [folder release]; folder = nil;
    }
  }
  rr = [result copy];
  [pool release];
  
  return [rr autorelease];
}

/* flags */

static inline NSArray *
_imapFlags2Flags(NGImap4ResponseNormalizer *self, NSArray *_flags) 
{
  NSEnumerator *enumerator;
  NSArray      *result;
  id           obj, *objs;
  unsigned     cnt;
  
  objs = calloc([_flags count] + 2, sizeof(id));
  
  enumerator = [_flags objectEnumerator];
  cnt = 0;
  while ((obj = [enumerator nextObject])) {
    if ([obj isNotEmpty]) {
      if ([obj hasPrefix:@"\\"])
	objs[cnt] = [obj substringFromIndex:1];
      else
	objs[cnt] = obj;
      cnt++;
    }
  }
  result = [NSArray arrayWithObjects:objs count:cnt];
  if (objs) free(objs);
  return result;
}

/* ACL */

- (NSDictionary *)normalizeGetACLResponse:(NGHashMap *)_map {
  /*
    Raw Sample (Cyrus):
      21 GETACL INBOX
      * ACL INBOX test.et.di.cete-lyon lrswipcda helge lrwip
      21 OK Completed
  */
  NSMutableDictionary *result;
  id obj;
  
  result = [self normalizeResponse:_map];
  if ((obj = [[_map objectEnumeratorForKey:@"acl"] nextObject]) != nil)
    [result setObject:obj forKey:@"acl"];
  if ((obj = [[_map objectEnumeratorForKey:@"mailbox"] nextObject]) != nil)
    [result setObject:obj forKey:@"mailbox"];
  return result;
}

- (NSDictionary *)normalizeListRightsResponse:(NGHashMap *)_map {
  /*
    Raw Sample (Cyrus):
      16 listrights INBOX anyone
      * LISTRIGHTS INBOX anyone "" l r s w i p c d a 0 1 2 3 4 5 6 7 8 9
      16 OK Completed
  */
  NSMutableDictionary *result;
  id obj;

  result = [self normalizeResponse:_map];

  if ((obj = [[_map objectEnumeratorForKey:@"listrights"] nextObject]))
    [result setObject:obj forKey:@"listrights"];
  if ((obj = [[_map objectEnumeratorForKey:@"requiredRights"] nextObject]))
    [result setObject:obj forKey:@"requiredRights"];

  if ((obj = [[_map objectEnumeratorForKey:@"mailbox"] nextObject]) != nil)
    [result setObject:obj forKey:@"mailbox"];
  if ((obj = [[_map objectEnumeratorForKey:@"uid"] nextObject]) != nil)
    [result setObject:obj forKey:@"uid"];
  return result;
}

- (NSDictionary *)normalizeMyRightsResponse:(NGHashMap *)_map {
  /*
    Raw Sample (Cyrus):
      18 myrights INBOX
      * MYRIGHTS INBOX lrswipcda
      18 OK Completed
  */
  NSMutableDictionary *result;
  id obj;

  result = [self normalizeResponse:_map];
  if ((obj = [[_map objectEnumeratorForKey:@"myrights"] nextObject]) != nil)
    [result setObject:obj forKey:@"myrights"];
  if ((obj = [[_map objectEnumeratorForKey:@"mailbox"] nextObject]) != nil)
    [result setObject:obj forKey:@"mailbox"];
  return result;
}

@end /* NGImap4ResponseNormalizer */
