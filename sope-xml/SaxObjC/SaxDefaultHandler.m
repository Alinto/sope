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

#include "SaxDefaultHandler.h"
#include "SaxException.h"

@implementation SaxDefaultHandler

/* SaxContentHandler */

- (void)startDocument {
}
- (void)endDocument {
}

- (void)startPrefixMapping:(NSString *)_prefix uri:(NSString *)_uri {
}
- (void)endPrefixMapping:(NSString *)_prefix {
}

- (void)startElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
  attributes:(id<SaxAttributes>)_attributes
{
}
- (void)endElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
{
}

- (void)characters:(unichar *)_chars length:(int)_len {
}
- (void)ignorableWhitespace:(unichar *)_chars length:(int)_len {
}

- (void)processingInstruction:(NSString *)_pi data:(NSString *)_data {
}
- (void)setDocumentLocator:(id<NSObject,SaxLocator>)_locator {
}
- (void)skippedEntity:(NSString *)_entityName {
}

/* SaxDTDHandler */

- (void)notationDeclaration:(NSString *)_name
  publicId:(NSString *)_pubId
  systemId:(NSString *)_sysId
{
}

- (void)unparsedEntityDeclaration:(NSString *)_name
  publicId:(NSString *)_pubId
  systemId:(NSString *)_sysId
  notationName:(NSString *)_notName
{
}

/* SaxEntityResolver */

- (id)resolveEntityWithPublicId:(NSString *)_pubId systemId:(NSString *)_sysId {
  return nil;
}

/* SaxErrorHandler */

- (void)warning:(SaxParseException *)_exception {
}
- (void)error:(SaxParseException *)_exception {
}

- (void)fatalError:(SaxParseException *)_exception {
  [_exception raise];
}

@end /* SaxDefaultHandler */
