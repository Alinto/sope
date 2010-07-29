/* 
   PropertyListParser.h

   Copyright (C) 1998 MDlink online service center, Helge Hess
   All rights reserved.

   Author: Helge Hess (helge@mdlink.de)

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/
// $Id: PropertyListParser.h 827 2005-06-03 14:18:27Z helge $

#ifndef __PropertyListParser_h__
#define __PropertyListParser_h__

#include <Foundation/NSObject.h>

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

// Note: you should prefer the NSString methods
NSString     *NSParseStringFromBuffer(const unsigned char *_buffer, 
				      unsigned _len);
NSArray      *NSParseArrayFromBuffer(const unsigned char *_buffer, 
				     unsigned _len);
NSDictionary *NSParseDictionaryFromBuffer(const unsigned char *_buffer, 
					  unsigned _len);

NSString     *NSParseStringFromData(NSData *_data);
NSArray      *NSParseArrayFromData(NSData *_data);
NSDictionary *NSParseDictionaryFromData(NSData *_data);
NSString     *NSParseStringFromString(NSString *_str);
NSArray      *NSParseArrayFromString(NSString *_str);
NSDictionary *NSParseDictionaryFromString(NSString *_str);

id NSParsePropertyListFromBuffer(const unsigned char *_buffer, unsigned _len);
id NSParsePropertyListFromData(NSData *_data);
id NSParsePropertyListFromString(NSString *_string);
id NSParsePropertyListFromFile(NSString *_path);

id NSParseStringsFromBuffer(const unsigned char *_buffer, unsigned _len);
id NSParseStringsFromData(NSData *_data);
id NSParseStringsFromString(NSString *_string);
id NSParseStringsFromFile(NSString *_path);

#endif /* __PropertyListParser_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
