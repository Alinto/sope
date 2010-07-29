/*
  Copyright (C) 2004 eXtrapola Srl

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

#ifndef __StructuredTextList_H__
#define __StructuredTextList_H__

#include "StructuredTextBodyElement.h"

#define StructuredTextList_BULLET	0
#define StructuredTextList_ENUMERATED	1
#define StructuredTextList_DEFINITION	2

@class StructuredTextListItem;

@interface StructuredTextList : StructuredTextBodyElement
{
  int typology;
}

- (id)initWithTypology:(int)aValue;

/* accessors */

- (int)typology;

/* operations */

- (void)addElement:(StructuredTextListItem *)anItem;

@end

#endif /* __StructuredTextList_H__ */
