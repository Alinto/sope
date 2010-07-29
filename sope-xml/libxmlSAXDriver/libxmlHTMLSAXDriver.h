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

#include <libxml/encoding.h>

#include <SaxObjC/SaxXMLReader.h>
#include <SaxObjC/SaxLexicalHandler.h>
#include <SaxObjC/SaxDeclHandler.h>

/*
  recognized properties:
    http://xml.org/sax/properties/declaration-handler
    http://xml.org/sax/properties/lexical-handler
    http://www.skyrix.com/sax/properties/html-namespace
*/

@class libxmlSAXLocator;

@interface libxmlHTMLSAXDriver : NSObject < SaxXMLReader >
{
  NSObject<SaxContentHandler> *contentHandler;
  id<NSObject,SaxDTDHandler>     dtdHandler;
  id<NSObject,SaxErrorHandler>   errorHandler;
  id<NSObject,SaxEntityResolver> entityResolver;
  
  id<NSObject,SaxLexicalHandler> lexicalHandler;
  id<NSObject,SaxDeclHandler>    declHandler;
  
  NSString *namespaceURI;
  unsigned depth;
  BOOL     encodeEntities;
  libxmlSAXLocator *locator;
  
  /* libxml */
  void *doc;
  void *ctxt;
  SaxAttributes *attributes;
}

@end
