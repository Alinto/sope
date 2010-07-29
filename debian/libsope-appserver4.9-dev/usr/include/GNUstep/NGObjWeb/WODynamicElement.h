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

#ifndef __NGObjWeb_WODynamicElement_H__
#define __NGObjWeb_WODynamicElement_H__

#include <NGObjWeb/WOElement.h>

@class NSArray, NSDictionary;
@class WOElement, WOAssociation;

struct _WOExtraAttrStruct;

@interface WODynamicElement : WOElement
{
@private
  /* attribute mappings which aren't parsed */
  struct _WOExtraAttrStruct *extraAttributes;
  
@protected
  WOAssociation  *otherTagString;  /* new in WO4 */
  BOOL           containsForm;
@private
  BOOL           debug;            /* new in WO4 */
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_associations
  template:(WOElement *)_childElement;

/* this method was discovered in the SSL example and might be private ! */
- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_associations
  contentElements:(NSArray *)_children;

@end

@interface WODynamicElement(PrivateMethods)

- (void)setExtraAttributes:(NSDictionary *)_extras;
- (void)appendExtraAttributesToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx;

- (id)template;

@end

#endif /* __NGObjWeb_WODynamicElement_H__ */
