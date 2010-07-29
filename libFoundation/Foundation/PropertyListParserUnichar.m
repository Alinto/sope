/* 
   PropertyListParser.m

   Copyright (C) 1998 MDlink online service center, Helge Hess
   All rights reserved.

   Author: Helge Hess (helge@mdlink.de)

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#include <ctype.h>
#include <Foundation/common.h>
#include <Foundation/NSException.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSNull.h>
#include <Foundation/exceptions/GeneralExceptions.h>

#ifdef NeXT /* NeXT Mach map_fd() */
#  include <mach/mach.h>
#  include <libc.h>
#elif defined(HAVE_MMAP) /* Posix mmap() */
#  include <sys/types.h>
#  include <sys/mman.h>
#  include <unistd.h>
#else  /* No file mapping available */
#endif

#include "PropertyListParser.h"

// TODO: track filename
// TODO: the code below has quite some duplicate code which should be replaced
//       by macros
// TODO: the 8bit parser used mmap() before, we can't do that with Unicode

static NSString     *_parseString (NSZone *_zone, const unichar *_buffer,
                                   unsigned *_idx, unsigned _len,
                                   NSException **_exception);
static NSDictionary *_parseDict   (NSZone *_zone, const unichar *_buffer,
                                   unsigned *_idx, unsigned _len,
                                   NSException **_exception);
static NSArray      *_parseArray  (NSZone *_zone, const unichar *_buffer,
                                   unsigned *_idx, unsigned _len,
                                   NSException **_exception);
static NSData       *_parseData   (NSZone *_zone, const unichar *_buffer,
                                   unsigned *_idx, unsigned _len,
                                   NSException **_exception);
static id           _parseProperty(NSZone *_zone, const unichar *_buffer,
                                   unsigned *_idx, unsigned _len,
                                   NSException **_exception);
static NSDictionary *_parseStrings(NSZone *_zone, const unichar *_buffer,
                                   unsigned *_idx, unsigned _len,
                                   NSException **_exception,
                                   NSString *fname);

static __inline__ BOOL NSPL_IS_UCS2_BUF(const unsigned char *_buffer, 
					unsigned _len)
{
    if (_len >= 2) {
        if (_buffer[0] == 0xFE && _buffer[1] == 0xFF)
            return YES;
	
	if (_buffer[0] == 0xFF && _buffer[1] == 0xFE)
            return YES;
    }
    return NO;
}

// public unichar functions

NSString *NSParseStringFromUnichars(const unichar *_buffer, unsigned _len)
{
    NSString    *result    = nil;
    NSException *exception = nil;
    unsigned    idx        = 0;
    
    result = _parseString(nil, _buffer, &idx, _len, &exception);
    result = AUTORELEASE(result);
    if (exception)
        [exception raise];
    return result;
}

NSArray *NSParseArrayFromUnichars(const unichar *_buffer, unsigned _len)
{
    NSArray     *result    = nil;
    NSException *exception = nil;
    unsigned    idx        = 0;
    
    result = _parseArray(nil, _buffer, &idx, _len, &exception);
    result = AUTORELEASE(result);
    if (exception)
        [exception raise];
    return result;
}

NSDictionary *NSParseDictionaryFromUnichars(const unichar *_buffer, 
					    unsigned _len)
{
    NSDictionary *result    = nil;
    NSException  *exception = nil;
    unsigned     idx        = 0;
    
    result = _parseDict(nil, _buffer, &idx, _len, &exception);
    result = AUTORELEASE(result);
    if (exception)
        [exception raise];
    return result;
}

// public functions

NSString *NSParseStringFromBuffer(const unsigned char *_buffer, unsigned _len)
{
    // DEPRECATED (based on char stream)
    NSString *result;
    NSString *s;
    
    if (NSPL_IS_UCS2_BUF(_buffer, _len)) {
	NSLog(@"WARNING(%s): tried to parse Unicode string (FE/FF or rev) ...",
	      __PRETTY_FUNCTION__);
	return nil;
    }
    
    s = [[NSString alloc] initWithCString:(char *)_buffer length:_len];
    result = NSParseStringFromString(s);
    [s release];
    return result;
}

NSArray *NSParseArrayFromBuffer(const unsigned char *_buffer, unsigned _len)
{
    // DEPRECATED (based on char stream)
    NSArray  *result;
    NSString *s;

    if (NSPL_IS_UCS2_BUF(_buffer, _len)) {
	NSLog(@"WARNING(%s): tried to parse Unicode string (FE/FF or rev) ...",
	      __PRETTY_FUNCTION__);
	return nil;
    }
    
    s = [[NSString alloc] initWithCString:(char *)_buffer length:_len];
    result = NSParseArrayFromString(s);
    [s release];
    return result;
}

NSDictionary *NSParseDictionaryFromBuffer(const unsigned char *_buffer, 
					  unsigned _len)
{
    // DEPRECATED (based on char stream)
    NSDictionary *result;
    NSString     *s;

    if (NSPL_IS_UCS2_BUF(_buffer, _len)) {
	NSLog(@"WARNING(%s): tried to parse Unicode string (FE/FF or rev) ...",
	      __PRETTY_FUNCTION__);
	return nil;
    }
    
    s = [[NSString alloc] initWithCString:(char *)_buffer length:_len];
    result = NSParseDictionaryFromString(s);
    [s release];
    return result;
}

NSString *NSParseStringFromData(NSData *_data)
{
    NSString *s, *r;
    
    if (_data == nil)
	return nil;
    
    // TODO: could we directly recode to unichar buffer?
    s = [[NSString alloc] initWithData:_data 
			  encoding:[NSString defaultCStringEncoding]];
    r = NSParseStringFromString(s);
    [s release];
    return r;
}

NSArray *NSParseArrayFromData(NSData *_data)
{
    NSArray  *r;
    NSString *s;
    
    if (_data == nil)
	return nil;
    
    // TODO: could we directly recode to unichar buffer?
    s = [[NSString alloc] initWithData:_data 
			  encoding:[NSString defaultCStringEncoding]];
    r = NSParseArrayFromString(s);
    [s release];
    return r;
}

NSDictionary *NSParseDictionaryFromData(NSData *_data)
{
    NSDictionary *r;
    NSString     *s;
    
    if (_data == nil)
	return nil;
    
    // TODO: could we directly recode to unichar buffer?
    s = [[NSString alloc] initWithData:_data 
			  encoding:[NSString defaultCStringEncoding]];
    r = NSParseDictionaryFromString(s);
    [s release];
    return r;
}

NSString *NSParseStringFromString(NSString *_str)
{
    NSString *s;
    unichar  *buf;
    unsigned len;
    
    len = [_str length];
    buf = calloc(len + 4, sizeof(unichar));
    [_str getCharacters:buf]; buf[len] = '\0';
    s = NSParseStringFromUnichars(buf, len);
    if (buf != NULL) free(buf);
    return s;
}

NSArray *NSParseArrayFromString(NSString *_str)
{
    NSArray  *a;
    unichar  *buf;
    unsigned len;
    
    len = [_str length];
    buf = calloc(len + 4, sizeof(unichar));
    [_str getCharacters:buf]; buf[len] = '\0';
    a = NSParseArrayFromUnichars(buf, len);
    if (buf) free(buf);
    return a;
}

NSDictionary *NSParseDictionaryFromString(NSString *_str)
{
    NSDictionary *d;
    unichar      *buf;
    unsigned     len;
    
    len = [_str length];
    buf = calloc(len + 4, sizeof(unichar));
    [_str getCharacters:buf]; buf[len] = '\0';
    d = NSParseDictionaryFromUnichars(buf, len);
    if (buf) free(buf);
    return d;
}

id NSParsePropertyListFromBuffer(const unsigned char *_buffer, unsigned _len)
{
    // DEPRECATED (based on char stream)
    id       result;
    NSString *s;

    if (NSPL_IS_UCS2_BUF(_buffer, _len)) {
	NSLog(@"WARNING(%s): tried to parse Unicode plist (FE/FF or rev) ...",
	      __PRETTY_FUNCTION__);
	return nil;
    }
    
    s = [[NSString alloc] initWithCString:(char *)_buffer length:_len];
    result = NSParsePropertyListFromString(s);
    [s release];
    return result;
}

id NSParsePropertyListFromData(NSData *_data)
{
    return NSParsePropertyListFromBuffer([_data bytes], [_data length]);
}

id NSParsePropertyListFromUnichars(const unichar *_buffer, unsigned _len)
{
    id          result = nil;
    NSException *exception = nil;
    unsigned    idx = 0;
    
    result = _parseProperty(nil, _buffer, &idx, _len, &exception);
    result = AUTORELEASE(result);
    if (exception)
        [exception raise];
    return result;
}

id NSParsePropertyListFromString(NSString *_string)
{
    unsigned len;
    unichar  *buf;
    id       p;

    len = [_string length];
    buf = calloc(len + 4, sizeof(unichar));
    [_string getCharacters:buf]; buf[len] = '\0';
    
    p = NSParsePropertyListFromUnichars(buf, len);
    
    if (buf != NULL) free(buf);
    return p;
}

id NSParsePropertyListFromFile(NSString *_path)
{
    NSString *content;
    id plist;
    
    if (_path == nil)
        return nil;
    
    content = [[NSString alloc] initWithContentsOfFile:_path];
    plist = NSParsePropertyListFromString(content);
    [content release];
    
    return plist;
}

id NSParseStringsFromBuffer(const unsigned char *_buffer, unsigned _len)
{
    // DEPRECATED (based on char stream)
    NSDictionary *result;
    NSString     *s;
    
    s = [[NSString alloc] initWithCString:(char *)_buffer length:_len];
    result = NSParseStringsFromString(s);
    [s release];
    return result;
}

id NSParseStringsFromData(NSData *_data)
{
    NSDictionary *result;
    NSString     *s;
    
    if (_data == nil)
	return nil;
    
    s = [[NSString alloc] initWithData:_data 
			  encoding:[NSString defaultCStringEncoding]];
    result = NSParseStringsFromString(s);
    [s release];
    return result;
}

id NSParseStringsFromStringWithFilename(NSString *_string, NSString *_fn) {
    NSDictionary *o;
    unsigned     len;
    unichar      *buf;
    NSException  *exception = nil;
    unsigned     idx        = 0;
    
    len = [_string length];
    buf = calloc(len + 3, sizeof(unichar));
    [_string getCharacters:buf]; buf[len] = '\0';
    
#if HEAVY_DEBUG
#warning REMOVE DEBUG LOG
    printf("PARSE STR: %s len=%d, %s ",
	   [_fn cString],
	   len, 
	   (*(Class *)_string)->name);
    fflush(stdout);
#endif
    
    o = _parseStrings(nil, buf, &idx, len, &exception, _fn);
    o = AUTORELEASE(o);

#if HEAVY_DEBUG
    printf("=> %d entries\n", [o count]);
#endif
    
    if (buf != NULL) free(buf);
    
    if (exception != nil)
        [exception raise];
    
    return o;
}
id NSParseStringsFromString(NSString *_string)
{
    return NSParseStringsFromStringWithFilename(_string, @"<string>");
}

id NSParseStringsFromFile(NSString *_path)
{
    NSString *content;
    id plist;
    
    if (_path == nil)
        return nil;
    
    content = [[NSString alloc] initWithContentsOfFile:_path];
    plist = NSParseStringsFromStringWithFilename(content, _path);
    [content release];
    
    return plist;
}

/* ******************* implementation ******************** */

static inline BOOL _isBreakChar(unsigned char _c)
{
    switch (_c) {
        case ' ': case '\t': case '\n': case '\r':
        case '/': case '=':  case ';':  case ',':
        case '{': case '(':  case '"':  case '<':
        case ')': case '}':  case '>':
            return YES;

        default:
            return NO;
    }
}
static inline BOOL _isUnquotedStringEndChar(unsigned char _c) {
    switch (_c) {
        case ' ': case '\t': case '\n': case '\r':
        case '=':  case ';':  case ',': case '"':
        case ')': case '}':  case '>':
            return YES;
        
        default:
            return NO;
    }
}

static inline int _valueOfHexChar(char _c)
{
    switch (_c) {
        case '0': case '1': case '2': case '3': case '4':
        case '5': case '6': case '7': case '8': case '9':
            return (_c - '0'); // 0-9 (ascii-char)'0' - 48 => (int)0
      
        case 'A': case 'B': case 'C':
        case 'D': case 'E': case 'F':
            return (_c - 'A' + 10); // A-F, A=10..F=15, 'A'=65..'F'=70
      
        case 'a': case 'b': case 'c':
        case 'd': case 'e': case 'f':
            return (_c - 'a' + 10); // a-f, a=10..F=15, 'a'=97..'f'=102

        default:
            return -1;
    }
}
static inline BOOL _isHexDigit(char _c)
{
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

static inline int _numberOfLines(const unichar *_buffer, unsigned _lastIdx)
{
    register unsigned int pos, lineCount = 1;

    for (pos = 0; (pos < _lastIdx) && (_buffer[pos] != '\0'); pos++) {
        if (_buffer[pos] == '\n')
            lineCount++;
    }
    return lineCount;
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
    
    /* error resulted from a previous error (exception already set) */
    if (_exception) 
        return _exception;
    
    exception = [[SyntaxErrorException alloc] init];
    
    _text = atEof
        ? [NSString stringWithFormat:@"Unexpected end: %@", _text]
        : [NSString stringWithFormat:@"Syntax error in line %i: %@",
                      numLines,_text];
  
    [exception setReason:_text];

    // user info
    {
        ui = [[exception userInfo] mutableCopy];
        if (ui == nil)
            ui = [[NSMutableDictionary alloc] initWithCapacity:8];

        [ui setObject:[NSNumber numberWithInt:numLines] forKey:@"line"];
        [ui setObject:[NSNumber numberWithInt:_len]     forKey:@"size"];
        [ui setObject:[NSNumber numberWithInt:_idx]     forKey:@"position"];

        /*
          if (_len > 0)
          [ui setObject:[NSString stringWithCString:_buffer length:_len]
              forKey:@"text"];
    
          if (!atEof && (_idx > 0)) {
          [ui setObject:[NSString stringWithCString:_buffer length:_idx]
          forKey:@"consumedText"];
          }
        */
        if (!atEof && (_idx > 0)) {
            register signed int pos; // Note: must be signed!
            const unichar *startPos, *endPos;

            for (pos = _idx; (pos >= 0) && (_buffer[pos] != '\n'); pos--)
                ;
            startPos = &(_buffer[pos + 1]);

            for (pos = _idx; ((pos < _len) && (_buffer[pos] != '\n')); pos++)
                ;
            endPos = &(_buffer[pos - 1]);
            
            if (startPos < endPos) {
		NSString *s;
		
		s = [[NSString alloc] initWithCharacters:startPos
				      length:(endPos - startPos)];
                [ui setObject:s forKey:@"lastLine"];
		[s release];
            }
            else {
                NSLog(@"%s: startPos=0x%p endPos=0x%p",
                      __PRETTY_FUNCTION__, startPos, endPos);
            }
        }
    
        [exception setUserInfo:ui];
    
        RELEASE(ui); ui = nil;
    }

    return exception;
}

static BOOL _skipComments(const unichar *_buffer,
                          unsigned *_idx, unsigned _len,
                          BOOL _skipSpaces, NSException **_exception)
{
    register unsigned pos = *_idx;
    BOOL lookAgain;

    if (pos >= _len)
        return NO;
    
    do { // until all comments are filtered ..
        lookAgain = NO;
        
        if ((_buffer[pos] == '/') && ((pos + 1) < _len)) {
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
                        pos++; // skip '*'
                        
                        if (pos < _len) {
                            if (_buffer[pos] == '/') { // found '*/'
                                commentIsClosed = YES;
                                pos ++; // skip '/'
                                lookAgain = YES;
                                break; // leave loop
                            }
#if DEBUG_PLIST
                            else
                                printf("'*' inside multiline comment !\n");
#endif
                        }
                    }
                }
                while (pos < _len);
                
                if (!commentIsClosed) {
                    // EOF found, comment wasn't closed
                    *_exception =
                        _makeException(*_exception, _buffer, *_idx, _len,
                                       @"comment was not closed "
                                       @"(expected '*/')");
                    return NO;
                }
            }
        }
        else if (_skipSpaces && isspace((int)_buffer[pos])) {
            pos++;
            lookAgain = YES;
        }
    }
    while (lookAgain && (pos < _len));
    
    // store position ..
    *_idx = pos;
    //NSLog(@"skipped comments, now at '%s'", &(_buffer[*_idx]));

    return (pos < _len);
}

static NSString *_parseString(NSZone *_zone, const unichar *_buffer,
                              unsigned *_idx,
                              unsigned _len, NSException **_exception)
{

    // skip comments and spaces
    if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
        // EOF reached during comment-skipping
        *_exception =
            _makeException(*_exception, _buffer, *_idx, _len,
                           @"did not find a string !");
        return nil;
    }
    
    if (_buffer[*_idx] == '"') { // a quoted string
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
	
        if (len == 0) // empty string
            return @"";
	
	if (containsEscaped) {
            register unsigned pos2;
            unichar *str;
            id   ostr = nil;

	    str = calloc(len + 3, sizeof(unichar));

            NSCAssert(len > 0, @"invalid length ..");
	    
            for (pos = startPos, pos2 = 0; _buffer[pos] != '"'; pos++,pos2++) {
                //NSLog(@"char=%c pos=%i pos2=%i", _buffer[pos], pos2);
                if (_buffer[pos] == '\\') { /* a quoted char */
                    pos++;
                    switch (_buffer[pos]) {
                    case 'a':  str[pos2] = '\a'; break;
                    case 'b':  str[pos2] = '\b'; break;
                    case 'f':  str[pos2] = '\f'; break;
                    case 'n':  str[pos2] = '\n'; break;
                    case 'r':  str[pos2] = '\r'; break;
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
            str[pos2] = '\0';
            NSCAssert(pos2 == len, @"invalid unescape ..");
	    
            ostr = [[NSString allocWithZone:_zone]
                              initWithCharacters:str length:len];
            if (str != NULL) free(str); str = NULL;
	    
            return ostr;
        }
        else {
            NSCAssert(len > 0, @"invalid length ..");

#if HEAVY_DEBUG
#warning REMOVE DEBUG LOG
	    if (len>10 && _buffer[startPos] == 'B' && 
		_buffer[startPos+1] == 'u') {
		printf("%s: make string len %d (%c,%c,%c,%c)\n",
		       __PRETTY_FUNCTION__, len,
		       _buffer[startPos],
		       _buffer[startPos+1],
		       _buffer[startPos+2],
		       _buffer[startPos+3]);
	    }
#endif
	    
            return [[NSString allocWithZone:_zone]
                              initWithCharacters:&(_buffer[startPos]) 
		              length:len];
        }
    }
    else { /* an unquoted string, may not be zero chars long ! */
        register unsigned pos = *_idx;
        register unsigned len = 0;
        unsigned startPos = pos;
        
        // loop until break char
        while (!_isUnquotedStringEndChar(_buffer[pos]) && (pos < _len)) {
            pos++;
            len++;
        }
        
        if (len == 0) { // wasn't a string ..
            *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                         @"did not find a string !");
            return nil;
        }
	
	*_idx = pos;
	
	return [[NSString allocWithZone:_zone]
		          initWithCharacters:&(_buffer[startPos]) length:len];
    }
}

static NSData *_parseData(NSZone *_zone, const unichar *_buffer,
                          unsigned *_idx, unsigned _len, 
			  NSException **_exception)
{
    if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
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
	
        if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
            *_exception = 
		_makeException(*_exception, _buffer, *_idx, _len,
			       @"data was not closed (expected '>')");
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
                return nil; // abort
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

        // now copy bytes ..
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
                        value = pending * 16 + value;
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

static NSDictionary *_parseDict
(NSZone *_zone, const unichar *_buffer, unsigned *_idx,
 unsigned _len, NSException **_exception)
{
    if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
        // EOF reached during comment-skipping
        *_exception =
            _makeException(*_exception, _buffer, *_idx, _len,
                           @"did not find dictionary (expected '{')");
        return nil;
    }
    
    if (_buffer[*_idx] != '{') { // it's not a dict that's follows
        *_exception =
            _makeException(*_exception, _buffer, *_idx, _len,
                           @"did not find dictionary (expected '{')");
        return nil;
    }
    else {
        NSMutableDictionary *result = nil;
        id   key     = nil;
        id   value   = nil;
        BOOL didFail = NO;
    
        *_idx += 1; // skip '{'

        if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
            *_exception =
                _makeException(*_exception, _buffer, *_idx, _len,
                               @"dictionary was not closed (expected '}')");
            return nil; // EOF
        }

        if (_buffer[*_idx] == '}') { // an empty dictionary
            *_idx += 1; // skip the '}'
            return [[NSDictionary allocWithZone:_zone] init];
        }
	
        result = [[NSMutableDictionary allocWithZone:_zone] init];
        do {
            key   = nil;
            value = nil;
      
            if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
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
            key = _parseProperty(_zone, _buffer, _idx, _len, _exception);
            if (key == nil) { // syntax error
                if (*_exception == nil) {
                    *_exception =
                        _makeException(*_exception,
                                       _buffer, *_idx, _len,
                                       @"got nil-key in dictionary ..");
                }
                didFail = YES;
                break;
            }

            /* The following parses:  (comment|space)* '=' (comment|space)* */
            if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
                *_exception =
                    _makeException(*_exception, _buffer, *_idx, _len,
                                   @"expected '=' after key in dictionary");
                didFail = YES;
                break; // unexpected EOF
            }
            // no we need a '=' assignment
            if (_buffer[*_idx] != '=') {
                *_exception =
                    _makeException(*_exception, _buffer, *_idx, _len,
                                   @"expected '=' after key in dictionary");
                didFail = YES;
                break;
            }
            *_idx += 1; // skip '='
            if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
                *_exception =
                    _makeException(*_exception, _buffer, *_idx, _len,
                                   @"expected value after key '=' in dictionary");
                didFail = YES;
                break; // unexpected EOF
            }

            // read value property
            value = _parseProperty(_zone, _buffer, _idx, _len, _exception);
            if (value == nil) { // syntax error
                value = [NSNull null];
                if (*_exception == nil) {
                    *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                                 @"got nil-value in dictionary");
                }
                didFail = YES;
                break;
            }
            
            NSCAssert(key,   @"invalid key ..");
            NSCAssert(value, @"invalid value ..");

            if ([result objectForKey:key]) {
#if !RAISE_ON_DUPLICATE_KEYS
                NSLog(@"WARNING: duplicate key '%@' found in dictionary !", key);
#else
                NSString *r;
                r = [NSString stringWithFormat:
                                @"duplicate key '%@' found in dictionary !",
                                key];
                *_exception =
                    _makeException(*_exception, _buffer, *_idx, _len, r);
                didFail = YES;
                break; // unexpected EOF
#endif
            }
            
            [result setObject:value forKey:key];

            // release key and value
            RELEASE(key);   key   = nil;
            RELEASE(value); value = nil;

            // read trailing ';' if available
            if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
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
                if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
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

        if (didFail) {
            RELEASE(key);    key    = nil;
            RELEASE(value);  value  = nil;
            RELEASE(result); result = nil;
            return nil;
        }
        else {
#if 1 // TODO: explain
            return result;
#else
	    NSDictionary *d;
	    d = [result copyWithZone:_zone];
	    RELEASE(result);
            return d;
#endif
	}
    }
}

static NSArray *_parseArray(NSZone *_zone, const unichar *_buffer, 
			    unsigned *_idx,
                            unsigned _len, NSException **_exception)
{
    if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
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
    
    {
        NSMutableArray *result = nil;
        id element = nil;

        *_idx += 1; // skip '('

        if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
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
            element = _parseProperty(_zone, _buffer, _idx, _len, _exception);
            if (element == nil) {
                *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                             @"expected element in array");
                RELEASE(result); result = nil;
                break;
            }
            [result addObject:element];
            RELEASE(element); element = nil;

            if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
                *_exception =
                    _makeException(*_exception, _buffer, *_idx, _len,
                                   @"array was not closed (expected ')' or ',')");
                RELEASE(result); result = nil;
                break;
            }

            if (_buffer[*_idx] == ')') { // closed array
                *_idx += 1; // skip ')'
                break;
            }
            else if (_buffer[*_idx] == ',') { // next element
                *_idx += 1; // skip ','

                if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
                    *_exception =
                        _makeException(*_exception, _buffer, *_idx, _len,
                                       @"array was not closed (expected ')')");
                    RELEASE(result); result = nil;
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
                RELEASE(result); result = nil;
                break;
            }
        }
        while ((*_idx < _len) && (result != nil));

        return result;
    }
}

static id _parseProperty(NSZone *_zone, const unichar *_buffer, unsigned *_idx,
                         unsigned _len, NSException **_exception)
{
    id result = nil;
    
    if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
        // no property found
        return nil; // EOF
    }

    switch (_buffer[*_idx]) {
    case '"': // quoted string
        result = _parseString(_zone, _buffer, _idx, _len, _exception);
        break;
    case '{': // dictionary
        result = _parseDict(_zone, _buffer, _idx, _len, _exception);
        break;
    case '(': // array
        result = _parseArray(_zone, _buffer, _idx, _len, _exception);
        break;
    case '<': // data
        result = _parseData(_zone, _buffer, _idx, _len, _exception);
        break;
    default: // an unquoted string
        result = _parseString(_zone, _buffer, _idx, _len, _exception);
        break;
    }
    
    return result;
}

static NSDictionary *_parseStrings(NSZone *_zone, const unichar *_buffer,
                                   unsigned *_idx, unsigned _len,
                                   NSException **_exception,
                                   NSString *fname)
{
    NSMutableDictionary *result = nil;
    id   key     = nil;
    id   value   = nil;
    BOOL didFail = NO;
    
    result = [[NSMutableDictionary allocWithZone:_zone] init];
    while ((*_idx < _len) && (result != nil) && !didFail) {
        key   = nil;
        value = nil;
      
        if (!_skipComments(_buffer, _idx, _len, YES, _exception))
            break; // expected EOF

        // read key string
        key = _parseString(_zone, _buffer, _idx, _len, _exception);
        if (key == nil) { // syntax error
            if (*_exception == nil) {
                NSString *txt = @"got nil-key in string table";
                if (fname)
                    txt = [txt stringByAppendingFormat:@" (path=%@)", fname];
                *_exception =
                    _makeException(*_exception, _buffer, *_idx, _len, txt);
            }
            didFail = YES;
            break;
        }

        /* The following parses:  (comment|space)* '=' (comment|space)* */
        if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
            NSString *txt = @"expected '=' after key in string table";
            if (fname)
                txt = [txt stringByAppendingFormat:@" (path=%@)", fname];
            *_exception =
                _makeException(*_exception, _buffer, *_idx, _len, txt);
            didFail = YES;
            break; // unexpected EOF
        }
        // now we need a '=' assignment
        if (_buffer[*_idx] != '=') {
            NSString *txt = @"expected '=' after key in string table";
            if (fname != nil)
                txt = [txt stringByAppendingFormat:@" (path=%@)", fname];
            *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                         txt);
            didFail = YES;
            break;
        }
        *_idx += 1; // skip '='
        if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
            NSString *txt = @"expected value after key in string table";
            if (fname)
                txt = [txt stringByAppendingFormat:@" (path=%@)", fname];
            *_exception =
                _makeException(*_exception, _buffer, *_idx, _len, txt);
            didFail = YES;
            break; // unexpected EOF
        }
	
        // read value string
        value = _parseString(_zone, _buffer, _idx, _len, _exception);
        if (value == nil) { // syntax error
            if (*_exception == nil) {
                *_exception =
                    _makeException(*_exception, _buffer, *_idx, _len,
                                   @"got nil-value after key in string table");
            }
            didFail = YES;
            break;
        }

        NSCAssert(key,   @"invalid key ..");
        NSCAssert(value, @"invalid value ..");

#if HEAVY_DEBUG	
#warning REMOVE DEBUG LOG
	if ([key indexOfString:@"PrayerAndRepe"] != NSNotFound) {
	    NSLog(@"%s: parsed string (%@,len=%d): %@", __PRETTY_FUNCTION__, 
		  NSStringFromClass([value class]),
		  [value length], value);
	}
#endif
	
        if ([result objectForKey:key]) {
            NSString *txt;

            txt = fname
                ? [NSString stringWithFormat:
                            @"duplicate key '%@' found in strings file '%@'",
                              key, fname]
                : [NSString stringWithFormat:
                            @"duplicate key '%@' found in strings file", key];
            
#if !RAISE_ON_DUPLICATE_KEYS
            NSLog(@"WARNING: %@ !", txt);
#else
            *_exception =
                _makeException(*_exception, _buffer, *_idx, _len, txt);
            didFail = YES;
            break; // unexpected EOF
#endif
        }
        else
            [result setObject:value forKey:key];
        
        // release key and value
        RELEASE(key);   key   = nil;
        RELEASE(value); value = nil;

        // read trailing ';' if available
        if (!_skipComments(_buffer, _idx, _len, YES, _exception))
            break; // expected EOF
	
        if (_buffer[*_idx] == ';') {
            *_idx += 1; // skip ';'
        }
	else {
	    NSLog(@"Warning: strings file misses semicolon "
		  @"(required by Cocoa).");
	}
    }

    if (didFail) {
        RELEASE(key);    key    = nil;
        RELEASE(value);  value  = nil;
        RELEASE(result); result = nil;
        return nil;
    }
    
    return result;
}

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
