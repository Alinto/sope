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

#include "DOMImplementation.h"
#include "DOMDocument.h"
#include "DOMDocumentFragment.h"
#include "common.h"

@implementation NGDOMImplementation

- (id)init {
  self->elementClass  = NSClassFromString(@"NGDOMElement");
  self->textNodeClass = NSClassFromString(@"NGDOMText");
  self->attrClass     = NSClassFromString(@"NGDOMAttribute");
  return self;
}

- (Class)domDocumentClass {
  return [NGDOMDocument class];
}
- (Class)domDocumentTypeClass {
  return NSClassFromString(@"NGDOMDocumentType");
}

- (Class)domElementClass {
  return self->elementClass;
}
- (Class)domElementNSClass {
  return self->elementClass;
}
- (Class)domDocumentFragmentClass {
  return NSClassFromString(@"NGDOMDocumentFragment");
}
- (Class)domTextNodeClass {
  return self->textNodeClass;
}
- (Class)domCommentClass {
  return NSClassFromString(@"NGDOMComment");
}
- (Class)domCDATAClass {
  return NSClassFromString(@"NGDOMCDATA");
}
- (Class)domProcessingInstructionClass {
  return NSClassFromString(@"NGDOMProcessingInstruction");
}
- (Class)domAttributeClass {
  return self->attrClass;
}
- (Class)domAttributeNSClass {
  return self->attrClass;
}
- (Class)domEntityReferenceClass {
  return NSClassFromString(@"NGDOMEntityReference");
}

- (id)createDocumentWithName:(NSString *)_qname
  namespaceURI:(NSString *)_uri
  documentType:(id)_doctype
{
  id doc;
  
  doc = [[[self domDocumentClass] alloc]
	  initWithName:_qname namespaceURI:_uri documentType:_doctype
	  dom:self];
  
  return [doc autorelease];
}

- (id)createDocumentType:(NSString *)_qname
  publicId:(NSString *)_pubId
  systemId:(NSString *)_sysId
{
  id doc;
  
  doc = [[[self domDocumentTypeClass] alloc]
	  initWithName:_qname publicId:_pubId systemId:_sysId dom:self];
  
  return [doc autorelease];
}

@end /* NGDOMImplementation */
