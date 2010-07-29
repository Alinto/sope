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

#ifndef __DOMNode_H__
#define __DOMNode_H__

#import <Foundation/NSObject.h>
#include <DOM/DOMProtocols.h>

@class NSMutableArray, NSData;
@class NGDOMDocument;

@interface NGDOMNode : NSObject < DOMNode >
{
}

@end

@interface NGDOMNode(Additions)

- (NSString *)nodeTypeString;
- (NSString *)xmlStringValue;
- (NSData *)xmlDataValue;
- (NSString *)textValue;

@end

@interface NGDOMNodeWithChildren : NGDOMNode
{
@private
  NSMutableArray *childNodes;
}
@end

@interface NSObject(DOMNodePrivate)

- (id)_domNodeBeforeNode:(id)_node;
- (id)_domNodeAfterNode:(id)_node;

- (void)_domNodeRegisterParentNode:(id)_parentNode;
- (void)_domNodeForgetParentNode:(id)_parentNode;

@end

NSString *DOMNodeName(id _node);
NSString *DOMNodeValue(id _node);

#endif /* __DOMNode_H__ */
