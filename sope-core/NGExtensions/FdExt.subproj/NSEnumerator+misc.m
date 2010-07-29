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

#import "NSEnumerator+misc.h"
#import <Foundation/Foundation.h>
#import <EOControl/EOQualifier.h>
#include "common.h"

@interface _NGFilterEnumerator : NSEnumerator
{
  NSEnumerator *source;
}

+ (NSEnumerator *)filterEnumeratorWithSource:(NSEnumerator *)_e;

- (NSEnumerator *)source;

@end

@interface _NGQualifierFilterEnumerator : _NGFilterEnumerator
{
  EOQualifier *q;
}
- (void)setQualifier:(EOQualifier *)_q;
- (EOQualifier *)qualifier;
@end

@interface _NGSelFilterEnumerator : _NGFilterEnumerator
{
  SEL  sel;
  id   arg;
}
- (void)setSelector:(SEL)_s;
- (SEL)selector;
- (void)setArgument:(id)_arg;
- (id)argument;
@end

@implementation NSEnumerator(misc)

- (NSEnumerator *)filterWithQualifier:(EOQualifier *)_qualifier {
  id e;
  
  e = [_NGQualifierFilterEnumerator filterEnumeratorWithSource:self];
  [e setQualifier:_qualifier];
  return e;
}
- (NSEnumerator *)filterWithQualifierString:(NSString *)_s {
  EOQualifier *q;
  
  q = [EOQualifier qualifierWithQualifierFormat:_s];
  return [self filterWithQualifier:q];
}

- (NSEnumerator *)filterWithSelector:(SEL)_selector withObject:(id)_argument {
  id e;
  
  e = [_NGSelFilterEnumerator filterEnumeratorWithSource:self];
  [e setSelector:_selector];
  [e setArgument:_argument];
  return e;
}

@end /* NSEnumerator(misc) */

@implementation _NGFilterEnumerator

- (id)initWithSource:(NSEnumerator *)_e {
  self->source = [_e retain];
  return self;
}
- (void)dealloc {
  [self->source release];
  [super dealloc];
}

+ (NSEnumerator *)filterEnumeratorWithSource:(NSEnumerator *)_e {
  return [[(_NGFilterEnumerator *)[self alloc] initWithSource:_e] autorelease];
}

- (NSEnumerator *)source {
  return self->source;
}

- (id)nextObject {
  return [self->source nextObject];
}

@end /* _NGFilterEnumerator */

@implementation _NGQualifierFilterEnumerator

- (void)dealloc {
  [self->q release];
  [super dealloc];
}

- (void)setQualifier:(EOQualifier *)_q {
  ASSIGN(self->q, _q);
}
- (EOQualifier *)qualifier {
  return self->q;
}

- (id)nextObject {
  while (YES) {
    id obj;
    
    if ((obj = [self->source nextObject]) == nil)
      return nil;
    if (self->q == nil)
      return obj;

    if ([(id<EOQualifierEvaluation>)self->q evaluateWithObject:obj])
      return obj;
  }
}

@end /* _NGQualifierFilterEnumerator */

@implementation _NGSelFilterEnumerator

- (void)dealloc {
  [self->arg release];
  [super dealloc];
}

- (void)setSelector:(SEL)_s {
  self->sel = _s;
}
- (SEL)selector {
  return self->sel;
}

- (void)setArgument:(id)_arg {
  ASSIGN(self->arg, _arg);
}
- (id)argument {
  return self->arg;
}

- (id)nextObject {
  while (YES) {
    id obj;
    BOOL (*m)(id,SEL,id);
    
    if ((obj = [self->source nextObject]) == nil)
      return nil;
    
    if ((m = (void *)[obj methodForSelector:self->sel]) == NULL)
      continue;

    if (m(obj, self->sel, self->arg))
      return obj;
  }
}

@end /* _NGSelFilterEnumerator */
