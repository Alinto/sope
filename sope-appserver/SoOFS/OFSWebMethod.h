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

#ifndef __OFS_OFSWebMethod_H__
#define __OFS_OFSWebMethod_H__

#include <SoOFS/OFSFile.h>

/*
  OFSWebMethod

  OFSWebMethod is for storing and activating NGObjWeb based components
  from OFS.
*/

@class NSException;
@class WOComponent, WOResourceManager, WOContext;

@interface OFSWebMethod : OFSFile
{
  WOComponent *component;
}

/* page */

- (WOComponent *)component;

/* actions */

- (id)GETAction:(WOContext *)_ctx;
- (id)viewAction:(WOContext *)_ctx;

@end

@interface NSObject(OFSWebMethodClassify)
- (BOOL)isOFSWebMethod;
@end

#endif /* __OFS_OFSWebMethod_H__ */
