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

#include "NSString+BasicAuth.h"
#include <NGExtensions/NGBase64Coding.h>
#include "common.h"

@implementation NSString(BasicAuth)

/* eg: authorization: "basic aGVsZ2U6aGVsZ2VoZWxnZQ==" */

- (BOOL)isHTTPBasicAuthorizationValue {
  return [self hasPrefix:@"basic"];
}

- (NSString *)decodedHTTPBasicAuthorizationValue {
  NSRange  r;
  NSString *s;
  
  r = [self rangeOfString:@" " options:NSBackwardsSearch];
  if (r.length == 0)
    return nil;
  
  s = [self substringFromIndex:(r.location + r.length)];
  return [s stringByDecodingBase64];
}

- (NSString *)loginOfHTTPBasicAuthorizationValue {
  NSString *s;
  NSRange  r;
  
  if ((s = [self decodedHTTPBasicAuthorizationValue]) == nil)
    return nil;
  if ((r = [s rangeOfString:@":"]).length == 0)
    return nil;
  return [s substringToIndex:r.location];
}
- (NSString *)passwordOfHTTPBasicAuthorizationValue {
  NSString *s;
  NSRange  r;
  
  if ((s = [self decodedHTTPBasicAuthorizationValue]) == nil)
    return nil;
  if ((r = [s rangeOfString:@":"]).length == 0)
    return nil;
  return [s substringFromIndex:(r.location + r.length)];
}

@end /* NSString(BasicAuth) */
