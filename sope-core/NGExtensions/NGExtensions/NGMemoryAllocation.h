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

#ifndef __NGExtensions_NGMemoryAllocation_H__
#define __NGExtensions_NGMemoryAllocation_H__

#if __GNU_LIBOBJC__ != 20100911
#include <objc/objc-api.h>
#endif

#include <stdlib.h>

#if LIB_FOUNDATION_BOEHM_GC
#  define NGMalloc       objc_malloc
#  define NGMallocAtomic objc_atomic_malloc
#  define NGFree         objc_free
#  define NGRealloc      objc_realloc
#else
#  define NGMalloc       malloc
#  define NGMallocAtomic malloc
#  define NGFree         free
#  define NGRealloc      realloc
#endif

#endif /* __NGExtensions_NGMemoryAllocation_H__ */
