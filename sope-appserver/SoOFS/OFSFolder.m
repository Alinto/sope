/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#include "OFSFolder.h"
#include "OFSFile.h"
#include "OFSFactoryContext.h"
#include "OFSFactoryRegistry.h"
#include "OFSResourceManager.h"
#include "OFSFolderClassDescription.h"
#include "OFSFolderDataSource.h"
#include <NGObjWeb/WOResponse.h>
#include "common.h"

@implementation OFSFolder

static BOOL factoryDebugOn  = NO;
static BOOL debugLookup     = NO;
static BOOL debugRestore    = NO;
static BOOL debugNegotiate  = NO;
static BOOL debugAuthLookup = NO;

+ (int)version {
  return [super version] + 1 /* v2 */;
}
+ (void)initialize {
  static BOOL didInit = NO;
  if (!didInit) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    didInit = YES;
    NSAssert2([super version] == 1,
	      @"invalid superclass (%@) version %i !",
	      NSStringFromClass([self superclass]), [super version]);
    
    debugLookup     = [ud boolForKey:@"SoDebugKeyLookup"];
    factoryDebugOn  = [ud boolForKey:@"SoOFSDebugFactory"];
    debugRestore    = [ud boolForKey:@"SoOFSDebugRestore"];
    debugNegotiate  = [ud boolForKey:@"SoOFSDebugNegotiate"];
    debugAuthLookup = [ud boolForKey:@"SoOFSDebugAuthLookup"];
  }
}

- (void)dealloc {
  [(OFSResourceManager *)self->resourceManager invalidate];
  [self->resourceManager release];
  
  [[self->children allValues] 
    makeObjectsPerformSelector:@selector(detachFromContainer)];
  
  [self->childNames  release];
  [self->props    release];
  [self->children release];
  [super dealloc];
}

/* accessors */

- (NSString *)propertyFilename {
  return @".props.plist";
}

- (BOOL)isCollection {
  return YES;
}
- (BOOL)hasChildren {
  return [self->childNames count] > 0 ? YES : NO;
}

- (NSArray *)allKeys {
  return self->childNames;
}

- (BOOL)hasKey:(NSString *)_key {
  return [self->childNames containsObject:_key];
}

- (id)objectForKey:(NSString *)_key {
  OFSFactoryContext *ctx;
  NSDictionary *fileAttrs;
  NSString     *fileType, *mimeType;
  NSString     *childPath;
  id child;
  id factory;
  
  if ((child = [self->children objectForKey:_key]))
    /* cached */
    return [child isNotNull] ? child : nil;
  
  if ([_key hasPrefix:@"."])
    /* do not consider keys starting with a point ... */
    return nil;
  
  if (self->flags.didLoadAll)
    /* everything is cached, should be in there .. */
    return nil;
  
  if (![self->childNames containsObject:_key])
    /* not a storage key anyway */
    return nil;
  
  /* find out filetype */
  
  childPath = [self storagePathForChildKey:_key];
  fileAttrs = [[self fileManager] fileAttributesAtPath:childPath
				  traverseLink:YES];
  fileType  = [fileAttrs objectForKey:NSFileType];
  mimeType  = [fileAttrs objectForKey:@"NSFileMimeType"];
  
  if (fileType == nil)
    [self logWithFormat:@"got no file type for child %@ ...", _key];
  
  /* create factory context */
  
  ctx = [OFSFactoryContext contextForChild:_key
			   storagePath:childPath
			   ofFolder:self];
  ctx->fileType = [fileType copy];
  ctx->mimeType = [mimeType copy];
  
  /* lookup factory */
  
  if ((factory = [self restorationFactoryForContext:ctx]) == nil) {
    [self logWithFormat:@"found no factory for key '%@' (%@, mime=%@)",
	    _key, fileType, mimeType];
    return [NSException exceptionWithHTTPStatus:500
			reason:@"found no factory for object !"];
  }
  
  if (factoryDebugOn)
    [self debugWithFormat:@"selected factory %@ for key %@", factory, _key];
  
  /* instantiate and register */
  
  if (self->children == nil) {
    self->children =
      [[NSMutableDictionary alloc] initWithCapacity:[self->childNames count]];
  }
  
  if ((child = [factory instantiateInFactoryContext:ctx]) == nil) {
    [self logWithFormat:@"factory did not instantiate object for key '%@'",
	    _key];
    child = [NSException exceptionWithHTTPStatus:500
			 reason:@"instantiation of object failed !"];
  }
  
  [self->children setObject:child forKey:_key];
  
  /* awake object, handle possible replacement result */
  
  if (![child isKindOfClass:[NSException class]]) {
    id replacement;
    
    replacement = [child awakeFromFetchInContext:ctx];
    if (replacement != child) {
      if (replacement == nil)
	[self->children removeObjectForKey:_key];
      else
	[self->children setObject:replacement forKey:_key];
    }
  }
  
  return child;
}

- (NSArray *)allValues {
  NSEnumerator *keys;
  NSString     *key;
  
  if (self->flags.didLoadAll)
    return [self->children allValues];
  
  /* query each key to load it into the children cache */
  
  keys = [self->childNames objectEnumerator];
  while ((key = [keys nextObject]))
    [self objectForKey:key];
  
  self->flags.didLoadAll = 1;
  return [self->children allValues];
}

- (NSEnumerator *)keyEnumerator {
  return [self->childNames objectEnumerator];
}
- (NSEnumerator *)objectEnumerator {
  return [[self allValues] objectEnumerator];
}

- (BOOL)isValidKey:(NSString *)_key {
  /* 
     Check whether key is usable for storage (extract some FS sensitive or 
     private keys)
  */
  unichar c;
  if ([_key length] == 0) return NO;
  c = [_key characterAtIndex:0];
  if (c == '.') return NO;
  if (c == '~') return NO;
  if (c == '%') return NO;
  if (c == '/') return NO;
  if ([_key rangeOfString:@"/"].length  > 0) 
    // TBD: we should allow '/' in filenames
    return NO;
  if ([_key isEqualToString:[self propertyFilename]])
    return NO;
  return YES;
}

/* datasource */

- (EODataSource *)contentDataSource {
  return [OFSFolderDataSource dataSourceOnFolder:self];
}

/* storage */

- (void)willChange {
}

- (NSString *)storagePathForChildKey:(NSString *)_name {
  if (![self isValidKey:_name]) return nil;
  return [[self storagePath] stringByAppendingPathComponent:_name];
}

- (OFSFactoryRegistry *)factoryRegistry {
  return [OFSFactoryRegistry sharedFactoryRegistry];
}

- (id)restorationFactoryForContext:(OFSFactoryContext *)_ctx {
  return [[self factoryRegistry] restorationFactoryForContext:_ctx];
}
- (id)creationFactoryForContext:(OFSFactoryContext *)_ctx {
  return [[self factoryRegistry] creationFactoryForContext:_ctx];
}

/* unarchiving */

- (NSClassDescription *)soClassDescription {
  // TODO: cache class description ?
  return [[[OFSFolderClassDescription alloc] initWithFolder:self] autorelease];
}
- (NSArray *)attributeKeys {
  return [self->props allKeys];
}
- (NSArray *)toOneRelationshipKeys {
  return [self allKeys];
}

- (void)filterChildNameArray:(NSMutableArray *)p {
  unsigned i;
  
  [p removeObject:[self propertyFilename]];
  
  for (i = 0; i < [p count];) {
    NSString *k;
    unsigned kl;
    
    k = [p objectAtIndex:i];
    kl = [k length];
    if (kl == 3 && !self->flags.hasCVS && [k isEqualToString:@"CVS"]) {
      self->flags.hasCVS = 1;
      [p removeObjectAtIndex:i];
    }
    else if (kl == 4 && !self->flags.hasSvn && [k isEqualToString:@".svn"]) {
      self->flags.hasSvn = 1;
      [p removeObjectAtIndex:i];
    }
    else if ([k hasPrefix:@"."])
      [p removeObjectAtIndex:i];
    else
      i++;
  }
  self->flags.checkedVersionSpecials = 1;
}

- (id)awakeFromFetchInContext:(OFSFactoryContext *)_ctx {
  NSString *sp;
  id       p;
  
  if (debugRestore)
    [self debugWithFormat:@"-awakeFromContext:%@", _ctx];
  
  if ((p = [super awakeFromFetchInContext:_ctx]) != self) {
    if (debugRestore)
      [self debugWithFormat:@"  parent replaced object with: %@", p];
    return p;
  }
  
  sp = [_ctx storagePath];
  if (debugRestore)
    [self debugWithFormat:@"  restore path: '%@'", sp];
  
  /* load the dictionary properties */
  
  p = [sp stringByAppendingPathComponent:[self propertyFilename]];
  self->props = [[NSDictionary alloc] initWithContentsOfFile:p];
  
  if (debugRestore) {
    [self debugWithFormat:@"  restored %i properties: %@", 
	    [self->props count],
	    [[self->props allKeys] componentsJoinedByString:@","]];
  }
  
  /* load the collection children names */
  
  p = [[[_ctx fileManager] directoryContentsAtPath:sp] mutableCopy];
  if (p == nil) {
    [self debugWithFormat:@"couldn't get child names at path '%@'.", p];
    return nil;
  }
  if (debugRestore)
    [self debugWithFormat:@"  storage child names at '%@': %@", sp, p];
  
  [self filterChildNameArray:p];
  [p sortUsingSelector:@selector(compare:)];
  
  self->childNames = [p copy];
  [p release];
  
  if (debugRestore) {
    [self debugWithFormat:@"  restored child names: %@", 
	    [self->childNames componentsJoinedByString:@","]];
  }
  
  return self;
}

- (void)flushChildCache {
  [[self->children allValues] 
    makeObjectsPerformSelector:@selector(detachFromContainer)];
  [self->children removeAllObjects];
  self->flags.didLoadAll = 0;
}

- (NSException *)reload {
  // TODO: reload folder !
  [self flushChildCache];
  return nil;
}

/* KVC */

- (id)valueForKey:(NSString *)_name {
  /* map out some very private keys */
  unsigned nl;
  unichar  c;
  NSString *v;
  
  if ((v = [self->props objectForKey:_name]))
    return v;
  
  if ((nl = [_name length]) == 0)
    return nil;
  
  c = [_name characterAtIndex:0];
  // TBD ?
  
  return [super valueForKey:_name];
}

/* operations */

- (BOOL)allowRecursiveDeleteInContext:(id)_ctx {
  return NO;
}

- (NSString *)defaultMethodNameInContext:(id)_ctx {
  return @"index";
}
- (id)lookupDefaultMethod {
  id ctx = nil;
  
  ctx = [[WOApplication application] context];
  return [self lookupName:[self defaultMethodNameInContext:ctx]
	       inContext:ctx
	       acquire:YES];
}

- (id)GETAction:(id)_ctx {
  WOResponse *r = [(id <WOPageGenerationContext>)_ctx response];
  NSString   *uri, *qs, *method;
  NSRange    ra;
  
  if (![[_ctx soRequestType] isEqualToString:@"METHOD"])
    return self;
  
  if ((method = [self defaultMethodNameInContext:_ctx]) == nil)
    /* no default method */
    return self;

  /* construct URI */
  
  uri = [[(id <WOPageGenerationContext>)_ctx request] uri];
  ra = [uri rangeOfString:@"?"];
  if (ra.length > 0) {
    qs  = [uri substringFromIndex:ra.location];
    uri = [uri substringToIndex:ra.location];
  }
  else
    qs = nil;
  uri = [uri stringByAppendingPathComponent:method];
  if (qs) uri = [uri stringByAppendingString:qs];
  
  [r setStatus:302 /* moved */];
  [r setHeader:uri forKey:@"location"];
  return r;
}

- (id)DELETEAction:(id)_ctx {
  NSException *e;
  
  if ((e = [self validateForDelete]))
    return e;
  
  if ([self hasChildren]) {
    if (![self allowRecursiveDeleteInContext:_ctx]) {
      return [NSException exceptionWithHTTPStatus:403 /* forbidden */
			  reason:@"tried to delete a filled folder"];
    }
  }
  return [super DELETEAction:_ctx];
}

- (id)PUTAction:(id)_ctx {
  OFSFactoryContext *ctx;
  NSString    *pathInfo;
  NSString    *childPath;
  id          factory;
  id          result, child;
  id          childPutMethod;
  
  pathInfo = [_ctx pathInfo];
  /* TODO: NEED TO REWRITE path info to a key (eg strip .vcf) ! */
  
  // TODO: return conflict, on attempt to create subfolder
  if ([pathInfo length] == 0) {
    [self debugWithFormat:@"attempt to PUT to an OFSFolder !"];
    [self debugWithFormat:@"body:\n%@", [[(id <WOPageGenerationContext>)_ctx request] contentAsString]];
    
    return [NSException exceptionWithHTTPStatus:405 /* method not allowed */
			reason:@"HTTP PUT not allowed on a folder resource"];
  }
  
  if ([self->childNames containsObject:pathInfo]) {
    /*
      Explained: PUT can be and is used to overwrite existing resources. But
      if PUT was issued on an existing resource, the SoObject for this resource
      will receive the PUT action, not it's contained.
      So: the container (folder) only receives a PUT action with a PATH_INFO if
      the resource to be PUT is new.
    */
    [self debugWithFormat:
	    @"internal inconsistency, tried to create an existing resource !"];
    return [NSException exceptionWithHTTPStatus:500 /* method not allowed */
			reason:@"tried to create an existing resource"];
  }
  
  if ((childPath = [self storagePathForChildKey:pathInfo]) == nil) {
    [self debugWithFormat:@"invalid name for child !"];
    return [NSException exceptionWithHTTPStatus:400 /* bad request */
			reason:@"the name for the child creation was invalid"];
  }
  
  /* create factory context */
  
  ctx = [OFSFactoryContext contextForNewChild:pathInfo
			   storagePath:childPath
			   ofFolder:self];
  ctx->fileType = [NSFileTypeRegular retain];
  ctx->mimeType = [[[(id <WOPageGenerationContext>)_ctx request] headerForKey:@"content-type"] copy];
  
  /* lookup factory */
  
  if ((factory = [self creationFactoryForContext:ctx]) == nil) {
    [self logWithFormat:@"found no factory for new key '%@' (%@, mime=%@)",
	    pathInfo, ctx->fileType, [ctx mimeType]];
    return [NSException exceptionWithHTTPStatus:500
			reason:@"found no factory for new object !"];
  }
  
  if (factoryDebugOn) {
    [self debugWithFormat:@"selected factory %@ for new child named %@", 
	    factory, pathInfo];
  }
  
  /* instantiate and register */
  
  if (self->children == nil) {
    self->children =
      [[NSMutableDictionary alloc] initWithCapacity:[self->childNames count]];
  }
  
  if ((child = [factory instantiateInFactoryContext:ctx]) == nil) {
    [self logWithFormat:
	    @"factory did not instantiate new object for key '%@'",
	    pathInfo];
    return [NSException exceptionWithHTTPStatus:500
			reason:@"instantiation of object failed !"];
  }
  if ([child isKindOfClass:[NSException class]])
    return child;
  
  childPutMethod = [child lookupName:@"PUT" inContext:_ctx acquire:NO];
  if (childPutMethod == nil) {
    return [NSException exceptionWithHTTPStatus:405 /* method not allowed */
			reason:@"new child does not support HTTP PUT."];
  }
  
  [self->children setObject:child forKey:pathInfo];
  
  /* awake object, handle possible replacement result */
  
  {
    id replacement;
    
    replacement = [child awakeFromInsertionInContext:ctx];
    if (replacement != child) {
      if ([replacement isKindOfClass:[NSException class]]) {
	replacement = [replacement retain];
	[self->children removeObjectForKey:pathInfo];
	return [replacement autorelease];
      }
      
      if (replacement == nil) {
	[self->children removeObjectForKey:pathInfo];
	return [NSException exceptionWithHTTPStatus:500
			    reason:@"awake failed, reason unknown"];
      }
      else {
	childPutMethod = 
	  [replacement lookupName:@"PUT" inContext:_ctx acquire:NO];
	
	if (childPutMethod == nil) {
	  [self->children removeObjectForKey:pathInfo];
	  return [NSException exceptionWithHTTPStatus:405 /* not allowed */
			      reason:@"new child does not support HTTP PUT."];
	}
	
	[self->children setObject:replacement forKey:pathInfo];
	child = replacement;
      }
    }
  }
  
  /* now forward the PUT to the child */
  
  result = [[childPutMethod bindToObject:child inContext:_ctx]
	                    callOnObject:child inContext:_ctx];
  
  /* check whether put was successful */
  
  if ([result isKindOfClass:[NSException class]]) {
    /* creation failed, unregister from childlist */
    [child detachFromContainer];
    [self->children removeObjectForKey:pathInfo];
  }
  
  return result;
}

- (id)MKCOLAction:(id)_ctx {
  NSString *pathInfo;
  
  pathInfo = [_ctx pathInfo];
  pathInfo = [pathInfo stringByUnescapingURL];
  
  if ([pathInfo length] == 0) {
    [self debugWithFormat:@"attempt to MKCOL an existint OFSFolder !"];
    return [NSException exceptionWithHTTPStatus:405 /* method not allowed */
			reason:@"tried MKCOL an an existing resource"];
  }
  
  // TBD: create new child
  // TBD: return conflict, on attempt to create subfolder
  return [NSException exceptionWithHTTPStatus:403 /* forbidden */
		      reason:@"creating collections is forbidden"];
}

/* lookup */

- (NSString *)normalizeKey:(NSString *)_name inContext:(id)_ctx {
  /* useful for content-negotiation */
  return _name;
}

- (NSString *)selectBestMatchForName:(NSString *)_name 
  fromChildNames:(NSArray *)_matches
  inContext:(id)_ctx
{
  NSString *storeName;
  unsigned count;
  
  if ((count = [_matches count]) == 0)
    storeName = nil;
  else if (count == 1)
    storeName = [_matches objectAtIndex:0];
  else {
    // TODO: some real negotiation based on "accept", "language", ..
    storeName = [_matches objectAtIndex:0];
    [self logWithFormat:@"negotiate: selected '%@' from: %@.", storeName,
	    [_matches componentsJoinedByString:@","]];
  }
  if (debugNegotiate) [self logWithFormat:@"negotiated: '%@'", storeName];
  return storeName;
}
  
- (NSString *)negotiateName:(NSString *)_name inContext:(id)_ctx {
  /* returns a "storeName", one which can be resolved in the store */
  NSMutableArray *matches;
  NSString *askedExt, *normName, *storeName;
  NSArray  *availKeys;
  unsigned i, count;

  if (debugNegotiate) [self logWithFormat:@"negotiate: %@", _name];
  
  availKeys = [self allKeys];
  if ((count = [availKeys count]) == 0)
    return nil;   /* no content */
  if ([availKeys containsObject:_name])
    return _name; /* exact match */
  
  /* some hard-coded content negotiation */
  
  askedExt = [_name pathExtension];
  normName = [_name stringByDeletingPathExtension];
  
  for (i = 0, matches = nil; i < count; i++) {
    NSString *storeName, *childNormName;
    
    storeName     = [availKeys objectAtIndex:i];
    childNormName = [storeName stringByDeletingPathExtension];
    
    if (debugNegotiate) [self logWithFormat:@"  check: %@", storeName];
    
    if (![normName isEqualToString:childNormName])
      /* does not match */
      continue;
    
    if (matches == nil) matches = [[NSMutableArray alloc] initWithCapacity:16];
    [matches addObject:storeName];
  }
  
  if (matches == nil)
    return nil; /* no matches */
  
  storeName = [self selectBestMatchForName:normName 
		    fromChildNames:matches
		    inContext:_ctx];
  storeName = [[storeName copy] autorelease];
  [matches release];
  return storeName;
}

- (BOOL)hasName:(NSString *)_name inContext:(id)_ctx {
  _name = [self normalizeKey:_name inContext:_ctx];
  
  if ([self hasKey:_name])
    /* is a stored key ! */
    return YES;
  
  /* queried something else */
  return [super hasName:_name inContext:_ctx];
}

- (NSException *)validateName:(NSString *)_name inContext:(id)_ctx {
  return [super validateName:[self normalizeKey:_name inContext:_ctx] inContext:_ctx];
}

- (id)lookupStoredName:(NSString *)_name inContext:(id)_ctx {
  NSString *storeName;
  
  if ((storeName = [self negotiateName:_name inContext:_ctx]) == nil)
    return nil;
  
  /* is a stored key ! */
  return [self objectForKey:storeName];
}

- (id)handleMissingName:(NSString *)_name inContext:(id)_ctx {
  // TODO: object autocreation support (aka "create on access")
  if (debugLookup)
    [self debugWithFormat:@"  found no matching value for key: %@", _name];
  return nil;
}

- (id)lookupName:(NSString *)_name inContext:(id)_ctx acquire:(BOOL)_flag {
  id value;
  
  if (debugLookup) [self debugWithFormat:@"lookup key '%@'", _name];

  /* normalize key */
  
  _name = [self normalizeKey:_name inContext:_ctx];
  if (debugLookup)
    [self debugWithFormat:@"  normalized '%@'", _name];

  /* lookup in folder storage */
  
  if ((value = [self lookupStoredName:_name inContext:_ctx])) {
    /* found an SoOFS child in storage */
    if (debugLookup) [self debugWithFormat:@"  stored value: %@", value];
    return value;
  }
  
  if (debugLookup) {
    [self debugWithFormat:@"  not a collection child: %@", 
	    [[self allKeys] componentsJoinedByString:@","]];
  }
  
  /* queried something else */
  if ((value = [super lookupName:_name inContext:_ctx acquire:_flag])) {
    if (debugLookup)
      [self debugWithFormat:@"  value from superclass: %@", value];
    return value;
  }
  
  return [self handleMissingName:_name inContext:_ctx];
}

/* security */

- (id)lookupAuthenticatorNamed:(NSString *)_name inContext:(id)_ctx {
  /* look for a "user-folder" (an authentication database) */
  id auth, res;

  if ((auth = [self lookupName:_name inContext:_ctx acquire:NO])==nil)
    return nil;
  
  if (debugAuthLookup)
    [self logWithFormat:@"use '%@' user-folder: %@", _name, auth];
  if (auth == self) {
    if (debugAuthLookup)
      [self logWithFormat:@"  auth recursion detected: %@", auth];
    return nil;
  }
  
  res = [auth authenticatorInContext:_ctx];
  if (debugAuthLookup)
    [self logWithFormat:@"  got authenticator: %@", res];
  if (res == self) {
    if (debugAuthLookup) {
      [self logWithFormat:
	      @"  recursion detected (%@ returned folder): %@, auth: %@", 
	      _name, res, auth];
    }
    return nil;
  }
  else if (res == auth) {
    if (debugAuthLookup) {
      [self logWithFormat:
	      @"  recursion detected (%@ returned auth): %@", 
	      _name, auth];
    }
    return nil;
  }
  return res;
}

- (id)authenticatorInContext:(id)_ctx {
  /* look for a "user-folder" (an authentication database) */
  id auth;
  
  /* the following are flawed and can lead to recursions */
  if ((auth = [self lookupAuthenticatorNamed:@"htpasswd" inContext:_ctx]))
    return auth;
  if ((auth = [self lookupAuthenticatorNamed:@"acl_users" inContext:_ctx]))
    return auth;
  
  // TODO: check children for extensions
  
  if (debugAuthLookup)
    [self logWithFormat:@"no user-folder in folder ..."];
  
  return [super authenticatorInContext:_ctx];
}

- (NSString *)ownerInContext:(id)_ctx {
  NSString *owner;
  
  if ((owner = [self->props objectForKey:@"SoOwner"]))
    return owner;
  
  /* let parent handle my owner */
  return [[self container] ownerOfChild:self inContext:_ctx];
}

- (NSString *)ownerOfChild:(id)_child inContext:(id)_ctx {
  NSDictionary *childOwners;
  NSString *owner;
  
  if ((childOwners = [self->props objectForKey:@"SoChildOwners"])) {
    if ((owner = [childOwners objectForKey:[_ctx nameInContainer]]))
      return owner;
  }
  
  /* let child inherit owner of container */
  return [self ownerInContext:_ctx];
}

/* WO integration */

- (WOResourceManager *)resourceManagerInContext:(id)_ctx {
  if (self->resourceManager == nil) {
    self->resourceManager =
      [[OFSResourceManager alloc] initWithBaseObject:self inContext:_ctx];
  }
  return self->resourceManager;
}

/* version control */

- (void)checkVersionControlSpecials {
  id<NGFileManager> fm;
  NSString *sp, *p;
  BOOL isDir = NO;
  
  if ((fm = [self fileManager]) == nil) return;
  if ((sp = [self storagePath]) == nil) return;
  
  p = [sp stringByAppendingPathComponent:@"CVS"];
  self->flags.hasCVS = [fm fileExistsAtPath:p isDirectory:&isDir]
    ? (isDir ? 1 : 0)
    : 0;
  
  p = [sp stringByAppendingPathComponent:@".svn"];
  self->flags.hasSvn = [fm fileExistsAtPath:p isDirectory:&isDir]
    ? (isDir ? 1 : 0)
    : 0;
  
  self->flags.checkedVersionSpecials = 1;
}
- (BOOL)isCvsControlled {
  if (!self->flags.checkedVersionSpecials)
    [self checkVersionControlSpecials];
  return self->flags.hasCVS;
}
- (BOOL)isSvnControlled {
  if (!self->flags.checkedVersionSpecials)
    [self checkVersionControlSpecials];
  return self->flags.hasSvn;
}

@end /* OFSFolder */

@implementation OFSFolder(Factory)

+ (id)instantiateInFactoryContext:(OFSFactoryContext *)_ctx {
  /* look into plist for class */
  NSDictionary *plist;
  NSData       *content;
  SoClass      *clazz;
  NSString     *plistPath;
  id object;
  
  plistPath = [[_ctx storagePath] 
		     stringByAppendingPathComponent:@".props.plist"];
  content = [[_ctx fileManager] contentsAtPath:plistPath];
  if (content == nil) {
    /* found no plist */
    clazz = [self soClass];
  }
  else {
    /* parse the existing plist file */
    NSString *string;
    NSString *className;
    
    string = [[NSString alloc] initWithData:content
  			     encoding:[NSString defaultCStringEncoding]];
    if (string == nil) {
      [self logWithFormat:@"could not make string for stored data."];
      return [NSException exceptionWithHTTPStatus:500
  			reason:@"stored property list is corrupted"];
    }
    
    if ((plist = [string propertyList]) == nil) {
      [string release];
      [self logWithFormat:@"could not make plist for stored data."];
      return [NSException exceptionWithHTTPStatus:500
  			reason:
  			  @"stored property list is corrupted "
  			  @"(not in plist format)"];
    }
    [string release];
  
    /* lookup the classname in plist */
    
    className = [plist objectForKey:@"SoClassName"];
    if ([className length] == 0) {
      if ((className = [plist objectForKey:@"SoFolderClassName"]))
        [self logWithFormat:
		@"%@: SoFolderClassName is deprecated (use SoClassName) !",
	        plistPath];
    }
    
    if ([className length] == 0) {
      /* no special class assigned, use default */
      clazz = [self soClass];
    }
    else {
      clazz = [[SoClassRegistry sharedClassRegistry] 
		soClassWithName:className];
      if (clazz == nil) {
        [self logWithFormat:@"did not find SoClass: %@", className];
        return nil;
      }
    }
  }
  
  /* instantiate */
  
  if (factoryDebugOn) {
    [self debugWithFormat:@"instantiate child %@ from class %@",
	    [_ctx nameInContainer], clazz];
  }
  
  object = [clazz instantiateObject];
  [object takeStorageInfoFromContext:_ctx];
  return object;
}

@end /* OFSFolder(Factory) */
