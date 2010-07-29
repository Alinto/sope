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

#include "NGRuleParser.h"
#include "NGRule.h"
#include "NGRuleModel.h"
#include "NGRuleAssignment.h"
#include "NSObject+Logs.h"
#include "NSString+misc.h"
#include "NSString+Ext.h"
#include "EOTrueQualifier.h"
#import <EOControl/EOQualifier.h>
#include "common.h"

// TODO: proper reports errors in last-exception !
// TODO: improve performance
// TODO: parse assignment class? (eg "a = b; (BoolAssignment)")

#define RULE_PRIORITY_NORMAL 100

@implementation NGRuleParser

static BOOL parseDebugOn = YES;

+ (void)initialize {
  parseDebugOn = [[NSUserDefaults standardUserDefaults] 
                                  boolForKey:@"NGRuleParserDebugEnabled"];
}

+ (id)sharedRuleParser {
  static NGRuleParser *parser = nil; // THREAD
  if (parser == nil)
    parser = [[NGRuleParser alloc] init];
  return parser;
}

- (id)init {
  if ((self = [super init])) {
    self->ruleQuotes = @"'\"";
    self->ruleEscape = '\\';
    self->priorityMapping =
      [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithInt:1000], @"important",
                              [NSNumber numberWithInt:200],  @"very high",
                              [NSNumber numberWithInt:150],  @"high",
                              [NSNumber numberWithInt:RULE_PRIORITY_NORMAL], 
                              @"normal",
                              [NSNumber numberWithInt:RULE_PRIORITY_NORMAL],
                              @"default",
                              [NSNumber numberWithInt:50],   @"low",
                              [NSNumber numberWithInt:5],    @"very low",
                              [NSNumber numberWithInt:0],    @"fallback",
                            nil];
    self->boolMapping =
      [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithBool:YES], @"yes",
                              [NSNumber numberWithBool:NO],  @"no",
                              [NSNumber numberWithBool:YES], @"true",
                              [NSNumber numberWithBool:NO],  @"false",
                            nil];
  }
  return self;
}

- (void)dealloc {
  [self->priorityMapping release];
  [self->boolMapping   release];
  [self->ruleQuotes    release];
  [self->lastException release];
  [super dealloc];
}

/* accessors */

- (NSException *)lastException {
  return self->lastException;
}

/* parsing */

- (NGRule *)parseRuleFromPropertyList:(id)_plist {
  if (_plist == nil)
    return nil;
  
  if ([_plist isKindOfClass:[NSString class]])
    return [self parseRuleFromString:_plist];
  
  [self debugWithFormat:
          @"cannot deal with plist rule of class '%@': %@",
          NSStringFromClass([_plist class]), _plist];
  return nil;
}

- (NGRule *)parseRuleFromArray:(NSArray *)_a {
  /* eg: ( "a>2", "a='3'", 5 ) */
  unsigned count;
  id qpart, apart, ppart;
  EOQualifier *q;
  id   action;
  int  priority;
  
  if (_a == nil) 
    return nil;
  if ((count = [_a count]) < 2) {
    [self debugWithFormat:@"invalid rule array: %@", _a];
    return nil;
  }

  /* extract parts */
  
  qpart = [_a objectAtIndex:0];
  apart = [_a objectAtIndex:1];
  ppart = count > 2 ? [_a objectAtIndex:2] : nil;
  
  /* parse separate strings */
  
  // TODO: handle plists !
  q        = [self parseQualifierFromString:[qpart stringValue]];
  action   = [self parseActionFromString:[apart stringValue]];
  priority = [self parsePriorityFromString:[ppart stringValue]];
  
  /* create rule */
  return [NGRule ruleWithQualifier:q action:action priority:priority];
}

- (NGRule *)parseRuleFromString:(NSString *)_s {
  /* "qualifier => assignment [; prio]" */
  NSString    *qs, *as, *ps;
  EOQualifier *q;
  id   action;
  int  priority;
  BOOL ok;

  if (_s == nil)
    return nil;
  
  [self debugWithFormat:@"should parse rule: '%@'", _s];

  /* split string */
  
  ok = [self splitString:_s 
             intoQualifierString:&qs
             actionString:&as
             andPriorityString:&ps];
  if (!ok) return nil;
  
  [self debugWithFormat:@"  splitted: q='%@', as='%@', pri=%@", qs, as, ps];
  
  /* parse separate strings */
  
  q        = [self parseQualifierFromString:qs];
  action   = [self parseActionFromString:as];
  priority = [self parsePriorityFromString:ps];
  
  /* create rule */
  return [NGRule ruleWithQualifier:q action:action priority:priority];
}

- (NGRuleModel *)parseRuleModelFromPropertyList:(id)_plist {
  if (_plist == nil)
    return nil;
  
  if ([_plist isKindOfClass:[NSString class]]) {
    NGRule *rule;
    
    if ((rule = [self parseRuleFromString:_plist]) == nil)
      return nil;
    
    return [[[NGRuleModel alloc]
                          initWithRules:[NSArray arrayWithObject:rule]]
                          autorelease];
  }
  else if ([_plist isKindOfClass:[NSArray class]]) {
    NSMutableArray *rules;
    unsigned i, count;
    
    if ((count = [(NSArray *)_plist count]) == 0)
      return [[[NGRuleModel alloc] init] autorelease];
    
    rules = [NSMutableArray arrayWithCapacity:(count + 1)];
    for (i = 0; i < count; i++) {
      NGRule *rule;
      
      rule = [self parseRuleFromPropertyList:[_plist objectAtIndex:i]];
      if (rule == nil) {
        [self debugWithFormat:@"could not parse rule %i in model !", (i + 1)];
        return nil;
      }
      [rules addObject:rule];
    }
    
    return [[[NGRuleModel alloc] initWithRules:rules] autorelease];
  }
  else {
    [self debugWithFormat:
            @"cannot deal with plist rule-model of class '%@': %@",
            NSStringFromClass([_plist class]), _plist];
    return nil;
  }
}

/* parsing of parts */

- (BOOL)splitString:(NSString *)_s 
  intoQualifierString:(NSString **)_qs
  actionString:(NSString **)_as
  andPriorityString:(NSString **)_ps
{
  unsigned len;
  NSRange  r;
  NSString *qs, *as, *ps;

  if (_qs) *_qs = nil;
  if (_as) *_as = nil;
  if (_ps) *_ps = nil;
  
  if ((len = [_s length]) == 0)
    return NO;
  
  /* split into qualifier and assignment/prio */
  
  r = [_s rangeOfString:@"=>" 
          skipQuotes:self->ruleQuotes 
          escapedByChar:self->ruleEscape];
  if (r.length == 0) {
    [self debugWithFormat:@"ERROR: missing => in rule '%@'", _s];
    return NO;
  }
  
  qs = [[_s substringToIndex:r.location] stringByTrimmingSpaces];
  as = [_s substringFromIndex:(r.location + r.length)];
  
  /* split assignment and prio */
  
  r = [as rangeOfString:@";" 
          skipQuotes:self->ruleQuotes 
          escapedByChar:self->ruleEscape];
  if (r.length == 0) {
    /* no priority */
    ps = nil;
    as = [as stringByTrimmingSpaces];
  }
  else {
    ps = [[as substringFromIndex:(r.location + r.length)] 
              stringByTrimmingSpaces];
    as = [[as substringToIndex:r.location] stringByTrimmingSpaces];
  }
  
  /* return results */
  *_qs = qs;
  *_as = as;
  *_ps = ps;
  return YES;
}

- (EOQualifier *)parseQualifierFromString:(NSString *)_s {
  if ([_s length] == 0)
    return nil;
  
  _s = [_s stringByTrimmingSpaces];
  
  if ([_s isEqualToString:@"*true*"]) {
    static EOTrueQualifier *tq = nil;
    if (tq == nil) tq = [[EOTrueQualifier alloc] init];
    return tq;
  }
  
  return [EOQualifier qualifierWithQualifierFormat:_s arguments:nil];
}

- (id)parseActionFromString:(NSString *)_s {
  NSRange  r;
  NSString *key;
  NSString *valstr;
  Class    AssignmentClass;
  id       value;
  
  _s = [_s stringByTrimmingSpaces];
  
  /* split assignment */
  
  r = [_s rangeOfString:@"="
          skipQuotes:self->ruleQuotes 
          escapedByChar:self->ruleEscape];
  if (r.length == 0) {
    [self debugWithFormat:@"cannot parse rule action: '%@'", _s];
    return nil;
  }
  
  key    = [[_s substringToIndex:r.location] stringByTrimmingSpaces];
  valstr = [[_s substringFromIndex:(r.location + r.length)] 
                stringByTrimmingSpaces];

  /* setup defaults */
  
  AssignmentClass = [NGRuleKeyAssignment class];
  value = valstr;
  
  /* parse value */
  
  if ([valstr length] > 0) {
    unichar c1 = [valstr characterAtIndex:0];
    id tmp;
    
    if (c1 == '"' || c1 == '\'') {
      /* a quoted, constant string */
      NSString *s, *qs;
      NSRange  r;
      
      AssignmentClass = [NGRuleAssignment class];
      
      qs = [NSString stringWithCharacters:&c1 length:1];
      s  = [valstr substringFromIndex:1]; // TODO: perf
      r  = [s rangeOfString:qs];
      if (r.length == 0) {
        [self debugWithFormat:
                @"quoting of assignment string-value is not closed !"];
        value = valstr;
      }
      else
        value = [s substringToIndex:r.location];
    }
    else if (isdigit(c1) || c1 == '-') {
      AssignmentClass = [NGRuleAssignment class];
      value = [NSNumber numberWithInt:[valstr intValue]];
    }
    else if ((tmp=[self->boolMapping objectForKey:[valstr lowercaseString]])) {
      AssignmentClass = [NGRuleAssignment class];
      value = tmp;
    }
    else if ([valstr isEqualToString:@"nil"] || 
             [valstr isEqualToString:@"null"]) {
      AssignmentClass = [NGRuleAssignment class];
      value = [NSNull null];
    }
    else if (c1 == '{' || c1 == '(') {
      AssignmentClass = [NGRuleAssignment class];
      value = [valstr propertyList];
    }
  }
  
  return [AssignmentClass assignmentWithKeyPath:key value:value];
}

- (int)parsePriorityFromString:(NSString *)_s {
  unichar c1;
  id num;
  
  _s = [_s stringByTrimmingSpaces];
  // [self debugWithFormat:@"parse priority: '%@'", _s];
  
  if ([_s length] == 0)
    return RULE_PRIORITY_NORMAL;
  c1 = [_s characterAtIndex:0];
  
  if (isdigit(c1) || c1 == '-')
    return [_s intValue];
  
  if ((num = [self->priorityMapping objectForKey:_s]))
    return [num intValue];
  
  [self debugWithFormat:@"cannot parse rule priority: '%@'", _s];
  return RULE_PRIORITY_NORMAL;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return parseDebugOn;
}

@end /* NGRuleParser */
