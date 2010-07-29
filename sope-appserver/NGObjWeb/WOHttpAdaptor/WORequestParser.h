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

#ifndef __WOHttpAdaptor_WORequestParser_H__
#define __WOHttpAdaptor_WORequestParser_H__

#import <Foundation/NSObject.h>

/*
  WORequestParser (NOT FINISHED YET)
  
  A specialized parser for WO HTTP requests. It has some advanced features
  like streaming large request bodies to disk and mapping them into memory
  instead of keeping the whole thing in memory all the time.
  It also correctly works with HTTP methods that have no content-length
  specified (the NGHttpParser tries to parse till EOF by default).

  Note: since the parser keep transient state in the ivars, you need to have
  at least one parser per thread when running in a multithreaded environment.
  
  Note: if parsing fails you *need* to close the socket connection !
*/

@class NSException;
@class NGBufferedStream;
@class WORequest;

@interface WORequestParser : NSObject
{
  NGBufferedStream *in;
  NSException *lastException;
  int (*readByte)(id,SEL);
  
  /* transient */
  unsigned char pushBack;
}

- (id)initWithBufferedStream:(NGBufferedStream *)_in;

/* parsing */

- (WORequest *)parseNextRequest;
- (NSException *)lastException;

@end

#endif /* __WOHttpAdaptor_WORequestParser_H__ */
