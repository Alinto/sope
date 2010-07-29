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

#ifndef __NGExtensions_NGPropertyListParser_H__
#define __NGExtensions_NGPropertyListParser_H__

#import <Foundation/NSObject.h>

@class NSString, NSArray, NSDictionary, NSData;

/*
  The property list format is:

    Strings: char's without specials:  'hello', but not 'hel  lo'
             or quoted string:         '"hello world !"

    Arrays:  '(' ')'
             or '(' element ( ',' element )* ')'

    Dicts:   '{' ( dictEntry )* '}'
             dictEntry = property '=' property ';' ;

    Data:    '<' data '>', eg: '< AABB 88CC 77a7 11 >'
 */

NSString     *NGParseStringFromBuffer(const unsigned char *_buffer, unsigned _len);
NSArray      *NGParseArrayFromBuffer(const unsigned char *_buffer, unsigned _len);
NSDictionary *NGParseDictionaryFromBuffer(const unsigned char *_buffer, unsigned _len);

NSString     *NGParseStringFromData(NSData *_data);
NSArray      *NGParseArrayFromData(NSData *_data);
NSDictionary *NGParseDictionaryFromData(NSData *_data);
NSString     *NGParseStringFromString(NSString *_str);
NSArray      *NGParseArrayFromString(NSString *_str);
NSDictionary *NGParseDictionaryFromString(NSString *_str);

id NGParsePropertyListFromBuffer(const unsigned char *_buffer, unsigned _len);
id NGParsePropertyListFromData(NSData *_data);
id NGParsePropertyListFromString(NSString *_string);
id NGParsePropertyListFromFile(NSString *_path);

NSDictionary *NGParseStringsFromBuffer(const unsigned char *_buffer,
				       unsigned _len);
NSDictionary *NGParseStringsFromData(NSData *_data);
NSDictionary *NGParseStringsFromString(NSString *_string);
NSDictionary *NGParseStringsFromFile(NSString *_path);

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>

@interface NSArray(NGPropertyListParser)

+ (id)skyArrayWithContentsOfFile:(NSString *)_path;
- (id)skyInitWithContentsOfFile:(NSString *)_path;

@end

@interface NSDictionary(NGPropertyListParser)

+ (id)skyDictionaryWithContentsOfFile:(NSString *)_path;
- (id)skyInitWithContentsOfFile:(NSString *)_path;

@end

#endif /* __NGExtensions_NGPropertyListParser_H__ */
