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

#ifndef __NGMail_NGMBoxReader_H__
#define __NGMail_NGMBoxReader_H__

#import <Foundation/NSEnumerator.h>

#import <NGStreams/NGStreamProtocols.h>
#import <NGMime/NGPart.h>

@class NSString, NSDictionary;

@interface NGMBoxReader : NSEnumerator
{
@protected
  id<NGByteSequenceStream> source;
  NSString *lastDate;
  NSString *separator;
  BOOL     isEndOfStream;

  int (*readByte)(id, SEL);
}

+ (id)readerForMBox:(NSString *)_path;
+ (id)mboxWithSource:(id<NGByteSequenceStream>)_source;
                      
- (id)initWithSource:(id<NGByteSequenceStream>)_source;

- (id<NGMimePart>)nextMessage; // same as -nextObject

@end

#endif /* __NGMail_NGMBoxReader_H__ */
