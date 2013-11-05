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

#include "STXSaxDriver.h"
#include "StructuredText.h"
#include "StructuredTextList.h"
#include "StructuredTextListItem.h"
#include "StructuredTextLiteralBlock.h"
#include "StructuredTextHeader.h"
#include "StructuredTextParagraph.h"
#include <SaxObjC/XMLNamespaces.h>
#include "common.h"

static NSString *SaxDeclHandlerProperty =
  @"http://xml.org/sax/properties/declaration-handler";
static NSString *SaxLexicalHandlerProperty =
  @"http://xml.org/sax/properties/lexical-handler";

@interface NSObject(SAX)
- (void)produceSaxEventsOnSTXSaxDriver:(STXSaxDriver *)_sax;
@end

@implementation STXSaxDriver

static BOOL debugOn = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  debugOn = [ud boolForKey:@"STXSaxDriverDebugEnabled"];
}

- (id)init {
  if ((self = [super init])) {
    self->attrs = [[SaxAttributes alloc] init];
  }
  return self;
}

- (void)dealloc {
  [self->context        release];
  [self->attrs          release];
  
  [self->lexicalHandler release];
  [self->contentHandler release];
  [self->errorHandler   release];
  [self->entityResolver release];
  [super dealloc];
}

/* properties */

- (void)setProperty:(NSString *)_name to:(id)_value {
  if ([_name isEqualToString:SaxLexicalHandlerProperty]) {
    [self->lexicalHandler autorelease];
    self->lexicalHandler = [_value retain];
    return;
  }
  if ([_name isEqualToString:SaxDeclHandlerProperty]) {
    return;
  }
  
  [SaxNotRecognizedException raise:@"PropertyException"
                             format:@"don't know property %@", _name];
}
- (id)property:(NSString *)_name {
  if ([_name isEqualToString:SaxLexicalHandlerProperty])
    return self->lexicalHandler;
  if ([_name isEqualToString:SaxDeclHandlerProperty])
    return nil;
  
  [SaxNotRecognizedException raise:@"PropertyException"
                             format:@"don't know property %@", _name];
  return nil;
}

/* features */

- (void)setFeature:(NSString *)_name to:(BOOL)_value {
  return;
#if 0 // be tolerant
  [SaxNotRecognizedException raise:@"FeatureException"
                             format:@"don't know feature %@", _name];
#endif
}
- (BOOL)feature:(NSString *)_name {
  return NO;
}

/* handlers */

- (void)setContentHandler:(id<NSObject,SaxContentHandler>)_handler {
  [self->contentHandler autorelease];
  self->contentHandler = [_handler retain];
}
- (id<NSObject,SaxContentHandler>)contentHandler {
  return self->contentHandler;
}

- (void)setLexicalHandler:(id<NSObject,SaxLexicalHandler>)_handler {
  [self->lexicalHandler autorelease];
  self->lexicalHandler = [_handler retain];
}
- (id<NSObject,SaxLexicalHandler>)lexicalHandler {
  return self->lexicalHandler;
}

- (void)setDTDHandler:(id<NSObject,SaxDTDHandler>)_handler {
}
- (id<NSObject,SaxDTDHandler>)dtdHandler {
  return nil;
}

- (void)setErrorHandler:(id<NSObject,SaxErrorHandler>)_handler {
  [self->errorHandler autorelease];
  self->errorHandler = [_handler retain];
}
- (id<NSObject,SaxErrorHandler>)errorHandler {
  return self->errorHandler;
}

- (void)setEntityResolver:(id<NSObject,SaxEntityResolver>)_handler {
  [self->entityResolver autorelease];
  self->entityResolver = [_handler retain];
}
- (id<NSObject,SaxEntityResolver>)entityResolver {
  return self->entityResolver;
}

/* support */

- (void)_beginTag:(NSString *)_tag {
  [self->contentHandler startElement:_tag namespace:XMLNS_XHTML rawName:_tag
                        attributes:nil /* id<SaxAttributes> */];
}
- (void)_endTag:(NSString *)_tag {
  [self->contentHandler endElement:_tag namespace:XMLNS_XHTML rawName:_tag];
}
- (void)_characters:(NSString *)_chars {
  unichar      *buf;
  unsigned int len;
  
  if ((len = [_chars length]) == 0) // TODO: may or may not be correct
    return;
  
  buf = calloc(len + 4, sizeof(unichar)); // TODO: cache/reuse buffer
  [_chars getCharacters:buf];
  
  [self->contentHandler characters:buf length:len];
  if (buf) free(buf);
}

/* STX delegate */


- (void)appendText:(NSString *)_txt inContext:(NSDictionary *)_ctx {
  [self _characters:_txt];
}

- (void)beginItalicsInContext:(NSDictionary *)_ctx {
  [self _beginTag:@"em"];
}
- (void)endItalicsInContext:(NSDictionary *)_ctx {
  [self _endTag:@"em"];
}

- (void)beginUnderlineInContext:(NSDictionary *)_ctx {
  [self _beginTag:@"u"];
}
- (void)endUnderlineInContext:(NSDictionary *)_ctx {
  [self _endTag:@"u"];
}

- (void)beginBoldInContext:(NSDictionary *)_ctx {
  [self _beginTag:@"strong"];
}
- (void)endBoldInContext:(NSDictionary *)_ctx {
  [self _endTag:@"strong"];
}

- (void)beginPreformattedInContext:(NSDictionary *)_ctx {
  [self _beginTag:@"pre"];
}
- (void)endPreformattedInContext:(NSDictionary *)_ctx {
  [self _endTag:@"pre"];
}

- (void)beginParagraphInContext:(NSDictionary *)_ctx {
  [self _beginTag:@"p"];
}
- (void)endParagraphInContext:(NSDictionary *)_ctx {
  [self _endTag:@"p"];
}

- (NSString *)insertLink:(NSString *)_txt 
  withUrl:(NSString *)_url target:(NSString *)_target 
  inContext:(NSDictionary *)_ctx 
{
  // TODO: need to generate SaxAttributes here
  
  [self->attrs clear];
  [self->attrs 
       addAttribute:@"href" uri:XMLNS_XHTML rawName:@"href"
       type:@"CDATA" value:_url];
  if ([_target length] > 0) {
    [self->attrs
	 addAttribute:@"target" uri:XMLNS_XHTML rawName:@"target"
	 type:@"CDATA" value:_target];
  }

  [self->contentHandler startElement:@"a" namespace:XMLNS_XHTML rawName:@"a"
                        attributes:self->attrs];
  [self _characters:_txt];
  [self _endTag:@"a"];

  // if we return nil, the content will be generated as if it didn't match
  // if we return an empty string, a zero-length string is reported
  return @""; 
}

- (NSString *)insertEmail:(NSString *)_txt withAddress:(NSString *)_link 
  inContext:(NSDictionary *)_ctx 
{
  // TODO: check&implement
#if 0
  [NSString stringWithFormat:@"<a href=\"%@\">%@</a>", anAddress, _txt];
#endif
  return _txt;
}

- (NSString *)insertImage:(NSString *)_title withUrl:(NSString *)_src
  inContext:(NSDictionary *)_ctx 
{
  // TODO: check&implement
#if 0
  [NSString stringWithFormat:@"<img src=\"%@\" title=\"%@\" />", anUrl, _txt];
#endif
  return _title;
}

- (NSString *)insertExtrapolaLink:(NSString *)_txt
  parameters:(NSDictionary *)_paras
  withTarget:(NSString *)_target
  inContext:(NSDictionary *)_ctx 
{
  // TODO: do we want to support that?
  if (debugOn) NSLog(@"insert extrapola link: %@", _txt);
  [self _characters:_txt];
  return nil;
}

- (NSString *)insertDynamicKey:(NSString *)_k inContext:(NSDictionary *)_ctx {
  // TODO: what to do here?
  return [_ctx objectForKey:_k];
}

- (NSString *)insertPreprocessedTextForKey:(NSString *)_k 
  inContext:(NSDictionary *)_ctx 
{
  // TODO: what to do here?
  return [_ctx objectForKey:_k];
}

/* generating element events */

- (void)produceSaxEventsForParagraph:(StructuredTextParagraph *)_p {
  NSString *s;
  
  if (debugOn) NSLog(@"      produce SAX events for paragraph: %@", _p);
  
  s = [_p textParsedWithDelegate:(id)self inContext:self->context];
  if ([s length] > 0) [self _characters:s];
}

- (void)produceSaxEventsForHeader:(StructuredTextHeader *)_h {
  NSString *tagName, *s;
  
  if (debugOn) NSLog(@"      produce SAX events for header: %@", _h);
  
  switch ([_h level]) {
  case 1: tagName = @"h1"; break;
  case 2: tagName = @"h2"; break;
  case 3: tagName = @"h3"; break;
  case 4: tagName = @"h4"; break;
  case 5: tagName = @"h5"; break;
  case 6: tagName = @"h6"; break;
  default:
    tagName = [@"h" stringByAppendingFormat:@"%d", [_h level]];
    break;
  }
  
  [self _beginTag:tagName];
  if ((s = [_h textParsedWithDelegate:(id)self inContext:self->context]))
    [self _characters:s];
  [self _endTag:tagName];
  
  [self produceSaxEventsForElements:[_h elements]];
}

- (void)produceSaxEventsForList:(StructuredTextList *)_list {
  NSString *tagName;
  
  if (debugOn) NSLog(@"      produce SAX events for list: %@", _list);
  switch ([_list typology]) {
    case StructuredTextList_BULLET:     tagName = @"ul"; break;
    case StructuredTextList_ENUMERATED: tagName = @"ol"; break;
    case StructuredTextList_DEFINITION: tagName = @"dl"; break;
    default: tagName = nil;
  }
  
  [self _beginTag:tagName];
  [self produceSaxEventsForElements:[_list elements]];
  [self _endTag:tagName];
}

- (void)produceSaxEventsForListItem:(StructuredTextListItem *)_item {
  NSString *s;
  int typology;
  
  if (debugOn) NSLog(@"        produce SAX events for item: %@", _item);
  
  typology = [[_item list] typology];

  if (typology == StructuredTextList_DEFINITION) {
    [self _beginTag:@"dt"];
    if ((s = [_item titleParsedWithDelegate:(id)self inContext:self->context]))
      [self _characters:s];
    [self _endTag:@"dt"];
  }
  
  switch (typology) {
    case StructuredTextList_BULLET:     [self _beginTag:@"li"]; break;
    case StructuredTextList_ENUMERATED: [self _beginTag:@"li"]; break;
    case StructuredTextList_DEFINITION: [self _beginTag:@"dd"]; break;
  }
  
  if ((s = [_item textParsedWithDelegate:(id)self inContext:self->context])) {
    if (debugOn) NSLog(@"          chars: %d", [s length]);
    [self _characters:s];
  }
  
    if (debugOn) NSLog(@"          elems: %d", [[_item elements] count]);
  [self produceSaxEventsForElements:[_item elements]];
  
  switch (typology) {
    case StructuredTextList_BULLET:     [self _endTag:@"li"]; break;
    case StructuredTextList_ENUMERATED: [self _endTag:@"li"]; break;
    case StructuredTextList_DEFINITION: [self _endTag:@"dd"]; break;
  }
}

- (void)produceSaxEventsForLiteralBlock:(StructuredTextLiteralBlock *)_block {
  [self _beginTag:@"pre"];
  [self _characters:[_block text]];
  [self _endTag:@"pre"];
}

/* generating events */

- (void)produceSaxEventsForElement:(id)_element {
  if (debugOn) NSLog(@"    produce SAX events for element: %@", _element);

  if (_element == nil)
    return;
  
  if ([_element respondsToSelector:@selector(produceSaxEventsOnSTXSaxDriver:)])
    [_element produceSaxEventsOnSTXSaxDriver:self];
  else {
    NSLog(@"Note: cannot handle STX element: %@", _element);
  }
}

- (void)produceSaxEventsForElements:(NSArray *)_elems {
  unsigned int i, c;
  
  if (debugOn)
    NSLog(@"  produce SAX events for elements: %d", [_elems count]);
  for (i = 0, c = [_elems count]; i < c; i++) {
    id currentObject;
    
    currentObject = [_elems objectAtIndex:i];
    if (debugOn) NSLog(@"   element[%d]/%d: %@", i, c, currentObject);
    [self produceSaxEventsForElement:currentObject];
  }
}

- (void)produceSaxEventsForStructuredTextDocument:(StructuredTextDocument *)_d{
  if (debugOn) NSLog(@"  produce SAX events for document: %@", _d);
  [self produceSaxEventsForElements:[_d bodyElements]];
}

- (void)produceSaxEventsForStructuredText:(StructuredText *)_stx 
  systemId:(NSString *)_sysId
{
  if (debugOn) NSLog(@"produce SAX events for: %@", _stx);
  
  [self->contentHandler startDocument];
  
  [self produceSaxEventsForStructuredTextDocument:[_stx document]];

  [self->contentHandler endDocument];
}

/* parsing */

- (void)parseFromString:(NSString *)_str systemId:(NSString *)_sysId {
  StructuredText *stx;
  
  if (_sysId == nil) _sysId = @"<string>";
  stx = [[[StructuredText alloc] initWithString:_str] autorelease];
  
  if (debugOn) NSLog(@"%s: %@: %@", __PRETTY_FUNCTION__, _sysId, stx);
  [self produceSaxEventsForStructuredText:stx systemId:_sysId];
}

- (void)parseFromData:(NSData *)_data systemId:(NSString *)_sysId {
  NSString *s;
  
  if (_sysId == nil) _sysId = @"<data>";
  s = [[NSString alloc] initWithData:_data encoding:NSISOLatin1StringEncoding];
  s = [s autorelease];
  
  [self parseFromString:s systemId:_sysId];
}

- (void)parseFromNSURL:(NSURL *)_url systemId:(NSString *)_sysId {
  NSData *data;
  
  if (_sysId == nil) 
    _sysId = [_url absoluteString];
  
  if ((data = [_url resourceDataUsingCache:NO]) == nil) {
    SaxParseException *e;
    NSDictionary      *ui;
    
    ui = [[NSDictionary alloc] initWithObjectsAndKeys:
                         _url   ? _url   : (NSURL *)@"<nil>",    @"url",
                         _sysId ? _sysId : (NSString *)@"<nil>", @"publicId",
                         self,                                   @"parser",
                         nil];
    
    e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
                               reason:@"could not retrieve URL content"
                               userInfo:ui];
    [ui release]; ui = nil;
    
    [self->errorHandler fatalError:e];
    return;
  }
  
  [self parseFromData:data systemId:_sysId];
}

- (void)parseFromSource:(id)_source systemId:(NSString *)_sysId {
  if (_source == nil) {
    /* no source ??? */
    SaxParseException *e;
    NSDictionary      *ui;
    
    ui = [[NSDictionary alloc] initWithObjectsAndKeys:
                         _sysId ? _sysId : (NSString *)@"<nil>", @"publicId",
                         self,                                   @"parser",
                         nil];
    
    e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
                               reason:@"missing source for parsing!"
                               userInfo:ui];
    [ui release]; ui = nil;
    
    [self->errorHandler fatalError:e];
    return;
  }
  
  if ([_source isKindOfClass:[NSString class]]) {
    [self parseFromString:_source systemId:_sysId];
    return;
  }

  if ([_source isKindOfClass:[NSURL class]]) {
    [self parseFromNSURL:_source systemId:_sysId];
    return;
  }
  
  if ([_source isKindOfClass:[NSData class]]) {
    [self parseFromData:_source systemId:_sysId];
    return;
  }
  
  {
    SaxParseException *e;
    NSDictionary      *ui;
    
    ui = [[NSDictionary alloc] initWithObjectsAndKeys:
                         _source ? _source : (id)@"<nil>",         @"source",
                         _sysId  ? _sysId  : (NSString *)@"<nil>", @"publicId",
                         self,                         @"parser",
                         nil];
    
    e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
                               reason:@"can not handle data-source"
                               userInfo:ui];
    [ui release]; ui = nil;
    
    [self->errorHandler fatalError:e];
    return;
  }
}

- (void)parseFromSource:(id)_source {
  [self parseFromSource:_source systemId:nil];
}
- (void)parseFromSystemId:(NSString *)_sysId {
  NSURL *url;

  if ([_sysId length] == 0) {
    SaxParseException *e;
    NSDictionary *ui;
    
    ui = [NSDictionary dictionaryWithObjectsAndKeys:self, @"parser", nil];
    e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
                               reason:@"missing system-id for parsing!"
                               userInfo:ui];
    [self->errorHandler fatalError:e];
    return;
  }
  
  if ([_sysId rangeOfString:@"://"].length == 0) {
    /* not a URL */
    if (![_sysId isAbsolutePath])
      _sysId = [[NSFileManager defaultManager] currentDirectoryPath];
    url = [[[NSURL alloc] initFileURLWithPath:_sysId] autorelease];
  }
  else
    url = [NSURL URLWithString:_sysId];
  
  [self parseFromSource:url systemId:_sysId];
}

@end /* STXSaxDriver */
