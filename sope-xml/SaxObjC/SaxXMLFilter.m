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

#include "SaxXMLFilter.h"
#include "common.h"

@implementation SaxXMLFilter

- (id)initWithParent:(id<NSObject,SaxXMLReader>)_parent {
  if ((self = [self init])) {
    [self setParent:_parent];
  }
  return self;
}

- (void)dealloc {
  [self->parent release];
  [super dealloc];
}

- (void)setParent:(id<NSObject,SaxXMLReader>)_parent {
  if (self->parent == _parent)
    return;
  
  [self->parent setContentHandler:nil];
  [self->parent setDTDHandler:nil];
  [self->parent setErrorHandler:nil];
  [self->parent setEntityResolver:nil];

  ASSIGN(self->parent, _parent);
  
  [self->parent setContentHandler:self];
  [self->parent setDTDHandler:self];
  [self->parent setErrorHandler:self];
  [self->parent setEntityResolver:self];
}

- (id<NSObject,SaxXMLReader>)parent {
  return self->parent;
}

/* features & properties */

- (void)setFeature:(NSString *)_name to:(BOOL)_value {
  [self->parent setFeature:_name to:_value];
}
- (BOOL)feature:(NSString *)_name {
  return [self->parent feature:_name];
}

- (void)setProperty:(NSString *)_name to:(id)_value {
  [self->parent setProperty:_name to:_value];
}
- (id)property:(NSString *)_name {
  return [self->parent property:_name];
}

/* handlers */

- (void)setDTDHandler:(id<NSObject,SaxDTDHandler>)_handler {
  ASSIGN(self->dtdHandler, _handler);
}
- (id<NSObject,SaxDTDHandler>)dtdHandler {
  return self->dtdHandler;
}

- (void)setErrorHandler:(id<NSObject,SaxErrorHandler>)_handler {
  ASSIGN(self->errorHandler, _handler);
}
- (id<NSObject,SaxErrorHandler>)errorHandler {
  return self->errorHandler;
}

- (void)setEntityResolver:(id<NSObject,SaxEntityResolver>)_handler {
  ASSIGN(self->entityResolver, _handler);
}
- (id<NSObject,SaxEntityResolver>)entityResolver {
  return self->entityResolver;
}

- (void)setContentHandler:(id<NSObject,SaxContentHandler>)_handler {
  ASSIGN(self->contentHandler, _handler);
}
- (id<NSObject,SaxContentHandler>)contentHandler {
  return self->contentHandler;
}

/* parsing */

- (void)parseFromSource:(id)_source {
  [self->parent parseFromSource:_source];
}
- (void)parseFromSystemId:(NSString *)_sysId {
  [self->parent parseFromSystemId:_sysId];
}

- (void)parseFromSource:(id)_source systemId:(NSString *)_sysId {
  [self->parent parseFromSource:_source systemId:_sysId];
}

/* SaxEntityResolver */

- (id)resolveEntityWithPublicId:(NSString *)_pubId
  systemId:(NSString *)_sysId
{
  return [self->entityResolver resolveEntityWithPublicId:_pubId systemId:_sysId];
}

/* SaxContentHandler */

- (void)startDocument {
  [self->contentHandler startDocument];
}
- (void)endDocument {
  [self->contentHandler endDocument];
}

- (void)startPrefixMapping:(NSString *)_prefix uri:(NSString *)_uri {
  [self->contentHandler startPrefixMapping:_prefix uri:_uri];
}
- (void)endPrefixMapping:(NSString *)_prefix {
  [self->contentHandler endPrefixMapping:_prefix];
}

- (void)startElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
  attributes:(id<SaxAttributes>)_attributes
{
  [self->contentHandler startElement:_localName namespace:_ns
                        rawName:_rawName attributes:_attributes];
}
- (void)endElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
{
  [self->contentHandler endElement:_localName namespace:_ns rawName:_rawName];
}

- (void)characters:(unichar *)_chars length:(int)_len {
  [self->contentHandler characters:_chars length:_len];
}
- (void)ignorableWhitespace:(unichar *)_chars length:(int)_len {
  [self->contentHandler ignorableWhitespace:_chars length:_len];
}
- (void)processingInstruction:(NSString *)_pi data:(NSString *)_data {
  [self->contentHandler processingInstruction:_pi data:_data];
}
- (void)setDocumentLocator:(id<NSObject,SaxLocator>)_locator {
  [self->contentHandler setDocumentLocator:_locator];
}
- (void)skippedEntity:(NSString *)_entityName {
  [self->contentHandler skippedEntity:_entityName];
}

/* error-handler */

- (void)warning:(SaxParseException *)_exception {
  [self->errorHandler warning:_exception];
}
- (void)error:(SaxParseException *)_exception {
  [self->errorHandler error:_exception];
}
- (void)fatalError:(SaxParseException *)_exception {
  [self->errorHandler fatalError:_exception];
}

/* dtd-handler */

- (void)notationDeclaration:(NSString *)_name
  publicId:(NSString *)_pubId
  systemId:(NSString *)_sysId
{
  [self->dtdHandler notationDeclaration:_name publicId:_pubId systemId:_sysId];
}

- (void)unparsedEntityDeclaration:(NSString *)_name
  publicId:(NSString *)_pubId
  systemId:(NSString *)_sysId
  notationName:(NSString *)_notName
{
  [self->dtdHandler unparsedEntityDeclaration:_name
                    publicId:_pubId systemId:_sysId
                    notationName:_notName];
}

@end /* SaxXMLFilter */
