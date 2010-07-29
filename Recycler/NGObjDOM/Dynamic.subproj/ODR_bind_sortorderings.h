/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

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
// $Id$

#ifndef __NGObjDOM_ODR_bind_sortorderings_H__
#define __NGObjDOM_ODR_bind_sortorderings_H__

#include <NGObjDOM/ODNodeRenderer.h>

#define ODR_SortOrderingContainer     @"ODR_SortOrderingContainer"
#define ODR_SortOrderingContainerMode @"ODR_SortOrderingContainerMode"

@interface ODR_bind_sortorderings : ODNodeRenderer
@end

@interface ODR_bind_sortordering : ODNodeRenderer
@end

#endif /* __NGObjDOM_ODR_bind_sortorderings_H__ */

