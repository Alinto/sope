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

#ifndef __DOMText_H__
#define __DOMText_H__

#include <DOM/DOMCharacterData.h>

/*
  Why do I get adjacent Text nodes?
  
    The DOM structure model that is created by whatever it is that creates it
    has one Text node per block of text when it starts. The only way you can
    have adjacent Text nodes is as a result of user operations; it is not an
    option for the DOM implementation when it first presents its structure
    model to the user. The normalize method (on the Element interface in
    level 1, but moved to Node for Level 2) will merge all the adjacent Text
    nodes into one again, so they will have the same form as if you wrote out
    the XML or HTML and then read it in again. Note that this will have no
    effect on CDATA Sections.
  
    A filtered view of a document, such as that obtained through use of
    TreeWalker, may have adjacent Text nodes because the intervening Nodes are
    not seen in that view.
*/

@interface NGDOMText : NGDOMCharacterData < DOMText >
{
}

@end

#endif /* __DOMTextNode_H__ */
