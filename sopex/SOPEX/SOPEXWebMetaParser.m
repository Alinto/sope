/*
  Copyright (C) 2004 Marcus Mueller <znek@mulle-kybernetik.com>

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "SOPEXWebMetaParser.h"

@implementation SOPEXWebMetaParser

+ (id)sharedWebMetaParser {
  static id parser = nil;
  if (parser == nil) parser = [[self alloc] init];
  return parser;
}

- (void)reset {
  [self->meta  removeAllObjects];
  [self->links removeAllObjects];
}
- (void)dealloc {
  [self reset];
  [self->meta  release];
  [self->links release];
  [super dealloc];
}

/* setup */

- (void)parserDidStartDocument:(NSXMLParser *)_parser {
  [self reset];
  
  if (self->meta == nil) 
    self->meta = [[NSMutableDictionary alloc] initWithCapacity:32];
  if (self->links == nil) 
    self->links = [[NSMutableArray alloc] initWithCapacity:32];
}

/* tags */

- (void)parser:(NSXMLParser *)_parser 
  didStartElement:(NSString *)_tag
  namespaceURI:(NSString *)_nsuri
  qualifiedName:(NSString *)_qname
  attributes:(NSDictionary *)_attrs
{
  if ([_tag length] == 4) {
    if ([@"meta" caseInsensitiveCompare:_tag] == NSOrderedSame) {
      // TODO: support <meta rev="made" href="..."/>, http-equiv
      NSString *name, *content;
      
      name    = [_attrs objectForKey:@"name"];
      content = [_attrs objectForKey:@"content"];
      if (name) [self->meta setObject:content ? content : @"" forKey:name];
    }
    else if ([@"link" caseInsensitiveCompare:_tag] == NSOrderedSame) {
      // attrs: type(text/css), rel(styleshet), href(...)
      if (_attrs) [self->links addObject:_attrs];
    }
  }
}

- (void)parser:(NSXMLParser *)_parser 
  didEndElement:(NSString *)_tag
  namespaceURI:(NSString *)_nsuri
  qualifiedName:(NSString *)_qname
{
  unichar c;
  
  c = [_tag characterAtIndex:0]; // assume that a tag has at least one char
  if (!(c == 'h' || c == 'H'))
    return;
  if ([_tag length] != 4)
    return;
  if ([_tag isEqualToString:@"head"]) {
    /* only look at HEAD section */
    [_parser abortParsing];
  }
}

/* high level */

- (void)processHTML:(NSString *)_html 
  meta:(NSDictionary **)_meta
  links:(NSArray **)_links
{
  NSAutoreleasePool *pool;
  
  if ([_html length] == 0) {
    if (_meta)  *_meta  = nil;
    if (_links) *_links = nil;
    return;
  }
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    NSXMLParser *parser;
    NSData      *xmlData;
    
    xmlData = [_html dataUsingEncoding:NSUTF8StringEncoding];
    parser  = [[[NSXMLParser alloc] initWithData:xmlData] autorelease];
    [parser setDelegate:self];
    [parser parse];
    
    if (_meta)  *_meta  = [self->meta  copy];
    if (_links) *_links = [self->links copy];
    [self reset];
  }
  [pool release];
  
  if (_meta)  [*_meta  autorelease];
  if (_links) [*_links autorelease];
}

@end /* SOPEXWebMetaParser */
