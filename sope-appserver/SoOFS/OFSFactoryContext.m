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

#include "OFSFactoryContext.h"
#include "OFSFolder.h"
#include "common.h"

@implementation OFSFactoryContext

+ (OFSFactoryContext *)contextForChild:(NSString *)_name
  storagePath:(NSString *)_sp
  ofFolder:(OFSFolder *)_folder
{
  OFSFactoryContext *ctx;
  
  ctx = [[self alloc] init];
  ctx->fileManager = [[_folder fileManager] retain];
  ctx->storagePath = [_sp copy];
  ctx->container   = [_folder retain];
  ctx->name        = [_name copy];
  return [ctx autorelease];
}
+ (OFSFactoryContext *)contextForNewChild:(NSString *)_name
  storagePath:(NSString *)_sp
  ofFolder:(OFSFolder *)_folder
{
  OFSFactoryContext *ctx;
  
  if ((ctx = [self contextForChild:_name storagePath:_sp ofFolder:_folder])) {
    ctx->isNewObject = YES;
  }
  return ctx;
}

+ (OFSFactoryContext *)contextWithFileManager:(id<NSObject,NGFileManager>)_fm
  storagePath:(NSString *)_sp
{
  OFSFactoryContext *ctx;
  
  ctx = [[self alloc] init];
  ctx->fileManager = [_fm retain];
  ctx->storagePath = [_sp copy];
  return [ctx autorelease];
}

- (void)dealloc {
  [self->fileType    release];
  [self->mimeType    release];
  [self->fileManager release];
  [self->container   release];
  [self->name        release];
  [self->storagePath release];
  [super dealloc];
}

/* accessors */

- (id<NSObject,NGFileManager>)fileManager {
  return self->fileManager;
}
- (NSString *)storagePath {
  return self->storagePath;
}
- (id)container {
  return self->container;
}
- (NSString *)nameInContainer {
  return self->name;
}

- (NSString *)fileType {
  return self->fileType;
}
- (NSString *)mimeType {
  return self->mimeType;
}

- (BOOL)isNewObject {
  return self->isNewObject;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  if (self->isNewObject)
    [ms appendString:@" NEW"];
  if (self->name)        [ms appendFormat:@" create=%@", self->name];
  if (self->container)   [ms appendFormat:@" in=%@",   self->container];
  if (self->fileType)    [ms appendFormat:@" type=%@", self->fileType];
  if (self->mimeType)    [ms appendFormat:@" mime=%@", self->mimeType];
  if (self->storagePath) [ms appendFormat:@" path=%@", self->storagePath];
  
  [ms appendString:@">"];
  return ms;
}

@end /* OFSFactoryContext */
