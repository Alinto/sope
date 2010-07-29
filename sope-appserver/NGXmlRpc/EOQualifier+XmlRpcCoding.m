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

#import <EOControl/EOQualifier.h>
#include "common.h"
#include <XmlRpc/XmlRpcCoder.h>

#if APPLE_FOUNDATION_LIBRARY || NeXT_Foundation_LIBRARY
@interface NSObject(Miss)
- (void)subclassResponsibility:(SEL)cmd;
@end
#endif

@implementation EOQualifier(XmlRpcCoding)

- (id)initWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  // TODO: hh asks: whats that ?
  return [self init];
}
- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  [self subclassResponsibility:_cmd];
}

@end /* EOQualifier */

@implementation EOAndQualifier(XmlRpcCoding)
- (id)initWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  NSArray *quals = [_coder decodeArrayForKey:@"qualifiers"];
  
  return [self initWithQualifierArray:quals];
}

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  [_coder encodeArray:[self qualifiers] forKey:@"qualifiers"];
}

@end /* EOAndQualifier(XmlRpcCoding) */

@implementation EOOrQualifier(XmlRpcCoding)
- (id)initWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  NSArray *quals = [_coder decodeArrayForKey:@"qualifiers"];
  
  return [self initWithQualifierArray:quals];
}

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  [_coder encodeArray:[self qualifiers] forKey:@"qualifiers"];
}

@end /* EOOrQualifier(XmlRpcCoding) */

@implementation EONotQualifier(XmlRpcCoding)
- (id)initWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  return [self initWithQualifier:[_coder decodeObject]];
}

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  [_coder encodeObject:[self qualifier]];
}

@end /* EONotQualifier(XmlRpcCoding) */

@implementation EOKeyValueQualifier(XmlRpcCoding)
- (id)initWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  NSString *k  = nil;
  id       val = nil;
  SEL      sel = NULL;

  k = [_coder decodeStringForKey:@"selector"];
  if (k) sel = NSSelectorFromString(k);
  val = [_coder decodeObjectForKey:@"value"];
  k   = [_coder decodeStringForKey:@"key"];
  
  return [self initWithKey:k operatorSelector:sel value:val];
}

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  [_coder encodeString:[self key]   forKey:@"key"];
  [_coder encodeObject:[self value] forKey:@"value"];
  [_coder encodeString:NSStringFromSelector([self selector])
          forKey:@"selector"];
}

@end /* EOKeyValueQualifier(XmlRpcCoding) */

@implementation EOKeyComparisonQualifier(XmlRpcCoding)

- (id)initWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  NSString *lKey = nil;
  NSString *rKey = nil;
  SEL      sel   = NULL;

  lKey = [_coder decodeStringForKey:@"selector"];
  if (lKey) sel = NSSelectorFromString(lKey);
  lKey = [_coder decodeObjectForKey:@"leftKey"];
  rKey = [_coder decodeStringForKey:@"rightKey"];
  
  return [self initWithLeftKey:lKey operatorSelector:sel rightKey:rKey];
}

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  [_coder encodeString:[self leftKey]  forKey:@"leftKey"];
  [_coder encodeObject:[self rightKey] forKey:@"rightKey"];
  [_coder encodeString:NSStringFromSelector([self selector])
          forKey:@"selector"];
}

@end /* EOKeyComparisonQualifier(XmlRpcCoding) */

#ifdef MULLE_EO_CONTROL
#warning !! EOQualifierVariable still private?
#else
@implementation EOQualifierVariable(XmlRpcCoding)

- (id)initWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  return [self initWithKey:[_coder decodeString]];
}

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  [_coder encodeString:[self key]];
}

@end /* EOQualifierVariable(XmlRpcCoding) */
#endif /* MULLE_EO_CONTROL */
