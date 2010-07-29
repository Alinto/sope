/* 
   StackZone.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>

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
#include <Foundation/StackZone.h>
#include <Foundation/NSUtilities.h>
#include <extensions/NSException.h>
#include <objc/objc-api.h>

@implementation StackZone

/* nextNode indicates to the next allocation node available. The `previous'
   component of this node points to the node allocated before it.
   When a new allocation is requested it is satisfied from the node pointed to
   by nextNode and then nextNode is updated to point to the zone where the
   next node will be allocated. The algorithm tries first to allocate memory
   in the nodes below the current node if they are freed. */

+ alloc
{
    return [self allocZoneInstance];
}

- init
{
    return [self initForSize:64536 granularity:0 canFree:YES];
}

- initForSize:(unsigned)startSize granularity:(unsigned)granularity
    canFree:(BOOL)canFree
{
    [self setName:@"Default zone"];
    memory = objc_malloc(startSize);
    nextNode = (AllocationNode*)memory;
    nextNode->previous = NULL;
    memorySize = startSize;
    return self;
}

- (void*)malloc:(unsigned)size
{
    AllocationNode* previous = nextNode->previous;

    /* Try to use the nodes below the top of stack if they are freed */
    while (previous && previous->freed == YES) {
	nextNode = previous;
	previous = previous->previous;
    }

    NSCAssert(nextNode, @"nextNode is NULL (previous=0x%p)", previous);

    /* Check if the requested size can be handled */
    if (((char*)nextNode) + size - memory
	    + sizeof(AllocationNode) >= memorySize)
	return NULL;

    /* Prepare nextNode to be allocated */
    nextNode->freed = NO;

    /* Make nextNode to point to the next allocation node */
    previous = nextNode;
    nextNode = (void*)(((char*)nextNode) + sizeof(AllocationNode) + size);
    nextNode->previous = previous;

    /* Return the memory from the previous node */
    return &(previous->allocatedMemory);
}

- (void*)calloc:(unsigned)numElems byteSize:(unsigned)byteSize
{
    unsigned size = numElems * byteSize;
    void* pointer = [self malloc:size];

    memset (pointer, 0, size);
    return pointer;
}

- (void*)realloc:(void*)pointer size:(unsigned)newSize
{
    AllocationNode* currentNode = nextNode->previous;
    unsigned size = ((char*)nextNode) - ((char*)currentNode)
			- sizeof(AllocationNode);
    void* newPointer;

    /* If the pointer is NULL behave like a normal allocation */
    if (!pointer)
	return [self malloc:newSize];

    while (currentNode && &(currentNode->allocatedMemory) != pointer) {
	size = ((char*)currentNode) - ((char*)(currentNode->previous))
		- sizeof(AllocationNode);
	currentNode = currentNode->previous;
    }

    /* If the requested size is lower than the allocated pointer size, return
       the old value. Otherwise allocate a new memory zone, copy the content of
       the old one and return the address of the new pointer. The old zone is
       marked as freed. */
    if (currentNode && size >= newSize)
	return pointer;
    else {
	newPointer = [self malloc:newSize];
	if (newPointer)
	    memcpy(newPointer, pointer, size);
	currentNode->freed = YES;
	return newPointer;
    }
}

- (void)recycle
{
}

- (BOOL)pointerInZone:(void*)pointer
{
    return (char*)pointer > memory && (char*)pointer < memory + memorySize;
}

- (void)freePointer:(void*)pointer
{
    AllocationNode* currentNode = nextNode->previous;

    /* Identify the allocation node of pointer and mark it as freed. */
    while (currentNode && &(currentNode->allocatedMemory) != pointer)
	currentNode = currentNode->previous;

    if (currentNode) {
	if (currentNode->freed == YES)
	    NSLog(@"attempt to free an already freed pointer: %p\n", pointer);
	else
	    currentNode->freed = YES;
    }
    else
	NSLog(@"attempt to free an unexisting pointer in zone: pointer %p, "
	      @"zone %p (%@)", pointer, self, [self name]);
}

- (BOOL)checkZone
{
    return YES;
}

@end /* StackZone */
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

