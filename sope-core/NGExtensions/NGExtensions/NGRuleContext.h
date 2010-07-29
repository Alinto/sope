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

#ifndef __NGRuleEngine_NGRuleContext_H__
#define __NGRuleEngine_NGRuleContext_H__

#import <Foundation/NSObject.h>

/*
  NGRuleContext
  
  This is a specialized rule evaluation object for key based (assignment)
  rules. It exports evaluated rule values using key-value coding, thereby
  giving a very simple access somewhat similiar to CSS.
*/

@class NSString, NSArray, NSMutableDictionary;
@class NGRuleModel;

@interface NGRuleContext : NSObject
{
  NSMutableDictionary *storedValues;
  NGRuleModel *model;
  BOOL        debugOn;
}

+ (id)ruleContextWithModelInUserDefault:(NSString *)_defName;
+ (id)ruleContextWithModel:(NGRuleModel *)_model;
- (id)initWithModel:(NGRuleModel *)_model;

/* accessors */

- (void)setModel:(NGRuleModel *)_model;
- (NGRuleModel *)model;

- (void)setDebugEnabled:(BOOL)_flag;
- (BOOL)isDebuggingEnabled;

/* values */

- (void)takeStoredValue:(id)_value forKey:(NSString *)_key;
- (id)storedValueForKey:(NSString *)_key;
- (void)reset;

- (void)takeValue:(id)_value forKey:(NSString *)_key;

/* processing */

- (id)valueForKey:(NSString *)_key;

- (id)inferredValueForKey:(NSString *)_key;
- (NSArray *)allPossibleValuesForKey:(NSString *)_key;

- (NSArray *)valuesForKeyPath:(NSString *)_kp
  takingSuccessiveValues:(NSArray *)_values
  forKeyPath:(NSString *)_valkp;

@end

#endif /* __NGRuleEngine_NGRuleContext_H__ */
