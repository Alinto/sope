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

#ifndef __NGRuleEngine_NGRuleModel_H__
#define __NGRuleEngine_NGRuleModel_H__

#import <Foundation/NSObject.h>
#import <EOControl/EOKeyValueArchiver.h>

/*
  NGRuleModel
  
  A rule model is a specialized sequence of rules.
*/

// TODO: need some method to join two models (two allow one model being
//       configured as a default but still have fallback rules in another)

@class NSArray, NSMutableArray, NSURL;
@class NGRule;

@interface NGRuleModel : NSObject < EOKeyValueArchiving >
{
  NSMutableArray *rules;
}

+ (id)ruleModelWithPropertyList:(id)_plist;
+ (id)ruleModelWithContentsOfUserDefault:(NSString *)_defName;

- (id)init;
- (id)initWithRules:(NSArray *)_rules;
- (id)initWithPropertyList:(id)_plist;
- (id)initWithContentsOfFile:(NSString *)_path;
- (id)initWithContentsOfUserDefault:(NSString *)_defaultName;
- (id)initWithKeyValueArchiveAtURL:(NSURL *)_url;

/* accessors */

- (void)setRules:(NSArray *)_rules;
- (NSArray *)rules;
- (void)addRule:(NGRule *)_rule;
- (void)removeRule:(NGRule *)_rule;
- (void)addRules:(NSArray *)_rules;

/* operations */

- (NSArray *)candidateRulesForKey:(NSString *)_key;

@end

#endif /* __NGRuleEngine_NGRuleModel_H__ */
