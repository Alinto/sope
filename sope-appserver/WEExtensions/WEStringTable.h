/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __OGoFoundation_WEStringTable_H__
#define __OGoFoundation_WEStringTable_H__

#import <Foundation/NSObject.h>

/*
  WEStringTable
  
  Keeps the contents of a .strings file (translation mapping file).
  
  TODO: support standard translation formats.
*/

@class NSString, NSDictionary, NSDate, NSArray, NSEnumerator;

@interface WEStringTable : NSObject
{
@protected
  NSString     *path;
  NSDictionary *data;
  NSDate       *lastRead;
}

+ (id)stringTableWithPath:(NSString *)_path;
- (id)initWithPath:(NSString *)_path;

- (NSString *)stringForKey:(NSString *)_key withDefaultValue:(NSString *)_def;

/* fake being a dictionary */

- (NSEnumerator *)keyEnumerator;
- (NSEnumerator *)objectEnumerator;
- (id)objectForKey:(id)_key;
- (unsigned int)count;
- (NSArray *)allKeys;
- (NSArray *)allValues;

@end

#endif /* __OGoFoundation_WEStringTable_H__ */
