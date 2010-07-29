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

#include "OFSPropertyListObject.h"
#include "OFSFactoryContext.h"
#include <WebDAV/SoObject+SoDAV.h>
#include "common.h"

@interface OFSPropertyListObjectClassDescription : NSClassDescription
{
@public
  OFSPropertyListObject *object;
}

@end

@implementation OFSPropertyListObject

static int debugOn = 0;

+ (int)version {
  return [super version] + 0 /* v1 */;
}
+ (void)initialize {
  static BOOL didInit = NO;
  if (!didInit) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    didInit = YES;
    NSAssert2([super version] == 1,
	      @"invalid superclass (%@) version %i !",
	      NSStringFromClass([self superclass]), [super version]);
    
    debugOn = [ud boolForKey:@"SoOFSDebugPlistObject"] ? 1 : 0;
  }
}

- (void)dealloc {
  [self->recordKeys release];
  [self->record     release];
  [super dealloc];
}

/* storage */

- (NSStringEncoding)stringEncoding {
  return [NSString defaultCStringEncoding];
}

- (void)setSoResourceClassName:(NSString *)_name {} // ignore
- (void)setSoClassName:(NSString *)_name         {} // ignore
- (NSString *)soResourceClassName { // deprecated
  return [[self soClass] className];
}
- (NSString *)soClassName {
  return [[self soClass] className];
}

- (NSArray *)attributeKeys {
  [[self restoreObject] raise];
  return self->recordKeys;
}

- (NSArray *)allKeys {
  return [self attributeKeys];
}

- (NSClassDescription *)soClassDescription {
  OFSPropertyListObjectClassDescription *cd;
  cd = [[OFSPropertyListObjectClassDescription alloc] init];
  cd->object = [self retain];
  return [cd autorelease];
}

- (NSString *)contentAsString {
  /* do not allow access to raw contents ! */
  return nil;
}

- (void)removeSpecialKeysFromRestoreDictionary:(NSMutableDictionary *)_md {
  /* remove special storage keys like SoClassName to plist */
  [_md removeObjectForKey:@"SoClassName"];
  [_md removeObjectForKey:@"SoResourceClassName"];
}
- (void)addSpecialKeysToSaveDictionary:(NSMutableDictionary *)_md {
  /* add special storage keys like SoClassName to plist */
  [_md setObject:[self soClassName] forKey:@"SoClassName"];
}

- (NSException *)restoreObject {
  NSMutableDictionary *plist = nil;
  NSException *e;
  NSData      *content;
  NSString    *s;
  id fm;
  
  if (self->flags.isLoaded) return nil;
  if ((fm = [self fileManager]) == nil) {
    e = [NSException exceptionWithHTTPStatus:500
                     reason:@"plist object has no filemanager ??"];
    return e;
  }
  s = [self storagePath];
  if ([s length] == 0) {
    e = [NSException exceptionWithHTTPStatus:500
                     reason:@"plist object has no storage path ??"];
    return e;
  }
  
  self->flags.isLoading = 1;
  self->flags.isLoaded  = 1;
  e = nil;
  
  /* load file, convert into string, then into a property list */
  
  if ((content = [fm contentsAtPath:s])==nil) {
    if (([fm respondsToSelector:@selector(lastException)])) {
      e = [fm lastException];
      goto done;
    }
    else {
      e = [NSException exceptionWithHTTPStatus:404 /* not found */
		       reason:@"failed to load property list file ..."];
      goto done;
    }
  }
  s = [[NSString alloc] initWithData:content encoding:[self stringEncoding]];
  if (s == nil) {
    e = [NSException exceptionWithHTTPStatus:500
		     reason:@"failed to create string from file ..."];
    goto done;
  }
  plist = [[s propertyList] mutableCopy];
  [s release];
  if (plist == nil) {
    e = [NSException exceptionWithHTTPStatus:500
		     reason:@"failed to create property list from file ..."];
    goto done;
  }
  
  [self removeSpecialKeysFromRestoreDictionary:plist];
  
  self->recordKeys = [[plist allKeys] copy];
  if (debugOn)
    [self debugWithFormat:@"taking values of: %@", plist];
  [self takeValuesFromDictionary:plist];
  [plist release];
  
 done:
  self->flags.isEdited  = 0;
  self->flags.isLoading = 0;
  return e;
}

- (void)willChange {
  if (!self->flags.isLoading)
    self->flags.isEdited = 1;
}
- (BOOL)isRestored {
  return self->flags.isLoaded ? YES : NO;
}

- (NSException *)saveObject {
  NSMutableDictionary *d;
  NSException  *e;
  NSString     *s;
  NSData       *content;
  id           fm;
  
  e = (self->flags.isNew)
    ? [self validateForInsert]
    : [self validateForSave];
  if (e) return e;
  
  if (!self->flags.isNew) {
    if ((e = [self restoreObject]))
      return e;
  }
  
  d = (self->recordKeys)
    ? [[self valuesForKeys:self->recordKeys] mutableCopy]
    : [self->record mutableCopy];
  
  if (d == nil) {
    [self logWithFormat:@"got no dict to save ..."];
    return [NSException exceptionWithHTTPStatus:500
			reason:@"got no record to save ..."];
  }
  
  [self addSpecialKeysToSaveDictionary:d];
  
  s = [d description];
  [d release];
  
  content = [s dataUsingEncoding:[self stringEncoding]];
  
  fm = [self fileManager];
  
  if (![fm writeContents:content atPath:[self storagePath]]) {
    [self logWithFormat:@"failed to update file: %@", [self storagePath]];
    
    if (([fm respondsToSelector:@selector(lastException)]))
      return [fm lastException];
    else {
      return [NSException exceptionWithHTTPStatus:500
			  reason:@"failed to update property list file ..."];
    }
  }
  
  self->flags.isNew = 0;
  return nil;
}

/* KVC */

- (void)handleTakeValue:(id)_value forUnboundKey:(NSString *)_key {
  id oldValue;
  
  if ((oldValue = [self->record objectForKey:_key]) == nil) {
    if (_value == nil) return;
  }
  else if (![_value isNotNull]) {
    [self willChange];
    [self->record removeObjectForKey:_key];
    return;
  }
  else if (oldValue == _value) {
    return;
  }
  else if ([oldValue isEqual:_value])
    return;
  
  [self willChange];
  
  if (self->record == nil)
    self->record = [[NSMutableDictionary alloc] initWithCapacity:16];
  
  if (!self->flags.isLoading && debugOn)
    [self debugWithFormat:@"set unbound key: %@", _key];
  
  if (![self->recordKeys containsObject:_key]) {
    NSMutableArray *rk;
    
    rk = [self->recordKeys mutableCopy];
    [rk addObject:_key];
    [self->recordKeys release];
    self->recordKeys = rk;
  }
  
  [self->record setObject:(_value ? _value: (id)@"") forKey:_key];
}

- (BOOL)isStoredKey:(NSString *)_key {
  /* says whether we need to restore the object to access the key */
  if ([_key hasPrefix:@"NS"]) {
    if ([_key isEqualToString:@"NSFileSubject"])
      return YES;
    return NO;
  }
  return YES;
}

- (void)takeValue:(id)_value forKey:(NSString *)_name {
  if (!self->flags.isLoaded && !self->flags.isLoading) {
    if ([self isStoredKey:_name])
      [[self restoreObject] raise];
  }
  
  [super takeValue:_value forKey:_name];
}

- (id)valueForKey:(NSString *)_name {
  id v = nil;
  
  if ([_name hasPrefix:@"NS"]) {
    if ([_name isEqualToString:@"NSFileSize"])
      v = [self davContentLength];
    else if ([_name isEqualToString:@"NSFileSubject"])
      v = [self davDisplayName];
    else
      /* this implies that stored keys never begin with NS ! (good ?) */
      v = [super valueForKey:_name];
  }
  else if ([self isStoredKey:_name]) {
    if ((v = [self restoreObject]))
      /* v is the restoration exception, do not want to raise */;
    else if ((v = [self->record objectForKey:_name]))
      /* a record value */;
    else
      /* stored-key doesn't say *where* it is stored ! */
      v = [super valueForKey:_name];
  }
  else
    v = [super valueForKey:_name];
  
  return v;
}

/* operations */

- (id)GETAction:(WOContext *)_ctx {
  NSException *e;
  
  if ((e = [self restoreObject]))
    return e;
  
  /* let the renderer deal with our representation ... */
  return self;
}

- (id)PUTAction:(WOContext *)_ctx {
  return [NSException exceptionWithHTTPStatus:405 /* method not allowed */
		      reason:@"HTTP PUT not yet allowed on plist objects"];
}

/* WebDAV support */

- (NSString *)davDisplayName {
  return [[self nameInContainer] stringByDeletingPathExtension];
}
- (id)davContentLength {
  static NSNumber *zero = nil;
  if (zero == nil) zero = [[NSNumber numberWithInt:0] retain];
  return zero;
}

- (NSException *)davSetProperties:(NSDictionary *)_setProps
  removePropertiesNamed:(NSArray *)_delProps 
  inContext:(id)_ctx
{
  NSException *e;
  
  if (debugOn)
    [self debugWithFormat:@"patch: %@, del: %@", _setProps, _delProps];
  
  if ((e = [self restoreObject]))
    return e;
  
  if ([_setProps count] > 0)
    [self takeValuesFromDictionary:_setProps];
  
  if ([_delProps count] > 0) {
    NSMutableArray *rk;
    
    [self->record removeObjectsForKeys:_delProps];
    rk = [self->recordKeys mutableCopy];
    [rk removeObjectsInArray:_delProps];
    [self->recordKeys release];
    self->recordKeys = rk;
  }
  
  if ((e = [self saveObject])) {
    [self logWithFormat:@"update failed ..."];
    return e;
  }
  
  return nil;
}

/* factory */

+ (id)instantiateInFactoryContext:(OFSFactoryContext *)_ctx {
  /* look into plist for class */
  NSException  *e;
  OFSPropertyListObject *object;
  SoClass      *clazz;
  
  if ([_ctx isNewObject]) {
    /* create a new object in the storage */
    clazz = [self soClass];
    
    /* instantiate */
    if (debugOn) {
      [self debugWithFormat:@"instantiate child %@ from class %@",
  	    [_ctx nameInContainer], clazz];
    }
    
    object = [clazz instantiateObject];
    [object takeStorageInfoFromContext:_ctx];
    
    if ([object isKindOfClass:[OFSPropertyListObject class]])
      object->flags.isNew = 1;

    if ((e = [object saveObject])) {
      [self debugWithFormat:@"  save failed: %@", e];
      return e;
    }
  }
  else {
    /* restore object from storage */
    NSDictionary *plist;
    NSData       *content;
    NSString     *string;
    NSString     *className;
    
    content = [[_ctx fileManager] contentsAtPath:[_ctx storagePath]];
    if (content == nil)
      /* hm, file doesn't exist ? */
      return [super instantiateInFactoryContext:_ctx];
    
    /* parse the existing plist file */
    
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
    if ([className length] == 0)
      /* no special class assigned, use default */
      clazz = [self soClass];
    else {
      clazz = [[SoClassRegistry sharedClassRegistry] soClassWithName:className];
      if (clazz == nil) {
        [self logWithFormat:@"did not find SoClass: %@", className];
        return nil;
      }
    }
    
    /* instantiate */
    
    if (debugOn) {
      [self debugWithFormat:@"instantiate child %@ from class %@",
  	    [_ctx nameInContainer], clazz];
    }
    
    object = [clazz instantiateObject];
    [object takeStorageInfoFromContext:_ctx];
    
    /* restore */
    
    if (debugOn) {
      [self debugWithFormat:@"restore child %@: %@",
  	    [_ctx nameInContainer], object];
    }
    
    if ((e = [object restoreObject])) {
      [self debugWithFormat:@"  restore failed: %@", e];
      return e;
    }
  }  
  return object;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn ? YES : NO;
}

@end /* OFSPropertyListObject */

@implementation OFSPropertyListObjectClassDescription

- (void)dealloc {
  [self->object release];
  [super dealloc];
}

- (NSArray *)attributeKeys {
  return [self->object attributeKeys];
}

@end /* OFSPropertyListObjectClassDescription */
