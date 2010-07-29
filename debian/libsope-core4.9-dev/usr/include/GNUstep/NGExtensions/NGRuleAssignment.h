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

#ifndef __NGRuleEngine_NGRuleAssignment_H__
#define __NGRuleEngine_NGRuleAssignment_H__

#import <Foundation/NSObject.h>
#import <EOControl/EOKeyValueArchiver.h>

/*
  NGRuleAssignment
  
  Assignments are the right-hand side of a rule in the rule system, if a rule
  is selected by qualifier and priority the assignment is the "thing" which 
  is executed.
  
  NGRuleKeyAssignment
  
  Special case of NGRuleAssignment which evaluates the "value" as a keypath
  relative to the context.
*/

@class NSString;

@interface NGRuleAssignment : NSObject < EOKeyValueArchiving >
{
  NSString *keyPath;
  id value;
}

+ (id)assignmentWithKeyPath:(NSString *)_kp value:(id)_value;
- (id)initWithKeyPath:(NSString *)_kp value:(id)_value;

/* accessors */

- (void)setKeyPath:(NSString *)_kp;
- (NSString *)keyPath;

- (void)setValue:(id)_value;
- (id)value;

/* operations */

- (BOOL)isCandidateForKey:(NSString *)_key;
- (id)fireInContext:(id)_ctx;

@end

@interface NGRuleKeyAssignment : NGRuleAssignment
{
}

@end

#endif /* __NGRuleEngine_NGRuleAssignment_H__ */
