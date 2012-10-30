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

#ifndef __SoObjects_SoComponent_H__
#define __SoObjects_SoComponent_H__

#include <NGObjWeb/WOComponent.h>

/*
  SoComponent
  
  This is a subclass of WOComponent intendend for use with components which
  are placed into a product bundle. The main difference is, that SoComponent's
  use the SoProductResourceManager to locate their resources.
*/

@class NSURL;
@class WOElement;
@class SoProductResourceManager;

@interface SoComponent : WOComponent
{
  SoProductResourceManager *soResourceManager; // __worm
  NSURL     *soBaseURL;  // __wobaseurl
  WOElement *soTemplate; // __wotemplate
}

@end

#endif /* __SoObjects_SoComponent_H__ */
