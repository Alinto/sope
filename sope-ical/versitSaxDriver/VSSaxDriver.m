/*
  Copyright (C) 2003-2004 Max Berger
  Copyright (C) 2004-2005 OpenGroupware.org
 
  This file is part of versitSaxDriver, written for the OpenGroupware.org 
  project (OGo).
  
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

#include "VSSaxDriver.h"
#include "VSStringFormatter.h"
#include <SaxObjC/SaxException.h>
#include <NGExtensions/NGQuotedPrintableCoding.h>
#include "common.h"

@interface VSSaxTag : NSObject
{
@private
  char          type;
  NSString      *tagName;
  NSString      *group;
@public
  SaxAttributes *attrs;
  unichar       *data;
  unsigned int  datalen;
}

+ (id)beginTag:(NSString *)_tag group:(NSString *)_group
  attributes:(SaxAttributes *)_attrs;
- (id)initEndTag:(NSString *)_tag;

- (id)initWithContentString:(NSString *)_data;

- (NSString *)tagName;
- (NSString *)group;
- (BOOL)isStartTag;
- (BOOL)isEndTag;
- (BOOL)isTag;

@end

@implementation VSSaxTag

+ (id)beginTag:(NSString *)_tag group:(NSString *)_group
  attributes:(SaxAttributes *)_attrs
{
  VSSaxTag *tag;

  tag = [[[self alloc] init] autorelease];
  tag->type    = 'B';
  tag->tagName = [_tag copy];
  tag->group   = [_group copy];
  tag->attrs   = [_attrs retain];
  return tag;
}
- (id)initEndTag:(NSString *)_tag {
  self->type    = 'E';
  self->tagName = [_tag copy];
  return self;
}
- (id)initWithContentString:(NSString *)_data {
  if (_data == nil) {
    [self release];
    return nil;
  }
  
  self->datalen = [_data length];
  self->data    = calloc(self->datalen + 1, sizeof(unichar));
  [_data getCharacters:self->data range:NSMakeRange(0, self->datalen)];
  return self;
}

- (void)dealloc {
  if (self->data) free(self->data);
  [self->group   release];
  [self->tagName release];
  [self->attrs   release];
  [super dealloc];
}

/* accessors */

- (NSString *)tagName {
  return self->tagName;
}
- (NSString *)group {
  return self->group;
}

- (BOOL)isStartTag {
  return self->type == 'B' ? YES : NO;
}
- (BOOL)isEndTag {
  return self->type == 'E' ? YES : NO;
}
- (BOOL)isTag {
  return (self->type == 'B' || self->type == 'E') ? YES : NO;
}

@end /* VSSaxTag */

@implementation VSSaxDriver

static BOOL debugOn = NO;

static NSCharacterSet *dotCharSet                     = nil;
static NSCharacterSet *equalSignCharSet               = nil;
static NSCharacterSet *commaCharSet                   = nil;
static NSCharacterSet *colonAndSemicolonCharSet       = nil;
static NSCharacterSet *colonSemicolonAndDquoteCharSet = nil;
static NSCharacterSet *whitespaceCharSet              = nil;

static VSStringFormatter *stringFormatter = nil;

+ (void)initialize {
  static BOOL didInit = NO;
  NSUserDefaults *ud;

  if (didInit)
    return;
  didInit = YES;

  ud      = [NSUserDefaults standardUserDefaults];
  debugOn = [ud boolForKey:@"VSSaxDriverDebugEnabled"];

  dotCharSet =
    [[NSCharacterSet characterSetWithCharactersInString:@"."] retain];
  equalSignCharSet =
    [[NSCharacterSet characterSetWithCharactersInString:@"="] retain];
  commaCharSet =
    [[NSCharacterSet characterSetWithCharactersInString:@","] retain];
  colonAndSemicolonCharSet =
    [[NSCharacterSet characterSetWithCharactersInString:@":;"] retain];
  colonSemicolonAndDquoteCharSet =
    [[NSCharacterSet characterSetWithCharactersInString:@":;\""] retain];
  whitespaceCharSet =
    [[NSCharacterSet whitespaceCharacterSet] retain];

  stringFormatter = [VSStringFormatter sharedFormatter];
}


- (id)init {
  if ((self = [super init])) {
    self->prefixURI         = @"";
    self->cardStack         = [[NSMutableArray alloc]      initWithCapacity:4];
    self->elementList       = [[NSMutableArray alloc]      initWithCapacity:8];
    self->attributeMapping  = [[NSMutableDictionary alloc] initWithCapacity:8];
    self->subItemMapping    = [[NSMutableDictionary alloc] initWithCapacity:8];
  }
  return self;
}

- (void)dealloc {
  [self->contentHandler    release];
  [self->errorHandler      release];
  [self->prefixURI         release];
  [self->cardStack         release];
  [self->elementList       release];
  [self->attributeElements release];
  [self->elementMapping    release];
  [self->attributeMapping  release];
  [self->subItemMapping    release];
  [super dealloc];
}

/* accessors */

- (void)setFeature:(NSString *)_name to:(BOOL)_value {
}
- (BOOL)feature:(NSString *)_name {
  return NO;
}

- (void)setProperty:(NSString *)_name to:(id)_value {
}
- (id)property:(NSString *)_name {
  return nil;
}

/* handlers */

- (void)setContentHandler:(id<NSObject,SaxContentHandler>)_handler {
  ASSIGN(self->contentHandler, _handler);
}

- (void)setDTDHandler:(id<NSObject,SaxDTDHandler>)_handler {
  // FIXME
}

- (void)setErrorHandler:(id<NSObject,SaxErrorHandler>)_handler {
  ASSIGN(self->errorHandler, _handler);
}
- (void)setEntityResolver:(id<NSObject,SaxEntityResolver>)_handler {
  // FIXME
}

- (id<NSObject,SaxContentHandler>)contentHandler {
  return self->contentHandler;
}

- (id<NSObject,SaxDTDHandler>)dtdHandler {
  // FIXME
  return nil;
}

- (id<NSObject,SaxErrorHandler>)errorHandler {
  return self->errorHandler;
}
- (id<NSObject,SaxEntityResolver>)entityResolver {
  // FIXME
  return nil;
}

- (void)setPrefixURI:(NSString *)_uri {
  ASSIGNCOPY(self->prefixURI, _uri);
}
- (NSString *)prefixURI {
  return self->prefixURI;
}

- (void)setAttributeElements:(NSSet *)_elements {
  ASSIGNCOPY(self->attributeElements, _elements);
}
- (NSSet *)attributeElements {
  return self->attributeElements;
}

- (void)setElementMapping:(NSDictionary *)_mapping {
  ASSIGNCOPY(self->elementMapping, _mapping);
}
- (NSDictionary *)elementMapping {
  return self->elementMapping;
}

- (void)setAttributeMapping:(NSDictionary *)_mapping {
  [self setAttributeMapping:_mapping forElement:@""];
}

- (void)setAttributeMapping:(NSDictionary *)_mapping 
  forElement:(NSString *)_element 
{
  if (_element == nil)
    _element = @"";
  [attributeMapping setObject:_mapping forKey:_element];
}

- (void)setSubItemMapping:(NSArray *)_mapping forElement:(NSString *)_element {
  [subItemMapping setObject:_mapping forKey:_element];  
}



/* parsing */

- (NSString *)_groupFromTagName:(NSString *)_tagName {
  NSRange  r;
  
  r = [_tagName rangeOfCharacterFromSet:dotCharSet];
  if (r.length == 0)
    return nil;
  
  return [_tagName substringToIndex:r.location];
}

- (NSString *)_mapTagName:(NSString *)_tagName {
  NSString *ret;
  NSRange  r;

  if ((ret = [self->elementMapping objectForKey:_tagName]) != nil)
    return ret;

  //NSLog(@"Unknown Key: %@ in %@",_tagName,self->elementMapping);
  ret = _tagName;
  
  /*
    This is to allow parsing of vCards produced by Apple
    Addressbook.
    The dot-notation is described as 'grouping' in RFC 2425, section 5.8.2.
  */
  r = [_tagName rangeOfCharacterFromSet:dotCharSet];
  if (r.length > 0)
    ret = [self _mapTagName:[_tagName substringFromIndex:(r.location + 1)]];
  
  return ret;
}

- (NSString *)_mapAttrName:(NSString *)_attrName forTag:(NSString *)_tagName {
  NSDictionary *tagMap;
  NSString *mappedName;

  /* check whether we have a attr-map stored under the element-name */
  tagMap = [self->attributeMapping objectForKey:_tagName];
  if ((mappedName = [tagMap objectForKey:_attrName]) != nil)
    return mappedName;
  
  /* check whether we have a attr-map stored under the mapped element-name */
  tagMap = [self->attributeMapping objectForKey:[self _mapTagName:_tagName]];
  if ((mappedName = [tagMap objectForKey:_attrName]) != nil)
    return mappedName;

  /* check whether we have a global attr-map */
  tagMap = [self->attributeMapping objectForKey:@""];
  if ((mappedName = [tagMap objectForKey:_attrName]) != nil)
    return mappedName;
  
  /* return the name as-is */
  return _attrName;
}

- (void)_parseAttr:(NSString *)_attr 
  forTag:(NSString *)_tagName
  intoAttr:(NSString **)attr_
  intoValue:(NSString **)value_
{
  NSRange  r;
  NSString *attrName, *attrValue, *mappedName;
  
  r = [_attr rangeOfCharacterFromSet:equalSignCharSet];
  if (r.length > 0) {
    unsigned left, right;

    attrName  = [[_attr substringToIndex:r.location] uppercaseString];
    left = NSMaxRange(r);
    right = [_attr length] - 1;
    if (left < right) {
      if (([_attr characterAtIndex:left]  == '"') &&
         ([_attr characterAtIndex:right] == '"'))
      {
        left += 1;
        r = NSMakeRange(left, right - left);
        attrValue = [_attr substringWithRange:r];
      }
      else {
        attrValue = [_attr substringFromIndex:left];
      }
    }
    else if (left == right) {
      attrValue = [_attr substringFromIndex:left];
    }
    else {
      attrValue = @"";
    }
  }
  else {
    attrName  = @"TYPE";
    attrValue = _attr;
  }
  
#if 0
  // ZNeK: what's this for?
  r = [attrValue rangeOfCharacterFromSet:commaCharSet];
  while (r.length > 0) {
    [attrValue replaceCharactersInRange:r withString:@" "];
    r = [attrValue rangeOfCharacterFromSet:commaCharSet];
  }
#endif

  mappedName = [self _mapAttrName:attrName forTag:_tagName];
  *attr_ = mappedName;
  *value_ = [stringFormatter stringByUnescapingRFC2445Text:attrValue];
}

- (SaxAttributes *)_mapAttrs:(NSArray *)_attrs forTag:(NSString *)_tagName {
  SaxAttributes       *retAttrs;
  NSEnumerator        *attrEnum;
  NSString            *curAttr, *mappedAttr, *mappedValue, *oldValue;
  NSMutableDictionary *attributes;

  if (_attrs == nil || [_attrs count] == 0)
    return nil;
  
  attributes = [[NSMutableDictionary alloc] initWithCapacity:4];
  retAttrs   = [[[SaxAttributes alloc] init] autorelease];
  
  attrEnum = [_attrs objectEnumerator];
  while ((curAttr = [attrEnum nextObject]) != nil) {
    [self _parseAttr:curAttr
          forTag:_tagName
          intoAttr:&mappedAttr
          intoValue:&mappedValue];
    if ((oldValue = [attributes objectForKey:mappedAttr]) != nil) {
      NSString *val;
      
      /* ZNeK: duh! */
      // TODO: hh asks: what does 'duh' is supposed to mean?
      val = [[NSString alloc] initWithFormat:@"%@ %@",oldValue, mappedValue];
      [attributes setObject:val forKey:mappedAttr];
      [val release];
    }
    else  
      [attributes setObject:mappedValue forKey:mappedAttr];
  }

  attrEnum = [attributes keyEnumerator];
  while ((curAttr = [attrEnum nextObject]) != nil) {
    /*
      TODO: values are not always mapped to CDATA! Eg in the dawson draft:
        | TYPE for TEL   | tel.type   | NMTOKENS  | 'VOICE'         |
        | TYPE for EMAIL | email.type | NMTOKENS  | 'INTERNET'      |
        | TYPE for PHOTO,| img.type   | CDATA     | REQUIRED        |
        |  and LOGO      |            |           |                 |
        | TYPE for SOUND | aud.type   | CDATA     | REQUIRED        |
        | VALUE          | value      | NOTATION  | See elements    |
    */
    
    [retAttrs addAttribute:curAttr uri:self->prefixURI rawName:curAttr
	      type:@"CDATA" value:[attributes objectForKey:curAttr]];
  }
  
  [attributes release];
  
  return retAttrs;
}

- (VSSaxTag *)_beginTag:(NSString *)_tagName group:(NSString *)_group
  withAttrs:(SaxAttributes *)_attrs
{
  VSSaxTag *tag;
  
  tag = [VSSaxTag beginTag:_tagName group:_group attributes:_attrs];
  [self->elementList addObject:tag];
  return tag;
}

- (void)_endTag:(NSString *)_tagName {
  VSSaxTag *tag;
  
  tag = [[VSSaxTag alloc] initEndTag:_tagName];
  [self->elementList addObject:tag];
  [tag release]; tag = nil;
}

- (void)_addSubItems:(NSArray *)_items group:(NSString *)_group
  withData:(NSString *)_content
{
  NSEnumerator *itemEnum, *contentEnum;
  NSString *subTag;
  
  itemEnum    = [_items objectEnumerator];
  contentEnum = [[_content componentsSeparatedByString:@";"] objectEnumerator];
  
  while ((subTag = [itemEnum nextObject]) != nil) {
    NSString *subContent;
    
    subContent = [contentEnum nextObject];
    
    [self _beginTag:subTag group:_group withAttrs:nil];
    if ([subContent length] > 0) {
      VSSaxTag *a;
      
      a = [(VSSaxTag*)[VSSaxTag alloc] initWithContentString:subContent];
      if (a != nil) {
	[self->elementList addObject:a];
	[a release];
      }
    }
    [self _endTag:subTag];
  }
}

- (void)_reportContentAsTag:(NSString *)_tagName
  group:(NSString *)_group
  withAttrs:(SaxAttributes *)_attrs 
  andContent:(NSString *)_content 
{
  /*
    This is called for all non-BEGIN|END types.
  */
  NSArray *subItems;
  
  _content = [stringFormatter stringByUnescapingRFC2445Text:_content];

  /* check whether type should be reported as an attribute in XML */
  
  if ([self->attributeElements containsObject:_tagName]) {
    /* 
       Add tag as an attribute to last component in the cardstack. This is
       stuff like the "VERSION" type contained in a "BEGIN:VCARD" which will
       be reported as <vcard version=""> (as an attribute of the container).
    */
    VSSaxTag *element;
    
    element = [self->cardStack lastObject];
    [element->attrs addAttribute:_tagName uri:self->prefixURI
	            rawName:_tagName type:@"CDATA" value:_content];
    return;
  }

  /* report type as an XML tag */
  
  [self _beginTag:_tagName group:_group withAttrs:_attrs];
  
  if ([_content length] > 0) {
    if ((subItems = [self->subItemMapping objectForKey:_tagName]) != nil) {
      [self _addSubItems:subItems group:_group withData:_content];
    }
    else {
      VSSaxTag *a;
      
      a = [(VSSaxTag *)[VSSaxTag alloc] initWithContentString:_content];
      if (a != nil) {
	[self->elementList addObject:a];
	[a release];
      }
    }
  }

  [self _endTag:_tagName];
}

/* report events for collected elements */

- (void)reportStartGroup:(NSString *)_group {
  SaxAttributes *attrs;
  
  attrs = [[SaxAttributes alloc] init];
  [attrs addAttribute:@"name" uri:self->prefixURI rawName:@"name"
	 type:@"CDATA" value:_group];
  
  [self->contentHandler startElement:@"group" namespace:self->prefixURI
                        rawName:@"group" attributes:attrs];
  [attrs release];
}
- (void)reportEndGroup {
  [self->contentHandler endElement:@"group" namespace:self->prefixURI
                        rawName:@"group"];
}

- (void)reportQueuedTags {
  /*
    Why does the parser need the list instead of reporting the events
    straight away?
    
    Because some vCard tags like the 'version' are reported as attributes
    on the container tag. So we have a sequence like:
      BEGIN:VCARD
      ...
      VERSION:3.0
    which will get reported as:
      <vcard version="3.0">
  */
  NSEnumerator *enu;
  VSSaxTag *tagToReport;
  NSString *lastGroup;
  
  lastGroup = nil;
  enu = [self->elementList objectEnumerator];
  while ((tagToReport = [enu nextObject]) != nil) {
    if ([tagToReport isStartTag]) {
      NSString *tg;
      
      tg = [tagToReport group];
      if (![lastGroup isEqualToString:tg] && lastGroup != tg) {
	if (lastGroup != nil) [self reportEndGroup];
	ASSIGNCOPY(lastGroup, tg);
	if (lastGroup != nil) [self reportStartGroup:lastGroup];
      }
    }
    
    if ([tagToReport isStartTag]) {
      [self->contentHandler startElement:[tagToReport tagName]
                            namespace:self->prefixURI
                            rawName:[tagToReport tagName]
                            attributes:tagToReport->attrs];
    }
    else if ([tagToReport isEndTag]) {
      [self->contentHandler endElement:[tagToReport tagName]
                            namespace:self->prefixURI
                            rawName:[tagToReport tagName]];
    }
    else {
      [self->contentHandler characters:tagToReport->data
                            length:tagToReport->datalen];
    }
  }
  
  /* flush event group */
  [self->elementList removeAllObjects];
  
  /* close open groups */
  if (lastGroup != nil) {
    [self reportEndGroup];
    [lastGroup release]; lastGroup = nil;
  }
}

/* errors */

- (void)reportError:(NSString *)_text {
  SaxParseException *e;

  e = (id)[SaxParseException exceptionWithName:@"SaxParseException"
			     reason:_text
			     userInfo:nil];
  [self->errorHandler error:e];
}
- (void)warn:(NSString *)_warn {
  SaxParseException *e;

  e = (id)[SaxParseException exceptionWithName:@"SaxParseException"
			     reason:_warn
			     userInfo:nil];
  [self->errorHandler warning:e];
}

/* parsing raw string */

- (void)_beginComponentWithValue:(NSString *)tagValue {
  VSSaxTag *tag;
  
  tag = [self _beginTag:[self _mapTagName:tagValue]
	      group:nil
	      withAttrs:[[[SaxAttributes alloc] init] autorelease]];
  [self->cardStack addObject:tag];
}

- (void)_endComponent:(NSString *)tagName value:(NSString *)tagValue {
  NSString *mtName;
    
  mtName = [self _mapTagName:tagValue];
  if ([self->cardStack count] > 0) {
      NSString *expectedName;
      
      expectedName = [(VSSaxTag *)[self->cardStack lastObject] tagName];
      if (![expectedName isEqualToString:mtName]) {
	NSString *s;
	
	// TODO: rather report an error?
	// TODO: setup userinfo dict with details
	s = [NSString stringWithFormat:
			@"Found end tag '%@' which does not match expected "
		        @"name '%@'!"
		        @" Tag '%@' has not been closed properly. Given "
		        @"document contains errors!",
		        mtName, expectedName, expectedName];
	[self reportError:s];
	
        /* probably futile attempt to parse anyways */
        if (debugOn) {
          NSLog(@"%s trying to fix previous error by inserting bogus end "
                @"tag.",
                __PRETTY_FUNCTION__);
        }
        [self _endTag:expectedName];
        [self->cardStack removeLastObject];
      }
  }
  else {
      // TOOD: generate error?
      [self reportError:[@"found end tag without any open tags left: "
		   stringByAppendingString:mtName]];
  }
  [self _endTag:mtName];
  [self->cardStack removeLastObject];
    
  /* report parsed elements */
    
  if ([self->cardStack count] == 0)
    [self reportQueuedTags];
}

- (void)_parseLine:(NSString *)_line {
  NSString       *tagName, *tagValue;
  NSMutableArray *tagAttributes;
  NSRange        r, todoRange;
  unsigned       length;
  
#if 0
  if (debugOn)
    NSLog(@"%s: parse line: '%@'", __PRETTY_FUNCTION__, _line);
#endif

  length    = [_line length];
  todoRange = NSMakeRange(0, length);
  r = [_line rangeOfCharacterFromSet:colonAndSemicolonCharSet
             options:0
             range:todoRange];
  /* is line well-formed? */
  if (r.length == 0 || r.location == 0) {
#if 0
    NSLog(@"todo-range: %i-%i, range: %i-%i, length %i, str-class %@",
          todoRange.location, todoRange.length,
          r.location, r.length,
          length, NSStringFromClass([_line class]));
#endif

    [self reportError:
            [@"got an improper content line! (did not find colon) ->\n" 
              stringByAppendingString:_line]];
    return;
  }
  
  /* tagname is everything up to a ':' or  ';' (value or parameter) */
  tagName       = [[_line substringToIndex:r.location] uppercaseString];
  tagAttributes = [[NSMutableArray alloc] initWithCapacity:16];
  
  if (debugOn && ([tagName length] == 0)) {
    [self reportError:[@"got an improper content line! ->\n" 
		  stringByAppendingString:_line]];
    return;
  }
  
  /* 
     possible shortcut: if we spotted a ':', we don't have to do "expensive"
     argument scanning/processing.
  */
  if ([_line characterAtIndex:r.location] != ':') {
    BOOL isAtEnd    = NO;
    BOOL isInDquote = NO;
    unsigned start;
    
    start     = NSMaxRange(r);
    todoRange = NSMakeRange(start, length - start);
    while(!isAtEnd) {
      BOOL skip = YES;

      /* scan for parameters */
      r = [_line rangeOfCharacterFromSet:colonSemicolonAndDquoteCharSet
                 options:0
                 range:todoRange];
      
      /* is line well-formed? */
      if (r.length == 0 || r.location == 0) {
	[self reportError:[@"got an improper content line! ->\n" 
		      stringByAppendingString:_line]];
        [tagAttributes release]; tagAttributes = nil;
        return;
      }
      
      /* first check if delimiter candidate is escaped */
      if ([_line characterAtIndex:(r.location - 1)] != '\\') {
        unichar delimiter;
        NSRange copyRange;

        delimiter = [_line characterAtIndex:r.location];
        if (delimiter == '\"') {
          /* not a real delimiter - toggle isInDquote for proper escaping */
          isInDquote = !isInDquote;
        }
        else {
          if (!isInDquote) {
            /* is a delimiter, which one? */
            skip = NO;
            if (delimiter == ':') {
              isAtEnd = YES;
            }
            copyRange = NSMakeRange(start, r.location - start);
            [tagAttributes addObject:[_line substringWithRange:copyRange]];
            if (!isAtEnd) {
              /* adjust start, todoRange */
              start     = NSMaxRange(r);
              todoRange = NSMakeRange(start, length - start);
            }
          }
        }
      }
      if (skip) {
        /* adjust todoRange */
        unsigned offset = NSMaxRange(r);
        todoRange = NSMakeRange(offset, length - offset);
      }
    }
  }
  tagValue = [_line substringFromIndex:NSMaxRange(r)];
  
  if (debugOn && ([tagName length] == 0)) {
    NSLog(@"%s: missing tagname in line: '%@'", 
          __PRETTY_FUNCTION__, _line);
  }
  
  /*
    At this point we have:
      name:       'BEGIN', 'TEL', 'EMAIL', 'ITEM1.ADR' etc
      value:      ';;;Magdeburg;;;Germany'
      attributes: ("type=INTERNET", "type=HOME", "type=pref")
  */

#if 0
#  warning DEBUG LOG ENABLED
  NSLog(@"TAG: %@, value %@ attrs %@",
        tagName, tagValue, tagAttributes);
#endif
  
  /* process tag */
  
  if ([tagName isEqualToString:@"BEGIN"]) {
    if ([tagAttributes count] > 0)
      [self warn:@"Losing unexpected parameters of BEGIN line."];
    [self _beginComponentWithValue:tagValue];
  }
  else if ([tagName isEqualToString:@"END"]) {
    if ([tagAttributes count] > 0)
      [self warn:@"Losing unexpected parameters of END line."];
    [self _endComponent:tagName value:tagValue];
  }
  else {
    /* a regular content tag */
    
    /* 
       check whether the tga value is encoded in quoted printable,
       this one is used with Outlook vCards (see data/ for examples)
    */
    // TODO: make the encoding check more generic
    if ([tagAttributes containsObject:@"ENCODING=QUOTED-PRINTABLE"]) {
      // TODO: QP is charset specific! The one below decodes in Unicode!
      tagValue = [tagValue stringByDecodingQuotedPrintable];
      [tagAttributes removeObject:@"ENCODING=QUOTED-PRINTABLE"];
    }
    
    [self _reportContentAsTag:[self _mapTagName:tagName]
	  group:[self _groupFromTagName:tagName]
	  withAttrs:[self _mapAttrs:tagAttributes forTag:tagName]
	  andContent:tagValue];
  }
  
  [tagAttributes release];
}


/* top level parsing method */

- (void)reportDocStart {
  [self->contentHandler startDocument];
  [self->contentHandler startPrefixMapping:@"" uri:self->prefixURI];
}
- (void)reportDocEnd {
  [self->contentHandler endPrefixMapping:@""];
  [self->contentHandler endDocument];
}

- (void)_parseString:(NSString *)_rawString {
  /*
    This method split the string into content lines for actual vCard
    parsing.

    RFC2445:
     contentline        = name *(";" param ) ":" value CRLF
     ; When parsing a content line, folded lines MUST first
     ; be unfolded
  */
  NSMutableString *line;
  unsigned pos, length;
  NSRange  r;

  [self reportDocStart];
  
  /* start parsing */
  
  length = [_rawString length];
  r      = NSMakeRange(0, 0);
  line   = [[NSMutableString alloc] initWithCapacity:75 + 2];
  
  for (pos = 0; pos < length; pos++) {
    unichar c;
    
    c = [_rawString characterAtIndex:pos];
    
    if (c == '\r') {
      if (((length - 1) - pos) >= 1) {
        if ([_rawString characterAtIndex:pos + 1] == '\n') {
          BOOL isAtEndOfLine = YES;
	  
          /* test for folding first */
          if (((length - 1) - pos) >= 2) {
            unichar ws;
	    
	    ws = [_rawString characterAtIndex:pos + 2];
            isAtEndOfLine = [whitespaceCharSet characterIsMember:ws] ? NO :YES;
            if (!isAtEndOfLine) {
              /* assemble part of line up to pos */
              if (r.length > 0) {
                [line appendString:[_rawString substringWithRange:r]];
              }
              /* unfold */
              pos += 2;
              r = NSMakeRange(pos + 1, 0); /* begin new range */
            }
          }
          if (isAtEndOfLine) {
            /* assemble part of line up to pos */
            if (r.length > 0) {
              [line appendString:[_rawString substringWithRange:r]];
            }
            [self _parseLine:line];
            /* reset line */
            [line deleteCharactersInRange:NSMakeRange(0, [line length])];
            pos += 1;
            r = NSMakeRange(pos + 1, 0); /* begin new range */
          }
        }
      }
      else {
        /* garbled last line! */
	[self warn:@"last line is truncated, trying to parse anyways!"];
      }
    }
    else if (c == '\n') { /* broken, non-standard */
      BOOL isAtEndOfLine = YES;
      
      /* test for folding first */
      if (((length - 1) - pos) >= 1) {
        unichar ws;
	
	ws = [_rawString characterAtIndex:(pos + 1)];
	
        isAtEndOfLine = [whitespaceCharSet characterIsMember:ws] ? NO : YES;
        if (!isAtEndOfLine) {
          /* assemble part of line up to pos */
          if (r.length > 0) {
            [line appendString:[_rawString substringWithRange:r]];
          }
          /* unfold */
          pos += 1;
          r = NSMakeRange(pos + 1, 0); /* begin new range */
        }
      }
      if (isAtEndOfLine) {
        /* assemble part of line up to pos */
        if (r.length > 0) {
          [line appendString:[_rawString substringWithRange:r]];
        }
        [self _parseLine:line];
        /* reset line */
        [line deleteCharactersInRange:NSMakeRange(0, [line length])];
        r = NSMakeRange(pos + 1, 0); /* begin new range */
      }
    }
    else {
      r.length += 1;
    }
  }
  if (r.length > 0) {
    [self warn:@"Last line of parse string is not properly terminated!"];
    [line appendString:[_rawString substringWithRange:r]];
    [self _parseLine:line];
  }
  
  if ([self->cardStack count] != 0) {
    [self warn:@"found elements on cardStack. This indicates an improper "
            @"nesting structure! Not all required events will have been "
            @"generated, leading to unpredictable results!"];
    [self->cardStack removeAllObjects]; // clean up
  }
  
  [line release]; line = nil;
  
  [self reportDocEnd];
}

/* main entry functions */

- (id)sourceForData:(NSData *)_data systemId:(NSString *)_sysId {
  SaxParseException *e = nil;
  NSStringEncoding encoding;
  unsigned len;
  const unsigned char *bytes;
  id source;
  
  if (debugOn) {
    NSLog(@"%s: trying to decode data (0x%p,len=%d) ...",
	    __PRETTY_FUNCTION__, _data, [_data length]);
  }
  
  if ((len = [_data length]) == 0) {
    e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
			       reason:@"Got no parsing data!"
			       userInfo:nil];
    [self->errorHandler fatalError:e];
    return nil;
  }
  if (len < 10) {
    e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
			       reason:@"Input data to short for vCard!"
			       userInfo:nil];
    [self->errorHandler fatalError:e];
    return nil;
  }
  
  bytes = [_data bytes];
  if ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
      (bytes[0] == 0xFE && bytes[1] == 0xFF)) {
    encoding = NSUnicodeStringEncoding;
  }
  else
    encoding = NSUTF8StringEncoding;
  
  // FIXME: Data is not always utf-8.....
  source = [[[NSString alloc] initWithData:_data encoding:encoding]
	     autorelease];
  if (source == nil) {
    e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
			       reason:@"Could not convert input to string!"
			       userInfo:nil];
    [self->errorHandler fatalError:e];
  }
  return source;
}

- (void)parseFromSource:(id)_source systemId:(NSString *)_sysId {
  if (debugOn)
    NSLog(@"%s: parse: %@ (sysid=%@)", __PRETTY_FUNCTION__, _source, _sysId);
  
  if ([_source isKindOfClass:[NSURL class]]) {
    NSURL *url;

    url = _source;
    if (_sysId == nil) _sysId = [url absoluteString];

    if (debugOn) {
      NSLog(@"%s: trying to load URL: %@ (sysid=%@)",__PRETTY_FUNCTION__, 
	    url, _sysId);
    }
    
    // TODO: remember encoding of source
    _source = [url resourceDataUsingCache:NO];
    if (_source == nil || ![_source length]) {
      SaxParseException *e;
      NSString          *s;
    
      if (debugOn) 
        NSLog(@"%s: got no data from url: %@", __PRETTY_FUNCTION__, url);
    
      s = [NSString stringWithFormat:@"got no data from url: %@", url]; 
      e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
                                 reason:s
                                 userInfo:nil];
      [self->errorHandler fatalError:e];
      return;
    }
  }
  
  if ([_source isKindOfClass:[NSData class]]) {
    if (_sysId == nil) _sysId = @"<data>";
    if ((_source = [self sourceForData:_source systemId:_sysId]) == nil)
      return;
  }

  if (![_source isKindOfClass:[NSString class]]) {
    SaxParseException *e;
    NSString *s;
    
    if (debugOn) 
      NSLog(@"%s: unrecognizable source: %@", __PRETTY_FUNCTION__,_source);
    
    s = [@"cannot handle data-source: " stringByAppendingString:
	    [_source description]];
    e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
                               reason:s
                               userInfo:nil];
    
    [self->errorHandler fatalError:e];
    return;
  }

  /* ensure consistent state */

  [self->cardStack   removeAllObjects];
  [self->elementList removeAllObjects];
  
  /* start parsing */
  
  if (debugOn) {
    NSLog(@"%s: trying to parse string (0x%p,len=%d) ...",
	  __PRETTY_FUNCTION__, _source, [_source length]);
  }
  if (_sysId == nil) _sysId = @"<string>";
  [self _parseString:_source];
  
  /* tear down */
  
  [self->cardStack   removeAllObjects];
  [self->elementList removeAllObjects];
}

- (void)parseFromSource:(id)_source {
  [self parseFromSource:_source systemId:nil];
}

- (void)parseFromSystemId:(NSString *)_sysId {
  NSURL *url;
  
  if ([_sysId rangeOfString:@"://"].length == 0) {
    /* seems to be a path, path to be a proper URL */
    url = [NSURL fileURLWithPath:_sysId];
  }
  else {
    /* Note: Cocoa NSURL doesn't complain on "/abc/def" like input! */
    url = [NSURL URLWithString:_sysId];
  }
  
  if (url == nil) {
    SaxParseException *e;
    
    e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
                               reason:@"cannot handle system-id"
                               userInfo:nil];
    [self->errorHandler fatalError:e];
    return;
  }
  
  [self parseFromSource:url systemId:_sysId];
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* VersitSaxDriver */
