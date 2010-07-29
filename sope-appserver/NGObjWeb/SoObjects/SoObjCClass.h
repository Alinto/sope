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

#ifndef __SoObjects_SoObjCClass_H__
#define __SoObjects_SoObjCClass_H__

#include <SoObjects/SoClass.h>

/*
  This is a concrete SoClass subclass which implements it's methods
  based on an Objective-C class.
  
  ClassName:
  The name of a SoObjCClass is the same as the name of the backend
  Objective-C class.
  
  Methods:
  SoClass methods are located by scanning the class methods for
  selectors ending in "Action", for example "doItAction:".
  
  Class-Description:
  The class description for SoObjCClass'es is located using
  NSClassDescription.
  
  Instantiation:
  SoObjCClass objects are instantiated using the usual
  alloc,init,autorelease sequence.
*/

@interface SoObjCClass : SoClass
{
  Class clazz;
}

- (id)initWithSoSuperClass:(SoClass *)_soClass class:(Class)_clazz;

/* accessors */

- (NSString *)className;
- (Class)objcClass;

/* scan the class for actions (need to rescan after bundles are loaded) */

- (void)rescanClass;

@end

#endif /* __SoObjects_SoObjCClass_H__ */
