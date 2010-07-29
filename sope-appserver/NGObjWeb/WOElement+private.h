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

#ifndef __NGObjWeb_WOElement_private_H__
#define __NGObjWeb_WOElement_private_H__

#include <NGObjWeb/WOElement.h>
#include <NGObjWeb/WOAssociation.h>
#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOSession.h>
#include "WOResponse+private.h"

@class WOComponent, WOForm;

@interface WOElement(PrivateMethods)

/* naming */

- (NSString *)stringForInt:(int)_i;

/* typing */

+ (BOOL)isDynamicElement;

/* tree output */

- (NSString *)indentString:(int)_indent;
- (NSString *)elementTreeWithIndent:(int)_indent;
- (NSString *)elementTree;

@end

@interface WOElement(QueryString)

- (NSString *)queryStringForQueryDictionary:(NSDictionary *)_queryDict
  andQueryParameters:(NSDictionary *)_paras
  inContext:(WOContext *)_ctx;

@end

@interface WOElement(DynamicForms)

- (void)_containsForm; // notifies the element that a form was added

@end

#endif /* __NGObjWeb_WOElement_private_H__ */
