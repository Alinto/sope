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

#include "_WOStringTable.h"
#include "common.h"

@implementation _WOStringTable

static NSStringEncoding stringFilesEncoding = NSUTF8StringEncoding;

- (id)initWithPath:(NSString *)_path {
  if ((self = [super init])) {
    self->path = [_path copyWithZone:[self zone]];
  }
  return self;
}
- (id)init {
  return [self initWithPath:nil];
}

- (void)dealloc {
  [self->path     release];
  [self->lastRead release];
  [self->data     release];
  [super dealloc];
}

/* loading */

- (NSException *)_handlePropertyListParseException:(NSException *)_exception {
  [self logWithFormat:@"could not load strings file file '%@': %@",
          self->path, _exception];
  self->data = nil;
  return nil;
}

- (void)checkState {
  NSString     *tmp;
  NSDictionary *plist;
  NSData       *sdata;
  
  if (self->data != nil)
    return;

#if 0
#if Cocoa_FOUNDATION_LIBRARY /* potentially effects OGo ;-) */
  /*
    For WO4.5 compatibility, we need first to try to open .strings file as a 
    dictionary
    Dictionary must be either in UTF-8 or UTF-16 encoding.
    If we don't do that, then a dict in UTF-8 encoding will be opened as a 
    dict using defaultCString encoding
  */
  plist = [NSDictionary dictionaryWithContentsOfFile:self->path];
  if (plist != nil) {
    self->data = [plist copy];
    return;
  }
#endif
#endif

  /* If file was not a dictionary, then it's a standard strings file */
  
  if ((sdata = [[NSData alloc] initWithContentsOfFile:self->path]) == nil) {
    [self errorWithFormat:@"could not read strings file: %@", self->path];
    self->data = nil;
    return;
  }
  
  tmp = [[NSString alloc] initWithData:sdata encoding:stringFilesEncoding];
  [sdata release]; sdata = nil;
  if (tmp == nil) {
    [self errorWithFormat:@"file is not in required encoding (%d): %@",
            stringFilesEncoding, self->path];
    self->data = nil;
    return;
  }
  
  NS_DURING {
    if ((plist = [tmp propertyListFromStringsFileFormat]) == nil) {
      [self errorWithFormat:@"%s: could not load strings file '%@'",
              __PRETTY_FUNCTION__,
              self->path];
    }
    [tmp release]; tmp = nil;
    self->data = [plist copy];
  }
  NS_HANDLER {
    [tmp release]; tmp = nil;
    [[self _handlePropertyListParseException:localException] raise];
  }
  NS_ENDHANDLER;
}

/* access */

- (NSString *)stringForKey:(NSString *)_key withDefaultValue:(NSString *)_def {
  NSString *value;
  
  [self checkState];
  value = [self->data objectForKey:_key];
  return value != nil ? value : _def;
}

/* fake being a dictionary */

- (NSEnumerator *)keyEnumerator {
  [self checkState];
  return [self->data keyEnumerator];
}
- (NSEnumerator *)objectEnumerator {
  [self checkState];
  return [self->data objectEnumerator];
}
- (id)objectForKey:(id)_key {
  [self checkState];
  return [self->data objectForKey:_key];
}
- (unsigned int)count {
  [self checkState];
  return [self->data count];
}
- (NSArray *)allKeys {
  [self checkState];
  return [self->data allKeys];
}
- (NSArray *)allValues {
  [self checkState];
  return [self->data allValues];
}

/* KVC */

- (id)valueForKey:(NSString *)_key {
  return [self objectForKey:_key];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]: ", self, NSStringFromClass([self class])];
  
  if (self->path)     [ms appendFormat:@" path='%@'",   self->path];
  if (self->data)     [ms appendFormat:@" strings=#%d", [self->data count]];
  if (self->lastRead) [ms appendFormat:@" loaddate=%@", self->lastRead];
  
  [ms appendString:@">"];
  return ms;
}
  
@end /* _WOStringTable */
