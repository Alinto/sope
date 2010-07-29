/* 
   NSDistributedLock.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

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

#include <Foundation/common.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDistributedLock.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSPathUtilities.h>

#include <fcntl.h>
#include <errno.h>

#define PERMS 0666

@implementation NSDistributedLock

// Creating an NSDistributedLock

+ (NSDistributedLock *)lockWithPath:(NSString *)aPath
{
    return AUTORELEASE([[self alloc] initWithPath:aPath]);
}

- (NSDistributedLock *)initWithPath:(NSString *)aPath
{
    self->path   = [aPath copyWithZone:[aPath zone]];
    self->locked = NO;
    return self;
}

// Acquiring a lock

- (BOOL)tryLock
{
    int fd;
    
    /* This open operation is atomic: it will either create a file if it
       doesn't exist already or return an error if it exists. */
    fd = open([path fileSystemRepresentation], O_RDWR|O_CREAT|O_EXCL, PERMS);
    if (fd < 0) {
	if (errno != EEXIST) {
	    [NSException raise:NSGenericException 
                         format:@"%s", strerror(errno)];
        }
	return NO;
    }
    close(fd);
    
    self->locked = YES;
    
    return YES;
}

// Relinquishing a lock

- (void)breakLock
{
    /* Don't care about errors */
    unlink([path fileSystemRepresentation]);
    self->locked = NO;
}

- (void)unlock
{
    if (!self->locked)
	[NSException raise:NSGenericException format:@"not locked"];
    if (unlink([path fileSystemRepresentation]) < 0)
	[NSException raise:NSGenericException format:@"%s", strerror(errno)];
    self->locked = NO;
}

// Getting lock information

- (NSDate *)lockDate
{
    struct stat statbuf;
    
    if (stat([path fileSystemRepresentation], &statbuf) < 0)
	return nil;

    return [NSDate dateWithTimeIntervalSince1970:statbuf.st_mtime];
}

@end /* NSDistributedLock */
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

