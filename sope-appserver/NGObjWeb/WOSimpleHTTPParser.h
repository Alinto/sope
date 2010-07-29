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

#ifndef __NGObjWeb_WOSimpleHTTPParser_H__
#define __NGObjWeb_WOSimpleHTTPParser_H__

#import <Foundation/NSObject.h>
#import <NGStreams/NGStreamProtocols.h>

@class NSData, NSMutableDictionary, NSException, NSString;
@class WORequest, WOResponse;

/*
  WOSimpleHTTPParser

  This is a simplified HTTP parser, it only parses HTTP as emitted by the
  ngobjweb module, for example it doesn't allow chunked content or folded
  header lines.
*/

@interface WOSimpleHTTPParser : NSObject
{
  id<NGStream> io;
  unsigned (*readBytes)(id, SEL, void *, unsigned);
  
  /* parsing results */
  NSData              *content;
  NSMutableDictionary *headers;
  NSException         *lastException;
  NSString            *httpVersion;
  
  /* parsing state */
  unsigned char *lineBuffer;
  unsigned int  lineBufSize;
  int clen;
}

- (id)initWithStream:(id<NGStream>)_stream;

/* transient state */

- (void)reset;

/* parsing */

- (WORequest *)parseRequest;
- (WOResponse *)parseResponse;
- (NSException *)lastException;

@end

#endif /* __NGObjWeb_WOSimpleHTTPParser_H__ */
