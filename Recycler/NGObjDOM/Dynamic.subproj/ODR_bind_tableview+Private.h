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

#ifndef __NGObjDOM_Dynamic_tableview_Private_H__
#define __NGObjDOM_Dynamic_tableview_Private_H__

#include "ODR_bind_tableview.h"

@interface ODR_bind_tableview(Private_Rendering)
- (void)_appendTitle:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx;

- (void)_appendFooter:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx;

- (void)_appendData:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx;
 
- (void)_appendHeader:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx;

- (void)_appendBatchResizeButtons:(id)_node
  toResponse:(WOResponse *)_response
  rowSpan:(unsigned int)_rowSpan
  actionUrl:(NSString *)_actionUrl
  inContext:(WOContext *)_ctx;

- (void)_appendCheckboxToResponse:(WOResponse *)_response
  ctx:(WOContext *)_ctx
  value:(NSString *)_value
  isChecked:(BOOL)_isChecked;

- (void)_applyIdentifier:(NSString *)_id node:(id)_node ctx:(WOContext *)_ctx;
- (void)_applyItemForIndex:(int)_i node:(id)_node ctx:(WOContext *)_ctx;
@end

@interface ODR_bind_tableview(Private_ActionHandling)

- (NSArray *)_sortedArrayOfNode:(id)_node
                      inContext:(WOContext *)_ctx
                          fetch:(BOOL)_doFetch;

- (void)_handleSortAction:(id)_node inContext:(WOContext *)_ctx;
- (id)_handleFirstButton:(id)_node inContext:(WOContext *)_ctx;
- (id)_handlePreviousButton:(id)_node inContext:(WOContext *)_ctx;
- (id)_handleNextButton:(id)_node inContext:(WOContext *)_ctx;
- (id)_handleLastButton:(id)_node inContext:(WOContext *)_ctx;

- (id)increaseAutoScrollHeight:(id)_node inContext:(WOContext *)_ctx;
- (id)decreaseAutoScrollHeight:(id)_node inContext:(WOContext *)_ctx;
- (id)increaseBatchSize:(id)_node inContext:(WOContext *)_ctx;
- (id)decreaseBatchSize:(id)_node inContext:(WOContext *)_ctx;

- (void)takeValuesForNode:(id)_node
              fromRequest:(WORequest *)_request
                 forBatch:(int)_batch
               selections:(NSMutableArray *)_selArray
                inContext:(WOContext *)_ctx;
@end

@interface ODR_bind_tableview(Private_JavaScriptAdditions)

- (void)_appendGroupCollapseScript:(WOResponse *)_resp
  inContext:(WOContext *)_ctx;

- (void)jsButton:(WOResponse *)_resp   ctx:(WOContext *)_ctx
            name:(NSString *)_name  button:(NSString *)_button;

- (void)appendJavaScript:(WOResponse *)_resp inContext:(WOContext *)_ctx;

- (void)_appendTableContentAsScript:(id)_node
  toResponse:(WOResponse *)_resp
  inContext:(WOContext *)_ctx;

- (void)_appendScriptLink:(WOResponse *)_response name:(NSString *)_name;

@end /* ODR_bind_tableview(Private_JavaScriptAdditions) */

@interface ODR_bind_tableview(Private_Grouping)

- (BOOL)_showGroupAtIndex:(int)_idx node:(id)_node ctx:(WOContext *)_ctx;
- (void)_setShowGroup:(BOOL)_flag
              atIndex:(int)_idx
                 node:(id)_node
                  ctx:(WOContext *)_ctx;

- (id)_invokeGrouping:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx;

- (void)_appendGroupTitle:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  infos:(NSMutableArray *)_infos
  actionUrl:(NSString *)_actionUrl
  rowSpan:(unsigned)_rowSpan
  groupId:(NSString *)_groupId
  index:(int)_idx;

@end /* ODR_bind_tableview(Private_Grouping) */



#endif /* __NGObjDOM_Dynamic_tableview_Private_H__ */
