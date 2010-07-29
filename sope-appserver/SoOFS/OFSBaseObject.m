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

#include "OFSBaseObject.h"
#include "OFSFactoryContext.h"
#include "OFSFolder.h"
#include "common.h"

@implementation OFSBaseObject

+ (int)version {
  return 1;
}

- (void)dealloc {
  [self detachFromContainer];
  [self->name        release];
  [self->fileManager release];
  [self->storagePath release];
  [self->soClass     release];
  [super dealloc];
}

/* awake */

- (NSException *)takeStorageInfoFromContext:(OFSFactoryContext *)_ctx {
  self->fileManager = [[_ctx fileManager] retain];
  self->storagePath = [[_ctx storagePath] copy];
  [self setContainer:[_ctx container] andName:[_ctx nameInContainer]];
  return nil;
}

- (id)awakeFromFetchInContext:(OFSFactoryContext *)_ctx {
  if (self->fileManager == nil || self->storagePath == nil)
    [self logWithFormat:@"WARNING: object has no storage info !"];
  
  return self;
}
- (id)awakeFromInsertionInContext:(OFSFactoryContext *)_ctx {
  self->fileManager = [[_ctx fileManager] retain];
  self->storagePath = [[_ctx storagePath] copy];
  [self setContainer:[_ctx container] andName:[_ctx nameInContainer]];
  return self;
}

/* accessors */

- (SoClass *)soClass {
  if (self->soClass == nil)
    return [super soClass];
  return self->soClass;
}

- (id<NSObject,NGFileManager>)fileManager {
  return self->fileManager;
}
- (NSString *)storagePath {
  return self->storagePath;
}
- (EOGlobalID *)globalID {
  return [[self fileManager] globalIDForPath:[self storagePath]];
}

- (BOOL)isCollection {
  return NO;
}
- (BOOL)hasChildren {
  return [self isCollection];
}
- (BOOL)doesExist {
  return [[self fileManager] fileExistsAtPath:[self storagePath]];
}

/* containment */

- (id)container {
  return self->container;
}
- (NSString *)nameInContainer {
  return self->name;
}
- (void)setContainer:(id)_container andName:(NSString *)_name {
  self->container = _container;
  ASSIGNCOPY(self->name, _name);
}

/* operations */

- (void)detachFromContainer {
  self->container = nil;
  [self->name release]; self->name = nil;
}
- (BOOL)isAttachedToContainer {
  return self->container ? YES : NO;
}

- (id)DELETEAction:(id)_ctx {
  NSException *e;
  id fm;
  
  if ((e = [self validateForDelete]))
    return e;
  
  if ((fm = [self fileManager]) == nil) {
    [self logWithFormat:@"missing filemanager for delete."];
    return [NSException exceptionWithHTTPStatus:500 /* server error */
			reason:@"missing filemanager for object ?!"];
  }
  
  if (![self doesExist])
    return [NSException exceptionWithHTTPStatus:404 /* not found */];
  
  if ([fm removeFileAtPath:[self storagePath] handler:nil])
    /* nil means "everything OK" ;-) [for the WebDAV renderer] */
    return [NSNumber numberWithBool:YES];
  
  if ([fm respondsToSelector:@selector(lastException)])
    return [fm lastException];
  
  return [NSException exceptionWithHTTPStatus:500 /* server error */
		      reason:@"filemanager couldn't remove file at path."];
}

/* KVC */

- (id)handleQueryWithUnboundKey:(NSString *)key {
  // TODO: any drawbacks when doing this ?
  return nil;
}

- (id)valueForKey:(NSString *)_name {
  /* map out some very private keys */
  unsigned nl;
  unichar  c;
  
  if ((nl = [_name length]) == 0)
    return nil;
  
  c = [_name characterAtIndex:0];
  if ((c == 's') && (nl == 11)) {
    if ([_name isEqualToString:@"storagePath"])
      /* do not allow KVC access to storage path */
      return nil;
  }
  else if ((c == 'f') && (nl == 11)) {
    if ([_name isEqualToString:@"fileManager"])
      /* do not allow KVC access to filemanager */
      return nil;
  }
  
  return [super valueForKey:_name];
}

/* key validations */

- (NSException *)validateForDelete {
  return nil;
}
- (NSException *)validateForInsert {
  return nil;
}
- (NSException *)validateForUpdate {
  return nil;
}
- (NSException *)validateForSave {
  return nil;
}

/* WebDAV */

- (NSString *)davDisplayName {
  NSString *s;
  if ((s = [self valueForKey:@"NSFileSubject"])) return s;
  return [self nameInContainer];
}
- (id)davLastModified {
  return [self valueForKey:NSFileModificationDate];
}

/* schema */

- (NSClassDescription *)soClassDescription {
  return nil;
}

/* security */

- (NSString *)ownerInContext:(id)_ctx {
  /* ask container ... */
  id c;
  
  if ((c = [self container]) == nil)
    return nil;

  if ([c respondsToSelector:@selector(ownerOfChild:inContext:)])
    return [c ownerOfChild:self inContext:_ctx];

  if (c == self)
    /* avoid endless recursion ... */
    return nil;

  return [c ownerInContext:_ctx];
}

- (id)authenticatorInContext:(id)_ctx {
  /* ask container ... */
  id lContainer;
  
  if ((lContainer = [self container]) == nil)
    return nil;

  if (lContainer == self)
    /* avoid endless recursion ... */
    return nil;

  return [lContainer authenticatorInContext:_ctx];
}

/* version control */

- (BOOL)isCvsControlled {
  return NO;
}
- (BOOL)isSvnControlled {
  return NO;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
#if DEBUG
  return YES;
#else
  return NO;
#endif
}
- (NSString *)loggingPrefix {
  /* improve perf ... */
  NSString *n = [self nameInContainer];
  return [NSString stringWithFormat:@"0x%p[%@]:%@",
		     self, NSStringFromClass([self class]),
		     n != nil ? n : (NSString *)@"ROOT"];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  if (self->storagePath) 
    [ms appendFormat:@" path=%@", self->storagePath];
  
  [ms appendString:@">"];
  return ms;
}

@end /* OFSBaseObject */
