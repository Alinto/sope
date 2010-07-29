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

#include "WODParser.h"
#include "common.h"

@implementation WODParser

static Class    StrClass    = Nil;
static Class    DictClass   = Nil;
static Class    NumberClass = Nil;
static NSNumber *yesNum     = nil;
static NSNumber *noNum      = nil;
static BOOL     useUTF8     = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

  StrClass    = [NSString class];
  DictClass   = [NSMutableDictionary class];
  NumberClass = [NSNumber      class];
  
  if (yesNum == nil) yesNum = [[NumberClass numberWithBool:YES] retain];
  if (noNum  == nil) noNum  = [[NumberClass numberWithBool:NO]  retain];
  
  useUTF8 = [ud boolForKey:@"WOParsersUseUTF8"];
}

- (id)initWithHandler:(id<WODParserHandler,NSObject>)_handler {
  ASSIGN(self->callback, _handler);
  return self;
}
- (void)dealloc {
  [self->callback release];
  [super dealloc];
}

/* callbacks */

- (id)associationWithValue:(id)_value {
  return [self->callback parser:self makeAssociationWithValue:_value];
}
- (id)associationWithKeyPath:(NSString *)_keyPath {
  return [self->callback parser:self makeAssociationWithKeyPath:_keyPath];
}

- (id)elementDefinitionForComponent:(NSString *)_cname
  associations:(id)_entry
  elementName:(NSString *)_elemName
{
  return [self->callback parser:self
                         makeDefinitionForComponentNamed:_cname
                         associations:_entry
                         elementName:_elemName];
}

/* parser */

static id _parseProperty(NSZone *_zone, const unichar *_buffer, unsigned *_idx,
                         unsigned _len, NSException **_exception,
                         BOOL _allowAssoc, id self);
static id _parseWodEntry(NSZone *_zone, const unichar *_buffer, unsigned *_idx,
                         unsigned _len, NSException **_exception,
                         NSString **_name, NSString **_class,
                         id self);

- (NSException *)parseDefinitionsFromBuffer:(const unichar *)_buffer
  length:(unsigned)_len
  mappings:(NSMutableDictionary *)_mappings
{
  NSException *exception     = nil;
  NSString    *elementName   = nil;
  NSString    *componentName = nil;
  unsigned    idx            = 0;
  id          entry          = nil;
  
  [_mappings removeAllObjects];
  
  while ((entry = _parseWodEntry(NULL, _buffer, &idx, _len, &exception,
                                 &elementName, &componentName,
                                 self)) != NULL) {
    id def;
    
    if (exception) {
      [entry         release]; entry         = nil;
      [elementName   release]; elementName   = nil;
      [componentName release]; componentName = nil;
      break;
    }

    if ([_mappings objectForKey:elementName] != nil)
      [self warnWithFormat:@"duplicate definition of element %@ !",
              elementName];

    def = [self elementDefinitionForComponent:componentName
                associations:entry
                elementName:elementName];
    
    [componentName release]; componentName = nil;
    [entry         release]; entry         = nil;

    if ((def != nil) && (elementName != nil))
      [_mappings setObject:def forKey:elementName];
#if 0
    NSLog(@"defined element %@ definition=%@", elementName, def);
#endif
    [elementName release]; elementName = nil;
  }

  return exception;
}

/* parsing */

- (NSStringEncoding)stringEncodingForData:(NSData *)_data  {
  // TODO: we could check for UTF-16 marker in front of data
  return useUTF8 ? NSUTF8StringEncoding : [NSString defaultCStringEncoding];
}

- (NSDictionary *)parseDeclarationData:(NSData *)_decl {
  NSMutableDictionary *defs;
  NSException  *ex;
  NSString     *s;
  unichar      *buf;
  unsigned int bufLen;
  
  if (![self->callback parser:self willParseDeclarationData:_decl])
    return nil;
  
  /* recode buffer using NSString */
  
  s = [[NSString alloc] initWithData:_decl 
			encoding:[self stringEncodingForData:_decl]];
  bufLen = [s length];
  buf = calloc(bufLen + 2, sizeof(unichar));
  [s getCharacters:buf];
  [s release]; s = nil;
  buf[bufLen] = 0; /* null-terminate buffer, parser might need that */
  
  /* start parsing */
  
  defs = [NSMutableDictionary dictionaryWithCapacity:100];
  
  ex = [self parseDefinitionsFromBuffer:buf length:bufLen mappings:defs];
  
  if (buf != NULL) free(buf); buf = NULL;

  /* report results */
  
  if (ex != nil) {
    [self->callback parser:self failedParsingDeclarationData:_decl 
	            exception:ex];
  }
  else {
    [self->callback parser:self finishedParsingDeclarationData:_decl
                    declarations:defs];
  }
  
  return defs;
}


static int _numberOfLines(const unichar *_buffer, unsigned _lastIdx) {
  register unsigned pos, lineCount = 1;
  
  for (pos = 0; (pos < _lastIdx) && (_buffer[pos] != '\0'); pos++) {
    if (_buffer[pos] == '\n')
      lineCount++;
  }
  return lineCount;
}

static inline BOOL _isBreakChar(const unichar _c) {
  switch (_c) {
    case ' ': case '\t': case '\n': case '\r':
    case '=':  case ';':  case ',':
    case '{': case '(':  case '"':  case '<':
    case '.': case ':':
    case ')': case '}':
      return YES;

    default:
      return NO;
  }
}
static inline BOOL _isIdChar(const unichar _c) {
  return (_isBreakChar(_c) && (_c != '.')) ? NO : YES;
}

static inline int _valueOfHexChar(const unichar _c) {
  switch (_c) {
    case '0': case '1': case '2': case '3': case '4':
    case '5': case '6': case '7': case '8': case '9':
      return (_c - 48); // 0-9 (ascii-char)'0' - 48 => (int)0
      
    case 'A': case 'B': case 'C':
    case 'D': case 'E': case 'F':
      return (_c - 55); // A-F, A=10..F=15, 'A'=65..'F'=70
      
    case 'a': case 'b': case 'c':
    case 'd': case 'e': case 'f':
      return (_c - 87); // a-f, a=10..F=15, 'a'=97..'f'=102

    default:
      return -1;
  }
}
static inline BOOL _isHexDigit(const unichar _c) {
  switch (_c) {
    case '0': case '1': case '2': case '3': case '4':
    case '5': case '6': case '7': case '8': case '9':
    case 'A': case 'B': case 'C':
    case 'D': case 'E': case 'F':
    case 'a': case 'b': case 'c':
    case 'd': case 'e': case 'f':
      return YES;

    default:
      return NO;
  }
}

static NSException *_makeException(NSException *_exception,
                                   const unichar *_buffer, unsigned _idx,
                                   unsigned _len, NSString *_text)
{
  NSMutableDictionary *ui = nil;
  NSException *exception = nil;
  int         numLines;
  BOOL        atEof;
  
  numLines   = _numberOfLines(_buffer, _idx);
  atEof      = (_idx >= _len) ? YES : NO;
  
  if (_exception)
    // error resulted from a previous error (exception already set)
    return _exception;

  if (atEof)
    _text = [@"Unexpected end: " stringByAppendingString:[_text stringValue]];
  else {
    _text = [StrClass stringWithFormat:@"Syntax error in line %i: %@",
                        numLines, _text];
  }

  // user info
  ui = [[exception userInfo] mutableCopy];
  if (ui == nil)
    ui = [[DictClass alloc] initWithCapacity:8];

  [ui setObject:[NumberClass numberWithInt:numLines] forKey:@"line"];
  [ui setObject:[NumberClass numberWithInt:_len]     forKey:@"size"];
  [ui setObject:[NumberClass numberWithInt:_idx]     forKey:@"position"];

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
			     length:endPos - startPos];
      [ui setObject:ll forKey:@"lastLine"];
      [ll release];
    }
    else {
      NSLog(@"%s: startPos=0x%p endPos=0x%p", __PRETTY_FUNCTION__,
            startPos, endPos);
    }
  }

  exception = [NSException exceptionWithName:@"SyntaxError"
                           reason:_text
                           userInfo:ui];
  [ui release]; ui = nil;

  return exception;
}

static BOOL _skipComments(const unichar *_buffer, 
			  unsigned *_idx, unsigned _len,
                          NSException **_exception)
{
  register unsigned pos = *_idx;
  BOOL lookAgain;

  if (pos >= _len)
    return NO;

  //NSLog(@"start at '%c' (%i)", _buffer[pos], pos);
  
  do { // until all comments are filtered ..
    lookAgain = NO;
    
    if ((_buffer[pos] == '/') && (pos + 1 < _len)) {
      if (_buffer[pos + 1] == '/') { // single line comments
        pos += 2; // skip '//'

        // search for '\n' ..
        while ((pos < _len) && (_buffer[pos] != '\n'))
          pos++;

        if ((pos < _len) && (_buffer[pos] == '\n')) {
          pos++; // skip newline, otherwise EOF was reached
          lookAgain = YES;
        }
      }
      else if (_buffer[pos + 1] == '*') { /* multiline comments */
        BOOL commentIsClosed = NO;
      
        pos += 2; // skip '/*'

        do { // search for '*/'
          while ((pos < _len) && (_buffer[pos] != '*'))
            pos++;

          if (pos < _len) { // found '*'
            if ((pos + 1) < _len) {
              if (_buffer[pos + 1] == '/') { // found '*/'
                commentIsClosed = YES;
                pos += 2; // skip '*/'
                lookAgain = YES;
                break; // leave loop
              }
              else {
                pos += 1; // skip '*'
              }
            }
          }
        }
        while (pos < _len);

        if (!commentIsClosed) {
          // EOF found, comment wasn't closed
          *_exception =
            _makeException(*_exception, _buffer, *_idx, _len,
                           @"comment was not closed (expected '*/')");
          return NO;
        }
      }
    }
    else if (isspace((int)_buffer[pos])) {
      pos++;
      lookAgain = YES;
    }
  }
  while (lookAgain && (pos < _len));
  
  // store position ..
  *_idx = pos;
  //NSLog(@"end at '%c' (%i)", _buffer[pos], pos);

  return (pos < _len);
}

static NSString *_parseIdentifier(NSZone *_zone,
                                  const unichar *_buffer, unsigned *_idx,
                                  unsigned _len, NSException **_exception)
{
  register unsigned pos = *_idx;
  register unsigned len = 0;
  unsigned startPos = pos;

  // skip comments and spaces
  if (!_skipComments(_buffer, _idx, _len, _exception)) {
    // EOF reached during comment-skipping
    *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                        @"did not find an id (expected 'a-zA-Z0-9') !");
    return nil;
  }
  
  // loop until break char
  while (_isIdChar(_buffer[pos]) && (pos < _len)) {
    pos++;
    len++;
  }

  if (len == 0) { // wasn't a string ..
    *_exception =
      _makeException(*_exception, _buffer, *_idx, _len,
                     @"did not find an id (expected 'a-zA-Z0-9') !");
    return nil;
  }
  else {
    *_idx = pos;
    return [[StrClass alloc] initWithCharacters:&(_buffer[startPos])
			     length:len];
  }
}
static NSString *_parseKeyPath(NSZone *_zone,
                               const unichar *_buffer, unsigned *_idx,
                               unsigned _len, NSException **_exception,
                               id self)
{
  NSMutableString *keypath   = nil;
  NSString        *component = nil;
  
  if (!_skipComments(_buffer, _idx, _len, _exception)) {
    // EOF reached during comment-skipping
    *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                 @"did not find keypath (expected id)");
    return nil;
  }

  component = _parseIdentifier(_zone, _buffer, _idx, _len, _exception);
  if (component == nil) {
    *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                 @"did not find keypath (expected id)");
    return nil;
  }
  if (_buffer[*_idx] != '.') // single id-keypath
    return component;

  keypath = [[NSMutableString allocWithZone:_zone] init];
  [keypath appendString:component];
  
  while ((_buffer[*_idx] == '.') && (component != nil)) {
    *_idx += 1; // skip '.'
    [keypath appendString:@"."];

    [component release]; component = nil;
    component = _parseIdentifier(_zone, _buffer, _idx, _len, _exception);

    if (component == nil) {
      [keypath release]; keypath = nil;
      *_exception =
        _makeException(*_exception, _buffer, *_idx, _len,
                       @"expected component after '.' in keypath !");
      break;
    }

    [keypath appendString:component];
  }
  [component release]; component = nil;

  return keypath;
}

static NSString *_parseQString(NSZone *_zone,
                               const unichar *_buffer, unsigned *_idx,
                               unsigned _len, NSException **_exception,
                               id self)
{
  // skip comments and spaces
  if (!_skipComments(_buffer, _idx, _len, _exception)) {
    // EOF reached during comment-skipping
    *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                        @"did not find a quoted string (expected '\"') !");
    return nil;
  }

  if (_buffer[*_idx] != '"') { // it's not a quoted string that's follows
    *_exception = 
      _makeException(*_exception, _buffer, *_idx, _len,
		     @"did not find quoted string (expected '\"')");
    return nil;
  }
  else { // a quoted string
    register unsigned pos = *_idx;
    register unsigned len = 0;
    unsigned startPos = pos + 1;
    BOOL     containsEscaped = NO;
    
    pos++; // skip starting quote

    // loop until closing quote
    while ((_buffer[pos] != '"') && (pos < _len)) {
      if (_buffer[pos] == '\\') {
        containsEscaped = YES;
        pos++; // skip following char
        if (pos == _len) {
          *_exception =
            _makeException(*_exception, _buffer, *_idx, _len,
                           @"escape in quoted string not finished !");
          return nil;
        }
      }
      pos++;
      len++;
    }

    if (pos == _len) { // syntax error, quote not closed
      *_idx = pos;
      *_exception =
	_makeException(*_exception, _buffer, *_idx, _len,
		       @"quoted string not closed (expected '\"')");
      return nil;
    }

    pos++;       // skip closing quote
    *_idx = pos; // store pointer
    pos = 0;
    
    if (len == 0) /* empty string */
      return @"";
    
    if (containsEscaped) {
      register unsigned pos2;
      id   ostr = nil;
      unichar *str;
      
      NSCAssert(len > 0, @"invalid length ..");
      str = calloc(len + 3, sizeof(unichar));
      
      for (pos = startPos, pos2 = 0; _buffer[pos] != '"'; pos++, pos2++) {
        //NSLog(@"char=%c pos=%i pos2=%i", _buffer[pos], pos2);
        if (_buffer[pos] == '\\') {
          pos++;
          switch (_buffer[pos]) {
            case 'a':  str[pos2] = '\a'; break;
            case 'b':  str[pos2] = '\b'; break;
            case 'f':  str[pos2] = '\f'; break;
            case 'n':  str[pos2] = '\n'; break;
            case 't':  str[pos2] = '\t'; break;
            case 'v':  str[pos2] = '\v'; break;
            case '\\': str[pos2] = '\\'; break;
            
            default:
              str[pos2] = _buffer[pos];
              break;
          }
        }
        else {
          str[pos2] = _buffer[pos];
        }
      }
      str[pos2] = 0;
      NSCAssert(pos2 == len, @"invalid unescape ..");
      
      ostr = [[StrClass alloc] initWithCharacters:str length:pos2];
      if (str != NULL) free(str); str = NULL;

      return ostr;
    }
    else {
      NSCAssert(len > 0, @"invalid length ..");
      return [[StrClass alloc] initWithCharacters:&(_buffer[startPos]) 
			       length:len];
    }
  }
}

static NSData *_parseData(NSZone *_zone, const unichar *_buffer,
                          unsigned *_idx, unsigned _len,
                          NSException **_exception,
                          id self)
{
  if (!_skipComments(_buffer, _idx, _len, _exception)) {
    // EOF reached during comment-skipping
    *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                 @"did not find a data (expected '<') !");
    return nil;
  }

  if (_buffer[*_idx] != '<') { // it's not a data that's follows
    *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                 @"did not find a data (expected '<') !");
    return nil;
  }
  else {
    register      unsigned pos = *_idx + 1;
    register      unsigned len = 0;
    unsigned      endPos = 0;
    NSMutableData *data  = nil;
    
    *_idx += 1; // skip '<'

    if (!_skipComments(_buffer, _idx, _len, _exception)) {
      *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                   @"data was not closed (expected '>') ..");
      return nil; // EOF
    }

    if (_buffer[*_idx] == '>') { // empty data
      *_idx += 1; // skip '>'
      return [[NSData allocWithZone:_zone] init];
    }

    // count significant chars
    while ((_buffer[pos] != '>') && (pos < _len)) {
      if ((_buffer[pos] == ' ') || (_buffer[pos] == '\t'))
        ;
      else if (_isHexDigit(_buffer[pos]))
        len++;
      else {
        *_idx = pos;
        *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                     @"invalid char in data property");
        return nil;
      }
      pos++;
    }
    if (pos == _len) {
      *_idx = pos;
      *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                   @"data was not closed (expected '>')");
      return nil; // EOF
    }
    endPos = pos; // store position of closing '>'

    // if odd, then add one byte for trailing nibble
    len = (len % 2 == 1) ? len / 2 + 1 : len / 2;
    data = [[NSMutableData allocWithZone:_zone] initWithLength:len];

    /* now copy bytes ... */
    {
      register unsigned i;
      register int pending = -1;
      char *buf = [data mutableBytes];
      
      for (pos = *_idx, i = 0; (pos < endPos) && (i < len); pos++) {
        int value = _valueOfHexChar(_buffer[pos]);

        if (value != -1) {
          if (pending == -1)
            pending = value;
          else {
            value = value * 16 + pending;
            pending = -1;

            buf[i] = value;
            i++;
          }
        }
      }
      if (pending != -1) { // was odd, now add the trailer ..
        NSCAssert(i < len, @"invalid length ..");
        buf[i] = pending * 16;
      }
    }
    
    // update global position
    *_idx = endPos + 1; // endPos + 1 (*endPos == '>', 1 => skips '>')

    return data;
  }
}

static NSDictionary *_parseDict(NSZone *_zone,
                                const unichar *_buffer, unsigned *_idx,
                                unsigned _len, NSException **_exception,
                                id self)
{
  if (!_skipComments(_buffer, _idx, _len, _exception)) {
    // EOF reached during comment-skipping
    *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                 @"did not find dictionary (expected '{')");
    return nil;
  }
  
  if (_buffer[*_idx] != '{') { // it's not a dict that's follows
    *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                 @"did not find dictionary (expected '{')");
    return nil;
  }
  else {
    NSMutableDictionary *result = nil;
    id   key     = nil;
    id   value   = nil;
    BOOL didFail = NO;
    
    *_idx += 1; // skip '{'

    if (!_skipComments(_buffer, _idx, _len, _exception)) {
      *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                   @"dictionary was not closed (expected '}')");
      return nil; // EOF
    }

    if (_buffer[*_idx] == '}') { // an empty dictionary
      *_idx += 1; // skip the '}'
      return [[DictClass allocWithZone:_zone] init];
    }

    result = [[DictClass allocWithZone:_zone] init];
    do {
      key   = nil;
      value = nil;
      
      if (!_skipComments(_buffer, _idx, _len, _exception)) {
        *_exception =
          _makeException(*_exception, _buffer, *_idx, _len,
                         @"dictionary was not closed (expected '}')");
        didFail = YES;
        break; // unexpected EOF
      }

      if (_buffer[*_idx] == '}') { // dictionary closed
        *_idx += 1; // skip the '}'
        break;
      }
      
      // read key property
      key = _parseProperty(_zone, _buffer, _idx, _len, _exception, NO, self);
      if (key == nil) { // syntax error
        if (*_exception == nil) {
          *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                       @"got nil-key in dictionary ..");
        }
        didFail = YES;
        break;
      }

      /* The following parses:  (comment|space)* '=' (comment|space)* */
      if (!_skipComments(_buffer, _idx, _len, _exception)) {
        *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                     @"expected '=' after key in dictionary");
        didFail = YES;
        break; // unexpected EOF
      }
      // now we need a '=' assignment
      if (_buffer[*_idx] != '=') {
        *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                     @"expected '=' after key in dictionary");
        didFail = YES;
        break;
      }
      *_idx += 1; // skip '='
      if (!_skipComments(_buffer, _idx, _len, _exception)) {
        *_exception =
          _makeException(*_exception, _buffer, *_idx, _len,
                         @"expected value after key '=' in dictionary");
        didFail = YES;
        break; // unexpected EOF
      }

      // read value property
      value = _parseProperty(_zone, _buffer, _idx, _len, _exception, NO, self);
#if 1
      if (*_exception) {
        didFail = YES;
        break;
      }
#else
      if (value == nil) { // syntax error
        if (*_exception == nil) {
          *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                       @"got nil-value in dictionary");
        }
        didFail = YES;
        break;
      }
#endif
      
      if ((key != nil) && (value != nil))
        [result setObject:value forKey:key];
      
      // release key and value
      RELEASE(key);   key   = nil;
      RELEASE(value); value = nil;

      // read trailing ';' if available
      if (!_skipComments(_buffer, _idx, _len, _exception)) {
        *_exception =
          _makeException(*_exception, _buffer, *_idx, _len,
                         @"dictionary was not closed (expected '}')");
        didFail = YES;
        break; // unexpected EOF
      }
      if (_buffer[*_idx] == ';') {
        *_idx += 1; // skip ';'
      }
      else { // no ';' at end of pair, only allowed at end of dictionary
        if (!_skipComments(_buffer, _idx, _len, _exception)) {
          *_exception =
            _makeException(*_exception, _buffer, *_idx, _len,
                           @"dictionary was not closed (expected '}')");
          didFail = YES;
          break; // unexpected EOF
        }

        if (_buffer[*_idx] != '}') { // dictionary wasn't closed
          *_exception =
            _makeException(*_exception, _buffer, *_idx, _len,
                           @"key-value pair without ';' at the end");
          didFail = YES;
          break;
        }
      }
    }
    while ((*_idx < _len) && (result != nil) && !didFail);

    RELEASE(key);    key    = nil;
    RELEASE(value);  value  = nil;
    if (didFail) {
      [result release]; result = nil;
      return nil;
    }
    else
      return result;
  }
}

static NSArray *_parseArray(NSZone *_zone, const unichar *_buffer, unsigned *_idx,
                            unsigned _len, NSException **_exception,
                            id self)
{
  if (!_skipComments(_buffer, _idx, _len, _exception)) {
    // EOF reached during comment-skipping
    *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                 @"did not find array (expected '(')");
    return nil;
  }

  if (_buffer[*_idx] != '(') { // it's not an array that's follows
    *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                 @"did not find array (expected '(')");
    return nil;
  }
  else {
    NSMutableArray *result = nil;
    id element = nil;

    *_idx += 1; // skip '('

    if (!_skipComments(_buffer, _idx, _len, _exception)) {
      *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                   @"array was not closed (expected ')')");
      return nil; // EOF
    }

    if (_buffer[*_idx] == ')') { // an empty array
      *_idx += 1; // skip the ')'
      return [[NSArray allocWithZone:_zone] init];
    }
    
    result = [[NSMutableArray allocWithZone:_zone] init];
    do {
      element = _parseProperty(_zone, _buffer, _idx, _len, _exception, NO, self);
      if (element == nil) {
        *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                     @"expected element in array");
        [result release]; result = nil;
        break;
      }
      [result addObject:element];
      [element release]; element = nil;
      
      if (!_skipComments(_buffer, _idx, _len, _exception)) {
        *_exception =
          _makeException(*_exception, _buffer, *_idx, _len,
                         @"array was not closed (expected ')' or ',')");
        [result release];
        result = nil;
        break;
      }
      
      if (_buffer[*_idx] == ')') { // closed array
        *_idx += 1; // skip ')'
        break;
      }
      else if (_buffer[*_idx] == ',') { // next element
        *_idx += 1; // skip ','
        
        if (!_skipComments(_buffer, _idx, _len, _exception)) {
          *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                       @"array was not closed (expected ')')");
          [result release];
          result = nil;
          break;
        }
        if (_buffer[*_idx] == ')') { // closed array, like this '(1,2,)'
          *_idx += 1; // skip ')'
          break;
        }
      }
      else { // syntax error
        *_exception =
          _makeException(*_exception, _buffer, *_idx, _len,
                         @"expected ')' or ',' after array element");
        [result release]; result = nil;
        break;
      }
    }
    while ((*_idx < _len) && (result != nil));
    
    [element release]; element = nil;

    return result;
  }
}

static NSNumber *_parseDigitPath(NSString *digitPath) {
  NSRange  r;

  r = [digitPath rangeOfString:@"."];
  return r.length > 0 
    ? [NumberClass numberWithDouble:[digitPath doubleValue]]
    : [NumberClass numberWithInt:[digitPath intValue]];
}

static BOOL _ucIsEqual(const unichar *s, char *tok, unsigned len) {
  switch (len) {
  case 0: return NO;
  case 1: return (s[0] == tok[0]) ? YES : NO;
  case 2:
    if (s[0] != tok[0] || s[0] == 0) return NO;
    if (s[1] != tok[1]) return NO;
    return YES;
  case 3:
    if (s[0] != tok[0] || s[0] == 0) return NO;
    if (s[1] != tok[1] || s[1] == 0) return NO;
    if (s[2] != tok[2]) return NO;
    return YES;
  default: {
    register unsigned int i;
    
    for (i = 0; i < len; i++) {
      if (s[i] != tok[i] || s[i] == 0) return NO;
    }
    return YES;
  }
  }
  return NO;
}

static id _parseProperty(NSZone *_zone, const unichar *_buffer, unsigned *_idx,
                         unsigned _len,
                         NSException **_exception, BOOL _allowAssoc,
                         id self)
{
  BOOL valueProperty = YES;
  id   result = nil;
  
  if (!_skipComments(_buffer, _idx, _len, _exception))
    return nil; // EOF

  switch (_buffer[*_idx]) {
    case '"': // quoted string
      NSCAssert(result == nil, @"result is already set ..");
      result = _parseQString(_zone, _buffer, _idx, _len, _exception, self);
      break;

    case '{': // dictionary
      NSCAssert(result == nil, @"result is already set ..");
      result = _parseDict(_zone, _buffer, _idx, _len, _exception, self);
      break;

    case '(': // array
      NSCAssert(result == nil, @"result is already set ..");
      result = _parseArray(_zone, _buffer, _idx, _len, _exception, self);
      break;

    case '<': // data
      NSCAssert(result == nil, @"result is already set ..");
      result = _parseData(_zone, _buffer, _idx, _len, _exception, self);
      break;
      
    default:
      NSCAssert(result == nil, @"result is already set ..");
      
      if (isdigit((int)_buffer[*_idx]) || (_buffer[*_idx] == '-')) {
        id digitPath;
        NSCAssert(result == nil, @"result is already set ..");
        
        digitPath = _parseKeyPath(_zone, _buffer, _idx, _len, _exception,self);
        result = [_parseDigitPath(digitPath) retain];
        [digitPath release]; digitPath = nil;
        valueProperty = YES;
      }
      else if (_isIdChar(_buffer[*_idx])) {
        valueProperty = NO;
	
        if ((_buffer[*_idx] == 'Y') || (_buffer[*_idx] == 'N')) {
          // parse YES and NO
          if ((*_idx + 4) < _len) {
            if (_ucIsEqual(&(_buffer[*_idx]), "YES", 3) &&
		_isBreakChar(_buffer[*_idx + 3])) {
              result = [yesNum retain];
              valueProperty = YES;
              *_idx += 3; // skip the YES
            }
          }
          if (((*_idx + 3) < _len) && !valueProperty) {
            if (_ucIsEqual(&(_buffer[*_idx]), "NO", 2) &&
		_isBreakChar(_buffer[*_idx + 2])) {
              result = [noNum retain];
              valueProperty = YES;
              *_idx += 2; // skip the NO
            }
          }
        }
        else if ((_buffer[*_idx] == 't') || (_buffer[*_idx] == 'f')) {
          // parse true and false
          if ((*_idx + 5) < _len) {
            if (_ucIsEqual(&(_buffer[*_idx]), "true", 4) &&
		_isBreakChar(_buffer[*_idx + 4])) {
              result = [yesNum retain];
              valueProperty = YES;
              *_idx += 4; // skip the true
            }
          }
          if (((*_idx + 6) < _len) && !valueProperty) {
            if (_ucIsEqual(&(_buffer[*_idx]), "false", 5) &&
		_isBreakChar(_buffer[*_idx + 5])) {
              result = [noNum retain];
              valueProperty = YES;
              *_idx += 5; // skip the false
            }
          }
        }
        
        if (!valueProperty) {
          NSCAssert(result == nil, @"result already set ..");
          result = _parseKeyPath(_zone, _buffer, _idx, _len, _exception, self);
        }
      }
      else {
        NSCAssert(result == nil, @"result already set ..");
        
        *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                     @"invalid char");
      }
      break;
  }

  if (*_exception)
    return nil;
  
  if (result == nil) {
    *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                 @"error in property value");
  }

  NSCAssert(result, @"missing property value ..");
  
  if (_allowAssoc) {
    id old = result;
    
    result = valueProperty
      ? [self associationWithValue:result]
      : [self associationWithKeyPath:result];
    
#if 0
    NSCAssert(result, @"got no association for property ..");
#endif
    [old release]; old = nil;
    
    return [result retain];
  }
  
  /* result is already retained */
  return result;
}

static NSDictionary *_parseWodConfig(NSZone *_zone, const unichar *_buffer,
                                     unsigned *_idx, unsigned _len,
                                     NSException **_exception,
                                     id self)
{
  if (!_skipComments(_buffer, _idx, _len, _exception)) {
    // EOF reached during comment-skipping
    *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                     @"did not find element configuration (expected '{')");
    return nil;
  }
  
  if (_buffer[*_idx] != '{') { // it's not a dict that's follows
    *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                     @"did not find element configuration (expected '{')");
    return nil;
  }
  else { // found '{'
    NSMutableDictionary *result = nil;
    NSString *key     = nil;
    id       value    = nil;
    BOOL     didFail  = NO;
    
    *_idx += 1; // skip '{'

    if (!_skipComments(_buffer, _idx, _len, _exception)) {
      *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                       @"element configuration was not closed (expected '}')");
      return nil; // EOF
    }

    if (_buffer[*_idx] == '}') { // an empty configuration
      *_idx += 1; // skip the '}'
      return [[DictClass allocWithZone:_zone] init];
    }

    result = [[DictClass allocWithZone:_zone] init];
    do {
      key   = nil;
      value = nil;
      
      if (!_skipComments(_buffer, _idx, _len, _exception)) {
        *_exception =
          _makeException(*_exception, _buffer, *_idx, _len,
                         @"dictionary was not closed (expected '}')");
        didFail = YES;
        break; // unexpected EOF
      }

      if (_buffer[*_idx] == '}') { // dictionary closed
        *_idx += 1; // skip the '}'
        break;
      }
      
      // read key property
      key = _parseIdentifier(_zone, _buffer, _idx, _len, _exception);
      if (key == nil) { // syntax error
        *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                         @"expected identifier in element configuration ..");
        didFail = YES;
        break;
      }

      /* The following parses:  (comment|space)* '=' (comment|space)* */
      if (!_skipComments(_buffer, _idx, _len, _exception)) {
        *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                         @"expected '=' after id in element configuration");
        didFail = YES;
        break; // unexpected EOF
      }
      // no we need a '=' assignment
      if (_buffer[*_idx] != '=') {
        *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                         @"expected '=' after id in element configuration");
        didFail = YES;
        break;
      }
      *_idx += 1; // skip '='
      if (!_skipComments(_buffer, _idx, _len, _exception)) {
        *_exception =
          _makeException(*_exception, _buffer, *_idx, _len,
                         @"expected value after id '=' in "
                         @"element configuration");
        didFail = YES;
        break; // unexpected EOF
      }

      // read value property
      value = _parseProperty(_zone, _buffer, _idx, _len, _exception, YES, self);
#if 1
      if (*_exception) {
        didFail = YES;
        break;
      }
#else
      if (value == nil) { // syntax error
        if (*_exception == nil) {
          *_exception =
            _makeException(*_exception, _buffer, *_idx, _len,
                           @"got nil-value in element configuration");
        }
        didFail = YES;
        break;
      }
      NSCAssert(key,   @"invalid key ..");
      NSCAssert(value, @"invalid value ..");
#endif

      if ((value != nil) && (key != nil))
        [result setObject:value forKey:key];

      // release key and value
      RELEASE(key);   key   = nil;
      RELEASE(value); value = nil;

      // read trailing ';' if available
      if (!_skipComments(_buffer, _idx, _len, _exception)) {
        *_exception =
          _makeException(*_exception, _buffer, *_idx, _len,
                         @"element configuration was not "
                         @"closed (expected '}')");
        didFail = YES;
        break; // unexpected EOF
      }
      if (_buffer[*_idx] == ';') {
        *_idx += 1; // skip ';'
      }
      else { // no ';' at end of pair, only allowed at end of dictionary
        if (!_skipComments(_buffer, _idx, _len, _exception)) {
          *_exception =
            _makeException(*_exception, _buffer, *_idx, _len,
                           @"element configuration was not "
                           @"closed (expected '}')");
          didFail = YES;
          break; // unexpected EOF
        }

        if (_buffer[*_idx] != '}') { // config wasn't closed
          *_exception =
            _makeException(*_exception, _buffer, *_idx, _len,
                           @"key-value pair without ';' at the end");
          didFail = YES;
          break;
        }
      }
    }
    while ((*_idx < _len) && (result != nil) && !didFail);

    [key   release]; key    = nil;
    [value release]; value  = nil;
    
    if (didFail) {
      [result release]; result = nil;
      return nil;
    }
    else
      return result;
  }
}

static id _parseWodEntry(NSZone *_zone, const unichar *_buffer, unsigned *_idx,
                         unsigned _len, NSException **_exception,
                         NSString **_name, NSString **_class, id self)
{
  NSString     *elementName   = nil;
  NSString     *componentName = nil;
  NSDictionary *config        = nil;

  *_name  = nil;
  *_class = nil;
  
  if (!_skipComments(_buffer, _idx, _len, _exception))
    return nil; // EOF

  // Element name
  elementName = _parseIdentifier(_zone, _buffer, _idx, _len, _exception);
  if (elementName == nil) {
    *_exception = _makeException(nil, _buffer, *_idx, _len,
                                 @"expected element name");
    goto failed;
  }

  if (!_skipComments(_buffer, _idx, _len, _exception))
    goto failed;

  // Element/Component separator
  if (_buffer[*_idx] == ':') {
    *_idx += 1; // skip ':'
  }
  else {
    *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                 @"expected ':' after element name");
    goto failed;
  }

  if (!_skipComments(_buffer, _idx, _len, _exception))
    goto failed;

  // Component Name
  componentName = _parseIdentifier(_zone, _buffer, _idx, _len, _exception);
  if (componentName == nil) {
    *_exception = _makeException(nil, _buffer, *_idx, _len,
                                 @"expected component name");
    goto failed;
  }

  if (!_skipComments(_buffer, _idx, _len, _exception))
    goto failed;

  // Configuration
  config = _parseWodConfig(_zone, _buffer, _idx, _len, _exception, self);
  if (config == nil)
    goto failed;
  
  //NSLog(@"%@ : %@ %@", elementName, componentName, config);

  // read trailing ';' if available
  if (_skipComments(_buffer, _idx, _len, _exception)) {
    if (_buffer[*_idx] == ';') {
      *_idx += 1; // skip ';'
    }
  }

  *_name  = elementName;
  *_class = componentName;
  return config;
  
 failed:
#if 0
  NSLog(@"failed at %@:%@ ..", elementName, componentName);
#endif
  [elementName   release]; elementName   = nil;
  [componentName release]; componentName = nil;
  [config        release]; config        = nil;
  return nil;
}

@end /* WODParser */
