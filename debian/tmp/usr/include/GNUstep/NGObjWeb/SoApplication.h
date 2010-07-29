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

#ifndef __SoObjects_SoApplication_H__
#define __SoObjects_SoApplication_H__

#include <NGObjWeb/WOApplication.h>

/*
  SoApplication
  
  A convenience WOApplication subclass for So based products. It:
  - registeres SoObjectRequestHandler as 'so','dav','RPC2' and default handler
  - loads products based on the SoApplicationLoadProducts default
  - initializes all required global objects (registries, security manager)
*/

@class SoProductRegistry, SoClassRegistry, SoSecurityManager;

@interface SoApplication : WOApplication
{
  SoProductRegistry *productRegistry;
  SoClassRegistry   *classRegistry;
  SoSecurityManager *securityManager;
}

/* accessors */

- (SoProductRegistry *)productRegistry;
- (SoClassRegistry *)classRegistry;
- (SoSecurityManager *)securityManager;

/* SoObject */

- (id)rootObjectInContext:(id)_ctx;

@end

@interface SoApplication(Authenticator)

- (id)authenticatorInContext:(id)_ctx;

@end

#endif /* __SoObjects_SoApplication_H__ */
