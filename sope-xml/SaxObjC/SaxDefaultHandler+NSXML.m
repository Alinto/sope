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

@implementation SaxDefaultHandler(NSXML)

static BOOL doDebug = NO;

- (void)parserDidStartDocument:(id)_parser {
  if (doDebug) NSLog(@"parser: startdoc %@", _parser);
  [self startDocument];
}
- (void)parserDidEndDocument:(id)_parser {
  if (doDebug) NSLog(@"parser: endoc    %@", _parser);
  [self endDocument];
}

- (id<NSObject,SaxAttributes>)_wrapAttributes:(NSDictionary *)_attrs {
  // TODO: implement ..
  return [[SaxAttributes alloc] initWithDictionary:_attrs];
}

- (void)parser:(id)_parser 
  didStartElement:(NSString *)_tag 
  namespaceURI:(NSString *)_nsuri 
  qualifiedName:(NSString *)_rawName 
  attributes:(NSDictionary *)_attrs
{
  id<NSObject,SaxAttributes> attrs;

  if ([_rawName length] == 0) _rawName = _tag;
  if (doDebug) 
    NSLog(@"parser: start %@ raw %@ uri %@", _tag, _rawName, _nsuri);
  
  attrs = [self _wrapAttributes:_attrs];
  [self startElement:_tag namespace:_nsuri rawName:_rawName
        attributes:attrs];
  [attrs release];
}

- (void)parser:(id)_parser 
  didEndElement:(NSString *)_tag 
  namespaceURI:(NSString *)_nsuri
  qualifiedName:(NSString *)_rawName
{
  if ([_rawName length] == 0) _rawName = _tag;
  if (doDebug) 
    NSLog(@"parser: end %@ raw %@ uri %@", _tag, _rawName, _nsuri);
  [self endElement:_tag namespace:_nsuri rawName:_rawName];
}

- (void)parser:(id)_parser 
  didStartMappingPrefix:(NSString *)_prefix 
  toURI:(NSString *)_uri
{
  [self startPrefixMapping:_prefix uri:_uri];
}
- (void)parser:(id)_parser didEndMappingPrefix:(NSString *)_prefix {
  [self endPrefixMapping:_prefix];
}

- (void)parser:(id)_parser foundCharacters:(NSString *)_string {
  /* Note: expensive ..., decompose string into chars */
  int     len;
  unichar *buf = NULL;
  
  if ((len = [_string length]) > 0) {
    buf = calloc(len + 2, sizeof(unichar));
    [_string getCharacters:buf];
  }
  [self characters:buf length:len];
  if (buf) free(buf);
}
- (void)parser:(id)_parser foundIgnorableWhitespace:(NSString *)_ws {
  /* Note: expensive ..., decompose string into chars */
  int     len;
  unichar *buf = NULL;
  
  if ((len = [_ws length]) > 0) {
    buf = calloc(len + 2, sizeof(unichar));
    [_ws getCharacters:buf];
  }
  [self ignorableWhitespace:buf length:len];
  if (buf) free(buf);
}

- (void)parser:(id)_parser foundCDATA:(NSData *)_data {
  /* TODO: what about that? */
  NSLog(@"ERROR(%s): CDATA section ignored!", __PRETTY_FUNCTION__);
}

#if 0 /* TODO: implement */
- (void)parser:(id)_parser foundComment:(NSString *)comment {
}
#endif

- (void)parser:(id)_parser 
  foundProcessingInstructionWithTarget:(NSString *)_target 
  data:(NSString *)_data
{
  [self processingInstruction:_target data:_data];
}

/* entity resolver */

- (NSData *)parser:(id)_parser 
  resolveExternalEntityName:(NSString *)_name 
  systemID:(NSString *)_sysId
{
  return [self resolveEntityWithPublicId:_name systemId:_sysId];
}

/* handle errors */

- (SaxParseException *)_wrapErrorIntoException:(NSError *)_error {
  // TODO: perform proper wrapping or conversion
  return (id)_error;
}

- (void)parser:(id)_parser parseErrorOccurred:(NSError *)_error {
  if (doDebug) NSLog(@"parser: error %@", _error);
  [self error:[self _wrapErrorIntoException:_error]];
}
- (void)parser:(id)_parser validationErrorOccurred:(NSError *)_error {
  if (doDebug) NSLog(@"parser: validation error %@", _error);
  [self error:[self _wrapErrorIntoException:_error]];
}

/* DTD processing */

- (void)parser:(id)_parser 
  foundNotationDeclarationWithName:(NSString *)_name 
  publicID:(NSString *)_pubId systemID:(NSString *)_sysId
{
  [self notationDeclaration:_name publicId:_pubId systemId:_sysId];
}

- (void)parser:(id)_parser 
  foundUnparsedEntityDeclarationWithName:(NSString *)_name 
  publicID:(NSString *)_pubId systemID:(NSString *)_sysId
  notationName:(NSString *)_notName
{
  [self unparsedEntityDeclaration:_name
        publicId:_pubId systemId:_sysId
        notationName:_notName];
}

#if 0 /* TODO: DTD processing ... */

- (void)parser:(id)_parser 
  foundAttributeDeclarationWithName:(NSString *)attributeName 
  forElement:(NSString *)_tag type:(NSString *)type 
  defaultValue:(NSString *)defaultValue;

- (void)parser:(id)_parser 
  foundElementDeclarationWithName:(NSString *)_tag model:(NSString *)model;

- (void)parser:(id)_parser 
  foundInternalEntityDeclarationWithName:(NSString *)name 
  value:(NSString *)value;

- (void)parser:(id)_parser 
  foundExternalEntityDeclarationWithName:(NSString *)name 
  publicID:(NSString *)publicID systemID:(NSString *)systemID;

#endif

@end /* SaxDefaultHandler(NSXML) */
