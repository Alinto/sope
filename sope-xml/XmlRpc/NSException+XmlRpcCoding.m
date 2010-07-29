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

#include "XmlRpcMethodResponse.h"
#include "common.h"
#include "XmlRpcCoder.h"

@implementation NSException(XmlRpcCoding)

- (NSString *)xmlRpcType {
  return @"struct";
}

- (NSNumber *)xmlRpcFaultCode {
  NSDictionary *ui;
  id code;

  ui = [self userInfo];
  
  if ((code = [ui objectForKey:@"XmlRpcFaultCode"]))
    /* code is set */;
  else if ((code = [ui objectForKey:@"faultCode"]))
    /* code is set */;
  else
    code = [self name];
  
  return [NSNumber numberWithInt:[code intValue]];
}

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  int      code;
  NSString *str, *n, *r;
  NSDictionary *ui;
  
  code = [[self xmlRpcFaultCode] intValue];
  
  n = [self name];
  r = [self reason];
  
  if ([n length] == 0)
    str = r;
  else if ([r length] == 0)
    str = n;
  else
    str = [NSString stringWithFormat:@"%@: %@", n, r];
  
  if ((ui = [self userInfo]))
    str = [NSString stringWithFormat:@"%@ %@", str, ui];
  
  [_coder encodeInt:code   forKey:@"faultCode"];
  [_coder encodeString:str forKey:@"faultString"];
}

+ (NSString *)exceptionNameForXmlRpcFaultCode:(int)_code {
  return [NSString stringWithFormat:@"XmlRpcFault<%i>", _code];
}
- (NSString *)exceptionNameForXmlRpcFaultCode:(int)_code {
  return [[self class] exceptionNameForXmlRpcFaultCode:_code];
}

+ (id)decodeObjectWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  int          code;
  NSString     *r;
  NSDictionary *ui;
  
  code = [_coder decodeIntForKey:@"faultCode"];
  r    = [_coder decodeStringForKey:@"faultString"];
  ui   = [NSDictionary dictionaryWithObjectsAndKeys:
                         [NSNumber numberWithInt:code], @"faultCode",
                         r, @"faultString",
                         nil];
  
  return [self exceptionWithName:
                 [self exceptionNameForXmlRpcFaultCode:code]
               reason:r
               userInfo:ui];
}

@end /* NSException(XmlRpcCoding) */
