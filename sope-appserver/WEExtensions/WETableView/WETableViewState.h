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

#ifndef __WEExtensions_WETableViewState_H__
#define __WEExtensions_WETableViewState_H__

#import <Foundation/NSObject.h>

@interface WETableViewState : NSObject
{
@public
  unsigned currentBatch;
  unsigned batchSize;
  unsigned firstIndex;
  unsigned lastIndex;
  unsigned batchCount;
  unsigned groupCount;
  BOOL     doCheckBoxes;
  BOOL     doOverflow;         // generate overflow-scrolling
  BOOL     doScriptScrolling;  // scroll pages per JavaScript
  BOOL     doScriptCollapsing; // collapse groups per JavaScript
  BOOL     showBatchResizeButtons;
}

@end

#endif /* __WEExtensions_WETableViewState_H__ */
