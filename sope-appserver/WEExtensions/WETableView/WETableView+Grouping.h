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
#ifndef __WETableView_Grouping_H__
#define __WETableView_Grouping_H__

#include "WETableView.h"

@class WORequest, WOContext, WOResponse;
@class NSString, NSMutableArray;

@interface WETableView(Grouping)

- (id)invokeGrouping:(WORequest *)_request inContext:(WOContext *)_ctx;
- (void)_appendGroupTitle:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  infos:(NSMutableArray *)_infos
  actionUrl:(NSString *)_actionUrl
  rowSpan:(unsigned)_rowSpan
  groupId:(NSString *)_groupId;

@end

#endif /*__WETableView_Grouping_H__*/
