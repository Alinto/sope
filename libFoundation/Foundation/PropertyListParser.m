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
                                   NSException **_exception,
                                   NSString *fname);

// public functions

NSString *NSParseStringFromBuffer(const unsigned char *_buffer, unsigned _len)
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
    
    result = _parseString(nil, _buffer, &idx, _len, &exception);
    result = AUTORELEASE(result);
    if (exception)
        [exception raise];
    return result;
}

NSArray *NSParseArrayFromBuffer(const unsigned char *_buffer, unsigned _len)
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
    
    result = _parseArray(nil, _buffer, &idx, _len, &exception);
    result = AUTORELEASE(result);
    if (exception)
        [exception raise];
    return result;
}

NSDictionary *NSParseDictionaryFromBuffer(const unsigned char *_buffer, unsigned _len)
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
    
    result = _parseDict(nil, _buffer, &idx, _len, &exception);
    result = AUTORELEASE(result);
    if (exception)
        [exception raise];
    return result;
}

NSString *NSParseStringFromData(NSData *_data)
{
    return NSParseStringFromBuffer([_data bytes], [_data length]);
}

NSArray *NSParseArrayFromData(NSData *_data)
{
    return NSParseArrayFromBuffer([_data bytes], [_data length]);
}

NSDictionary *NSParseDictionaryFromData(NSData *_data)
{
    return NSParseDictionaryFromBuffer([_data bytes], [_data length]);
}

NSString *NSParseStringFromString(NSString *_str)
{
    NSString *s;
    char     *buf;
    unsigned len;
    
    len = [_str cStringLength];
    buf = malloc(len + 1);
    [_str getCString:buf]; buf[len] = '\0';
    s = NSParseStringFromBuffer(buf, len);
    free(buf);
    return s;
}

NSArray *NSParseArrayFromString(NSString *_str)
{
    NSArray  *a;
    char     *buf;
    unsigned len;
    
    len = [_str cStringLength];
    buf = malloc(len + 1);
    [_str getCString:buf]; buf[len] = '\0';
    a = NSParseArrayFromBuffer(buf, len);
    free(buf);
    return a;
}

NSDictionary *NSParseDictionaryFromString(NSString *_str)
{
    NSDictionary *d;
    char         *buf;
    unsigned     len;
    
    len = [_str cStringLength];
    buf = malloc(len + 1);
    [_str getCString:buf]; buf[len] = '\0';
    d = NSParseDictionaryFromBuffer(buf, len);
    free(buf);
    return d;
}

id NSParsePropertyListFromBuffer(const unsigned char *_buffer, unsigned _len)
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
    
    result = _parseProperty(nil, _buffer, &idx, _len, &exception);
    result = AUTORELEASE(result);
    if (exception)
        [exception raise];
    return result;
}

id NSParsePropertyListFromData(NSData *_data)
{
    return NSParsePropertyListFromBuffer([_data bytes], [_data length]);
}

id NSParsePropertyListFromString(NSString *_string)
{
    unsigned len;
    char     *buf;
    id       p;

    len = [_string cStringLength];
    buf = malloc(len + 1);
    [_string getCString:buf]; buf[len] = '\0';
    
    p = NSParsePropertyListFromBuffer(buf, len);
    free(buf);
    return p;
}

id NSParsePropertyListFromFile(NSString *_path)
{
    if (_path == nil) {
        return nil;
    }
    else {
#if HAVE_MMAP
        NSException *exception = nil;
        int         fd         = 0;
        id          result     = nil;
        unsigned    plen       = [_path cStringLength];
        char        *path;
        
        path = malloc(plen + 1);
        [_path getCString:path]; path[plen] = '\0';
        
        if ((fd = open(path, O_RDONLY, 0)) != -1) {
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
                    NSLog(@"%s: Couldn't map file '%@' into virtual memory !",
                          __PRETTY_FUNCTION__, _path);
                }
            }
            else {
                NSLog(@"%s: File '%@' couldn't be mapped !",
                      __PRETTY_FUNCTION__,_path);
            }
            close(fd);
        }
#if 0
        else {
            NSLog(@"%s: File %@ does not exist !", __PRETTY_FUNCTION__, _path);
        }
#endif

        if (path) {
            free(path);
            path = NULL;
        }
        
        result = AUTORELEASE(result);
        if (exception) {
            NSMutableDictionary *ui;
            ui = [[exception userInfo] mutableCopy];
            [ui setObject:_path forKey:@"path"];
            [exception setUserInfo:ui];
            RELEASE(ui); ui = nil;
            [exception raise];
        }
        return result;
#else
        NSData *data;
        
        if ((data = [NSData dataWithContentsOfFile:_path])) {
            id          result = nil;
            NSException *exception = nil;
            unsigned    idx = 0;
            void        *_buffer;
            unsigned    _len;

            _buffer = (void *)[data bytes];
            _len    = [data length];
            
            result = _parseProperty(nil, _buffer, &idx, _len, &exception);
            result = AUTORELEASE(result);
            
            if (exception) {
                NSMutableDictionary *ui;
                ui = [[exception userInfo] mutableCopy];
                [ui setObject:_path forKey:@"path"];
                [exception setUserInfo:ui];
                RELEASE(ui); ui = nil;
                
                [exception raise];
            }
            return result;
        }
        else {
            NSLog(@"%s: couldn't read file %@ !", __PRETTY_FUNCTION__, _path);
            return nil;
        }
#endif
    }
}

id NSParseStringsFromBuffer(const unsigned char *_buffer, unsigned _len)
{
    NSDictionary *result    = nil;
    NSException  *exception = nil;
    unsigned     idx        = 0;

    result = _parseStrings(nil, _buffer, &idx, _len, &exception, @"<buffer>");
    result = AUTORELEASE(result);
    if (exception)
        [exception raise];
    return result;
}

id NSParseStringsFromData(NSData *_data)
{
    NSDictionary *result    = nil;
    NSException  *exception = nil;
    unsigned     idx        = 0;

    result = _parseStrings(nil, [_data bytes], &idx, [_data length],
                           &exception, @"<data>");
    result = AUTORELEASE(result);
    if (exception)
        [exception raise];
    return result;
}

id NSParseStringsFromString(NSString *_string)
{
    NSDictionary *o;
    unsigned     len;
    char         *buf;
    NSException  *exception = nil;
    unsigned     idx        = 0;
    
    len = [_string cStringLength];
    buf = malloc(len + 1);
    [_string getCString:buf]; buf[len] = '\0';
    
    o = _parseStrings(nil, buf, &idx, len, &exception, @"<string>");
    o = AUTORELEASE(o);
    
    free(buf);

    if (exception)
        [exception raise];
    
    return o;
}

id NSParseStringsFromFile(NSString *_path)
{
#ifdef HAVE_MMAP
    struct stat statInfo;
    NSException *exception = nil;
    int         fd = 0;
    id          result = nil;
    unsigned    plen = [_path cStringLength];
    char        *path;
    
    path = malloc(plen + 1);
    [_path getCString:path]; path[plen] = '\0';
    
    fd = open(path, O_RDONLY, 0);
    free(path); path = NULL;
    
    if (fd != -1) {
        if (fstat(fd, &statInfo) == 0) {
            void *mem = NULL;

            mem = mmap(0, statInfo.st_size, PROT_READ, MAP_SHARED, fd, 0);
            if (mem != MAP_FAILED) {
                NS_DURING {
                    unsigned idx = 0;
                    result = _parseStrings(nil, mem, &idx, statInfo.st_size,
                                           &exception,
                                           _path);
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
                NSLog(@"Couldn't map file %@ into virtual memory !", _path);
        }
        else {
            NSLog(@"File %@ couldn't be mapped !", _path);
        }
        close(fd);
    }
#if 0
    else {
        NSLog(@"File %@ does not exist !", _path);
    }
#endif

    result = AUTORELEASE(result);
    if (exception) {
        NSMutableDictionary *ui;
        ui = [[exception userInfo] mutableCopy];
        [ui setObject:_path forKey:@"path"];
        [exception setUserInfo:ui];
        RELEASE(ui); ui = nil;
        
        [exception raise];
    }
    return result;
#else
    NSData *data;

    if ((data = [NSData dataWithContentsOfFile:_path])) {
        NSDictionary *result    = nil;
        NSException  *exception = nil;
        unsigned     idx        = 0;
        void         *_buffer;
        unsigned     _len;

        _buffer = (void *)[data bytes];
        _len    = [data length];
        result  = _parseStrings(nil, _buffer, &idx, _len, &exception, _path);
        result  = AUTORELEASE(result);
        
        if (exception) {
            NSMutableDictionary *ui;
            ui = [[exception userInfo] mutableCopy];
            [ui setObject:_path forKey:@"path"];
            [exception setUserInfo:ui];
            RELEASE(ui); ui = nil;
                
            [exception raise];
        }
        return result;
    }
    else {
        NSLog(@"%s: couldn't read file %@ !", __PRETTY_FUNCTION__, _path);
        return nil;
    }
#endif
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

static inline int _numberOfLines(const unsigned char *_buffer, unsigned _lastIdx)
{
    register unsigned int pos, lineCount = 1;

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
            register unsigned pos;
            const unsigned char *startPos, *endPos;

            for (pos = _idx; (pos >= 0) && (_buffer[pos] != '\n'); pos--)
                ;
            startPos = &(_buffer[pos + 1]);

            for (pos = _idx; ((pos < _len) && (_buffer[pos] != '\n')); pos++)
                ;
            endPos = &(_buffer[pos - 1]);
            
            if (startPos < endPos) {
                [ui setObject:[NSString stringWithCString:startPos
                                        length:(endPos - startPos)]
                    forKey:@"lastLine"];
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

static BOOL _skipComments(const unsigned char *_buffer,
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

static NSString *_parseString(NSZone *_zone, const unsigned char *_buffer,
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
    
        if (len == 0) { // empty string
            return @"";
        }
        else if (containsEscaped) {
            register unsigned pos2;
            char *str = MallocAtomic(len + 1);
            id   ostr = nil;

            NSCAssert(len > 0, @"invalid length ..");

            for (pos = startPos, pos2 = 0; _buffer[pos] != '"'; pos++, pos2++) {
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
                              initWithCString:str length:len];
            lfFree(str); str = NULL;

            return ostr;
        }
        else {
            NSCAssert(len > 0, @"invalid length ..");
      
            return [[NSString allocWithZone:_zone]
                              initWithCString:&(_buffer[startPos]) length:len];
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
        else {
            *_idx = pos;
            return [[NSString allocWithZone:_zone]
                              initWithCString:&(_buffer[startPos]) length:len];
        }
    }
}

static NSData *_parseData(NSZone *_zone, const unsigned char *_buffer,
                          unsigned *_idx, unsigned _len, NSException **_exception)
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
(NSZone *_zone, const unsigned char *_buffer, unsigned *_idx,
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
#if 1
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
            if (fname)
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
    }

    if (didFail) {
        RELEASE(key);    key    = nil;
        RELEASE(value);  value  = nil;
        RELEASE(result); result = nil;
        return nil;
    }
    else
        return result;
}

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
