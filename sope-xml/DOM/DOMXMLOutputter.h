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

#ifndef __DOMXMLOutputter_H__
#define __DOMXMLOutputter_H__

#import <Foundation/NSObject.h>
#include <DOM/DOMNode.h>

/*
  DOMXMLOutputter
  
  Class to generate a text representation of an DOM node to stdout.
*/

@class NSMutableArray;

@interface DOMXMLOutputter : NSObject
{
  NSMutableArray *stack;
  unsigned indent;
}

- (void)outputNode:(id<DOMNode>)_node to:(id)_target;
- (void)outputDocument:(id)_document to:(id)_target;

@end

#endif /* __DOMXMLOutputter_H__ */
