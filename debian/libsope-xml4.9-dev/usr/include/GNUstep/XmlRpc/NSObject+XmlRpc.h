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

#ifndef __NSObject_XMLRPC_H__
#define __NSObject_XMLRPC_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>

@interface NSObject(XmlRpcValues)

+ (id)objectWithXmlRpcType:(NSString *)_type
  characters:(unichar *)_chars length:(int)_len;

@end

@interface NSObject(XmlRpcSignatures)
- (NSString *)xmlRpcType;
@end

@interface NSArray(XmlRpcSignatures)
- (NSArray *)xmlRpcElementSignature;
@end

#endif /* __NSObject_XMLRPC_H__ */
