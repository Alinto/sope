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

#ifndef __NGStreams_NGTextStream_H__
#define __NGStreams_NGTextStream_H__

#import <Foundation/NSObject.h>
#include <NGStreams/NGTextStreamProtocols.h>

/*
  NGTextStream
  
  Abstract superclass for 'text streams'. Text streams are streams which
  are based on unichars and NSStrings instead of bytes and byte buffers.
*/

@class NSException;

@interface NGTextStream : NSObject < NGExtendedTextStream >
{
@private
  NSException *lastException;
}

// NGTextInputStream

- (unichar)readCharacter;       // abstract
- (NSException *)lastException;
- (void)setLastException:(NSException *)_exception;
- (void)resetLastException;

/* NGExtendedTextInputStream */

- (NSString *)readLineAsString; // inefficient
- (unsigned)readCharacters:(unichar *)_chars count:(unsigned)_count;
- (BOOL)safeReadCharacters:(unichar *)_chars count:(unsigned)_count;

// NGTextOutputStream

- (BOOL)writeCharacter:(unichar)_character; // abstract
- (BOOL)writeString:(NSString *)_string;    // writeCharacter: based
- (BOOL)flush; // does nothing

// NGExtendedTextOutputStream

- (BOOL)writeFormat:(NSString *)_format arguments:(va_list)_ap;
- (BOOL)writeFormat:(NSString *)_format, ...;
- (BOOL)writeNewline;

- (unsigned)writeCharacters:(const unichar *)_chars count:(unsigned)_count;
- (BOOL)safeWriteCharacters:(const unichar *)_chars count:(unsigned)_count;

@end

#endif /* __NGStreams_NGTextStream_H__ */
