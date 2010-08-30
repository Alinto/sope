/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

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

#include "TableCallbacks.h"
#include "common.h"
#include <string.h>

//#define NSNonOwnedCStringMapKeyCallBacks NSNonOwnedPointerMapKeyCallBacks

/* From Aho, Sethi & Ullman: Principles of compiler design. */
static unsigned __hashCString(void *table, const void *aString) {
  register const char* p = (char*)aString;
  register unsigned hash = 0, hash2;
  register int i, n;
  
  n = aString ? strlen(aString) : 0;
  for(i=0; i < n; i++) {
    hash <<= 4;
    hash += *p++;
    if((hash2 = hash & 0xf0000000))
      hash ^= (hash2 >> 24) ^ hash2;
  }
  return hash;
}

static BOOL __compareCString(void *table, 
                               const void *anObject1,
                               const void *anObject2)
{
  if (anObject1 == NULL && anObject2 == NULL) return YES;
  if (anObject1 == NULL || anObject2 == NULL) return NO;
  return strcmp((char*)anObject1, (char*)anObject2) == 0;
}

static void __retain(void *table, const void *anObject) {}
static void TableCallbacksRelease(void *table, void *anObject) {}

static NSString *__describe(void *table, const void *anObject) {
    return [NSString stringWithFormat:@"%p", anObject];
}

const NSMapTableKeyCallBacks libxmlNonOwnedCStringMapKeyCallBacks =  {
    (NSUInteger(*)(NSMapTable *, const void *))__hashCString,
    (BOOL(*)(NSMapTable *, const void *, const void *))__compareCString,
    (void (*)(NSMapTable *, const void *anObject))__retain,
    (void (*)(NSMapTable *, void *anObject))TableCallbacksRelease,
    (NSString *(*)(NSMapTable *, const void *))__describe,
    (const void *)NULL
};
