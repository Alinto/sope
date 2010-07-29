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

#ifndef __NGStreams_NGTextStreamProtocols_H__
#define __NGStreams_NGTextStreamProtocols_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@class NSString, NSException;

@protocol NGTextInputStream < NSObject >

- (unichar)readCharacter;

@end

@protocol NGTextOutputStream < NSObject >

- (BOOL)writeCharacter:(unichar)_character;
- (BOOL)writeString:(NSString *)_string;

- (BOOL)flush;

@end

@protocol NGTextStream < NGTextInputStream, NGTextOutputStream >

- (NSException *)lastException;

@end

// extended text streams

@protocol NGExtendedTextInputStream < NGTextInputStream >

- (NSString *)readLineAsString;

@end

@protocol NGExtendedTextOutputStream < NGTextOutputStream >

- (BOOL)writeFormat:(NSString *)_format, ...;
- (BOOL)writeNewline;

@end

@protocol NGExtendedTextStream < NGExtendedTextInputStream, NGExtendedTextOutputStream >
@end

#endif /* __NGStreams_NGTextStreamProtocols_H__ */
