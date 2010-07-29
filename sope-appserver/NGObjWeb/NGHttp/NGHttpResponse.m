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

#import "common.h"
#import "NGHttpResponse.h"
#import "NGHttpRequest.h"
#import "NGHttpHeaderFields.h"

@interface NGHttpMessage(PrivateMethods)
- (id)initWithHeader:(NGHashMap *)_header version:(NSString *)_version;
@end

@implementation NGHttpResponse

- (id)init {
  return [super initWithHeader:nil version:@"1.0"];
}
- (id)initWithRequest:(NGHttpRequest *)_request {
  if ((self = [super init])) {
    self->header     = [[NGMutableHashMap allocWithZone:[self zone]] init];
    self->body       = nil;

    if (_request) {
      self->majorVersion = [_request majorVersion];
      self->minorVersion = [_request minorVersion];
      self->request    = RETAIN(_request);
    }
    else {
      self->majorVersion = 1;
      self->minorVersion = 0;
    }
    
    self->statusCode = NGHttpStatusCode_OK;
    self->reason     = nil;
  }
  return self;
}

- (id)initWithStatus:(int)_status reason:(NSString *)_reason
  header:(NGHashMap *)_header version:(NSString *)_version
{
  if ((self = [super initWithHeader:_header version:_version])) {
    self->statusCode = _status;
    self->reason = [_reason copy];
  }
  return self;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  RELEASE(self->request);
  RELEASE(self->reason);
  [super dealloc];
}
#endif

// accessors

- (void)setStatusCode:(NGHttpStatusCode)_code {
  self->statusCode = _code;
}
- (NGHttpStatusCode)statusCode {
  return self->statusCode;
}

- (void)setReason:(NSString *)_text {
  if (self->reason != _text) {
    RELEASE(self->reason);
    self->reason = [_text copyWithZone:[self zone]];
  }
}
- (NSString *)reason {
  return self->reason;
}

- (void)setRequest:(NGHttpRequest *)_request {
  ASSIGN(self->request, _request);
}
- (NGHttpRequest *)request {
  return self->request;
}

// description

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<HttpResponse: "
                     @"status=%i reason=%@ header=%@ version=%i/%i body=%@>",
                     self->statusCode,
                     self->reason,
                     self->header,
                     self->majorVersion, self->minorVersion,
                     self->body
                   ];
}

@end

@implementation NGHttpResponse(CommonHeaders)

- (void)setWWWAuthenticate:(NGHttpChallenge *)_challenge {
  [self setValue:_challenge ofHeaderFieldWithName:@"www-authenticate"];
}
- (NGHttpChallenge *)wwwAuthenticate {
  return [self valueOfHeaderFieldWithName:@"www-authenticate"];
}

@end
