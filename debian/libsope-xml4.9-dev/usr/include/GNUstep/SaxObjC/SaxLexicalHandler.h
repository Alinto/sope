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

#ifndef __SaxLexicalHandler_H__
#define __SaxLexicalHandler_H__

#import <Foundation/NSString.h>

/*
  new in SAX 2.0beta

  SAX2 extension handler for lexical events. 

  This is an optional extension handler for SAX2 to provide lexical
  information about an XML document, such as comments and CDATA section
  boundaries; XML readers are not required to support this handler.

  The events in the lexical handler apply to the entire document, not
  just to the document element, and all lexical handler events must
  appear between the content handler's startDocument and endDocument
  events.

  To set the LexicalHandler for an XML reader, use the setProperty method
  with the propertyId "http://xml.org/sax/handlers/LexicalHandler". If
  the reader does not support lexical events, it will throw a
  SAXNotRecognizedException or a SAXNotSupportedException when you attempt
  to register the handler.
*/

@protocol SaxLexicalHandler

/*
  Report an XML comment anywhere in the document.
  
  This callback will be used for comments inside or outside the document
  element, including comments in the external DTD subset (if read).
*/
- (void)comment:(unichar *)_chars length:(int)_len;

/*
  Report the start of DTD declarations, if any.
  
  Any declarations are assumed to be in the internal subset unless
  otherwise indicated by a startEntity event.

  Note that the start/endDTD events will appear within the
  start/endDocument events from ContentHandler and before the first
  startElement event.
*/
- (void)startDTD:(NSString *)_name
  publicId:(NSString *)_pub
  systemId:(NSString *)_sys;

/* Report the end of DTD declarations. */
- (void)endDTD;

/*
  Report the beginning of an entity in content.
  
  NOTE: entity references in attribute values -- and the start and end
  of the document entity -- are never reported.

  The start and end of the external DTD subset are reported using the
  pseudo-name "[dtd]". All other events must be properly nested within
  start/end entity events.

  Note that skipped entities will be reported through the skippedEntity
  event, which is part of the ContentHandler interface.

  If it is a parameter entity, the name will begin with '%'.
*/
- (void)startEntity:(NSString *)_name;

/* report the end of an entity */
- (void)endEntity:(NSString *)_name;

/*
  Report the start of a CDATA section.
  
  The contents of the CDATA section will be reported through the regular
  characters event.
*/
- (void)startCDATA;

/* Report the end of a CDATA section */
- (void)endCDATA;

@end

#endif /* __SaxLexicalHandler_H__ */
