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

#ifndef __DOMElement_H__
#define __DOMElement_H__

#include <DOM/DOMNode.h>

/*
  Why is there no removeAttributeNodeNS method?
  
  There is, but it's called removeAttributeNode. 

  We needed both setAttributeNode and setAttributeNodeNS, because those
  functions use different rules to select which (if any) existing Attr the
  new one will replace. setAttributeNode bases this decision on the nodeName,
  while setAttributeNodeNS looks at the combination of namespaceURI and
  localname. However, when you remove a specific Attr Node, its nodeName,
  localname, and namespaceURI are ignored, and there's no need for a second
  method to support this. 
*/

@class NSString, NSMutableDictionary, NSMutableArray;

@interface NGDOMElement : NGDOMNodeWithChildren < DOMElement >
{
  id                  parent;
  NSString            *tagName;
  NSMutableDictionary *keyToAttribute;
  NSMutableArray      *attributes;
  
  NSString *namespaceURI;
  NSString *prefix;

  /* positional info */
  unsigned line;
  
  /* caches */
  id attrNodeMap;
}

@end

@interface NGDOMElement(PrivateCtors)
/* use DOMDocument for constructing DOMElements ! */

- (id)initWithTagName:(NSString *)_tagName;
- (id)initWithTagName:(NSString *)_tagName namespaceURI:(NSString *)_uri;

@end

#endif /* __DOMElement_H__ */
