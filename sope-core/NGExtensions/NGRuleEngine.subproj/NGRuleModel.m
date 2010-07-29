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

#include "NGRuleModel.h"
#include "NGRule.h"
#include "NGRuleParser.h"
#include "EOTrueQualifier.h"
#include <NGExtensions/NSObject+Logs.h>
#import <EOControl/EOControl.h>
#include "common.h"

// TODO: add a candidate cache

@implementation NGRuleModel

+ (id)ruleModelWithPropertyList:(id)_plist {
  static NGRuleParser *ruleParser = nil; // THREAD

  if (ruleParser == nil)
    ruleParser = [[NGRuleParser sharedRuleParser] retain];
  
  return [ruleParser parseRuleModelFromPropertyList:_plist];
}
+ (id)ruleModelWithContentsOfUserDefault:(NSString *)_defName {
  id plist;
  
  plist = [[NSUserDefaults standardUserDefaults] objectForKey:_defName];
  if (plist == nil) return nil;
  
  return [self ruleModelWithPropertyList:plist];
}

- (id)init {
  if ((self = [super init])) {
    self->rules = [[NSMutableArray alloc] initWithCapacity:16];
  }
  return self;
}
- (id)initWithRules:(NSArray *)_rules {
  if ((self = [self init])) {
    [self->rules addObjectsFromArray:_rules];
  }
  return self;
}

- (id)initWithPropertyList:(id)_plist {
  [self autorelease];
  return [[[self class] ruleModelWithPropertyList:_plist] retain];
}

- (id)initWithContentsOfFile:(NSString *)_path {
  NSString *s;
  id plist;
  
  if ((s = [[NSString alloc] initWithContentsOfFile:_path])) {
    [self release];
    return nil;
  }
  plist = [s propertyList];
  [s release];
  return [self initWithPropertyList:plist];
}

- (id)initWithContentsOfUserDefault:(NSString *)_defName {
  [self autorelease];
  return [[[self class] ruleModelWithContentsOfUserDefault:_defName] retain];
}

- (id)initWithKeyValueArchiveAtURL:(NSURL *)_url {
  EOKeyValueUnarchiver *unarchiver;
  NSDictionary *plist;
  
  if ((plist = [NSDictionary dictionaryWithContentsOfURL:_url]) == nil) {
    [self errorWithFormat:@"Could not read plist at URL: %@", _url];
    [self release];
    return nil;
  }
  
  unarchiver = [[EOKeyValueUnarchiver alloc] initWithDictionary:plist];
  self = [self initWithKeyValueUnarchiver:unarchiver];
  [unarchiver release]; unarchiver = nil;
  
  return self;
}

- (void)dealloc {
  [self->rules release];
  [super dealloc];
}

/* accessors */

- (void)setRules:(NSArray *)_rules {
  [self->rules removeAllObjects];
  if (_rules != nil) [self->rules addObjectsFromArray:_rules];
}
- (NSArray *)rules {
  return [[self->rules shallowCopy] autorelease];
}

- (void)addRule:(NGRule *)_rule {
  if (_rule == nil) return;
  [self->rules addObject:_rule];
}
- (void)removeRule:(NGRule *)_rule {
  if (_rule == nil) return;
  [self->rules removeObject:_rule];
}

- (void)addRules:(NSArray *)_rules {
  if (_rules != nil) [self->rules addObjectsFromArray:_rules];
}

/* operations */

static int candidateSort(NGRule *rule1, NGRule *rule2, NGRuleModel *model) {
  static Class TrueQualClass = Nil;
  EOQualifier *q1, *q2;
  register int pri1, pri2;
  
  pri1 = [rule1 priority];
  pri2 = [rule2 priority];
  if (pri1 != pri2)
    return pri1 > pri2 ? NSOrderedAscending : NSOrderedDescending;
  
  /* check number of qualifiers (order on how specific the qualifier is) */

  if (TrueQualClass == Nil) TrueQualClass = [EOTrueQualifier class];
  q1 = [rule1 qualifier];
  q2 = [rule2 qualifier];
  
  pri1 = [q1 isKindOfClass:TrueQualClass]
    ? - 1
    : ([q1 respondsToSelector:@selector(count)] ? [q1 count] : 0);
  pri2 = [q2 isKindOfClass:TrueQualClass]
    ? -1
    : ([q2 respondsToSelector:@selector(count)] ? [q2 count] : 0);
  
  if (pri1 != pri2)
    return pri1 > pri2 ? NSOrderedAscending : NSOrderedDescending;
  
  return NSOrderedSame;
}

- (NSArray *)candidateRulesForKey:(NSString *)_key {
  NSMutableArray *candidates;
  unsigned i, cnt;
  
  /* first, find all candidates */
  candidates = nil;
  cnt = [self->rules count];
  for (i = 0; i < cnt; i++) {
    NGRule *rule;
    
    rule = [self->rules objectAtIndex:i];
    if ([rule isCandidateForKey:_key]) {
      if (candidates == nil)
        candidates = [[NSMutableArray alloc] initWithCapacity:cnt];
      [candidates addObject:rule];
    }
  }

  /* sort candidates */
  [candidates sortUsingFunction:(void *)candidateSort context:self];
  [candidates autorelease];
  
  return candidates;
}

/* representations */

/* key/value archiving */

- (id)initWithKeyValueUnarchiver:(EOKeyValueUnarchiver *)_unarchiver {
  return [self initWithRules:[_unarchiver decodeObjectForKey:@"rules"]];
}
- (void)encodeWithKeyValueArchiver:(EOKeyValueArchiver *)_archiver {
  [_archiver encodeObject:[self rules] forKey:@"rules"];
}

@end /* NGRuleModel */
