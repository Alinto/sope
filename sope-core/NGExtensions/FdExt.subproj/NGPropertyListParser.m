/*
  Copyright (C) 2000-2008 SKYRIX Software AG
  Copyright (C) 2008      Helge Hess

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

#if !LIB_FOUNDATION_LIBRARY

//#define HAVE_MMAP

#ifdef HAVE_MMAP
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <unistd.h>
#endif
#include <ctype.h>

#import "common.h"
#import "NGPropertyListParser.h"
#import "NGMemoryAllocation.h"
//#import "NSObjectMacros.h"
//#import "NSException.h"
#import <Foundation/NSData.h>

#define NoZone NULL

@interface NSException(UsedPrivates) /* may break on Panther? */
- (void)setUserInfo:(NSDictionary *)_ui;
- (void)setReason:(NSString *)_reason;
@end

static NSString     *_parseString (NSZone *_zone, const unsigned char *_buffer,
                                   unsigned *_idx, unsigned _len,
                                   NSException **_exception);
static NSDictionary *_parseDict   (NSZone *_zone, const unsigned char *_buffer,
                                   unsigned *_idx, unsigned _len,
                                   NSException **_exception);
static NSArray      *_parseArray  (NSZone *_zone, const unsigned char *_buffer,
                                   unsigned *_idx, unsigned _len,
                                   NSException **_exception);
static NSData       *_parseData   (NSZone *_zone, const unsigned char *_buffer,
                                   unsigned *_idx, unsigned _len,
                                   NSException **_exception);
static id           _parseProperty(NSZone *_zone, const unsigned char *_buffer,
                                   unsigned *_idx, unsigned _len,
                                   NSException **_exception);
static NSDictionary *_parseStrings(NSZone *_zone, const unsigned char *_buffer,
                                   unsigned *_idx, unsigned _len,
                                   NSException **_exception);

// public functions

NSString *NGParseStringFromBuffer(const unsigned char *_buffer, unsigned _len)
{
    NSString    *result    = nil;
    NSException *exception = nil;
    unsigned    idx        = 0;

    if (_len >= 2) {
        if (_buffer[0] == 0xFE && _buffer[1] == 0xFF) {
            NSLog(@"WARNING(%s): tried to parse Unicode string (FE/FF) ...",
                  __PRETTY_FUNCTION__);
            return nil;
        }
        else if (_buffer[0] == 0xFF && _buffer[1] == 0xFE) {
            NSLog(@"WARNING(%s): tried to parse Unicode string (FF/FE) ...",
                  __PRETTY_FUNCTION__);
            return nil;
        }
    }
    
    result = 
	[_parseString(NoZone, _buffer, &idx, _len, &exception) autorelease];
    [exception raise];
    return result;
}

NSArray *NGParseArrayFromBuffer(const unsigned char *_buffer, unsigned _len)
{
    NSArray     *result    = nil;
    NSException *exception = nil;
    unsigned    idx        = 0;

    if (_len >= 2) {
        if (_buffer[0] == 0xFE && _buffer[1] == 0xFF) {
            NSLog(@"WARNING(%s): tried to parse Unicode array (FE/FF) ...",
                  __PRETTY_FUNCTION__);
            return nil;
        }
        else if (_buffer[0] == 0xFF && _buffer[1] == 0xFE) {
            NSLog(@"WARNING(%s): tried to parse Unicode array (FF/FE) ...",
                  __PRETTY_FUNCTION__);
            return nil;
        }
    }
    
    result = [_parseArray(NoZone, _buffer, &idx, _len, &exception) autorelease];
    [exception raise];
    return result;
}

NSDictionary *NGParseDictionaryFromBuffer(const unsigned char *_buffer, unsigned _len)
{
    NSDictionary *result    = nil;
    NSException  *exception = nil;
    unsigned     idx        = 0;

    if (_len >= 2) {
        if (_buffer[0] == 0xFE && _buffer[1] == 0xFF) {
            NSLog(@"WARNING(%s): tried to parse Unicode dict (FE/FF) ...",
                  __PRETTY_FUNCTION__);
            return nil;
        }
        else if (_buffer[0] == 0xFF && _buffer[1] == 0xFE) {
            NSLog(@"WARNING(%s): tried to parse Unicode dict (FF/FE) ...",
                  __PRETTY_FUNCTION__);
            return nil;
        }
    }
    
    result = [_parseDict(NoZone, _buffer, &idx, _len, &exception) autorelease];
    [exception raise];
    return result;
}

NSString *NGParseStringFromData(NSData *_data)
{
    return NGParseStringFromBuffer([_data bytes], [_data length]);
}

NSArray *NGParseArrayFromData(NSData *_data)
{
    return NGParseArrayFromBuffer([_data bytes], [_data length]);
}

NSDictionary *NGParseDictionaryFromData(NSData *_data)
{
    return NGParseDictionaryFromBuffer([_data bytes], [_data length]);
}

NSString *NGParseStringFromString(NSString *_str)
{
    // TODO: Unicode
    return NGParseStringFromBuffer((unsigned char *)[_str cString], 
				   [_str cStringLength]);
}

NSArray *NGParseArrayFromString(NSString *_str)
{
    // TODO: Unicode
    return NGParseArrayFromBuffer((unsigned char *)[_str cString], 
				  [_str cStringLength]);
}

NSDictionary *NGParseDictionaryFromString(NSString *_str)
{
    // TODO: Unicode
    return NGParseDictionaryFromBuffer((unsigned char *)[_str cString], 
				       [_str cStringLength]);
}

id NGParsePropertyListFromBuffer(const unsigned char *_buffer, unsigned _len)
{
    id          result = nil;
    NSException *exception = nil;
    unsigned    idx = 0;
    
    if (_len >= 2) {
        if (_buffer[0] == 0xFE && _buffer[1] == 0xFF) {
            NSLog(@"WARNING(%s): tried to parse Unicode plist (FE/FF) ...",
                  __PRETTY_FUNCTION__);
            return nil;
        }
        else if (_buffer[0] == 0xFF && _buffer[1] == 0xFE) {
            NSLog(@"WARNING(%s): tried to parse Unicode plist (FF/FE) ...",
                  __PRETTY_FUNCTION__);
            return nil;
        }
    }
    
    result = [_parseProperty(NoZone, _buffer, &idx, _len, &exception) 
			    autorelease];
    [exception raise];
    return result;
}

id NGParsePropertyListFromData(NSData *_data)
{
    return NGParsePropertyListFromBuffer([_data bytes], [_data length]);
}

id NGParsePropertyListFromString(NSString *_string)
{
    return NGParsePropertyListFromBuffer((unsigned char *)[_string cString],
					 [_string cStringLength]);
}

id NGParsePropertyListFromFile(NSString *_path)
{
#ifdef HAVE_MMAP
    NSException *exception = nil;
    int         fd         = 0;
    id          result     = nil;

    fd = open([_path cString], O_RDONLY);
    if (fd != -1) {
        struct stat statInfo;
        if (fstat(fd, &statInfo) == 0) {
            void *mem = NULL;

            mem = mmap(0, statInfo.st_size, PROT_READ, MAP_SHARED, fd, 0);
            if ((mem != MAP_FAILED) || (mem == NULL)) {
                NS_DURING {
                    unsigned idx = 0;
                    result = _parseProperty(nil, mem, &idx, statInfo.st_size,
                                            &exception);
                }
                NS_HANDLER {
                    result = nil;
                    exception = [localException retain];
                }
                NS_ENDHANDLER;

                munmap(mem, statInfo.st_size);
                mem = NULL;
            }
            else {
                NSLog(@"Could not map file %@ into virtual memory !", _path);
            }
        }
        else {
            NSLog(@"File %@ could not be mapped !", _path);
        }
        close(fd);
    }
    else {
        NSLog(@"File %@ does not exist !", _path);
    }

    [result autorelease];
    if (exception)
        [exception raise];
  
    return result;
#else
    NSData *data = [NSData dataWithContentsOfFile:_path];
    
    if (data) {
        return NGParsePropertyListFromData(data);
    }
    else {
        NSLog(@"%s: Could not parse plist file %@ !", __PRETTY_FUNCTION__,
              _path);
        return nil;
    }
#endif
}

NSDictionary *NGParseStringsFromBuffer(const unsigned char *_buffer, 
				       unsigned _len)
{
    NSDictionary *result    = nil;
    NSException  *exception = nil;
    unsigned     idx        = 0;
    
    result = [_parseStrings(NoZone, _buffer, &idx, _len, &exception) autorelease];
    [exception raise];
    return result;
}

NSDictionary *NGParseStringsFromData(NSData *_data)
{
    return NGParseStringsFromBuffer([_data bytes], [_data length]);
}

NSDictionary *NGParseStringsFromString(NSString *_string)
{
    return NGParseStringsFromBuffer((unsigned char *)[_string cString],
				    [_string cStringLength]);
}

NSDictionary *NGParseStringsFromFile(NSString *_path)
{
#ifdef HAVE_MMAP
    struct stat statInfo;
    NSException *exception = nil;
    int         fd = 0;
    id          result = nil;

    fd = open([_path cString], O_RDONLY);
    if (fd != -1) {
        if (fstat(fd, &statInfo) == 0) {
            void *mem = NULL;

            mem = mmap(0, statInfo.st_size, PROT_READ, MAP_SHARED, fd, 0);
            if (mem != MAP_FAILED) {
                NS_DURING {
                    unsigned idx = 0;
                    result = _parseStrings(nil, mem, &idx, statInfo.st_size,
                                           &exception);
                }
                NS_HANDLER {
                    exception = [localException retain];
                    result = nil;
                }
                NS_ENDHANDLER;

                munmap(mem, statInfo.st_size);
                mem = NULL;
            }
            else
                NSLog(@"Could not map file %@ into virtual memory !", _path);
        }
        else {
            NSLog(@"File %@ could not be mapped !", _path);
        }
        close(fd);
    }
    else {
        NSLog(@"File %@ does not exist !", _path);
    }

    [result autorelease];
    [exception raise];
  
    return result;
#else
    NSData *data = [NSData dataWithContentsOfFile:_path];

    if (data)
        return NGParseStringsFromData(data);
    else {
        NSLog(@"%s: Could not parse strings file %@ !",
              __PRETTY_FUNCTION__, _path);
        return nil;
    }
#endif
}

/* ******************* implementation ******************** */

static inline BOOL _isBreakChar(char _c)
{
    switch (_c) {
        case ' ': case '\t': case '\n': case '\r':
        case '/': case '=':  case ';':  case ',':
        case '{': case '(':  case '"':  case '<':
        case '}': case ')': case '>':
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

static inline int _numberOfLines(const unsigned char *_buffer, unsigned _lastIdx)
{
    register int pos, lineCount = 1;

    for (pos = 0; (pos < _lastIdx) && (_buffer[pos] != '\0'); pos++) {
        if (_buffer[pos] == '\n')
            lineCount++;
    }
    return lineCount;
}

static NSException *_makeException(NSException *_exception,
                                   const unsigned char *_buffer, unsigned _idx,
                                   unsigned _len, NSString *_text)
{
    NSMutableDictionary *ui = nil;
    NSException *exception = nil;
    int         numLines   = _numberOfLines(_buffer, _idx);
    BOOL        atEof      = (_idx >= _len) ? YES : NO;

    if (_exception != nil) 
	// error resulted from a previous error (exception already set)
        return _exception;

    _text = atEof
        ? [NSString stringWithFormat:@"Unexpected end: %@", _text]
        : [NSString stringWithFormat:@"Syntax error in line %i: %@",
		    numLines,_text];
    
    // user info
    {
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
            register unsigned pos;
            const unsigned char *startPos, *endPos;

            for (pos = _idx; (pos >= 0) && (_buffer[pos] != '\n'); pos--)
                ;
            startPos = &(_buffer[pos + 1]);

            for (pos = _idx; ((pos < _len) && (_buffer[pos] != '\n')); pos++)
                ;
            endPos = &(_buffer[pos - 1]);

            if (startPos < endPos) {
		NSString *s;
		
		s = [[NSString alloc] initWithCString:(char *)startPos 
				      length:(endPos - startPos)];
		if (s != nil) {
		    [ui setObject:s forKey:@"lastLine"];
		    [s release];
		}
		else {
		    NSLog(@"ERROR(%s): could not get last-line!",
			  __PRETTY_FUNCTION__);
		}
            }
            else
                NSLog(@"startPos=0x%p endPos=0x%p", startPos, endPos);
        }
    }

    exception = [NSException exceptionWithName:@"SyntaxErrorException"
                             reason:_text
                             userInfo:ui];
    [ui release]; ui = nil;
    
    return exception;
}

static BOOL _skipComments(const unsigned char *_buffer, unsigned *_idx, unsigned _len,
                          BOOL _skipSpaces, NSException **_exception)
{
    register unsigned pos = *_idx;
    BOOL lookAgain;

    if (pos >= _len)
        return NO;
  
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

                do { 
		    // search for '*/'
                    while ((pos < _len) && (_buffer[pos] != '*'))
                        pos++;
		    
                    if (pos + 1 >= _len)
			// did not find '*' or not enough left for '/'
			break;
		    
		    pos++; // skip '*'
		    
		    if (_buffer[pos] != '/')
			// missing slash in '*/'
			continue;
		    
		    commentIsClosed = YES;
		    pos++; // skip '/'
		    lookAgain = YES;
		    break; // leave loop
                }
                while (pos < _len);

                if (!commentIsClosed) {
                    // EOF found, comment was not closed
                    *_exception =
                        _makeException(*_exception, _buffer, *_idx, _len,
                                       @"comment was not closed (expected '*/')");
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

static NSString *_parseString(NSZone *_zone, const unsigned char *_buffer, unsigned *_idx,
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
    
        if (len == 0) { // empty string
            return @"";
        }
        else if (containsEscaped) {
            register unsigned pos2;
            char *str = NGMallocAtomic(len + 1);
            id   ostr = nil;

            NSCAssert(len > 0, @"invalid length ..");

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
            str[pos2] = '\0';
            NSCAssert(pos2 == len, @"invalid unescape ..");

            ostr = [[NSString allocWithZone:_zone]
                              initWithCString:str length:len];
            NGFree(str); str = NULL;

            return ostr;
        }
        else {
            NSCAssert(len > 0, @"invalid length ..");
      
            return [[NSString allocWithZone:_zone]
		       initWithCString:(char*)&(_buffer[startPos]) length:len];
        }
    }
    else { // an unquoted string, may not be zero chars long !
        register unsigned pos = *_idx;
        register unsigned len = 0;
        unsigned startPos = pos;

        // loop until break char
        while (!_isBreakChar(_buffer[pos]) && (pos < _len)) {
            pos++;
            len++;
        }

        if (len == 0) { // was not a string ..
            *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                         @"did not find a string !");
            return nil;
        }
        else {
            *_idx = pos;
            return [[NSString allocWithZone:_zone]
		       initWithCString:(char*)&(_buffer[startPos]) length:len];
        }
    }
}

static NSData *_parseData(NSZone *_zone, const unsigned char *_buffer,
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
            register unsigned pending = -1;
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

static NSDictionary *_parseDict(NSZone *_zone, const unsigned char *_buffer, unsigned *_idx,
                                unsigned _len, NSException **_exception)
{
    if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
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
                    *_exception = _makeException(*_exception, _buffer, *_idx, _len,
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
                if (*_exception == nil) {
                    *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                                 @"got nil-value in dictionary");
                }
                didFail = YES;
                break;
            }

            NSCAssert(key,   @"invalid key ..");
            NSCAssert(value, @"invalid value ..");

            [result setObject:value forKey:key];

            // release key and value
            [key   release]; key   = nil;
            [value release]; value = nil;

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

                if (_buffer[*_idx] != '}') { // dictionary was not closed
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
            [key    release]; key    = nil;
            [value  release]; value  = nil;
            [result release]; result = nil;
            return nil;
        }
        else
            return result;
    }
}

static NSArray *_parseArray(NSZone *_zone, const unsigned char *_buffer, unsigned *_idx,
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
    else {
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
                [result release]; result = nil;
                break;
            }
            [result addObject:element];
            [element release]; element = nil;

            if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
                *_exception =
                    _makeException(*_exception, _buffer, *_idx, _len,
                                   @"array was not closed (expected ')' or ',')");
                [result release]; result = nil;
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
                    [result release]; result = nil;
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

        return result;
    }
}

static id _parseProperty(NSZone *_zone, const unsigned char *_buffer, unsigned *_idx,
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

static NSDictionary *_parseStrings(NSZone *_zone, const unsigned char *_buffer,
                                   unsigned *_idx, unsigned _len,
                                   NSException **_exception)
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
                *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                             @"got nil-key in string table ..");
            }
            didFail = YES;
            break;
        }

        /* The following parses:  (comment|space)* '=' (comment|space)* */
        if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
            *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                         @"expected '=' after key in string table");
            didFail = YES;
            break; // unexpected EOF
        }
        // no we need a '=' assignment
        if (_buffer[*_idx] != '=') {
            *_exception = _makeException(*_exception, _buffer, *_idx, _len,
                                         @"expected '=' after key in string table");
            didFail = YES;
            break;
        }
        *_idx += 1; // skip '='
        if (!_skipComments(_buffer, _idx, _len, YES, _exception)) {
            *_exception =
                _makeException(*_exception, _buffer, *_idx, _len,
                               @"expected value after key in string table");
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

        [result setObject:value forKey:key];

        // release key and value
        [key   release]; key   = nil;
        [value release]; value = nil;

        // read trailing ';' if available
        if (!_skipComments(_buffer, _idx, _len, YES, _exception))
            break; // expected EOF

        if (_buffer[*_idx] == ';') {
            *_idx += 1; // skip ';'
        }
    }

    if (didFail) {
        [key    release]; key    = nil;
        [value  release]; value  = nil;
        [result release]; result = nil;
        return nil;
    }
    else
        return result;
}

// ******************** categories ********************

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSException.h>

@implementation NSArray(NGPropertyListParser)

+ (id)skyArrayWithContentsOfFile:(NSString *)_path {
    volatile id plist = nil;
    
    NSString *format = @"%@: Caught exception %@ with reason %@ ";
    
    NS_DURING {
        plist = NGParsePropertyListFromFile(_path);
    
        if (![plist isKindOfClass:[NSArray class]])
            plist = nil;
    }
    NS_HANDLER {
        NSLog(format, self, [localException name], [localException reason]);
        plist = nil;
    }
    NS_ENDHANDLER;

    return plist;
}

- (id)skyInitWithContentsOfFile:(NSString *)_path {
    NSArray *plist = [NSArray arrayWithContentsOfFile:_path];

    if (plist)
        return [self initWithArray:plist];
    else {
        [self autorelease];
        return nil;
    }
}

@end /* NSArray(NGPropertyListParser) */

@implementation NSDictionary(NGPropertyListParser)

+ (id)skyDictionaryWithContentsOfFile:(NSString *)_path {
    volatile id plist = nil;

    NSString *format = @"%@: Caught exception %@ with reason %@ ";
    
    NS_DURING {
        plist = NGParsePropertyListFromFile(_path);
    
        if (![plist isKindOfClass:[NSDictionary class]])
            plist = nil;
    }
    NS_HANDLER {
        NSLog(format, self, [localException name], [localException reason]);
        plist = nil;
    }
    NS_ENDHANDLER;

    return plist;
}

- (id)skyInitWithContentsOfFile:(NSString *)_path {
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:_path];

    if (plist)
        return [self initWithDictionary:plist];
    else {
        [self autorelease];
        return nil;
    }
}

@end /* NSDictionary(NGPropertyListParser) */

#else /* LIB_FOUNDATION_LIBRARY */

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSException.h>

@implementation NSArray(NGPropertyListParser)

+ (id)skyArrayWithContentsOfFile:(NSString *)_path {
    return [self arrayWithContentsOfFile:_path];
}

- (id)skyInitWithContentsOfFile:(NSString *)_path {
    [self release];
    return [[[self class] skyArrayWithContentsOfFile:_path] retain];
}

@end /* NSArray(NGPropertyListParser) */

@implementation NSDictionary(NGPropertyListParser)

+ (id)skyDictionaryWithContentsOfFile:(NSString *)_path {
    return [self dictionaryWithContentsOfFile:_path];
}

- (id)skyInitWithContentsOfFile:(NSString *)_path {
    [self release];
    return [[[self class] skyDictionaryWithContentsOfFile:_path] retain];
}

@end /* NSDictionary(NGPropertyListParser) */

#endif /* LIB_FOUNDATION_LIBRARY */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
