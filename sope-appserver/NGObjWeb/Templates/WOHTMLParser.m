/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#include "WOHTMLParser.h"
#include <NGObjWeb/WODynamicElement.h>
#include <NGObjWeb/WOElement.h>
#include "common.h"

/*
  Internals
  
  The root parse function is _parseElement() which calls either 
  _parseWOElement() or _parseHashElement() if it finds a NGObjWeb tag at the 
  beginning of the buffer. 
  If it doesn't it collects all content till it encounteres an NGObjWeb tag, 
  and reports that content as "static text" to the callback.
  
  Parsing a dynamic element is:
    - parse the start tag
    - parse the attributes
    - parse the contents, static strings and elements
      - add content to a children array
    - produce WOElement by calling
      -dynamicElementWithName:attributes:contentElements:
    - parse close tag
*/

@interface WOElement(StaticStringElement)
- (id)initWithBuffer:(const char *)_buffer length:(unsigned)_len;
@end

@implementation WOHTMLParser

static WOElement *_parseElement(NSZone *_zone,
                                const unichar *_buffer, unsigned *_idx,
                                unsigned _len, NSException **_exception,
                                WOHTMLParser *self);

static Class StrClass      = Nil;
static Class DictClass     = Nil;
static Class NumberClass   = Nil;
static Class WOStringClass = Nil;
static BOOL  skipPlainTags = NO; /* do process markers inside HTML tags ? */
static BOOL  compressHTMLWhitespace = YES;
static BOOL  useUTF8 = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  StrClass      = [NSString            class];
  DictClass     = [NSMutableDictionary class];
  NumberClass   = [NSNumber            class];
  WOStringClass = NSClassFromString(@"_WOStaticHTMLElement");

  useUTF8       = [ud boolForKey:@"WOParsersUseUTF8"];
}

- (id)initWithHandler:(id<NSObject,WOHTMLParserHandler>)_handler {
  self->callback = [_handler retain];
  return self;
}
- (void)dealloc {
  [self->parsingException release];
  [self->callback         release];
  [super dealloc];
}

/* callbacks */

- (NSException *)_makeSyntaxErrorException {
  return [NSException exceptionWithName:@"SyntaxError"
                      reason:@"template syntax error"
                      userInfo:nil];
}

- (WOElement *)dynamicElementWithName:(NSString *)_element
  attributes:(NSDictionary *)_attributes // not the associations !
  contentElements:(NSArray *)_subElements
{
  return [self->callback dynamicElementWithName:_element
                         attributes:_attributes
                         contentElements:_subElements];
}

- (id)_makeConstantStringElementWithBuffer:(const unichar *)_buf
  length:(unsigned)_len
{
  return [[WOStringClass allocWithZone:NULL] 
	   initWithCharacters:_buf length:_len];
}

/* accessors */

- (NSException *)parsingException {
  return self->parsingException;
}

/* parsing API */

- (NSStringEncoding)stringEncodingForData:(NSData *)_data  {
  // TODO: we could check for UTF-16 marker in front of data
  return useUTF8 ? NSUTF8StringEncoding : [NSString defaultCStringEncoding];
}

- (NSArray *)parseHTMLData:(NSData *)_html {
  NSMutableArray *topLevel;
  const unichar  *html;
  unsigned       idx, len;
  NSException    *exception = nil;
  unichar        *buf;
  unsigned int   bufLen;
  NSString       *s;
  
  if (![self->callback parser:self willParseHTMLData:_html])
    return nil;
  
  [self->parsingException release]; self->parsingException = nil;
  
  if (_html == nil)
    return nil;
  
  /* recode buffer using NSString */
  
  s = [[NSString alloc] initWithData:_html
			encoding:[self stringEncodingForData:_html]];
  bufLen = [s length];
  buf = calloc(bufLen + 2, sizeof(unichar));
  [s getCharacters:buf];
  [s release]; s = nil;
  buf[bufLen] = 0; /* null-terminate buffer, parser might need that */
  
  /* start parsing */
  
  topLevel = [NSMutableArray arrayWithCapacity:64];
  idx  = 0;
  len  = bufLen;
  html = buf;
  
  while ((idx < len) && (exception == nil)) {
    WOElement *element;
    
    element = _parseElement(NULL, html, &idx, len, &exception, self);
    if (element == nil)
      continue;
    
    [topLevel addObject:element];
    [element release]; element = nil;
  }

  if (buf != NULL) {
    free(buf); buf = NULL;
    html = NULL;
  }
  
  ASSIGN(self->parsingException, exception);
  
  if (exception != nil) {
    [self->callback parser:self 
	            failedParsingHTMLData:_html exception:exception];
  }
  else {
    [self->callback parser:self 
	            finishedParsingHTMLData:_html elements:topLevel];
  }
  
  return self->parsingException ? (NSMutableArray *)nil : topLevel;
}

/* internal parsing */

static int _numberOfLines(const unichar *_buffer, unsigned _lastIdx) {
  register int pos, lineCount = 1;
  
  for (pos = 0; (pos < (int)_lastIdx) && (_buffer[pos] != '\0'); pos++) {
    if (_buffer[pos] == '\n')
      lineCount++;
  }
  return lineCount;
}

static inline BOOL _isHTMLSpace(const unichar c) {
  switch (c) {
    case ' ': case '\t': case '\r': case '\n':
      return YES;

    default:
      return NO;
  }
}

static NSException *_makeHtmlException(NSException *_exception,
                                       const unichar *_buffer, unsigned _idx,
                                       unsigned _len, NSString *_text,
                                       WOHTMLParser *self)
{
  NSMutableDictionary *ui = nil;
  NSException *exception = nil;
  int         numLines   = _numberOfLines(_buffer, _idx);
  BOOL        atEof      = (_idx >= _len) ? YES : NO;

  if (_exception)
    // error resulted from a previous error (exception already set)
    return _exception;
  
  exception = [self _makeSyntaxErrorException];

  if (atEof)
    _text = [@"Unexpected end: " stringByAppendingString:[_text stringValue]];
  else {
    _text = [StrClass stringWithFormat:@"Syntax error in line %i: %@",
                      numLines, _text];
  }
  
  [exception setReason:_text];

  /* user info */
  {
    ui = [[exception userInfo] mutableCopy];
    if (ui == nil)
      ui = [[DictClass alloc] initWithCapacity:8];
    
    [ui setObject:[NumberClass numberWithInt:numLines] forKey:@"line"];
    [ui setObject:[NumberClass numberWithInt:_len]     forKey:@"size"];
    [ui setObject:[NumberClass numberWithInt:_idx]     forKey:@"position"];
    
    if (self)
      [ui setObject:self forKey:@"handler"];
    
    if (!atEof && (_idx > 0)) {
      register unsigned pos;
      const unichar *startPos, *endPos;

      for (pos = _idx; (pos >= 0) && (_buffer[pos] != '\n'); pos--)
        ;
      startPos = &(_buffer[pos + 1]);

      for (pos = _idx; ((pos < _len) && (_buffer[pos] != '\n')); pos++)
        ;
      endPos = &(_buffer[pos - 1]);
      
      if (startPos < endPos) {
        NSString *ll;
        
	ll = [[StrClass alloc] initWithCharacters:startPos 
			       length:(endPos - startPos)];
        [ui setObject:ll forKey:@"lastLine"];
        [ll release];
      }
#if HEAVY_DEBUG
      else {
        //NSLog(@"startPos=0x%p endPos=0x%p", startPos, endPos);
      }
#endif
    }
    
#if NeXT_Foundation_LIBRARY || APPLE_FOUNDATION_LIBRARY || \
    COCOA_Foundation_LIBRARY
    exception = [NSException exceptionWithName:[exception name] reason:[exception reason] userInfo:ui];
#else
    [exception setUserInfo:ui];
#endif

    [ui release]; ui = nil;
  }

  return exception;
}

static inline BOOL
_isComment(const unichar *_buffer, unsigned _idx, unsigned _len)
{
  // <!----> - 7 chars
  if ((_idx + 7) >= _len)  // check whether it is long enough
    return NO;
  if (_buffer[_idx] != '<') // check whether it is a tag
    return NO;

  _idx++; if (_buffer[_idx] != '!') return NO;
  _idx++; if (_buffer[_idx] != '-') return NO;
  _idx++; if (_buffer[_idx] != '-') return NO;

  return YES;
}

static inline BOOL _isHashTag(const unichar *_buf, unsigned _idx, 
			      unsigned _len) {
  /* check for "<#.>" (len 4) */
  if ((_idx + 3) >= _len)  // check whether it is long enough
    return NO;
  return (_buf[_idx] == '<' && _buf[_idx + 1] == '#') ? YES : NO;
}
static inline BOOL _isHashCloseTag(const unichar *_buf, 
				   unsigned _idx, unsigned _len) 
{
  /* check for "</#.>" (len 5) */
  if ((_idx + 5) >= _len)  // check whether it is long enough
    return NO;
  return (_buf[_idx] == '<' && _buf[_idx + 1] == '/' && _buf[_idx + 2] == '#') 
    ? YES : NO;
}

static BOOL _ucIsCaseEqual(const unichar *s, char *tok, unsigned len) {
  register unsigned int i;
  
  for (i = 0; i < len; i++) {
    register unsigned char c;
    
    if (s[i] == tok[i])
      continue;
    
    if (s[i] == 0)
      return NO;
    
    c = isupper(tok[i]) ? tolower(tok[i]) : toupper(tok[i]);
    if (s[i] != c)
      return NO;
  }
  return YES;
}

static inline BOOL _isWOTag(const unichar *_buf, unsigned _idx, 
			    unsigned _len) {
  /* check for "<WEBOBJECT .......>" (len 19) (lowercase is allowed) */
  if ((_idx + 18) >= _len)  // check whether it is long enough
    return NO;
  if (_buf[_idx] != '<') // check whether it is a tag
    return NO;
  
  // now check for '<WEBOBJECT'
  return _ucIsCaseEqual(&(_buf[_idx]), "<WEBOBJECT", 10);
}

static inline BOOL
_isWOCloseTag(const unichar *_buf, unsigned _idx, unsigned _len)
{
  /* check for </WEBOBJECT> (len=12) */
  if ((_idx + 12) > _len)  // check whether it is long enough
    return NO;
  if (_buf[_idx] != '<') // check whether it is a tag
    return NO;
  
  return _ucIsCaseEqual(&(_buf[_idx]), "</WEBOBJECT>", 12);
}

static inline void _skipSpaces(register const unichar *_buffer, unsigned *_idx,
                               unsigned _len)
{
  register unsigned pos = *_idx;

  if (pos >= _len) return; // EOF

  while ((pos < _len) && _isHTMLSpace(_buffer[pos]))
    pos++;

  *_idx = pos;
}

static NSString *_parseStringValue(NSZone *_zone,
                                   register const unichar *_buffer,
                                   unsigned *_idx, unsigned _len,
                                   NSException **_exception,
                                   WOHTMLParser *self)
{
  register unsigned pos = *_idx; // bug: skip-spaces could be further?
  
  _skipSpaces(_buffer, _idx, _len);
  if (pos >= _len) return nil; // EOF
  
  if (_buffer[pos] == '>') return nil;
  if (_buffer[pos] == '/') return nil;
  if (_buffer[pos] == '=') return nil;
  
  if (_buffer[pos] == '"') { // quoted string
    register unsigned len = 0;
    unsigned startPos = pos + 1;

    pos++; // skip starting quote ('"')
    
    // loop until closing quote
    while ((_buffer[pos] != '"') && (pos < _len)) {
      pos++;
      len++;
    }
    
    if (pos == _len) { // syntax error, quote not closed
      *_idx = pos;
      *_exception = _makeHtmlException(*_exception, _buffer, *_idx, _len,
                                   @"quoted string not closed (expected '\"')",
                                   nil);
      return nil;
    }

    NSCAssert(_buffer[pos] == '"', @"invalid parser state ..");
    pos++;       // skip closing quote
    *_idx = pos; // store pointer

    if (len == 0) // empty string
      return @"";
    
    return [[StrClass alloc] initWithCharacters:&(_buffer[startPos]) 
			     length:len];
  }
  
  /* string without quotes */
  {
    unsigned startPos = pos;

    //NSLog(@"parsing id at '%c'[%i] ..", _buffer[pos], pos);
    
    // loop until '>' or '=' or '/' or space
    while ((_buffer[pos] != '>') &&
           (_buffer[pos] != '=') &&
           (_buffer[pos] != '/') &&
           (!_isHTMLSpace(_buffer[pos])) &&
           (pos < _len)) {
      pos++;
    }
    *_idx = pos;

    if ((pos - startPos) == 0) // wasn't a string ..
      return nil;

    return [[StrClass alloc] initWithCharacters:&(_buffer[startPos]) 
			     length:(pos - startPos)];
  }
}

static NSMutableDictionary *
_parseTagAttributes(NSZone *_zone, const unichar *_buffer,
		    BOOL _uppercaseName,
                    unsigned *_idx, unsigned _len,
                    NSException **_exception, WOHTMLParser *self);

static WOElement *_parseHashElement(NSZone *_zone, const unichar *_buffer,
				    unsigned *_idx, unsigned _len,
				    NSException **_exc,
				    WOHTMLParser *self)
{
  /*
    parses:
      <#dynelem>....</#dynelem>
    or
      <#dynelem/>
  */
  static NSString *nameKey = @"NAME";
  WOElement      *element    = nil;
  BOOL           foundEndTag = NO;
  BOOL           isAutoClose = NO;
  NSMutableArray *children   = nil;
  NSString       *name;
  NSDictionary   *nameDict;
  NSMutableDictionary *attrs;
  BOOL hadSlashAfterHash;
  
  if (*_idx >= _len) return nil; // EOF
  
  if (!_isHashTag(_buffer, *_idx, _len))
    return nil; // not a hash tag ..
  
  // skip '<#'
  *_idx += 2;
  hadSlashAfterHash = (_buffer[*_idx] == '/') ? YES : NO;
  
  if (hadSlashAfterHash) {
    /* a tag starting like this: "<#/", probably a typo */
    [self warnWithFormat:@"typo in hash close tag ('<#/' => '</#')."];
  }
  
  /* parse tag name */
  
  if ((name = _parseStringValue(_zone, _buffer, _idx,_len,_exc,self)) == nil) {
#if HEAVY_DEBUG
    [self errorWithFormat:@"got no name for hash tag '<#NAME>'"];
#endif
    if (_exc != NULL && *_exc != nil) // if there was an error ..
      return nil;
  }
  _skipSpaces(_buffer, _idx, _len);
  
  /* parse attributes */
  
  attrs = _parseTagAttributes(_zone, _buffer,
			      NO /* keep name attributes as-is */,
			      _idx, _len, _exc, self);
  if (_exc != NULL) {
    if (*_exc != nil) {
      [name release]; name = nil;
      return nil; // invalid tag attrs
    }
  }
  
  /* parse tag end (> or /) */
  
  if (*_idx >= _len) {
    *_exc =
      _makeHtmlException(*_exc, _buffer, *_idx, _len,
                     @"unexpected EOF: missing '>' in hash element tag (EOF).",
                     self);
    [name release]; name = nil;
    return nil; // unexpected EOF
  }
  if (_buffer[*_idx] != '>' && _buffer[*_idx] != '/') {
    *_exc = _makeHtmlException(*_exc, _buffer, *_idx, _len,
				     @"missing '>' in hash element tag.", self);
    [name release]; name = nil;
    return nil; // unexpected EOF
  }

  if (_buffer[*_idx] == '>') {
    /* has sub-elements (<#name>...</#name>) */
    *_idx += 1; // skip '>'
  
    while ((*_idx < _len) && (*_exc == nil)) {
      id subElement = nil;
    
#if HEAVY_DEBUG
      NSLog(@"subelement at '%c'[%i] ..", _buffer[*_idx], *_idx);
#endif
    
      if (_isHashCloseTag(_buffer, *_idx, _len)) {
	foundEndTag = YES;
	break;
      }

      subElement = _parseElement(_zone, _buffer, _idx, _len, _exc, self);
    
#if HEAVY_DEBUG
      NSLog(@"  parsed subelement '%@' ..", subElement);
#endif
    
      if (subElement != nil) {
	if (children == nil)
	  children = [NSMutableArray arrayWithCapacity:10];
	[children addObject:subElement];
	[subElement release]; subElement = nil;
      }
    }
  }
  else {
    /* has no sub-elements (<#name/>) */
    *_idx += 1; // skip '/'
    isAutoClose = YES;
    if (_buffer[*_idx] != '>') {
      *_exc = _makeHtmlException(*_exc, _buffer, *_idx, _len,
				 @"missing '>' in hash element tag.", self);
      [name release]; name = nil;
      return nil; // unexpected EOF
    }
    *_idx += 1; // skip '>'
  }
  
  /* produce elements */

  if ([name length] < 1) {
    element = nil;
    *_exc = _makeHtmlException(*_exc, NULL, 0, 0,
				     @"missing name in hash element tag.",
				     nil);
    [name release];
    return nil;
  }
  
  nameDict = [[NSDictionary alloc] initWithObjects:&name forKeys:&nameKey 
				   count:1];
  if (attrs != nil)
    [attrs addEntriesFromDictionary:nameDict];
  
  element = [self dynamicElementWithName:name
		  attributes:(attrs != nil ? (NSDictionary *)attrs : nameDict)
		  contentElements:children];
  [name release];     name = nil;
  [nameDict release]; nameDict = nil;
  
  if (element == nil) { // build error
    *_exc = _makeHtmlException(*_exc, _buffer, *_idx, _len,
                                 @"could not build hash element !.", self);
    return nil;
  }
  
  if (!foundEndTag && !isAutoClose) {
    *_exc = _makeHtmlException(*_exc, _buffer, *_idx, _len,
                                 @"did not find hash end tag (</#...>) ..",
                                 self);
    [element release]; element = nil;
    return nil;
  }
  else if (!isAutoClose) {
    /* skip close tag ('</#name>') */
    NSCAssert(_isHashCloseTag(_buffer, *_idx, _len), 
	      @"invalid parser state ..");
    
    *_idx += 3; // skip '</#'
    while ((*_idx < _len) && (_buffer[*_idx] != '>'))
      *_idx += 1;
    *_idx += 1; // skip '>'
#if HEAVY_DEBUG
    NSLog(@"parsed close tag, now at '%c'[%i] ..", _buffer[*_idx], *_idx);
#endif
  }
  return element;
}

static NSMutableDictionary *
_parseTagAttributes(NSZone *_zone, const unichar *_buffer,
		    BOOL _uppercaseName,
                    unsigned *_idx, unsigned _len,
                    NSException **_exception, WOHTMLParser *self)
{
  NSMutableDictionary *dict = nil;

  _skipSpaces(_buffer, _idx, _len);
  if (*_idx >= _len) return nil; // EOF

#if HEAVY_DEBUG
  NSLog(@"parsing attributes at '%c'[%i] ..", _buffer[*_idx], *_idx);
#endif
  
  do {
    NSString *key   = nil;
    NSString *value = nil;
    
    _skipSpaces(_buffer, _idx, _len);
    if (*_idx >= _len) break; // EOF

    /* read tag key (eg NAME) */
    key = _parseStringValue(_zone, _buffer, _idx, _len, _exception, self);
    if (key == nil) // EOF
      break;

    /* fixup NAME attribute, the only one where case matters */
    
    if (_uppercaseName && [key length] == 4) {
      if ([@"name" caseInsensitiveCompare:key] == NSOrderedSame) {
	[key release];
	key = @"NAME";
      }
    }
    
    /* The following parses:  space* '=' space* */

    _skipSpaces(_buffer, _idx, _len);
    if (*_idx >= _len) {
      *_exception = _makeHtmlException(*_exception, _buffer, *_idx, _len,
                                   @"expected '=' after key in attributes ..",
                                   nil);
      break; // unexpected EOF
    }
    if (_buffer[*_idx] != '=') {
      *_exception = _makeHtmlException(*_exception, _buffer, *_idx, _len,
                                   @"expected '=' after key in attributes ..",
                                   nil);
      break;
    }
    NSCAssert(_buffer[*_idx] == '=', @"invalid parser state ..");
    *_idx += 1; // skip '='
    _skipSpaces(_buffer, _idx, _len);
    if (*_idx >= _len) {
      *_exception = _makeHtmlException(*_exception, _buffer, *_idx, _len,
                                 @"expected value after key in attributes ..",
                                 nil);
      break; // unexpected EOF
    }

    // read value
    value = _parseStringValue(_zone, _buffer, _idx, _len, _exception, self);
    if (value == nil) {
      *_exception = _makeHtmlException(*_exception, _buffer, *_idx, _len,
                                 @"expected value after key in attributes ..",
                                 nil);
      break; // unexpected EOF
    }

    NSCAssert(key,   @"invalid key ..");
    NSCAssert(value, @"invalid value ..");

    if (dict == nil)
      dict = [[DictClass allocWithZone:_zone] init];
    NSCAssert(dict, @"no attributes dictionary ?");
    [dict setObject:value forKey:key];
    
    [key   release]; key   = nil;
    [value release]; value = nil;
  }
  while (*_idx < _len);

  return dict;
}
static WOElement *_parseWOElement(NSZone *_zone, const unichar *_buffer,
                                  unsigned *_idx, unsigned _len,
                                  NSException **_exception,
                                  WOHTMLParser *self)
{
  WOElement           *element    = nil;
  NSMutableDictionary *attrs      = nil;
  BOOL                foundEndTag = NO;
  NSMutableArray      *children   = nil;
  
  if (*_idx >= _len) return nil; // EOF
  
  if (!_isWOTag(_buffer, *_idx, _len))
    return nil; // not a WO tag ..

  NSCAssert(_ucIsCaseEqual(&(_buffer[*_idx]), "<WEBOBJECT", 10),
            @"Invalid parser state (expected <WEBOBJECT in buffer)!");
  
  // skip '<WEBOBJECT'
  *_idx += 10;
  
  attrs = _parseTagAttributes(_zone, _buffer, YES /* uppercase NAME */,
			      _idx, _len, _exception, self);
  if (attrs == nil) {
#if 0
    [self errorWithFormat:
            @"got no attributes for WO tag (need at least 'NAME').."];
#endif
    if (_exception != NULL) // if there was an error .. // TODO: check this!
      return nil;
  }
  
  _skipSpaces(_buffer, _idx, _len);
  if (*_idx >= _len) {
    *_exception =
      _makeHtmlException(*_exception, _buffer, *_idx, _len,
                     @"unexpected EOF: missing '>' in WEBOBJECT tag.",
                     self);
    [attrs release]; attrs = nil;
    return nil; // unexpected EOF
  }
  if (_buffer[*_idx] != '>') {
    *_exception = _makeHtmlException(*_exception, _buffer, *_idx, _len,
                                 @"missing '>' in WEBOBJECT tag.", self);
    [attrs release]; attrs = nil;
    return nil; // unexpected EOF
  }
  NSCAssert(_buffer[*_idx] == '>', @"invalid parser state ..");

  *_idx += 1; // skip '>'

  // parse sub-elements
  
  while ((*_idx < _len) && (*_exception == nil)) {
    id subElement = nil;

    //NSLog(@"subelement at '%c'[%i] ..", _buffer[*_idx], *_idx);

    if (_isWOCloseTag(_buffer, *_idx, _len)) {
      foundEndTag = YES;
      break;
    }

    subElement = _parseElement(_zone, _buffer, _idx, _len, _exception, self);

    //NSLog(@"  parsed subelement '%@' ..", subElement);

    if (subElement) {
      if (children == nil)
        children = [NSMutableArray arrayWithCapacity:10];
      [children addObject:subElement];
      [subElement release]; subElement = nil;
    }
  }

  /* produce elements */
  {
    NSString *name;
    
    if ((name = [attrs objectForKey:@"NAME"]) == nil)
      name = [attrs objectForKey:@"name"];
    if (name == nil) {
      if ((name = [attrs objectForKey:@"name"])) {
	NSLog(@"%s: missing 'name' attribute !",
	      __PRETTY_FUNCTION__);
      }
    }
    
    if ([name length] < 1) {
      element = nil;
      *_exception = _makeHtmlException(*_exception, NULL, 0, 0,
                                       @"no NAME attribute in WEBOBJECT tag.",
                                       nil);
      return nil;
    }
    else {
      element = [self dynamicElementWithName:name
                      attributes:attrs
                      contentElements:children];
    }
  }
  [attrs release]; attrs = nil;

  if (element == nil) { // build error
    *_exception = _makeHtmlException(*_exception, _buffer, *_idx, _len,
                                 @"could not build WEBOBJECT.", self);
    return nil;
  }
  
  if (!foundEndTag) {
    *_exception = _makeHtmlException(*_exception, _buffer, *_idx, _len,
                                 @"did not find WEBOBJECT end tag ..",
                                 self);
    [element release]; element = nil;
    return nil;
  }
  else {
    NSCAssert(_isWOCloseTag(_buffer, *_idx, _len), @"invalid parser state ..");
    
    // skip close tag ('</WEBOBJECT>')
    *_idx += 11; // skip '</WEBOBJECT'
    while ((*_idx < _len) && (_buffer[*_idx] != '>'))
      *_idx += 1;
    *_idx += 1; // skip '>'

    //NSLog(@"parsed close tag, now at '%c'[%i] ..", _buffer[*_idx], *_idx);
  }
  return element;
}

static inline NSString *_makeTextString(NSZone *_zone, const unichar *_buffer,
                                        unsigned _len, WOHTMLParser *self)
{
  NSString *result = nil;
  register unichar  *buffer;
  register unsigned pos, bufPos;
  
  if (_len == 0) // empty string
    return @"";

  if (!compressHTMLWhitespace)
    /* deliver whitespace as in template */
    return [[StrClass alloc] initWithCharacters:_buffer length:_len];
  
  buffer = calloc(_len + 3, sizeof(unichar));
  
  for (pos = 0, bufPos = 0; pos < _len; ) {
      buffer[bufPos] = _buffer[pos];

      if ((_buffer[pos] == ' ') || (_buffer[pos] == '\t')) {
        do {
          pos++;
        }
        while (((_buffer[pos] == ' ') || (_buffer[pos] =='\t')) &&
               (pos < _len));
        
        bufPos++;
      }
      else {
        pos++;
        bufPos++;
      }
  }
  
  result = [[StrClass alloc] initWithCharacters:buffer length:bufPos];
  if (buffer != NULL) free(buffer);
  return result;
}

static WOElement *_parseElement(NSZone *_zone,
                                const unichar *_buffer, unsigned *_idx,
                                unsigned _len, NSException **_exception,
                                WOHTMLParser *self)
{
  register unsigned pos = *_idx;
  unsigned startPos = pos;
  
  if (*_idx >= _len) // EOF
    return nil;
  
  if (_isHashTag(_buffer, *_idx, _len)) {
    /* start parsing of dynamic content */
    return _parseHashElement(_zone, _buffer, _idx, _len, _exception, self);
  }
  if (_isHashCloseTag(_buffer, *_idx, _len)) {
    /* check for a common template syntax error */
    *_exception = _makeHtmlException(*_exception, _buffer, *_idx, _len,
				     @"unexpected hash close tag (</#...>).",
				     self);
    return nil;
  }
  
  if (_isWOTag(_buffer, *_idx, _len)) {
    /* start parsing of dynamic content */
    return _parseWOElement(_zone, _buffer, _idx, _len, _exception, self);
  }
  if (_isWOCloseTag(_buffer, *_idx, _len)) {
    /* check for a common template syntax error */
    *_exception = _makeHtmlException(*_exception, _buffer, *_idx, _len,
				     @"unexpected WEBOBJECT close tag "
				     @"(</WEBOBJECT...>).",
				     self);
    return nil;
  }
  
  /* parse text/tag content */
  do {
    while ((_buffer[pos] != '<') && (pos < _len))
      pos++;
    
    if (pos >= _len) // EOF was reached
      break;
    
    NSCAssert(_buffer[pos] == '<', @"invalid parser state ..");
    
    if (_isHashTag(_buffer, pos, _len)) /* found Hash */
      break;
    if (_isHashCloseTag(_buffer, pos, _len))
      break;
    if (_isWOTag(_buffer, pos, _len)) /* found Hash */
      break;
    if (_isWOCloseTag(_buffer, pos, _len))
      break;
    
#if HEAVY_DEBUG
    NSLog(@"is comment ? from '%c%c%c'[%i]",
          _buffer[pos], _buffer[pos+1], _buffer[pos+2], pos);
#endif
    if (_isComment(_buffer, pos, _len)) {
      pos += 3; // skip '<--'

      while (pos < _len) {
	if (_buffer[pos] == '-') {
	  if (pos + 2 < _len) {
	    if ((_buffer[pos + 1] == '-') && (_buffer[pos + 2] == '>')) {
	      // found '-->'
	      pos += 3; // skip '-->'
	      *_idx = pos;
	      break;
	    }
	  }
	}
	pos++;
      }
      if (pos >= _len) // EOF was reached
        break;
    }
    else {
      // skip '<', read usual tag
      pos++;
      if (pos >= _len) { // EOF was reached with opening '<'
        [self warnWithFormat:@"reached EOF with '<' at end !"];
        break;
      }
      
      if (skipPlainTags) {
	/* skip until end of HTML tag (not #-tag) */
	do {
	  pos++;
	}
	while ((_buffer[pos] != '>') && (pos < _len));
	if (pos >= _len) break; // EOF
      }
      
      pos++;
    }
  }
  while (pos < _len);
  
  /* store back position */
  *_idx = pos;
  
#if HEAVY_DEBUG
  NSLog(@"Debug: stopped parsing at '%c'[%i]", _buffer[pos], pos);
#endif

  if ((pos - startPos) > 0) {
    return [self _makeConstantStringElementWithBuffer:&(_buffer[startPos])
		 length:(pos - startPos)];
  }
  else
    return nil;
}

@end /* WOHTMLParser */
