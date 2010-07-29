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

#ifndef __ODNodeRenderer_attributes_H__
#define __ODNodeRenderer_attributes_H__

#include <NGObjDOM/ODNodeRenderer.h>

@interface ODNodeRenderer(attributes)

/* evaluate attributes depending on the namespace */
- (BOOL)boolFor:(NSString *)_attr         node:(id)_node ctx:(id)_ctx;
- (int)intFor:(NSString *)_attr           node:(id)_node ctx:(id)_ctx;
- (id)valueFor:(NSString *)_attr          node:(id)_node ctx:(id)_ctx;
- (NSString *)stringFor:(NSString *)_attr node:(id)_node ctx:(id)_ctx;

- (void)setBool:(BOOL)_value for:(NSString *)_attr node:(id)_node ctx:(id)_ctx;
- (void)setInt:(int)_value   for:(NSString *)_attr node:(id)_node ctx:(id)_ctx;
- (void)setValue:(id)_value  for:(NSString *)_attr node:(id)_node ctx:(id)_ctx;
- (void)setString:(NSString *)_value
  for:(NSString *)_attrName
  node:(id)_node
  ctx:(id)_ctx;

- (void)forceSetValue:(id)_v  for:(NSString *)_attr node:(id)_n ctx:(id)_ctx;
- (void)forceSetBool:(BOOL)_v for:(NSString *)_attr node:(id)_n ctx:(id)_ctx;
- (void)forceSetInt:(int)_v   for:(NSString *)_attr node:(id)_n ctx:(id)_ctx;
- (void)forceSetString:(NSString *)_v
  for:(NSString *)_attrName
  node:(id)_node
  ctx:(id)_ctx;

- (BOOL)isSettable:(NSString *)_attr node:(id)_node ctx:(id)_ctx;
- (BOOL)hasAttribute:(NSString *)_attr node:(id)_node ctx:(id)_ctx;

- (NSString *)stringForInt:(int)_int;

/* evaluate associations (looks for 'special' namespaces) */

- (id)valueForAttributeNode:(id)_attrNode inContext:(id)_ctx;
- (id)invokeValueForAttributeNode:(id)_attrNode inContext:(id)_ctx;

@end

#endif /* __ODNodeRenderer_attributes_H__ */
