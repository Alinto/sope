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

#include <NGXmlRpc/XmlRpcMethodResponse+WO.h>
#include <NGObjWeb/WOResponse.h>
#include "common.h"

@implementation XmlRpcMethodResponse(WO)

// TODO: not required anymore by NGXmlRpcClient, can be removed ?

- (id)initWithResponse:(WOResponse *)_response {
  /* 
     should be based on NSData, so that the XML parser can decide the string
     encoding (based on the <?xml > declaration) !
  */
  NSString *xmlRpcString;
  
  xmlRpcString = [[NSString alloc] initWithData:[_response content]
				   encoding:[_response contentEncoding]];
  
  self = [self initWithXmlRpcString:xmlRpcString];
  [xmlRpcString release];
  return self;
}

- (WOResponse *)generateResponse {
  WOResponse *response;
  
  response = [[[WOResponse alloc] init] autorelease];
  [response setStatus:200];
  [response setHTTPVersion:@"HTTP/1.0"];
  [response setContentEncoding:NSUTF8StringEncoding];
  [response setHeader:@"text/xml" forKey:@"content-type"];
  [response appendContentString:[self xmlRpcString]];
  return response;
}

@end /* XmlRpcMethodResponse(WO) */
