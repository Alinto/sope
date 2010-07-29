/*
  Copyright (C) 2003-2005 SKYRIX Software AG

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

#include "NGRule.h"
#include "NGRuleAssignment.h"
#include "NGRuleParser.h"
#include "common.h"
#import <EOControl/EOQualifier.h>

@implementation NGRule

+ (id)ruleWithQualifier:(EOQualifier *)_q action:(id)_action priority:(int)_p {
  return [[[self alloc] initWithQualifier:_q action:_action priority:_p] 
                 autorelease];
}
+ (id)ruleWithQualifier:(EOQualifier *)_q action:(id)_action {
  return [self ruleWithQualifier:_q action:_action priority:0];
}

- (id)initWithString:(NSString *)_s {
  [self release];
  return [[[NGRuleParser sharedRuleParser] parseRuleFromString:_s] retain];
}
- (id)initWithPropertyList:(id)_plist {
  [self release];
  return [[[NGRuleParser sharedRuleParser] 
                         parseRuleFromPropertyList:_plist] retain];
}

- (id)initWithQualifier:(EOQualifier *)_q action:(id)_action priority:(int)_p {
  if ((self = [super init])) {
    self->qualifier = [_q      retain];
    self->action    = [_action retain];
    self->priority  = _p;
  }
  return self;
}
- (id)init {
  return [self initWithQualifier:nil action:nil priority:0];
}

- (void)dealloc {
  [self->qualifier release];
  [self->action    release];
  [super dealloc];
}

/* accessors */

- (void)setQualifier:(EOQualifier *)_q {
  ASSIGN(self->qualifier, _q);
}
- (EOQualifier *)qualifier {
  return self->qualifier;
}

- (void)setAction:(id)_action {
  ASSIGN(self->action, _action);
}
- (id)action {
  return self->action;
}

- (void)setPriority:(int)_pri {
  self->priority = _pri;
}
- (int)priority {
  return self->priority;
}

/* operations */

- (BOOL)isCandidateForKey:(NSString *)_key {
  id o;
  if (_key == nil) return YES;
  
  o = [self action];
  if ([o respondsToSelector:@selector(isCandidateForKey:)])
    return [o isCandidateForKey:_key];
  
  return NO; /* action is not an assignment ! */
}

- (id)fireInContext:(id)_ctx {
  return [self->action fireInContext:_ctx];
}

/* key/value archiving */

- (id)initWithKeyValueUnarchiver:(EOKeyValueUnarchiver *)_unarchiver {
  return [self initWithQualifier:[_unarchiver decodeObjectForKey:@"lhs"]
	       action:[_unarchiver decodeObjectForKey:@"rhs"]
	       priority:[_unarchiver decodeIntForKey:@"author"]];
}
- (void)encodeWithKeyValueArchiver:(EOKeyValueArchiver *)_archiver {
  [_archiver encodeInt:[self priority]     forKey:@"author"];
  [_archiver encodeObject:[self qualifier] forKey:@"lhs"];
  [_archiver encodeObject:[self action]    forKey:@"rhs"];
}

/* representations */

- (NSString *)stringValue {
  NSString *sq, *sa;
  
  sq = [[self qualifier] description];
  sa = [[self action]    description];
  return [NSString stringWithFormat:@"%@ => %@ ; %i",
                     sq, sa, [self priority]];
}

- (NSString *)description {
  return [self stringValue];
}

@end /* NGRule(Parsing) */
