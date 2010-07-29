/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#ifndef __NGObjWeb_DynElem_WOForm_H__
#define __NGObjWeb_DynElem_WOForm_H__

#include <NGObjWeb/WOHTMLDynamicElement.h>

@class WOAssociation;

@interface WOForm : WOHTMLDynamicElement
{
@protected
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
  
  WOAssociation *action;
  WOAssociation *href;
  WOAssociation *pageName;
  WOElement     *template;

  /* new in WO4: */
  WOAssociation *queryDictionary;
  NSDictionary  *queryParameters;  /* associations beginning with '?' */
  WOAssociation *actionClass;
  WOAssociation *directActionName;
  BOOL          sidInUrl;          /* include session-id in wa URL ? */
  
  /* SOPE specific */
  WOAssociation *method;
  WOAssociation *fragmentIdentifier;
}

@end

#endif /* __NGObjWeb_DynElem_WOForm_H__ */
