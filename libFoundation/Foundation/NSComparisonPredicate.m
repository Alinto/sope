/* 
   NSComparisonPredicate.m

   Copyright (C) 2005, Helge Hess
   All rights reserved.

   Author: Helge Hess <helge.hess@opengroupware.org>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#include "NSComparisonPredicate.h"
#include "NSExpression.h"
#include "common.h"

@implementation NSComparisonPredicate

+ (NSPredicate *)predicateWithLeftExpression:(NSExpression *)_lhs
  rightExpression:(NSExpression *)_rhs
  customSelector:(SEL)_selector
{
    return [[[self alloc] initWithLeftExpression:_lhs rightExpression:_rhs
			  customSelector:_selector] autorelease];
}

+ (NSPredicate *)predicateWithLeftExpression:(NSExpression *)_lhs
  rightExpression:(NSExpression *)_rhs
  modifier:(NSComparisonPredicateModifier)_modifier
  type:(NSPredicateOperatorType)_type
  options:(unsigned)_options
{
    return [[[self alloc] initWithLeftExpression:_lhs rightExpression:_rhs
			  modifier:_modifier type:_type 
			  options:_options] autorelease];
}

- (id)initWithLeftExpression:(NSExpression *)_lhs
  rightExpression:(NSExpression *)_rhs
  customSelector:(SEL)_selector
{
    if ((self = [super init]) != nil) {
	self->lhs      = [_lhs retain];
	self->rhs      = [_rhs retain];
	self->operator = _selector;
    }
    return self;
}

- (id)initWithLeftExpression:(NSExpression *)_lhs
  rightExpression:(NSExpression *)_rhs
  modifier:(NSComparisonPredicateModifier)_modifier
  type:(NSPredicateOperatorType)_type
  options:(unsigned)_options
{
    return [self notImplemented:_cmd];
}

- (id)init
{
    return [self initWithLeftExpression:nil rightExpression:nil
		 customSelector:NULL];
}

- (void)dealloc
{
    [self->lhs release];
    [self->rhs release];
    [super dealloc];
}

/* accessors */

- (NSExpression *)leftExpression
{
    return self->lhs;
}
- (NSExpression *)rightExpression
{
    return self->rhs;
}

- (SEL)customSelector
{
    return self->operator;
}

- (NSComparisonPredicateModifier)comparisonPredicateModifier
{
    // TODO
    return 0;
}

- (NSPredicateOperatorType)predicateOperatorType
{
    // TODO
    return 0;
}

- (unsigned)options
{
    // TODO
    return 0;
}

@end /* NSComparisonPredicate */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
