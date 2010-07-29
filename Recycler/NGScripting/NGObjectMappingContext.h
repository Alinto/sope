/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id: NGObjectMappingContext.h 6 2004-08-20 17:57:50Z helge $

#ifndef __NGObjectMappingContext_H__
#define __NGObjectMappingContext_H__

#import <Foundation/NSObject.h>

@interface NGObjectMappingContext : NSObject < NSCoding >
{
@public
  /* method cache */
  id (*objForHandle)(id,SEL,void *);
  void *(*handleForObj)(id,SEL,id);
}

/* mapping */

- (void *)handleForObject:(id)_object;
- (id)objectForHandle:(void *)_handle;

- (void)forgetObject:(id)_object;
- (void)forgetHandle:(void *)_handle;

/* context stack */

+ (id)activeObjectMappingContext;

- (void)pushContext;
- (id)popContext;

- (void)collectGarbage; /* can be run async (active ctx will match) */

@end

/* functions which operate on the current context */

extern id   NGObjectMapping_GetObjectForHandle(void *_object);
extern void *NGObjectMapping_GetHandleForObject(id _object);

#endif /* __NGObjectMappingContext_H__ */
