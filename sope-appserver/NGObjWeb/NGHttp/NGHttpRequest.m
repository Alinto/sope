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

#include "NGHttpRequest.h"
#include "common.h"
#include "NGUrlFormCoder.h"

NSString *methodNames[] = {
  @"<unknown HTTP method>",
  @"OPTIONS",
  @"GET",
  @"HEAD",
  @"POST",
  @"PUT",
  @"PATCH",
  @"COPY",
  @"MOVE",
  @"DELETE",
  @"LINK",
  @"UNLINK",
  @"TRACE",
  @"WRAPPED",
  @"CONNECT",
  @"PROPFIND",
  @"PROPPATCH",
  @"MKCOL",
  @"LOCK",
  @"UNLOCK",
  /* Exchange Ext Methods */
  @"SEARCH", 
  @"SUBSCRIBE",
  @"UNSUBSCRIBE",
  @"NOTIFY",
  @"POLL",
  /* Exchange Bulk Methods */
  @"BCOPY",
  @"BDELETE",
  @"BMOVE",
  @"BPROPFIND",
  @"BPROPPATCH",
  /* RFC 3253 (DeltaV) */
  @"REPORT",
  @"VERSION-CONTROL",
  /* RFC 3744 (WebDAV ACL) */
  @"ACL",
  /* RFC 4791 (CalDAV) */
  @"MKCALENDAR",
  /* http://ietfreport.isoc.org/idref/draft-daboo-carddav/ (CardDAV) */
  @"MKADDRESSBOOK",
  nil
};

@interface NGHttpMessage(PrivateMethods)
- (id)initWithHeader:(NGHashMap *)_header version:(NSString *)_version;
@end

@implementation NGHttpRequest

- (id)initWithMethod:(NSString *)_methodName uri:(NSString *)_uri
  header:(NGHashMap *)_header version:(NSString *)_version
{
  if ((self = [super initWithHeader:_header version:_version])) {
    self->method = NGHttpMethodFromString(_methodName);
    self->uri    = [_uri copyWithZone:[self zone]];
  }
  return self;
}
- (id)initWithHeader:(NGHashMap *)_header version:(NSString *)_version {
  return [self initWithMethod:@"GET" uri:@"/" header:_header version:_version];
}

- (void)dealloc {
  [self->uri           release];
  [self->uriParameters release];
  [super dealloc];
}

/* accessors */

- (NGHttpMethod)method {
  return self->method;
}
- (NSString *)methodName {
  return (self->method < NGHttpMethod_last) 
    ? methodNames[self->method] : (NSString *)nil;
}

- (NSString *)path {
  return self->uri;
}

- (NSString *)uri {
  return self->uri;
}

- (NGHashMap *)uriParameters { // parameters in x-www-form-urlencoded encoding
  if (self->uriParameters == nil) {
    const char *cstr;
    const unsigned char *pos;
    
    cstr = [self->uri cString];
    pos  = (const unsigned char *)index(cstr, '?');
    if (pos != NULL) {
      pos++;
      self->uriParameters = NGDecodeUrlFormParameters(pos, strlen((char*)pos));
    }
  }
  return self->uriParameters;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return NO;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<HttpRequest: method=%@ uri=%@ header=%@ body=%@>",
                     [self methodName],
                     [self uri],
                     self->header,
                     self->body];
}

@end /* NGHttpRequest */

NGHttpMethod NGHttpMethodFromString(NSString *_value) {
  int i = 0;

  for (i = 1; i < NGHttpMethod_last; i++) {
    NSString *name = methodNames[i];

    if ([name isEqualToString:_value])
      return i;
  }
  return 0;
}
