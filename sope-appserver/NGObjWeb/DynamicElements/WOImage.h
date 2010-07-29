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

#ifndef __NGObjWeb_DynElems_WOImage_H__
#define __NGObjWeb_DynElems_WOImage_H__

#include <NGObjWeb/WOHTMLDynamicElement.h>

/*
  WOImage is a class cluster with separate subclasses for the different
  image types (dynamic, element, external and resource - image).
  
  Note: WOImage is a class cluster!
  
  WOImage associations:
    otherTagString
    filename
    framework
    src
    value
    data
    mimeType
    key

  TODO: add support for "?" parameters?
*/

@interface WOImage : WOHTMLDynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
}

@end /* WOImage */

@interface WOImage(Privates)

- (NSString *)associationDescription;

@end

#endif /* __NGObjWeb_DynElems_WOImage_H__ */
