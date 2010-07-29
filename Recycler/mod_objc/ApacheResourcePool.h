// $Id: ApacheResourcePool.h,v 1.1 2004/06/08 11:15:59 helge Exp $

#ifndef __ApacheResourcePool_H__
#define __ApacheResourcePool_H__

#include "ApacheObject.h"
#include <stdio.h>

/*
  Note: Apache resource pools are some kind of mixture between an
  FoundationNSAutoreleasePool and a Foundation NSZone. You should mix
  up Apache resource pools and autorelease pools !

  Objective-C support: ApacheResourcePool can register release
  callbacks for Foundation objects.
  Eg:
    ApacheResourcePool *p;
    id s = [[NSString alloc] initWithCString:"blah"];
    [p releaseObject:s];
  
  This will release the string (but not necessarily -dealloc !!!) if the
  resource pool is freed by Apache.

  Most commonly used Apache resource pools (info take from API notes):
    
    permanent-pool:
      - the "root" pool
    
    pconf
      - subpool of permanent-pool
      - created at the beginning of the config cycle
      - exists until the server is restarted or terminated
      - passed to all config routines via [cmd pool] or inPool:pool
      - passed to the module init function
    
    ptemp
      - subpool of permanent-pool
      - created at the beginning of the config cycle
      - exists until the end of the config parsing
      - passed to config routines via [cmd temporaryPool]
    
    pchild
      - subpool of permanent-pool
      - created when a child is forked
      - exists until child exits
      - passedto -initializeChildProcessWithServer:inPool: and
        -exitChildProcessWithServer:inPool:
    
    ptrans
      - subpool of permanent-pool
      - created by child before going into the accept loop
      - passed in with [connection pool]
    
    r->pool
      - for the main request a subpool of ptrans
        for sub requests a subpool of the parent request pool
      - exist until the end of the processing of the request
      - note: the request itself is allocated from this pool !!
*/

@interface ApacheResourcePool : ApacheObject
{
}

- (id)makeSubPool;

/* Clearing out EVERYTHING in an pool... destroys any sub-pools */
- (void)clearPool;

- (BOOL)isAncestorOf:(ApacheResourcePool *)_pool;

/* stats */

- (unsigned int)bytesInPool;
+ (unsigned int)bytesInFreeBlocks;

/* memory blocks */

- (void *)malloc:(unsigned)size;
- (void *)mallocAtomic:(unsigned)size;
- (void *)calloc:(unsigned)numElems byteSize:(unsigned)byteSize;
- (void *)callocAtomic:(unsigned)numElems byteSize:(unsigned)byteSize;

- (void *)realloc:(void*)pointer size:(unsigned)size;
- (void)freePointer:(void *)pointer;

/* string allocations */

- (unsigned char *)strdup:(const unsigned char *)_cstr;
- (unsigned char *)strdup:(const unsigned char *)_cstr length:(unsigned)_l;
- (unsigned char *)strcat:(const unsigned char *)_cstr;
- (unsigned char *)pvsprintf:(const unsigned char *)_fmt arguments:(va_list)va;

/* file allocations */

- (FILE *)openFile:(NSString *)_name mode:(NSString *)_mode;
- (FILE *)openFD:(int)_fd mode:(NSString *)_mode;
- (int)popenf:(NSString *)_name flag:(int)_flg mode:(int)_mode;

- (void)closeFile:(FILE *)_file;
- (void)pclosef:(int)_fd;
#ifdef WIN32
- (void)closeHandle:(HANDLE)_h;
#endif

- (void)noteCleanUpsForFile:(FILE *)_file;
- (void)noteCleanUpsForFD:(int)_fd;
#ifdef WIN32
- (void)noteCleanUpsForHandle:(HANDLE)_h;
#endif
- (void)killCleanUpsForFD:(int)_fd;

/* process management */

/*
  Preparing for exec() --- close files, etc., but *don't* flush I/O
  buffers, *don't* wait for subprocesses, and *don't* free any memory.
*/
+ (void)cleanUpForExec;

/* Objective-C objects */

- (void)releaseObject:(id)_object;
- (void)unreleaseObject:(id)_object;

@end

@interface NSObject(PoolRelease)

- (void)cleanupForApacheExec; /* called before exec() */

@end

#endif /* __ApacheResourcePool_H__ */
