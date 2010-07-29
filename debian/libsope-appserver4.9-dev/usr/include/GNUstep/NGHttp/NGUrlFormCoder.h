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

#ifndef __NGHttp_NGUrlFormCoder_H__
#define __NGHttp_NGUrlFormCoder_H__

#import <Foundation/NSString.h>

@class NGHashMap;

/*
  Decodes 'x-www-form-urlencoded' buffers.

  The _buffer parameter starts with the string after the '?' in a URI, that is,
  the buffer is _not_ the complete URI.
  The function returns a retained hashmap.

  TODO: should be moved to NGExtensions
*/
NGHashMap *NGDecodeUrlFormParameters(const unsigned char *_buf, unsigned _len);

#if 0 /* do not use, use NGExtensions/NSString+misc.h ... */
@interface NSString(FormURLCoding)

- (NSString *)stringByApplyingURLEncoding;

@end
#endif

#endif /* __NGHttp_NGUrlFormCoder_H__ */
