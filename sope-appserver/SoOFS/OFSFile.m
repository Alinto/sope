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

#include "OFSFile.h"
#include "OFSFolder.h"
#include "OFSFactoryContext.h"
#include "OFSFileRenderer.h"
#include <NGObjWeb/WOResponse.h>
#include "common.h"

@implementation OFSFile

+ (int)version {
  return [super version] + 0 /* v1 */;
}
+ (void)initialize {
  static BOOL didInit = NO;
  if (!didInit) {
    didInit = YES;
    NSAssert2([super version] == 1,
	      @"invalid superclass (%@) version %i !",
	      NSStringFromClass([self superclass]), [super version]);
  }
}

- (void)dealloc {
  [self->attrCache release];
  [super dealloc];
}

/* accessors */

- (BOOL)isCollection {
  return NO;
}
- (BOOL)hasChildren {
  return NO;
}

- (NSStringEncoding)contentEncoding {
  return [NSString defaultCStringEncoding];
}

- (NSString *)contentAsString {
  NSData   *data;
  NSString *s;
  
  if ((data = [[self fileManager] contentsAtPath:[self storagePath]]) == nil)
    return nil;
  
  s = [[NSString alloc] initWithData:data encoding:[self contentEncoding]];
  return [s autorelease];
}

/* writing content */

- (NSException *)writeState:(id)_value {
  // TODO: better name: -writeContent:?
  NSData *data;
  id fm;
  
  if (_value == nil) {
    return [NSException exceptionWithHTTPStatus:500
			reason:@"missing value to write !"];
  }
  
  // TODO: could support some more objects ?
  if ([_value isKindOfClass:[NSData class]])
    data = _value;
  else
    data = [[_value stringValue] dataUsingEncoding:[self contentEncoding]];
  
  fm = [self fileManager];
  if (![fm writeContents:data atPath:[self storagePath]]) {
    if ([fm respondsToSelector:@selector(lastException)]) {
      NSException *e = [fm lastException];
      [self logWithFormat:@"write of %i bytes failed: %@", [data length], e];
      return e;
    }
    
    return [NSException exceptionWithHTTPStatus:500
			reason:@"could not write content, reason unknown"];
  }
  
  return nil; /* nil is OK */
}

/* attributes */

- (NSDictionary *)fileAttributes {
  id fm;
  
  if ((fm = [self fileManager]) == nil)
    return nil;
  if (self->attrCache == nil) {
    self->attrCache =
      [[fm fileAttributesAtPath:[self storagePath] traverseLink:NO] copy];
  }
  return self->attrCache;
}

/* KVC */

- (BOOL)allowAccessToFileAttribute:(NSString *)_name {
  return YES;
}

- (id)valueForKey:(NSString *)_name {
  unsigned nl;
  unichar  c;
  
  if ((nl = [_name length]) == 0)
    return nil;
  
  c = [_name characterAtIndex:0];
  if (c == 'N' && (nl > 6)) {
    if ([_name hasPrefix:@"NSFile"]) {
      if ([self allowAccessToFileAttribute:_name])
	return [[self fileAttributes] objectForKey:_name];
    }
  }
  
  return [super valueForKey:_name];
}

/* operations */

- (NSString *)contentTypeInContext:(WOContext *)_ctx {
  NSString *ext, *type;
  
  type = nil;
  if ((ext = [[self nameInContainer] pathExtension])) {
    // TODO: read /etc/mime.types
    if ([ext isEqualToString:@"html"])       type = @"text/html";
    else if ([ext isEqualToString:@"xhtml"]) type = @"text/xhtml";
    else if ([ext isEqualToString:@"gif"])   type = @"image/gif";
    else if ([ext isEqualToString:@"png"])   type = @"image/png";
  }
  return type != nil ? type : (NSString *)@"application/octet-stream";
}

- (id)davContentLength {
  return [[self fileAttributes] objectForKey:NSFileSize];
}
- (NSDate *)davLastModified {
  return [[self fileAttributes] objectForKey:NSFileModificationDate];
}

- (id)rendererForObject:(id)_object inContext:(WOContext *)_ctx {
  return nil;
}

- (id)viewAction:(WOContext *)_ctx {
  return self;
}
- (id)GETAction:(WOContext *)_ctx {
  return self;
}
- (id)HEADAction:(WOContext *)_ctx {
  return self;
}

- (id)PUTAction:(WOContext *)_ctx {
  NSException *e;
  NSData *content;
  
  if ((e = [self validateForSave])) {
    [self debugWithFormat:@"object did not validate for save ..."];
    return e;
  }
  
  if ((content = [[_ctx request] content]) == nil)
    content = [NSData data];
  
  if ((e = [self writeState:content]))
    return e;
  
  return self;
}

/* version control */

- (BOOL)isCvsControlled {
  return [[self container] isCvsControlled];
}
- (BOOL)isSvnControlled {
  return [[self container] isSvnControlled];
}

/* factory */

+ (id)instantiateInFactoryContext:(OFSFactoryContext *)_ctx {
  id object;
  
  object = [[self soClass] instantiateObject];
  [object takeStorageInfoFromContext:_ctx];
  return object;
}

@end /* OFSFile */
