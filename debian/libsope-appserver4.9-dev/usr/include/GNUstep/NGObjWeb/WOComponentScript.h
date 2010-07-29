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

#ifndef __NGObjWeb_WOComponentScript_H__
#define __NGObjWeb_WOComponentScript_H__

#import <Foundation/NSObject.h>
#include <NGObjWeb/WOElement.h>

#include <NGObjWeb/WOTemplate.h>

@class NSArray, NSString, NSURL;
@class WOComponentScriptPart;

@interface WOComponentScript : NSObject
{
  NSArray  *scriptParts;
  NSString *language;
}

- (id)initWithContentsOfFile:(NSString *)_path;

/* accessors */

- (NSString *)language;

/* operations */

- (void)addScriptPart:(WOComponentScriptPart *)_part;

@end

@interface WOComponentScriptPart : NSObject
{
  NSURL    *url;
  unsigned startLine;
  NSString *script;
}

- (id)initWithContentsOfFile:(NSString *)_path;
- (id)initWithURL:(NSURL *)_url startLine:(unsigned)_ln script:(NSString *)_s;

@end

#endif /* __NGObjWeb_WOComponentScript_H__ */
