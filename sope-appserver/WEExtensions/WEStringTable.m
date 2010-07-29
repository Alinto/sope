/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

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

#include "WEStringTable.h"
#include "common.h"

@implementation WEStringTable

static BOOL debugOn          = NO;
static BOOL useLatin1Strings = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  debugOn          = [ud boolForKey:@"WEStringTableDebugEnabled"];
  useLatin1Strings = [ud boolForKey:@"WEStringTableUseLatin1"];
}

+ (id)stringTableWithPath:(NSString *)_path {
  return [[(WEStringTable *)[self alloc] initWithPath:_path] autorelease];
}

- (id)initWithPath:(NSString *)_path {
  self->path = [_path copyWithZone:[self zone]];
  return self;
}

- (void)dealloc {
  [self->path     release];
  [self->lastRead release];
  [self->data     release];
  [super dealloc];
}

/* loading */

- (NSException *)reportParsingError:(NSException *)_error {
  [self logWithFormat:@"%s: could not load strings file '%@': %@", 
          __PRETTY_FUNCTION__, self->path, _error];
  return nil;
}

- (NSStringEncoding)stringsFileEncoding {
  return useLatin1Strings ? NSISOLatin1StringEncoding : NSUTF8StringEncoding;
}

- (void)checkState {
  NSString     *plistString;
  NSDictionary *plist;
  NSData       *rawData;
  
  if (self->data != nil)
    return;
  
  rawData = [[NSData alloc] initWithContentsOfMappedFile:self->path];
  if (rawData == nil) {
    [self logWithFormat:@"ERROR: could not load strings file: %@", self->path];
    return;
  }
  
  if (debugOn) {
    [self debugWithFormat:@"read strings file %@, len: %d", 
	  self->path, [rawData length]];
  }
  
  plistString = [[NSString alloc] initWithData:rawData 
				  encoding:[self stringsFileEncoding]];
  [rawData release]; rawData = nil;
  if (plistString == nil) {
    [self logWithFormat:@"ERROR: could not decode strings file charset: %@", 
	    self->path];
    return;
  }
  
  if (debugOn) {
    [self debugWithFormat:@"  string len %d, class %@", 
	  [plistString length], NSStringFromClass([plistString class])];
  }
  
  NS_DURING {
    if ((plist = [plistString propertyListFromStringsFileFormat]) == nil) {
      NSLog(@"%s: could not load strings file '%@'",
            __PRETTY_FUNCTION__,
            self->path);
    }
    self->data     = [plist copy];
    self->lastRead = [[NSDate date] retain];
  }
  NS_HANDLER
    [[self reportParsingError:localException] raise];
  NS_ENDHANDLER;

  if (debugOn)
    [self debugWithFormat:@"  parsed entries: %d", [self->data count]];
  
  [plistString release];
}

/* access */

- (NSString *)stringForKey:(NSString *)_key withDefaultValue:(NSString *)_def {
  NSString *value;
  
  [self checkState];
  value = [self->data objectForKey:_key];
  return value ? value : _def;
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

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* WEStringTable */
