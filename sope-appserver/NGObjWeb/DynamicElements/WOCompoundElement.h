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

#ifndef __NGObjWeb_DynElm_WOCompoundElement_H__
#define __NGObjWeb_DynElm_WOCompoundElement_H__

#import <NGObjWeb/WODynamicElement.h>

/*
  This is a FINAL class, do not subclass !
*/

@class NSArray;

@interface WOCompoundElement : WODynamicElement
{
@private
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
  
  unsigned short count;
  id children[1];
}

+ (id)allocForCount:(int)_count zone:(NSZone *)_zone;
- (id)initWithContentElements:(NSArray *)_elements;
- (id)initWithChildren:(NSArray *)_children; // deprecated

@end

@interface WOHTMLStaticGroup : WOCompoundElement

/* this element was discovered in SSLContainer.h and may not be public */

@end

#endif /* __NGObjWeb_DynElm_WOCompoundElement_H__ */
