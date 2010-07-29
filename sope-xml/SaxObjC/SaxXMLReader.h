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

#ifndef __SaxXMLReader_H__
#define __SaxXMLReader_H__

#import <Foundation/NSObject.h>
#include <SaxObjC/SaxContentHandler.h>
#include <SaxObjC/SaxDTDHandler.h>
#include <SaxObjC/SaxErrorHandler.h>
#include <SaxObjC/SaxEntityResolver.h>

/*
  new in SAX 2.0beta, replaces SaxParser

  Interface for reading an XML document using callbacks. 

  This is a common interface that can be shared by many XML parsers. This
  interface allows an application to set and query features and properties
  in the parser, to register event handlers for document processing, and to
  initiate a document parse.

  This interface replaces the (now deprecated) SAX 1.0 Parser interface; it
  currently extends Parser to aid in the transition to SAX2, but it will
  likely not do so in any future versions of SAX.

  The Reader interface contains two important enhancements over the old
  Parser interface:

    1. it adds a standard way to query and set features and properties; and 
    2. it adds Namespace support, which is required for many higher-level XML
       standards. 

  There are adapters available to convert a SAX1 Parser to a SAX2 XMLReader
  and vice-versa.
*/

@protocol SaxXMLReader

/* features & properties */

- (void)setFeature:(NSString *)_name to:(BOOL)_value;
- (BOOL)feature:(NSString *)_name;
- (void)setProperty:(NSString *)_name to:(id)_value;
- (id)property:(NSString *)_name;

/* handlers */

- (void)setContentHandler:(id<NSObject,SaxContentHandler>)_handler;
- (void)setDTDHandler:(id<NSObject,SaxDTDHandler>)_handler;
- (void)setErrorHandler:(id<NSObject,SaxErrorHandler>)_handler;
- (void)setEntityResolver:(id<NSObject,SaxEntityResolver>)_handler;
- (id<NSObject,SaxContentHandler>)contentHandler;
- (id<NSObject,SaxDTDHandler>)dtdHandler;
- (id<NSObject,SaxErrorHandler>)errorHandler;
- (id<NSObject,SaxEntityResolver>)entityResolver;

/* parsing */

- (void)parseFromSource:(id)_source;
- (void)parseFromSource:(id)_source systemId:(NSString *)_sysId;
- (void)parseFromSystemId:(NSString *)_sysId;

@end

#endif /* __SaxXMLReader_H__ */
