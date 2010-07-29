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

#ifndef __NGRuleEngine_NGRule_H__
#define __NGRuleEngine_NGRule_H__

#import <Foundation/NSObject.h>
#import <EOControl/EOKeyValueArchiver.h>

/*
  NGRule

  This class represents a rule inside the rule-model. A rule conceptually has:
  - a qualifier - aka lhs (the condition which must be true for the rule)
  - an action   - aka rhs (the "thing" which is performed when the rule is
                           triggered)
  - a priority  - to select a rule if multiple ones match
  
  String Representation:
    qualifer => action [; priority]
    *true*   => action
  
  Example:
    "(request.isXmlRpcRequest = YES) => dispatcher = XmlRpc ;0"
*/

@class EOQualifier;

@interface NGRule : NSObject < EOKeyValueArchiving >
{
  EOQualifier *qualifier;
  id          action;
  int         priority;
}

+ (id)ruleWithQualifier:(EOQualifier *)_q action:(id)_action priority:(int)_p;
+ (id)ruleWithQualifier:(EOQualifier *)_q action:(id)_action;
- (id)initWithQualifier:(EOQualifier *)_q action:(id)_action priority:(int)_p;

- (id)initWithPropertyList:(id)_plist;
- (id)initWithString:(NSString *)_s;

/* accessors */

- (void)setQualifier:(EOQualifier *)_q;
- (EOQualifier *)qualifier;

- (void)setAction:(id)_action;
- (id)action;

- (void)setPriority:(int)_pri;
- (int)priority;

/* operations */

- (BOOL)isCandidateForKey:(NSString *)_key;
- (id)fireInContext:(id)_ctx;

/* representations */

- (NSString *)stringValue;

@end

@interface NSObject(RuleAction)
- (id)fireInContext:(id)_ctx;
@end

#endif /* __NGRuleEngine_NGRule_H__ */
