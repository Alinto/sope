/*
  Copyright (C) 2000-2008 SKYRIX Software AG
  Copyright (C) 2007-2008 Helge Hess

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

#include <NGStreams/NGCTextStream.h>
#include <NGStreams/NGStreamExceptions.h>
#include <NGStreams/NGFileStream.h>
#include <NGExtensions/NGCharBuffers.h>
#include "common.h"

static NSString *NGNewLineString = @"\n";

@interface _NGCTextStreamLineEnumerator : NSEnumerator
{
  NGCTextStream *stream;
}
- (id)initWithTextStream:(NGCTextStream *)_stream;
- (id)nextObject;
@end

NGStreams_DECLARE id<NGExtendedTextInputStream>  NGTextIn  = nil;
NGStreams_DECLARE id<NGExtendedTextOutputStream> NGTextOut = nil;
NGStreams_DECLARE id<NGExtendedTextOutputStream> NGTextErr = nil;

@implementation NGCTextStream

+ (int)version {
  return [super version] + 0 /* v2 */;
}

// stdio

NGStreams_DECLARE void NGInitTextStdio(void) {
  static BOOL isInitialized = NO;
  if (!isInitialized) {
    isInitialized = YES;
    
    NGInitStdio();
    
    NGTextIn  = [(NGCTextStream *)[NGCTextStream alloc]
                    initWithSource:(id<NGStream>)NGIn];
    NGTextOut = [(NGCTextStream *)[NGCTextStream alloc]
                    initWithSource:(id<NGStream>)NGOut];
    NGTextErr = [(NGCTextStream *)[NGCTextStream alloc]
                    initWithSource:(id<NGStream>)NGErr];
  }
}

+ (void)_flushForExit:(NSNotification *)_notification {
  // [NGTextIn  flush]; 
  [NGTextIn  release]; NGTextIn  = nil;
  [NGTextOut flush]; [NGTextOut release]; NGTextOut = nil;
  [NGTextErr flush]; [NGTextErr release]; NGTextErr = nil;
}

static void _flushAtExit(void) {
  // [NGTextIn flush];
  [NGTextIn  release]; NGTextIn  = nil;
  [NGTextOut flush]; [NGTextOut release]; NGTextOut = nil;
  [NGTextErr flush]; [NGTextErr release]; NGTextErr = nil;
}

+ (void)initialize {
  BOOL isInitialized = NO;
  if (!isInitialized) {
    NSAssert2([super version] == 2,
              @"invalid superclass (%@) version %i !",
              NSStringFromClass([self superclass]), [super version]);
    isInitialized = YES;

    atexit(_flushAtExit);
  }
}

// system text stream

+ (id)textStreamWithInputSource:(id<NGInputStream>)_s {
  if (_s == nil) return nil;
  return [[(NGCTextStream *)[self alloc] initWithInputSource:_s] autorelease];
}
+ (id)textStreamWithOutputSource:(id<NGOutputStream>)_s {
  if (_s == nil) return nil;
  return [[(NGCTextStream *)[self alloc] initWithOutputSource:_s] autorelease];
}
+ (id)textStreamWithSource:(id<NGStream>)_stream {
  if (_stream == nil) return nil;
  return [[(NGCTextStream *)[self alloc] initWithSource:_stream] autorelease];
}

- (id)initWithSource:(id<NGStream>)_stream {
  if (_stream == nil) {
    [self release];
    return nil;
  }
  if ((self = [super init]) != nil) {
    self->source = [_stream retain];
    
    /* On MacOS 10.5 this is per default 30 aka MacOS Roman */
    self->encoding = [NSString defaultCStringEncoding];

#ifdef __APPLE__
    //#  warning no selector caching on MacOSX ...
#else
    /* check whether we are dealing with a proxy .. */
    if ([source isKindOfClass:[NSObject class]]) {
      self->readBytes   = (NGIOReadMethodType)
        [(NSObject *)source methodForSelector:@selector(readBytes:count:)];
      self->writeBytes  = (NGIOWriteMethodType)
        [(NSObject *)source methodForSelector:@selector(writeBytes:count:)];
      self->flushBuffer = (BOOL (*)(id,SEL))
        [(NSObject *)source methodForSelector:@selector(flush)];
    }
#endif
  }
  return self;
}
- (id)initWithInputSource:(id<NGInputStream>)_source {
  return [self initWithSource:(id)_source];
}
- (id)initWithOutputSource:(id<NGOutputStream>)_source {
  return [self initWithSource:(id)_source];
}

- (void)dealloc {
  [self->source release];
  self->readBytes   = NULL;
  self->writeBytes  = NULL;
  self->flushBuffer = NULL;
  [super dealloc];
}

/* accessors */

- (id<NGStream>)source {
  return self->source;
}
- (int)fileDescriptor {
  return [(id)[self source] fileDescriptor];
}

- (BOOL)isOpen {
  return [(id)[self source] isOpen];
}

/* operations */

- (BOOL)close {
  return [self->source close];
}

/* NGTextInputStream */

- (unichar)readCharacter {
  return [self readChar];
}

- (unsigned char)readChar {
  unsigned char c;
  unsigned res;
  
  if (readBytes) {
    res = readBytes(self->source, @selector(readBytes:count:),
                    &c, sizeof(unsigned char));
  }
  else
    res = [self->source readBytes:&c count:sizeof(unsigned char)];
  
  if (res == NGStreamError) {
    [self setLastException:[self->source lastException]];
    return -1;
  }
  
  return c;
}

/* TODO: fix exception handling */

- (NSString *)readLineAsString {
  NGCharBuffer8   buffer = NULL;
  unsigned char   c;

  *(&buffer) = NGCharBuffer8_new(128);

  NS_DURING {
    unsigned int res;
    
    if (readBytes) {
      do {
        res = self->readBytes(source, @selector(readBytes:count:),
                        &c, sizeof(unsigned char));
        if (res != 1) [[self->source lastException] raise];
        
        if (c == '\r') {
          res = readBytes(source, @selector(readBytes:count:),
                          &c, sizeof(unsigned char));
          if (res != 1) [[self->source lastException] raise];
        }
        
        if ((c != '\n') && (c != 0)) {
          NSAssert1(c != 0, @"tried to add '0' character to buffer '%s' ..",
                    buffer->buffer);
          NGCharBuffer8_addChar(buffer, c);
        }
      }
      while ((c != '\n') && (c != 0));
    }
    else {
      do {
        res = [self->source readBytes:&c count:sizeof(unsigned char)];
	/* TODO: raises exception */
        if (res != 1) [[self->source lastException] raise];
        if (c == '\r') {
          res = [self->source readBytes:&c count:sizeof(unsigned char)];
          if (res != 1) [[self->source lastException] raise];
        }
        
        if ((c != '\n') && (c != 0))
          NGCharBuffer8_addChar(buffer, c);
      }
      while ((c != '\n') && (c != 0));
    }
  }
  NS_HANDLER {
    if ([localException isKindOfClass:[NGEndOfStreamException class]]) {
      if (buffer->length == 0) {
        NGCharBuffer8_dealloc(buffer);
        buffer = NULL;
      }
    }
    else
      [localException raise];
  }
  NS_ENDHANDLER;
  
  return buffer ? NGCharBuffer8_makeStringAndDealloc(buffer) : (NSString *)nil;
}

- (NSEnumerator *)lineEnumerator {
  return [[[_NGCTextStreamLineEnumerator alloc]
                                         initWithTextStream:self]
                                         autorelease];
}


/* NGTextOutputStream */

- (BOOL)writeCharacter:(unichar)_character {
  unsigned char c;
  unsigned res;
  
  if (_character > ((sizeof(unsigned char) * 256) - 1)) {
    // character is not in range of maximum system encoding
    [NSException raise:@"NGCTextStreamEncodingException"
                 format:
                   @"called writeCharacter: with character code (0x%X)"
                   @" exceeding the maximum system character code (0x%X)",
                   _character, ((sizeof(unsigned char) * 256) - 1)];
  }

  c = _character;

  if (self->writeBytes != NULL) {
    res = self->writeBytes(self->source, @selector(writeBytes:count:),
			   &c, sizeof(unsigned char));
  }
  else
    res = [self->source writeBytes:&c count:sizeof(unsigned char)];

  if (res == NGStreamError) {
    [self setLastException:[self->source lastException]];
    return NO;
  }
  
  return YES;
}

- (BOOL)writeString:(NSString *)_string {
  unsigned char *str, *buf;
  unsigned toGo;

#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1040 || (GNUSTEP && OS_API_VERSION(100400,GS_API_LATEST))
  if ((toGo = [_string maximumLengthOfBytesUsingEncoding:self->encoding]) == 0)
    return YES;
  
  buf = str = calloc(toGo + 2, sizeof(unsigned char));
  // Note: maxLength INCLUDES the 0-terminator. And -getCString: does
  //       0-terminate the buffer
  if (![_string getCString:(char *)str maxLength:(toGo + 1)
		encoding:self->encoding]) {
    NSLog(@"ERROR(%s): failed to extract cString in defaultCStringEncoding(%i)"
	  @" from NSString: '%@'\n", __PRETTY_FUNCTION__,
	  self->encoding, _string);
    return NO;
  }
  
  // we need to update the *real* (not the max) length
  toGo = strlen((char *)str);
#else
  if ((toGo = [_string cStringLength]) == 0)
    return YES;

  buf = str = calloc(toGo + 2, sizeof(unsigned char));
  [_string getCString:(char *)str];
  str[toGo] = '\0';
#endif
  
  NS_DURING {
    while (toGo > 0) {
      unsigned writeCount;
      
      writeCount = writeBytes
        ? writeBytes(source, @selector(writeBytes:count:), str, toGo)
        : [source writeBytes:str count:toGo];
      
      if (writeCount == NGStreamError)
        [[self->source lastException] raise];
      
      toGo -= writeCount;
      str  += writeCount;
    }
  }
  NS_HANDLER {
    if (buf != NULL) { free(buf); buf = NULL; };
    [localException raise];
  }
  NS_ENDHANDLER;
  
  if (buf) { free(buf); buf = NULL; }
  return YES;
}

- (BOOL)flush {
  if (flushBuffer)
    return flushBuffer(self->source, @selector(flush));
  else
    return [self->source flush];
}

- (BOOL)writeNewline {
  if (![self writeString:NGNewLineString]) return NO;
  if (![self flush]) return NO;
  return YES;
}

@end /* NGCTextStream */

@implementation _NGCTextStreamLineEnumerator

- (id)initWithTextStream:(NGCTextStream *)_stream {
  self->stream = [_stream retain];
  return self;
}

- (void)dealloc {
  [self->stream release];
  [super dealloc];
}

- (id)nextObject {
  id result;

  *(&result) = nil;
  
  NS_DURING {
    result = [self->stream readLineAsString];
  }
  NS_HANDLER {
    if ([localException isKindOfClass:[NGEndOfStreamException class]])
      result = nil;
    else
      [localException raise];
  }
  NS_ENDHANDLER;
  
  return result;
}

@end /* _NGCTextStreamLineEnumerator */
