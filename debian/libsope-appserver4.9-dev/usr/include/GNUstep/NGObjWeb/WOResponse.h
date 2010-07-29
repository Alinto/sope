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

#ifndef __NGObjWeb_WOResponse_H__
#define __NGObjWeb_WOResponse_H__

#import <Foundation/NSString.h>
#include <NGObjWeb/WOMessage.h>
#include <NGObjWeb/WOActionResults.h>

/*
  WOResponse
  
  This WOMessage subclass add functionality for HTTP responses, mostly
  the HTTP status. WOResponse also provides some methods for zipping itself.
*/

@class NSData;
@class WORequest;

@interface WOResponse : WOMessage < WOActionResults >
{
  unsigned int status;
}

/* HTTP */

- (void)setStatus:(unsigned int)_status;
- (unsigned int)status;

@end

@interface WOResponse(PrivateMethods)

+ (WOResponse *)responseWithRequest:(WORequest *)_request;
- (id)initWithRequest:(WORequest *)_request;

- (void)disableClientCaching;

@end

@interface WOResponse(Zipping)

- (BOOL)shouldZipResponseToRequest:(WORequest *)_rq;
- (NSData *)zipResponse;

@end

#endif /* __NGObjWeb_WOResponse_H__ */
