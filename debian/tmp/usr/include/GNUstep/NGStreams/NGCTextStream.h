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

#ifndef __NGStreams_NGCTextStream_H__
#define __NGStreams_NGCTextStream_H__

#include <NGStreams/NGStreamsDecls.h>
#include <NGStreams/NGStream.h>
#include <NGStreams/NGTextStream.h>
#include <NGStreams/NGTextStreamProtocols.h>
#include <NGStreams/NGFilterStream.h>

@class NSEnumerator;

NGStreams_EXPORT id<NGExtendedTextInputStream>  NGTextIn;
NGStreams_EXPORT id<NGExtendedTextOutputStream> NGTextOut;
NGStreams_EXPORT id<NGExtendedTextOutputStream> NGTextErr;
NGStreams_EXPORT void NGInitTextStdio(void);

/*
  NGCTextStream

  NGCTextStream is a text stream which operates in the operation systems
  default encoding (it returns the bytes read from the source as characters).
  Note that the results of the unicode-methods do not necessarily represent a
  valid unicode character. This is only the case for character codes in the
  7bit ASCII set.
  NGCTextStream never returns a character value above 255.
  
  To retrieve correctly converted unicode characters use the NGTextStream
  class.
*/

@interface NGCTextStream : NGTextStream
{
@private
  id<NGStream>        source; // retained
  NGIOReadMethodType  readBytes;
  NGIOWriteMethodType writeBytes;
  BOOL                (*flushBuffer)(id, SEL);
  NSStringEncoding    encoding;
}

+ (id)textStreamWithInputSource:(id<NGInputStream>)_source;
+ (id)textStreamWithOutputSource:(id<NGOutputStream>)_source;
+ (id)textStreamWithSource:(id<NGStream>)_stream;
- (id)initWithSource:(id<NGStream>)_stream;
- (id)initWithInputSource:(id<NGInputStream>)_source;
- (id)initWithOutputSource:(id<NGOutputStream>)_source;

// accessors

- (id<NGStream>)source;

// operations

- (BOOL)close; // forwarded to source

// NGTextInputStream, NGExtendedTextInputStream

- (unichar)readCharacter;
- (unsigned char)readChar;

- (NSString *)readLineAsString;

// Enumeration

- (NSEnumerator *)lineEnumerator;

// NGTextOutputStream, NGExtendedTextOutputStream

- (BOOL)writeCharacter:(unichar)_character;
- (BOOL)writeString:(NSString *)_string;
- (BOOL)flush;

- (BOOL)writeNewline;

@end

#endif /* __NGStreams_NGCTextStream_H__ */
