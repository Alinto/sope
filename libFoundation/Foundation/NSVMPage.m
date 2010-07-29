/* 
   NSVMPage.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
	   Mircea Oancea <mircea@jupiter.elcom.pub.ro>

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

#include <config.h>
#include <objc/objc-api.h>

#ifdef NeXT
# include <mach/mach.h>
# include <mach/mach_error.h>
#endif

#if defined(__MINGW32__)
#  include <windows.h>
static DWORD getpagesize(void)
{
    SYSTEM_INFO info;
    GetSystemInfo(&info);
    return info.dwPageSize;
}
#elif !defined(HAVE_GETPAGESIZE)
#  if HAVE_SYSCONF
#    include <unistd.h>
#    ifdef _SC_PAGE_SIZE
#      define _SC_PAGESIZE _SC_PAGE_SIZE
#    endif
#    define getpagesize()	sysconf(_SC_PAGESIZE)
#  elif HAVE_GETSYSTEMINFO
#    include <windows.h>
static DWORD getpagesize(void)
{
    SYSTEM_INFO info;
    GetSystemInfo(&info);
    return info.dwPageSize;
}
#  endif
#endif

#include <Foundation/common.h>
#include <Foundation/NSZone.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/exceptions/GeneralExceptions.h>

/* 
 * Get the Virtual Memory Page Size 
 */

unsigned NSPageSize(void)
{
    return getpagesize();
}

unsigned NSLogPageSize(void)
{
    register unsigned pagesize = NSPageSize();
    register unsigned log = 0;

    if(pagesize >= 65536) { log += 16; pagesize >>= 16; }
    if(pagesize >=   256) { log +=  8; pagesize >>=  8; }
    if(pagesize >=    16) { log +=  4; pagesize >>=  4; }
    if(pagesize >=     4) { log +=  2; pagesize >>=  2; }
    if(pagesize >=     2) { log +=  1; pagesize >>=  1; }
    return log;
}

unsigned NSRoundDownToMultipleOfPageSize(unsigned byteCount)
{
    unsigned pageSize = NSPageSize();
    return (byteCount / pageSize) * pageSize;
}

unsigned NSRoundUpToMultipleOfPageSize(unsigned byteCount)
{
    unsigned pageSize = NSPageSize();
    unsigned anotherOne = (byteCount % pageSize != 0);

    return (byteCount / pageSize + anotherOne) * pageSize;
}

/* Allocate or Free Virtual Memory */
void *NSAllocateMemoryPages(unsigned byteCount)
{
#ifdef NeXT
    kern_return_t ret;
    vm_address_t p;
    unsigned size = NSRoundUpToMultipleOfPageSize(byteCount);

    if((ret = vm_allocate(task_self(), &p, size, TRUE)) != KERN_SUCCESS) {
	THROW([memoryExhaustedException
		    setPointer:(void**)&p memorySize:size]);
	return NULL;
    }
    else return (void*)p;
#else
    return objc_calloc(byteCount, 1);
#endif 
}

void NSDeallocateMemoryPages(void *pointer, unsigned byteCount)
{
#ifdef NeXT
    unsigned size = NSRoundUpToMultipleOfPageSize(byteCount);
    kern_return_t ret;

    if ((ret = vm_deallocate(task_self(), (vm_address_t)pointer, size))
	    != KERN_SUCCESS)
	THROW([[[MemoryDeallocationException alloc]
	    setReason:[NSString stringWithCString:mach_error_string(ret)]]
	    setPointer:&pointer memorySize:size]);
#else
    objc_free(pointer);
#endif
}

void NSCopyMemoryPages(const void *source, void *dest, unsigned byteCount)
{
#ifdef NeXT
    unsigned size = NSRoundUpToMultipleOfPageSize(byteCount);
    kern_return_t ret;

    if((ret = vm_copy(task_self(), (vm_address_t)source, size,
		      (vm_address_t)dest)) != KERN_SUCCESS)
	THROW([[MemoryCopyException alloc]
	    setReason:[NSString stringWithCString:mach_error_string(ret)]]);
#else
    memcpy(dest, source, byteCount);
#endif
}
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

