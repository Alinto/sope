/*
  Copyright (C) 2005 SKYRIX Software AG

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

#ifndef __EOCoreData_COMMON_H__
#define __EOCoreData_COMMON_H__

#import <Foundation/Foundation.h>
#import <Foundation/NSObjCRuntime.h>

#include <EOControl/EOControl.h>

#import <CoreData/NSEntityDescription.h>
#import <CoreData/NSFetchRequest.h>
#import <CoreData/NSManagedObject.h>
#import <CoreData/NSManagedObjectContext.h>
#import <CoreData/NSManagedObjectModel.h>


#ifndef ASSIGN
#  define ASSIGN(object, value) \
       ({id __object = (id)object;    \
         id __value = (id)value;      \
         if (__value != __object) { if (__value) [__value retain]; \
          if (__object) [__object release]; \
          object = __value;}})
#endif
#ifndef ASSIGNCOPY
#  define ASSIGNCOPY(object, value) \
       ({id __object = (id)object;    \
         id __value = (id)value;      \
         if (__value != __object) { if (__value) __value = [__value copy];   \
          if (__object) [__object release]; \
          object = __value;}})
#endif


#if GNU_RUNTIME
#  include <objc/objc.h>
#endif

#ifndef SEL_EQ
#  if GNU_RUNTIME
#    define SEL_EQ(sel1,sel2) sel_eq(sel1,sel2)
#  else
#    define SEL_EQ(sel1,sel2) (sel1 == sel2)
#  endif
#endif

#endif /* __EOCoreData_COMMON_H__ */
