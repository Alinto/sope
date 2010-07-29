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

#ifndef __DOMAttribute_H__
#define __DOMAttribute_H__

#include <DOM/DOMNode.h>

/*
  Why is Attr a Node? Can it have children? Can it be a child?
  
  Attr is a Node because its value is actually carried by its children,
  which may be a mixture of Text and EntityReference nodes, and because
  making it a Node allows us to store it in a NamedNodeMap for easy retrieval. 

  The getAttribute method hides this detail by returning a string representing
  the concatenation of all these children, and similarly setAttribute replaces
  the Attr's contents with a single Text node holding the new string. To create
  or manipulate other children of an Attr, you have to access the Attr node
  directly via the getAttributeNode and setAttributeNode methods, or by
  retrieving it from the element's "attributes" NamedNodeMap. 

  Section 1.1.1 of the Level 1 DOM Recommendation gives a list of which nodes
  can be parents and children of which other nodes. Attr is not a legal child
  of any node, so attempts to insert it as one will throw a DOMException
  (HIERARCHY_REQUEST_ERR).

  Note that:
    parentNode, nextSibling, previousSibling always return nil !!!
*/

@interface NGDOMAttribute : NGDOMNodeWithChildren < DOMAttr >
{
  id       element;
  NSString *name;
  NSString *namespaceURI;
  NSString *prefix;
  BOOL     isSpecified;
  NSString *value;
}

@end

@interface NGDOMAttribute(PrivateCtors)
/* use DOMDocument for constructing DOMAttributes ! */

- (id)initWithName:(NSString *)_name;
- (id)initWithName:(NSString *)_name namespaceURI:(NSString *)_uri;

@end

@interface NGDOMAttribute(ObjCValues)

- (NSString *)stringValue;
- (int)intValue;
- (double)doubleValue;

@end /* DOMAttribute(Values) */

#endif /* __DOMAttribute_H__ */
