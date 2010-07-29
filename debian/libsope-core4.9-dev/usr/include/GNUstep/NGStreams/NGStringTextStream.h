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

#ifndef __NGStreams_NGStringTextStream_H__
#define __NGStreams_NGStringTextStream_H__

#include <NGStreams/NGTextStream.h>
#include <NGStreams/NGTextStreamProtocols.h>

/*
  NGStringTextStream
  
  A text stream which navigates inside an NSString or NSMutableString object.
*/

@interface NGStringTextStream : NGTextStream
{
@private
  NSString *string; // retained
  unsigned index;   // position
  BOOL     isMutable;
}

+ (id)textStreamWithString:(NSString *)_string;
- (id)initWithString:(NSString *)_string;

// accessors

- (NSString *)string;

// operations

- (BOOL)close; // releases string

// NGTextInputStream, NGExtendedTextInputStream

- (unichar)readCharacter;

- (NSString *)readLineAsString; // inefficient implementation

// NGTextOutputStream, NGExtendedTextOutputStream

// throws
//   NGReadOnlyStreamException when the stream is not writeable
//   NGStreamNotOpenException  when the stream is not open
- (BOOL)writeCharacter:(unichar)_character;

// throws
//   NGReadOnlyStreamException when the stream is not writeable
//   NGStreamNotOpenException  when the stream is not open
- (BOOL)writeString:(NSString *)_string;

- (BOOL)flush;

@end

#endif /* __NGStreams_NGStringTextStream_H__ */
