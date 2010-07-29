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

#include "SoObject+SoDAV.h"
#include "SoObject.h"
#include "NSException+HTTP.h"
#include "SoDAVLockManager.h"
#include <NGObjWeb/WOApplication.h>
#include "common.h"

/* informal interface for methods tried by the DAV key implementation */

@interface NSObject(SoResourceObject)

- (BOOL)isCollection;
- (NSString *)displayName;
- (NSString *)path;

- (unsigned int)contentLength;
- (EOGlobalID *)globalID;

- (id)baseURL;
- (id)baseURLInContext:(id)_ctx;

@end

@implementation NSObject(SoObjectSoDAVImp)

- (NSArray *)defaultWebDAVPropertyNamesInContext:(id)_ctx {
  // TODO: check for set in SoClass slots
  static NSArray *defNames = nil;
  if (defNames == nil) {
    defNames = [[[NSUserDefaults standardUserDefaults] 
		                 arrayForKey:@"SoDefaultWebDAVPropertyNames"]
		                 copy];
  }
#if 0 /* TODO: check whether this would be better ... */
  keys = [[self soClassDescription] attributeKeys];
  [self debugWithFormat:@"using keys from description: %@", keys];
#endif
  return defNames;
}

- (NSArray *)davComplianceClassesInContext:(id)_ctx {
  /*
    Class 1 is everything in WebDAV which is a MUST.
    
    Class 2 adds the LOCK method, the supportedlock property, the lockdiscovery
    property, the time-out response header and the lock-token request header.
    
    In this method we check that by querying the lock manager. If the object
    has one, it will return class 2, otherwise just class 1.
  */
  static NSArray *class1 = nil, *class2 = nil;
  
  if (class1 == nil)
    class1 = [[NSArray alloc] initWithObjects:@"1", nil];
  if (class2 == nil)
    class2 = [[NSArray alloc] initWithObjects:@"1", @"2", nil];
  
  return ([self davLockManagerInContext:_ctx] != nil)
    ? class2 : class1;
}

- (NSArray *)davAllowedMethodsInContext:(id)_ctx {
  static NSArray *defMethods = nil;
  NSMutableArray *allow;
  
  if (defMethods == nil) {
    defMethods = [[[NSUserDefaults standardUserDefaults] 
                                   arrayForKey:@"SoWebDAVDefaultAllowMethods"] 
                                   copy];
  }
  
  allow = [NSMutableArray arrayWithCapacity:16];
  if (defMethods) [allow addObjectsFromArray:defMethods];
  
  if ([self respondsToSelector:@selector(performWebDAVQuery:inContext:)]) {
    [allow addObject:@"PROPFIND"];
    [allow addObject:@"SEARCH"];
  }
  if ([self respondsToSelector:
	      @selector(davSetProperties:removePropertiesNamed:)])
    [allow addObject:@"PROPPATCH"];
  
  return allow;
}

/* attributes */

- (BOOL)davIsCollection {
  id v;
  
  if ([self respondsToSelector:@selector(isCollection)])
    return [self isCollection];
  if ([(v = [self valueForKey:@"NSFileType"]) isNotNull]) {
    if ([v isEqualToString:NSFileTypeDirectory])
      return YES;
    else
      return NO;
  }
  if ([[self toManyRelationshipKeys] count] > 0)
    return YES;
  if ([[self toOneRelationshipKeys] count] > 0)
    return YES;
  return NO;
}

- (BOOL)davIsFolder {
  return [self davIsCollection];
}

- (BOOL)davHasSubFolders {
  NSEnumerator *e;
  NSString *childName;
  id       ctx;
  
  if (![self davIsCollection]) return NO;
  ctx = [[WOApplication application] context];
  
  e = [self davChildKeysInContext:ctx];
  while ((childName = [e nextObject])) {
    if ([[self lookupName:childName inContext:ctx acquire:NO] davIsFolder])
      return YES;
  }
  return NO;
}

- (BOOL)davDenySubFolders {
  return [self davIsCollection] ? NO : YES;
}

- (unsigned int)davChildCount {
  NSEnumerator *e;
  unsigned int i;
  
  if (![self davIsCollection]) return 0;
  e = [self davChildKeysInContext:[[WOApplication application] context]];
  for (i = 0; [e nextObject]; i++)
    ;
  return i;
}
- (unsigned int)davObjectCount {
  NSEnumerator *e;
  unsigned int i;
  NSString     *childName;
  WOContext    *ctx;
  
  if (![self davIsCollection]) return 0;
  
  ctx = [[WOApplication application] context];
  i = 0;
  e = [self davChildKeysInContext:ctx];
  while ((childName = [e nextObject]) != nil) {
    if (![[self lookupName:childName inContext:ctx acquire:NO]davIsCollection])
      i++;
  }
  return i;
}
- (unsigned int)davVisibleCount {
  return [self davObjectCount];
}

- (BOOL)davIsHidden {
  return NO;
}

- (id)davUid {
  if ([self respondsToSelector:@selector(globalID)])
    return [self globalID];
  return [self davURL];
}
- (id)davEntityTag {
  return nil;
}

- (BOOL)davIsStructuredDocument {
  return NO;
}

- (id)davURL {
  id url;
  
  if ([self respondsToSelector:@selector(baseURLInContext:)]) {
    url = [self baseURLInContext:[[WOApplication application] context]];
  }
  else if ([self respondsToSelector:@selector(baseURL)]) {
    [self logWithFormat:@"object does not respond to baseURLInContext:?"];
    url = [self baseURL];
  }
  else {
    [self warnWithFormat:@"unable to calculate davURL for this object !"];
    url = nil;
  }
  if (url == nil)
    [self warnWithFormat:@"got no davURL for this object !"];
  
  return url;
}

- (NSDate *)davLastModified {
  id v;
  if ((v = [self valueForKey:NSFileModificationDate])) return v;
  return [NSDate date];
}

- (NSDate *)davCreationDate {
  id v;
  if ((v = [self valueForKey:@"NSFileCreationDate"]))  return v;
  if ((v = [self valueForKey:NSFileModificationDate])) return v;
  return nil;
}

- (NSString *)davContentType {
  if ([self davIsFolder]) {
    //return @"x-directory/webdav"; /* this is taken from Nautilus */
    return @"httpd/unix-directory"; /* this is returned by Apache */
  }
  
  return @"application/octet-stream";
}

- (id)davContentLength {
  id v;
  if ((v = [self valueForKey:NSFileSize])) return v;
  if ([self respondsToSelector:@selector(contentLength)])
    return [NSNumber numberWithUnsignedInt:[self contentLength]];
  return 0;
}
- (NSString *)davDisplayName {
  id v = nil;
  
  if ([self respondsToSelector:@selector(displayName)])
    return [self displayName];
#if COCOA_Foundation_LIBRARY
  NS_DURING /* handle query for unbound key is easily triggered ... */
    if ((v = [self valueForKey:@"NSFileSubject"])) ;
    else if ((v = [self valueForKey:@"NSFileName"])) ;
    else if ((v = [self valueForKey:@"NSFilePath"])) ;
  NS_HANDLER
    v = nil;
  NS_ENDHANDLER;
#else
  if ((v = [self valueForKey:@"NSFileSubject"])) return v;
  if ((v = [self valueForKey:@"NSFileName"])) return v;
  if ((v = [self valueForKey:@"NSFilePath"])) return [v lastPathComponent];
#endif
  if ([self respondsToSelector:@selector(path)])
    return [[self path] lastPathComponent];
  return nil;
}

- (NSString *)davResourceType {
  if ([self davIsCollection])
    return @"collection";
  return nil;
}

- (NSString *)davContentClass {
  /* this doesn't return something really useful, override if necessary ! */
  return ([self davIsFolder])
    ? @"urn:content-classes:folder"
    : @"urn:content-classes:item";
}

- (BOOL)davIsExecutable {
  return NO;
}

/* lock manager */

- (SoDAVLockManager *)davLockManagerInContext:(id)_ctx {
  return [SoDAVLockManager sharedLockManager];
}

@end /* NSObject(SoObjectSoDAV) */

@interface WOCoreApplication(Resources)
+ (NSString *)findNGObjWebResource:(NSString *)_name ofType:(NSString *)_ext;
@end

@implementation NSObject(SoObjectDAVMaps)

+ (id)defaultWebDAVAttributeMap {
  static NSDictionary *defMap = nil;
  if (defMap == nil) {
    NSString *path;
    
    path = [WOApplication findNGObjWebResource:@"DAVPropMap" ofType:@"plist"];
    if (path != nil) {
      defMap = [[NSDictionary alloc] initWithContentsOfFile:path];
      if (defMap == nil)
	NSLog(@"could not parse plist file: %@", path);
    }
  }
  return defMap;
}

- (id)davAttributeMapInContext:(id)_ctx {
  /* default is: do map some DAV properties, pass through anything else */
  return [[self class] defaultWebDAVAttributeMap];
}

@end /* NSObject(SoObjectDAVMaps) */

#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WORequestHandler.h>

@implementation WOCoreApplication(WebDAV)

- (BOOL)davIsCollection {
  return YES;
}
- (BOOL)davHasSubFolders {
  return YES;
}
- (id)davUid {
  return [self davURL];
}
- (id)davURL {
  return [self baseURL];
}
- (NSDate *)davLastModified {
  return [NSDate date];
}
- (NSDate *)davCreationDate {
  return nil;
}
- (NSString *)davContentType {
  return @"text/html";
}
- (id)davContentLength {
  return 0;
}
- (NSString *)davDisplayName {
  return @"ROOT";
}

@end /* WOCoreApplication(WebDAV) */

@implementation WOApplication(WebDAV)

- (NSString *)davDisplayName {
  return [self name];
}

@end /* WOApplication(WebDAV) */

@implementation WORequestHandler(WebDAV)

- (BOOL)davIsCollection {
  return YES;
}
- (BOOL)davHasSubFolders {
  return YES;
}

- (id)davUid {
  return [self davURL];
}

- (NSDate *)davLastModified {
  return [NSDate date];
}
- (NSDate *)davCreationDate {
  return nil;
}

- (NSString *)davContentType {
  return @"text/html";
}

- (id)davContentLength {
  return 0;
}

@end /* WORequestHandler(WebDAV) */

#include "SoControlPanel.h"

@implementation SoControlPanel(WebDAV)

- (BOOL)davIsCollection {
  return YES;
}
- (BOOL)davHasSubFolders {
  return YES;
}

- (id)davUid {
  return [self davURL];
}

- (NSDate *)davLastModified {
  return [NSDate date];
}
- (NSDate *)davCreationDate {
  return nil;
}

- (id)davContentLength {
  return 0;
}

@end /* SoControlPanel(WebDAV) */

@implementation NSObject(DavOperations)

- (NSException *)davSetProperties:(NSDictionary *)_setProps
  removePropertiesNamed:(NSArray *)_delProps
  inContext:(id)_ctx
{
  return [NSException exceptionWithHTTPStatus:405 /* not allowed */
                      reason:@"this object cannot edit object properties "
                      @"via WebDAV"];
}

- (id)davCreateObject:(NSString *)_name
  properties:(NSDictionary *)_props
  inContext:(id)_ctx
{
  return [NSException exceptionWithHTTPStatus:405 /* not allowed */
                      reason:@"this object cannot create child objects "
                      @"via WebDAV"];
}

- (NSException *)davCreateCollection:(NSString *)_name inContext:(id)_ctx {
  return [NSException exceptionWithHTTPStatus:405 /* not allowed */
                      reason:@"this object cannot create subcollections "
                      @"via WebDAV"];
}

- (NSException *)davMoveToTargetObject:(id)_target newName:(NSString *)_name
  inContext:(id)_ctx
{
  return [NSException exceptionWithHTTPStatus:405 /* not allowed */
                      reason:@"this object cannot be moved via WebDAV"];
}

- (NSException *)davCopyToTargetObject:(id)_target newName:(NSString *)_name
  inContext:(id)_ctx
{
  return [NSException exceptionWithHTTPStatus:405 /* not allowed */
                      reason:@"this object cannot be copied via WebDAV"];
}

@end /* NSObject(DavOperations) */
