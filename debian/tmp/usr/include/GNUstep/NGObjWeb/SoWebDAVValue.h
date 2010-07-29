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

#ifndef __WebDAV_SoWebDAVValue_H__
#define __WebDAV_SoWebDAVValue_H__

#import <Foundation/NSObject.h>

/*
  SoWebDAVValue
  
  This class can be used for keeping together all information of complex
  WebDAV values (eg namespaces of values, nested XML tags, etc).
  
  The default implementation allows you to associated attributes with the
  generated property tag (eg value typing information).
*/

@class NSString, NSDictionary;

@interface SoWebDAVValue : NSObject
{
  NSDictionary *attributes;
  id object;
}

+ (id)valueForObject:(id)_obj attributes:(NSDictionary *)_attrs;
- (id)initWithObject:(id)_obj attributes:(NSDictionary *)_attrs;

- (NSString *)stringForTag:(NSString *)_key rawName:(NSString *)_extName
  inContext:(id)_ctx
  prefixes:(NSDictionary *)_prefixes;

@end

#endif /* __WebDAV_SoWebDAVValue_H__ */
