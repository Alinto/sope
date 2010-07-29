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

#import <EOControl/EOSortOrdering.h>
#include "common.h"
#include <XmlRpc/XmlRpcCoder.h>

@implementation EOSortOrdering(XmlRpcCoding)

- (id)initWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  NSString *k = nil;
  SEL      sel  = NULL;

  k = [_coder decodeStringForKey:@"selector"];
  if (k) sel = NSSelectorFromString(k);
  k = [_coder decodeStringForKey:@"key"];
  
  return [self initWithKey:k selector:sel];
}

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  [_coder encodeString:[self key] forKey:@"key"];
  [_coder encodeString:NSStringFromSelector([self selector])
                forKey:@"selector"];
}

@end /* EOSortOrdering(XmlRpcCoding) */
