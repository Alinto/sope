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

#ifndef __DOM_DOMNodeQueryPath_H__
#define __DOM_DOMNodeQueryPath_H__

#include <DOM/DOMNode.h>
#include <DOM/DOMQueryPathExpression.h>

/*
  Perform query path lookups on a DOM node. Look into DOMQueryPathExpression
  for the actual path syntax.
*/

@class NSString, NSArray;

@interface NGDOMNode(QueryPath)

/* Evaluate a stack of path specifiers. */
- (id)lookupPathComponents:(NSArray *)_path;

/* Same like above using a string */
- (id)lookupQueryPath:(NSString *)_path;

@end

#endif /* __DOM_DOMNodeQueryPath_H__ */
