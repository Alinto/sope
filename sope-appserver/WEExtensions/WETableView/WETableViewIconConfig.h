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

#ifndef __WEExtensions_WETableViewIconConfig_H__
#define __WEExtensions_WETableViewIconConfig_H__

#include "WETableViewConfigObject.h"

@interface WETableViewIconConfig : WETableViewConfigObject
{
@public
  WOAssociation  *plusResizeIcon;
  WOAssociation  *minusResizeIcon;
@private
  WOAssociation  *downwardIcon;  // downwardSortIcon
  WOAssociation  *upwardIcon;    // upwardSortIcon
  WOAssociation  *nonSortIcon;   // nonSortIcon
  WOAssociation  *firstIcon;
  WOAssociation  *firstBlind;    // firstBlindIcon
  WOAssociation  *previousIcon;
  WOAssociation  *previousBlind; // previousBlindIcon
  WOAssociation  *nextIcon;
  WOAssociation  *nextBlind;     // nextBlindIcon
  WOAssociation  *lastIcon;
  WOAssociation  *lastBlind;     // lastBlindIcon
  WOAssociation  *selectAllIcon;
  WOAssociation  *deselectAllIcon;
}

@end

#endif /* __WEExtensions_WETableViewIconConfig_H__ */
