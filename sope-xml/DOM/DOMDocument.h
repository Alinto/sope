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

#ifndef __DOMDocument_H__
#define __DOMDocument_H__

#include <DOM/DOMNode.h>

@class NSString, NSArray;
@class NGDOMImplementation;

@interface NGDOMDocument : NGDOMNodeWithChildren < DOMDocument >
{
  NSString          *qname;
  NSString          *uri;
  id                doctype;
  NGDOMImplementation *dom;
  
  NSArray           *errors;
  NSArray           *warnings;
}

+ (id)documentFromData:(NSData *)_data;
+ (id)documentFromString:(NSString *)_string;
+ (id)documentFromURI:(NSString *)_uri;

/* errors/warnings */

- (void)addErrors:(NSArray *)_errors;
- (void)addWarnings:(NSArray *)_errors;

@end

@interface NGDOMDocument(DocumentTraversal)

- (id)createNodeIterator:(id)_node
  whatToShow:(unsigned long)_whatToShow
  filter:(id)_filter;

- (id)createTreeWalker:(id)_node
  whatToShow:(unsigned long)_whatToShow
  filter:(id)_filter
  expandEntityReferences:(BOOL)_expandEntityReferences;

@end

@interface NGDOMDocument(PrivateCtors)

/* use DOMImplementation for constructing DOMDocument ! */

- (id)initWithName:(NSString *)_qname
  namespaceURI:(NSString *)_uri
  documentType:(id)_doctype
  dom:(NGDOMImplementation *)_dom;

@end

#endif /* __DOMDocument_H__ */
