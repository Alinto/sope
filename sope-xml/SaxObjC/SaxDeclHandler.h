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

#ifndef __SaxDeclHandler_H__
#define __SaxDeclHandler_H__

@class NSString;

/*
  new in SAX 2.0beta

  In Java this class is in the ext-package, that is,
  implementation is optional.

  SAX2 extension handler for DTD declaration events. 

  This is an optional extension handler for SAX2 to provide information
  about DTD declarations in an XML document. XML readers are not required
  to support this handler.

  Note that data-related DTD declarations (unparsed entities and notations)
  are already reported through the DTDHandler interface.

  If you are using the declaration handler together with a lexical handler,
  all of the events will occur between the startDTD and the endDTD events.

  To set the DeclHandler for an XML reader, use the setProperty method with
  the propertyId "http://xml.org/sax/handlers/DeclHandler". If the reader
  does not support declaration events, it will throw a
  SAXNotRecognizedException or a SAXNotSupportedException when you attempt
  to register the handler.
*/

@protocol SaxDeclHandler

/*
  Report an attribute type declaration.
  
  Only the effective (first) declaration for an attribute will be
  reported. The type will be one of the strings "CDATA", "ID", "IDREF",
  "IDREFS", "NMTOKEN", "NMTOKENS", "ENTITY", "ENTITIES", or "NOTATION",
  or a parenthesized token group with the separator "|" and all whitespace
  removed.

  valueDefault - A string representing the attribute default ("#IMPLIED",
  "#REQUIRED", or "#FIXED") or nil if none of these applies
*/
- (void)attributeDeclaration:(NSString *)_attributeName
  elementName:(NSString *)_elementName
  type:(NSString *)_type
  defaultType:(NSString *)_defType
  defaultValue:(NSString *)_defValue;

/*
  Report an attribute type declaration.
  
  Only the effective (first) declaration for an attribute will be
  reported. The type will be one of the strings "CDATA", "ID", "IDREF",
  "IDREFS", "NMTOKEN", "NMTOKENS", "ENTITY", "ENTITIES", or "NOTATION",
  or a parenthesized token group with the separator "|" and all whitespace
  removed.

  If it is a parameter entity, the name will begin with '%'.
*/
- (void)elementDeclaration:(NSString *)_name contentModel:(NSString *)_model;

/*
  Report a parsed external entity declaration.
  
  Only the effective (first) declaration for each entity will be reported.

  If it is a parameter entity, the name will begin with '%'.
*/
- (void)externalEntityDeclaration:(NSString *)_name
  publicId:(NSString *)_pub
  systemId:(NSString *)_sys;

/*
  Report an internal entity declaration.
  
  Only the effective (first) declaration for each entity will be reported.

  If it is a parameter entity, the name will begin with '%'.
*/
- (void)internalEntityDeclaration:(NSString *)_name value:(NSString *)_value;

@end

#endif /* __SaxDeclHandler_H__ */
