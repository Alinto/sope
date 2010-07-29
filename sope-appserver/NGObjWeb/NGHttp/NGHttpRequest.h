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

#ifndef __NGHttp_NGHttpRequest_H__
#define __NGHttp_NGHttpRequest_H__

#import "NGHttpMessage.h"

@class NSString;

typedef enum {
  NGHttpMethod_unknown = 0,
  NGHttpMethod_OPTIONS = 1,
  NGHttpMethod_GET,
  NGHttpMethod_HEAD,
  NGHttpMethod_POST,
  NGHttpMethod_PUT,
  NGHttpMethod_PATCH,
  NGHttpMethod_COPY,
  NGHttpMethod_MOVE,
  NGHttpMethod_DELETE,
  NGHttpMethod_LINK,
  NGHttpMethod_UNLINK,
  NGHttpMethod_TRACE,
  NGHttpMethod_WRAPPED,
  NGHttpMethod_CONNECT,
  NGHttpMethod_PROPFIND,
  NGHttpMethod_PROPPATCH,
  NGHttpMethod_MKCOL,
  NGHttpMethod_LOCK,
  NGHttpMethod_UNLOCK,
  /* Exchange Ext Methods */
  NGHttpMethod_SEARCH, 
  NGHttpMethod_SUBSCRIBE,
  NGHttpMethod_UNSUBSCRIBE,
  NGHttpMethod_NOTIFY,
  NGHttpMethod_POLL,
  /* Exchange Bulk Methods */
  NGHttpMethod_BCOPY,
  NGHttpMethod_BDELETE,
  NGHttpMethod_BMOVE,
  NGHttpMethod_BPROPFIND,
  NGHttpMethod_BPROPPATCH,
  /* RFC 3253 (DeltaV) */
  NGHttpMethod_REPORT,
  NGHttpMethod_VERSION_CONTROL,
  /* RFC 4791 (CalDAV) */
  NGHttpMethod_MKCALENDAR,
  /* http://ietfreport.isoc.org/idref/draft-daboo-carddav/ (CardDAV) */
  NGHttpMethod_MKADDRESSBOOK,
  NGHttpMethod_last
} NGHttpMethod;

NGHttpMethod NGHttpMethodFromString(NSString *_value);

@interface NGHttpRequest : NGHttpMessage
{
  NGHttpMethod method;
  NSString     *uri;
  NGHashMap    *uriParameters;
}

- (id)initWithMethod:(NSString *)_methodName uri:(NSString *)_uri
  header:(NGHashMap *)_header version:(NSString *)_version;

/* accessors */

- (NGHttpMethod)method;
- (NSString *)methodName;
- (NSString *)uri;

- (NGHashMap *)uriParameters; // parameters in x-www-form-urlencoded encoding

@end

#endif /* __NGHttp_NGHttpRequest_H__ */
