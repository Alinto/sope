/*
  Copyright (C) 2003-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#include "NGRuleContext.h"
#include "NGRule.h"
#include "NGRuleModel.h"
#include "NSObject+Logs.h"
#include "common.h"
#import <EOControl/EOQualifier.h>

@implementation NGRuleContext

+ (id)ruleContextWithModelInUserDefault:(NSString *)_defName {
  NGRuleModel *mod;
  
  if ((mod = [NGRuleModel ruleModelWithContentsOfUserDefault:_defName]) == nil)
    return nil;
  
  return [self ruleContextWithModel:mod];
}

+ (id)ruleContextWithModel:(NGRuleModel *)_model {
  return [[[self alloc] initWithModel:_model] autorelease];
}

- (id)initWithModel:(NGRuleModel *)_model {
  if ((self = [super init])) {
    [self setModel:_model];
  }
  return self;
}
- (id)init {
  return [self initWithModel:nil];
}

- (void)dealloc {
  [self->model        release];
  [self->storedValues release];
  [super dealloc];
}

/* accessors */

- (void)setModel:(NGRuleModel *)_model {
  ASSIGN(self->model, _model);
}
- (NGRuleModel *)model {
  return self->model;
}

/* values */

- (void)takeStoredValue:(id)_value forKey:(NSString *)_key {
  if (_value) {
    if (self->storedValues == nil)
      self->storedValues = [[NSMutableDictionary alloc] initWithCapacity:32];
    [self->storedValues setObject:_value forKey:_key];
  }
  else
    [self->storedValues removeObjectForKey:_key];
}
- (id)storedValueForKey:(NSString *)_key {
  return [self->storedValues objectForKey:_key];
}

- (void)takeValue:(id)_value forKey:(NSString *)_key {
  [self takeStoredValue:_value forKey:_key];
}

- (void)reset {
  [self->storedValues removeAllObjects];
}

/* processing */

- (id)inferredValueForKey:(NSString *)_key {
  NSArray  *rules;
  unsigned i, count;
  
  if (self->debugOn)
    [self debugWithFormat:@"calculate value for key: '%@'", _key];
  
  /* select candidates */
  rules = [[self model] candidateRulesForKey:_key];
  if (self->debugOn)
    [self debugWithFormat:@"  candidate rules: %@", rules];
  
  /* check qualifiers */
  for (i = 0, count = [rules count]; i < count; i++) {
    NGRule *rule;
    
    rule = [rules objectAtIndex:i];
    if ([(id<EOQualifierEvaluation>)[rule qualifier] evaluateWithObject:self]){
      if (self->debugOn)
        [self debugWithFormat:@"  rule %i matches: %@", i, rule];
      return [[rule action] fireInContext:self];
    }
  }
  if (self->debugOn)
    [self debugWithFormat:@"  no rule matched !"];
  return nil;
}

- (NSArray *)allPossibleValuesForKey:(NSString *)_key {
  NSMutableArray *values;
  NSArray  *rules;
  unsigned i, count;
  
  if (self->debugOn)
    [self debugWithFormat:@"calculate all values for key: '%@'", _key];
  
  /* select candidates */
  rules = [[self model] candidateRulesForKey:_key];
  if (self->debugOn)
    [self debugWithFormat:@"  candidate rules: %@", rules];
  
  values = [NSMutableArray arrayWithCapacity:16];
  
  /* check qualifiers */
  for (i = 0, count = [rules count]; i < count; i++) {
    NGRule *rule;
    
    rule = [rules objectAtIndex:i];
    if ([(id<EOQualifierEvaluation>)[rule qualifier] evaluateWithObject:self]){
      id v;
      
      if (self->debugOn)
        [self debugWithFormat:@"  rule %i matches: %@", i, rule];
      
      v = [[rule action] fireInContext:self];
      [values addObject:(v != nil ? v : (id)[NSNull null])];
    }
  }
  if (self->debugOn)
    [self debugWithFormat:@"  %d rules matched.", [values count]];
  return values;
}

- (id)valueForKey:(NSString *)_key {
  id v;

  // TODO: add rule cache?
  
  /* look for constants */
  if ((v = [self->storedValues objectForKey:_key]) != nil)
    return v;
  
  /* look into rule system */
  if ((v = [self inferredValueForKey:_key]) != nil)
    return v;
  
  return nil;
}

- (NSArray *)valuesForKeyPath:(NSString *)_kp
  takingSuccessiveValues:(NSArray *)_values
  forKeyPath:(NSString *)_valkp
{
  NSMutableArray *results;
  unsigned i, count;
  
  count   = [_values count];
  results = [NSMutableArray arrayWithCapacity:count];
  
  for (i = 0; i < count; i++) {
    id ruleValue;
    
    /* take the value */
    [self takeValue:[_values objectAtIndex:i] forKeyPath:_valkp];

    /* calculate the rule value */
    ruleValue = [self valueForKeyPath:_kp];
    [results addObject:(ruleValue != nil ? ruleValue : (id)[NSNull null])];
  }
  return results;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return self->debugOn;
}
- (void)setDebugEnabled:(BOOL)_flag {
  self->debugOn = _flag;
}

@end /* NGRuleContext */
