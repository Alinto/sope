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

#include "WOElementID.h"
#include "common.h"

// TODO: do not keep the array in the ivars, but use malloc

//#define PROF_ELEMID 1

@implementation WOElementID

- (id)initWithString:(NSString *)_rid {  
  NSArray *reid;
  int     i;
  
  reid = [_rid componentsSeparatedByString:@"."];
  if ((self->elementIdCount = [reid count]) == 0) {
    [self release];
    return nil;
  }
  if (self->elementIdCount > NGObjWeb_MAX_ELEMENT_ID_COUNT) {
    [self errorWithFormat:@"request element ID is too long (%i parts)",
            self->elementIdCount];
    [self release];
    return nil;
  }
  for (i = 0; i < self->elementIdCount; i++)
    self->elementId[i].string = [[reid objectAtIndex:i] copy];
  return self;
}

- (void)dealloc {
  int i;
  
  [self->cs release];
  for (i = 0; i < self->elementIdCount; i++) {
    [self->elementId[i].string release];
    [self->elementId[i].fqn    release];
  }
  [super dealloc];
}

/* methods */

#if PROF_ELEMID
static int prioCacheHit    = 0;
static int prioStrCacheHit = 0;
static int prioConstruct   = 0;
static int callCount       = 0;
#endif

- (NSString *)elementID {
  /* 
    TODO: increase performance (~24% of -componentActionURL [was 50%]) 
    Prof: 1.9% -appendString
          18%  -stringByAppendingString
          1.9% -copy
  */
  static NSString *nums[30] = {
    @".0", @".1", @".2", @".3", @".4", @".5", @".6", @".7", @".8", @".9",
    @".10", @".11", @".12", @".13", @".14", 
    @".15", @".16", @".17", @".18", @".19",
    @".20", @".21", @".22", @".23", @".24", 
    @".25", @".26", @".27", @".28", @".29",
  };
  NSString *e;
  int i;
#if PROF_ELEMID
  if (callCount % 10 == 0) {
    printf("ElementIDProfing: #calls=%i "
           "#priohits=%i(string=%i), #prioconstructs=%i\n",
           callCount, prioCacheHit, prioStrCacheHit, prioConstruct);
  }
  callCount++;
#endif
  
  if (self->elementIdCount == 0) {
    return nil;
  }
  else if (self->elementIdCount == 1) {
    /* a single part in element id (the ctx-id) ... (rare case ...) */
    if ((e = self->elementId[0].string))
      return e;
    
    return [NSString stringWithFormat:@"%d", self->elementId[0].number];
  }
  else if ((e = self->elementId[(self->elementIdCount - 2)].fqn)) {
    /* the prior part has a cached fqn */
    /* TODO cache prior string as C-string ! */
    NSString *o;
#if PROF_ELEMID
    prioCacheHit++;
#endif
    
    if ((o = self->elementId[self->elementIdCount - 1].string)) {
      NSMutableString *eid;
#if PROF_ELEMID
      prioStrCacheHit++;
#endif
      eid = [e mutableCopy];
      [eid appendString:@"."];
      [eid appendString:o];
      return [eid autorelease];
    }
    else {
      i = self->elementId[self->elementIdCount - 1].number;
      if (i >= 0 && i < 30)
        return [e stringByAppendingString:nums[i]];
      return [e stringByAppendingFormat:@".%i", i];
    }
  }
  if (self->cs == nil) {
    self->cs = [[NSMutableString alloc] initWithCapacity:64];
    self->addStr = [self->cs methodForSelector:@selector(appendString:)];
  }
  else
    [self->cs setString:@""];

  for (i = 0; i < self->elementIdCount; i++) {
    register id o;
    
    if (i == (self->elementIdCount - 1)) {
      /* the last iteration, cache the fqn of the *prior* element ! */
      self->elementId[i - 1].fqn = [self->cs copy];
#if PROF_ELEMID
      prioConstruct++;
#endif
    }
    
    if ((o = self->elementId[i].string)) {
      /* some identity comparison for faster NSNumber->NSString conversion */
      if (i != 0) addStr(self->cs, @selector(appendString:), @".");
      addStr(self->cs, @selector(appendString:), o);
    }
    else {
      register int n;
      
      n = self->elementId[i].number;
      if (n >= 0 && n < 30) {
        if (i != 0)
          addStr(self->cs, @selector(appendString:), nums[n]);
        else
          /* very rare, the first id is almost always a string (ctx-id!) */
          [self->cs appendFormat:@"%i", n];
      }
      else {
        [self->cs appendFormat:(i != 0 ? @".%i" : @"%i"), n];
      }
    }
  }
  return [[self->cs copy] autorelease];
}

- (void)appendElementIDComponent:(NSString *)_eid {
  self->elementId[(int)self->elementIdCount].string = [_eid copy];
  self->elementIdCount++;
  NSAssert(self->elementIdCount < NGObjWeb_MAX_ELEMENT_ID_COUNT,
           @"element id size exceeded !");
}
- (void)appendIntElementIDComponent:(int)_eid {
  self->elementId[(int)self->elementIdCount].number = _eid;
  self->elementIdCount++;
  NSAssert(self->elementIdCount < NGObjWeb_MAX_ELEMENT_ID_COUNT,
           @"element id size exceeded !");
}

- (void)appendZeroElementIDComponent {
  self->elementId[(int)self->elementIdCount].number = 0;
  self->elementIdCount++;
  NSAssert(self->elementIdCount < NGObjWeb_MAX_ELEMENT_ID_COUNT,
           @"element id size exceeded !");
}

- (void)deleteAllElementIDComponents {
  int i;
  for (i = 0; i < self->elementIdCount; i++) {
    [self->elementId[i].string release];
    self->elementId[i].string = nil;
    [self->elementId[i].fqn release];
    self->elementId[i].fqn = nil;
  }
  self->elementIdCount = 0;
}

- (void)deleteLastElementIDComponent {
  if (self->elementIdCount == 0)
    return;
  
  self->elementIdCount--;
  [self->elementId[(int)self->elementIdCount].string release];
  self->elementId[(int)(self->elementIdCount)].string = nil;
  [self->elementId[(int)self->elementIdCount].fqn release];
  self->elementId[(int)(self->elementIdCount)].fqn = nil;
}

- (void)incrementLastElementIDComponent {
  register WOElementIDPart *p;
  id v;
  
  if (self->elementIdCount < 1) {
    [self warnWithFormat:@"tried to increment a non-existing element-id"];
    return;
  }
  else if (self->elementIdCount >= NGObjWeb_MAX_ELEMENT_ID_COUNT) {
    [self errorWithFormat:@"exceeded element-id restriction (max=%i)", 
	          NGObjWeb_MAX_ELEMENT_ID_COUNT];
    return;
  }
  
  // TODO: range check ?
  p = &(self->elementId[(int)(self->elementIdCount - 1)]);
  
  [p->fqn release]; p->fqn = nil;
  if ((v = p->string)) {
    p->number = [v intValue] + 1;
    [p->string release]; p->string = nil;
  }
  else
    p->number++;
}

/* request ID processing */

- (id)currentElementID {
  return (self->idPos >= self->elementIdCount)
    ? nil
    : (id)self->elementId[(int)self->idPos].string;
}
- (id)consumeElementID {
  (self->idPos)++;
  return [self currentElementID];
}

@end /* WOElementID */
