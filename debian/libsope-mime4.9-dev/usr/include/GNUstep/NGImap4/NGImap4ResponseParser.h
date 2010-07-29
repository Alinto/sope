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

#ifndef __OGo_NGImap4_NGImap4ResponseParser_H__
#define __OGo_NGImap4_NGImap4ResponseParser_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSException.h>
#include <NGStreams/NGSocketProtocols.h>
#include <NGImap4/NGImap4Support.h>

@class NSString, NSException, NSMutableString;
@class NGHashMap, NGByteBuffer;

@interface NGImap4ResponseParser : NSObject
{
  NGByteBuffer     *buffer;    
  BOOL             debug;
  NSMutableString  *lineDebug;
  
  int (*la)(id, SEL, unsigned);

  NSMutableString *serverResponseDebug;
}

+ (id)parserWithStream:(id<NGActiveSocket>)_stream;
- (id)initWithStream:(id<NGActiveSocket>)_stream;

/* parsing */

- (NGHashMap *)parseResponseForTagId:(int)_tag exception:(NSException **)e_;
- (NGHashMap *)parseSieveResponse;

@end

#endif /* __OGo_NGImap4_NGImap4ResponseParser_H__ */
