/* 
   NSPipe.m

   Copyright (C) 1995, 1996, 1997 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@net-community.com>

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

#include <errno.h>

#include <Foundation/common.h>
#include <Foundation/NSFileHandle.h>
#include <Foundation/NSConcreteFileHandle.h>
#include <Foundation/NSException.h>
#include <Foundation/NSUtilities.h>

#if defined(__MINGW32__)
#define pipe _pipe
#endif

@interface NSConcretePipe : NSPipe
{
    NSFileHandle *_readFd;
    NSFileHandle *_writeFd;
}
@end


@implementation NSConcretePipe

- (NSFileHandle *)fileHandleForReading
{
    return _readFd;
}
- (NSFileHandle *)fileHandleForWriting
{
    return _writeFd;
}

- (id)init
{
#if !defined(__MINGW32__)
    int fildes[2];

    if (pipe(fildes) == -1) {
	NSLog (@"pipe system call failed: %s", strerror (errno));
	(void)AUTORELEASE(self);
	return nil;
    }
    _readFd = [[NSConcretePipeFileHandle alloc] initWithFileDescriptor:fildes[0]
                                                closeOnDealloc:YES];
    _writeFd = [[NSConcretePipeFileHandle alloc] initWithFileDescriptor:fildes[1]
                                                 closeOnDealloc:YES];
#else
    BOOL ok;
    HANDLE reading, writing;
    
    ok = CreatePipe(&reading, &writing, NULL, 0);
    NSAssert(ok, @"couldn't create pipe !");

    _readFd  = [[NSFileHandle alloc] initWithFileHandle:reading];
    _writeFd = [[NSFileHandle alloc] initWithFileHandle:writing];
#endif
    
    return self;
}

- (void)dealloc
{
    RELEASE(_readFd);
    RELEASE(_writeFd);
    [super dealloc];
}

@end

@implementation NSPipe

+ (id)pipe
{
    return AUTORELEASE([[NSConcretePipe alloc] init]);
}

- (NSFileHandle *)fileHandleForReading
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (NSFileHandle *)fileHandleForWriting
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (id)init
{
    [self shouldNotImplement:_cmd];
    return nil;
}

@end

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
