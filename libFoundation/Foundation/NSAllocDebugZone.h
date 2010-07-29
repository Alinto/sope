/* 
   NSAllocDebugZone.h

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

/*
    Alloc debug serves to trace erroneous memory usage in the following
    modes:
	- use free() instead of Free()
	- use Free() instead of free()
	- check double deallocation
	- check deallocation of non-existing pointers
	- use a block past its margins
	- list blocks allocated since mark
	- stop when alloc-ing pointer marked
	- do SYSTEM_MALLOC_CHECK and internal checks every * operation
	- be able to control things from gdb
	- be able to control things from environment variables
    
    AllocDebug is controlled by the following environment variables:
	ALLOCDEBUG		
	    - must be set to something to use alloc debug zone
	ALLOCDEBUG_STOP
	    - stop in debugger (SIGINT) when alloc-ing pointer number *
	    - nil or 0 means no stop
	ALLOCDEBUG_COUNT
	    - number of passes inside allocation/deallocation functions
	    to SYSTEM_MALLOC_CHECK and internal check
	    - nil or 0 means no checks
	ALLOCDEBUG_UPPER
	ALLOCDEBUG_LOWER
	    - number of bytes to alloc at top/bottom of object block
	    - these bytes are set to a given value (0x88) and checked
	    at free and internal check to guard against using memory
	    past the limit.
		    
    AlloDebug provides these functions to be used from debugger (gdb)
	debuggerStopMark(unsigned mark)
	    - overrides ALLOCDEBUG_STOP
	debuggerCheckTime(unsigned count)
	    - overrides ALLOCDEBUG_COUNT
	debuggerDescription(id obj)
	    - performs printf("%s\n", [obj description])
	debuggerPerform(id obj, char* sel)
	    - performs [obj sel]
	debuggerPerformWith(id obj, char* sel, id arg)
	    - performs [obj sel:(id)atoi(arg)]
*/

#ifndef __NSAllocDebugZone_h__
#define __NSAllocDebugZone_h__

#include <Foundation/NSObject.h>

typedef enum {debugNone=0, debugAlloc=1} TDebugMode;

@interface NSAllocDebugZone : NSZone
@end

void debuggerStopMark(unsigned mark);
void debuggerCheckTime(unsigned count);
void debuggerDescription(id obj);
void debuggerPerform(id obj, char* sel);
void debuggerPerformWith(id obj, char* sel, id arg);

#endif /* __NSAllocDebugZone_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
