/* 
   NSMappedData.m

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
#include <Foundation/NSPosixFileDescriptor.h>
#include <Foundation/NSException.h>
#include <Foundation/exceptions/GeneralExceptions.h>

#ifdef NeXT /* NeXT Mach map_fd() */
# include <mach/mach.h>
# include <libc.h>
#elif defined(HAVE_MMAP) /* Posix mmap() */
#  include <sys/types.h>
#  include <sys/mman.h>
#  include <unistd.h>
#else  /* No file mapping available */
#endif

#include "NSMappedData.h"

/*
 * Read-only mapped data
 */

@implementation NSMappedData

- (id)initWithPosixFileDescriptor:(NSPosixFileDescriptor*)descriptor
  range:(NSRange)range
{
    file = RETAIN(descriptor);

    if (range.location + range.length > [file fileLength])
	[[[RangeException alloc]
		initWithReason:@"invalid range to be mapped" 
		size:[file fileLength] 
		index:range.location+range.length] raise];

    length = capacity = range.length;
    [file seekToPosition:range.location];

    if (!length)
	return self;

#ifdef NeXT	
    /* NeXt Mach map_fd() */
    {
	kern_return_t r;

	r = map_fd([file fileDescriptor], (vm_offset_t)0, 
	    (vm_offset_t*)(&bytes), TRUE, (vm_size_t)length);
	if (r != KERN_SUCCESS) {
	    bytes = NULL;
	    AUTORELEASE(self);
	    return nil;
	}
	return self;
    }
#elif defined(HAVE_MMAP)
    /* Posix mmap() */
    {
	bytes = mmap(0, length, PROT_READ, MAP_SHARED,
		     [file fileDescriptor], 0);
	if ((long)bytes == -1L) {
	    bytes = NULL;
	    (void)AUTORELEASE(self);
	    return nil;
	}
	return self;
    }
#else	
    /* No file mapping available */
    {
	bytes = MallocAtomic (length);
	[file readBytes:bytes range:range];
	return self;
    }
#endif
}

- (void)dealloc
{
#ifdef NeXT	
    /* NeXt Mach map_fd() */
    if (bytes && length)
	vm_deallocate(task_self(), (vm_address_t)bytes, length);
#elif defined(HAVE_MMAP)
    /* Posix mmap() */
    if (bytes && length)
	munmap(bytes, length);
#else	
    /* No file mapping available */
    lfFree(bytes);
#endif
    RELEASE(file);
    [super dealloc];
}

- (id)copyWithZone:(NSZone*)zone
{
    return RETAIN(self);
}

- (const void*)bytes
{
    return bytes;
}

- (unsigned int)length
{
    return length;
}

@end /* NSMappedData */
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

