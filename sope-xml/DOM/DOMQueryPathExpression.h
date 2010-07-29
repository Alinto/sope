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

#ifndef __DOMQueryPathExpression_H__
#define __DOMQueryPathExpression_H__

#import <Foundation/NSObject.h>

@class NSString, NSArray;

@interface DOMQueryPathExpression : NSObject

/*
  Syntax:
    
    First the QueryPath is separated into path components, then the path
    components are evaluated:
    
    '-'   - placed in front of the path component, makes the search flat
    '/'   - select DOM root node (usually the document-element)
    '.'   - select current node
    '..'  - select DOM parent node
    '*'   - select all child elements (either deep or non-deep)
    '!x'  - evaluate keypath 'x' on node
    '?x'  - lookup processing instruction 'x' (either deep or non-deep)
    '@x'  - lookup attribute 'x',
              if x is '*', select all attributes (the map)
              x may contain a ':' for namespace queries
    
    any other string: select a child-node with the string as the name.

  Samples:

    "./head/title" - lookup the 'title' node contained in the 'head' child node
    "./@name"      - lookup the 'name' attribute of the current node
    "./?blah"      - lookup the PI 'blah' starting with the current node
    "./!values"    - call 'valueForKey:@"values"' on the current node
    "/-title"      - flat search for 'title' element
*/

+ (id)queryPathWithString:(NSString *)_string;
+ (id)queryPathWithComponents:(NSArray *)_string;
+ (NSArray *)queryPathComponentsOfString:(NSString *)_path;

- (id)evaluateWithNode:(id)_node; // DEPRECATED !!!
- (id)evaluateWithNodeList:(id)_nodeList;

@end

#endif /* __DOMQueryPathExpression_H__ */
