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

#ifndef __NGHttp_H__
#define __NGHttp_H__

#import <NGHttp/NGHttpMessage.h>
#import <NGHttp/NGHttpMessageParser.h>
#import <NGHttp/NGHttpRequest.h>
#import <NGHttp/NGHttpResponse.h>
#import <NGHttp/NGHttpHeaderFieldParser.h>
#import <NGHttp/NGHttpHeaderFields.h>
#import <NGHttp/NGHttpCookie.h>
#import <NGHttp/NGUrlFormCoder.h>

// kit class

@interface NGHttp : NSObject
@end

#define LINK_NGHttp \
  static void __link_NGHttp(void) { \
    [NGHttp self]; \
    __link_NGHttp(); \
  }

#endif /* __NGHttp_H__ */
