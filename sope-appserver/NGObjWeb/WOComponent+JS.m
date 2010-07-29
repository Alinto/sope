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

#include "common.h"
#include <NGObjWeb/NGObjWeb.h>

/*
  WOComponent JavaScript object

  Properties

    String      sessionID
    String      name
    String      path
    String      baseURL
    Object      context
    Object      session
    Object      application
    WOComponent parent
    bool        hasSession
    bool        cachingEnabled
    bool        isEventLoggingEnabled
    bool        isStateless
    bool        synchronizesVariablesWithBindings
  
  Methods

    reset()    
    WOComponent     pageWithName(name)
    WOElement       templateWithName(name)
    Object          performParentAction(name)
    bool            canGetValueForBinding(name)
    bool            canSetValueForBinding(name)
                    setValueForBinding(value,name)
    Object          valueForBinding(name)
    bool            hasBinding(name)
                    print(string[,...string])
    ResourceManager getResourceManager()
*/

static NSNumber *nYes = nil;
static NSNumber *nNo  = nil;

#define ENSURE_BOOLNUMS {\
  if (nYes == nil) nYes = [[NSNumber alloc] initWithBool:YES];\
  if (nNo  == nil) nNo  = [[NSNumber alloc] initWithBool:NO];\
}

@implementation WOComponent(JSKVC)

#if 1
- (void)takeValue:(id)_value forJSPropertyNamed:(NSString *)_key {
  [self takeValue:_value forKey:_key];
}
- (id)valueForJSPropertyNamed:(NSString *)_key {
  return [self valueForKey:_key];
}
#endif

@end /* WOComponent(JSKVC) */
