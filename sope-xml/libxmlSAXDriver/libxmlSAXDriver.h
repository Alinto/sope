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

#ifndef __libxmlSAXDriver_H__
#define __libxmlSAXDriver_H__

#import <Foundation/NSObject.h>
#include <SaxObjC/SaxXMLReader.h>
#include <SaxObjC/SaxContentHandler.h>
#include <SaxObjC/SaxDTDHandler.h>
#include <SaxObjC/SaxErrorHandler.h>
#include <SaxObjC/SaxEntityResolver.h>
#include <SaxObjC/SaxLexicalHandler.h>
#include <SaxObjC/SaxLocator.h>
#include <SaxObjC/SaxDeclHandler.h>

@class NSMutableArray;
@class SaxAttributes;

@class libxmlSAXLocator;

@interface libxmlSAXDriver : NSObject < SaxXMLReader >
{
@private
  id<NSObject,SaxContentHandler> contentHandler;
  id<NSObject,SaxDTDHandler>     dtdHandler;
  id<NSObject,SaxErrorHandler>   errorHandler;
  id<NSObject,SaxEntityResolver> entityResolver;
  
  id<NSObject,SaxLexicalHandler> lexicalHandler;
  id<NSObject,SaxDeclHandler>    declHandler;
  
  void           *sax;    /* ptr to libxml sax structure */
  void           *ctxt;   /* libxml parser context */
  void           *entity; /* used during entity lookup */
  
  int            depth;
  NSMutableArray *nsStack;
  BOOL           fNamespaces;
  BOOL           fNamespacePrefixes;
  
  /* cache */
  libxmlSAXLocator *locator;
  SaxAttributes    *attrs;
}

@end

#endif /* __libxmlSAXDriver_H__ */
