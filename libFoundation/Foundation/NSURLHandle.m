/* 
   NSURLHandle.m

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

#include <Foundation/NSURLHandle.h>
#include <Foundation/NSURL.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSException.h>
#include <common.h>

@implementation NSURLHandle

// THREAD
static NSMutableArray *classRegistry = nil;

+ (void)initialize
{
    if (classRegistry == nil) {
        classRegistry = [[NSMutableArray alloc] init];
        [classRegistry addObject:NSClassFromString(@"NSFileURLHandle")];
    }
}

+ (Class)URLHandleClassForURL:(NSURL *)_url
{
    NSEnumerator *e;
    Class        clazz;
    
    if (_url == nil)
        return Nil;

    NSAssert(classRegistry, @"class registry is not setup ..");
    
    e = [classRegistry objectEnumerator];
    while ((clazz = [e nextObject])) {
        if ([clazz canInitWithURL:_url])
            return clazz;
    }
    return Nil;
}

+ (void)registerURLHandleClass:(Class)_clazz
{
    if (_clazz == Nil)
        return;
    
    NSAssert(classRegistry, @"class registry is not setup ..");
    [classRegistry addObject:_clazz];
}

+ (NSURLHandle *)cachedHandleForURL:(NSURL *)_url
{
    Class hClass;
    
    if (self != [NSURLHandle class])
        return nil;
    
    if ((hClass = [self URLHandleClassForURL:_url]) == self)
        /* avoid recursion */
        return nil;
    
    return [hClass cachedHandleForURL:_url];
}

+ (BOOL)canInitWithURL:(NSURL *)_url
{
    return NO;
}

- (id)initWithURL:(NSURL *)_url cached:(BOOL)_flag
{
    return self;
}
- (id)init
{
    return [self initWithURL:nil cached:NO];
}

- (void)dealloc
{
    RELEASE(self->clients);
    [super dealloc];
}

/* loading */

- (NSData *)loadInForeground
{
    return [self subclassResponsibility:_cmd];
}

- (void)loadInBackground
{
    NSData *data;
    [self beginLoadInBackground];
    data = [self loadInForeground];
    [self endLoadInBackground];
}
- (void)beginLoadInBackground
{
}
- (void)endLoadInBackground
{
}

- (NSURLHandleStatus)status
{
    return NSURLHandleNotLoaded;
}

/* clients */

- (void)addClient:(id<NSURLHandleClient>)_client
{
    if (self->clients == nil)
        self->clients = [[NSMutableArray alloc] initWithCapacity:2];
    [self->clients addObject:_client];
}
- (void)removeClient:(id<NSURLHandleClient>)_client
{
    [self->clients removeObjectIdenticalTo:_client];
}

/* reading data */

- (NSData *)resourceData
{
    return [self loadInForeground];
}
- (void)flushCachedData
{
}

/* writing data */

- (BOOL)writeData:(NSData *)_data
{
    [self flushCachedData];
    [self subclassResponsibility:_cmd];
    return NO;
}

/* properties */

- (id)propertyForKey:(NSString *)_propertyKey
{
    return nil;
}
- (id)propertyForKeyIfAvailable:(NSString *)_propertyKey
{
    return nil;
}

- (BOOL)writeProperty:(id)_propValue forKey:(NSString *)_propertyKey
{
    return NO;
}

@end /* NSURLHandle */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
