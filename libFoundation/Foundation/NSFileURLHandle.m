/* 
   NSFileURLHandle.m

   Copyright (C) 2000 MDlink GmbH, Helge Hess
   All rights reserved.

   Author: Helge Hess <helge.hess@mdlink.de>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#include "NSFileURLHandle.h"
#include <Foundation/NSURL.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSData.h>
#include <Foundation/NSException.h>

@implementation NSFileURLHandle

+ (BOOL)canInitWithURL:(NSURL *)_url
{
    return [_url isFileURL];
}

- (id)initWithURL:(NSURL *)_url cached:(BOOL)_flag
{
    NSAssert([_url isFileURL],
             @"file handle can only load 'file' URLs (%@)", _url);
    self->path      = [[_url path] copy];
    self->cacheData = _flag;
    return self;
}

- (void)dealloc
{
    RELEASE(self->data);
    RELEASE(self->path);
    RELEASE(self->props);
    [super dealloc];
}

/* path */

- (NSString *)filePath
{
    return self->path;
}
- (NSFileManager *)fileManager
{
    return [NSFileManager defaultManager];
}

/* loading */

- (NSData *)loadInForeground
{
    NSData *ldata;
    
    RELEASE(self->data); self->data = nil;
    
    ldata = [NSData dataWithContentsOfFile:[self filePath]];
    
    self->status = (ldata)
        ? NSURLHandleLoadSucceeded
        : NSURLHandleLoadFailed;

    if (self->cacheData)
        self->data = RETAIN(ldata);
    
    return ldata;
}
- (NSURLHandleStatus)status
{
    return self->status;
}

/* reading data */

- (NSData *)resourceData
{
    if (self->cacheData && (self->data != nil))
        return self->data;

    return [self loadInForeground];
}
- (void)flushCachedData
{
    self->status = NSURLHandleNotLoaded;
    RELEASE(self->props); self->props = nil;
    RELEASE(self->data);  self->data  = nil;
}

/* writing data */

- (BOOL)writeData:(NSData *)_data
{
    if (_data == nil)
        return YES;

    return [_data writeToFile:[self filePath] atomically:YES];
}

/* properties */

- (id)propertyForKey:(NSString *)_propertyKey
{
    if (self->props == nil) {
        self->props = [[[self fileManager]
                              fileAttributesAtPath:[self filePath]
                              traverseLink:YES]
                              copy];
    }
    return [self->props objectForKey:_propertyKey];
}

- (id)propertyForKeyIfAvailable:(NSString *)_propertyKey
{
    return [self->props objectForKey:_propertyKey];
}

- (BOOL)writeProperty:(id)_propValue forKey:(NSString *)_propertyKey
{
    NSDictionary *attrs;
    
    if ((_propertyKey == nil) || (_propValue == nil))
        return NO;

    RELEASE(self->props); self->props = nil;

    attrs = [NSDictionary dictionaryWithObject:_propValue forKey:_propertyKey];
    
    return [[self fileManager] changeFileAttributes:attrs
                               atPath:[self filePath]];
}

@end /* NSFileURLHandle */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
