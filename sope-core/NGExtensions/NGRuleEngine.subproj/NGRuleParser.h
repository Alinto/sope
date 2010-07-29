/*
  Copyright (C) 2003-2004 SKYRIX Software AG

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

#ifndef __NGRuleEngine_NGRuleParser_H__
#define __NGRuleEngine_NGRuleParser_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

/*
  NGRuleParser
  
  This class parses NGRule objects. The serialization format is:
  
     qualifier => assignment [; priority]
     
  The qualifier is either the special '*true*' or a serialized EOQualifier
  and the assignment is a key/value statement, eg "value=blue".

  We map some special priority "keys":
    "important" => 1000
    "very high" => 200
    "high"      => 150
    "default"   => 100
    "normal"    => 100
    "low"       => 50
    "very low"  => 5
    "fallback"  => 0
*/

@class NSException, NSString, NSDictionary;
@class EOQualifier;
@class NGRule, NGRuleModel;

@interface NGRuleParser : NSObject
{
  NSString     *ruleQuotes;
  unichar      ruleEscape;
  NSException  *lastException;
  NSDictionary *priorityMapping; /* maps strings to ints (eg high => 10)  */
  NSDictionary *boolMapping;     /* maps strings to bool (eg false => NO) */
}

+ (id)sharedRuleParser;

/* accessors */

- (NSException *)lastException;

/* parsing */

- (NGRule *)parseRuleFromPropertyList:(id)_plist;
- (NGRule *)parseRuleFromString:(NSString *)_plist;
- (NGRuleModel *)parseRuleModelFromPropertyList:(id)_plist;

/* parsing of the individual parts */

- (EOQualifier *)parseQualifierFromString:(NSString *)_s;
- (id)parseActionFromString:(NSString *)_s;
- (int)parsePriorityFromString:(NSString *)_s;

- (BOOL)splitString:(NSString *)_s 
  intoQualifierString:(NSString **)_qs
  actionString:(NSString **)_as
  andPriorityString:(NSString **)_ps;

@end

#endif /* __NGRuleEngine_NGRuleParser_H__ */
