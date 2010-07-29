/* 
   NSExpression.m

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

#include "NSExpression.h"

@class NSString, NSArray;

@interface NSSelfExpression : NSExpression
@end

@interface NSConstantValueExpression : NSExpression
{
@public
    id value;
}
@end

@interface NSKeyPathExpression : NSExpression
{
@public
    NSString *keyPath;
}
@end

@interface NSVariableExpression : NSExpression
{
@public
    NSString *varname;
}
@end

@interface NSFunctionExpression : NSExpression
{
@public
    NSString *funcname;
    NSArray  *parameters;
}
@end

#include "NSCoder.h"
#include "NSArray.h"
#include "NSDictionary.h"
#include "NSKeyValueCoding.h"
#include "common.h"

@implementation NSExpression

+ (NSExpression *)expressionForConstantValue:(id)_value
{
    NSConstantValueExpression *e;
    
    e = [[[NSConstantValueExpression alloc] 
	     initWithExpressionType:NSConstantValueExpressionType]
	     autorelease];
    e->value = [_value retain];
    return e;
}

+ (NSExpression *)expressionForEvaluatedObject
{
    static NSSelfExpression *me = nil; // THREAD?
    if (me == nil) {
	me = [[NSSelfExpression alloc] initWithExpressionType:
					   NSEvaluatedObjectExpressionType];
    }
    return me;
}

+ (NSExpression *)expressionForFunction:(NSString *)_f arguments:(NSArray *)_a
{
    NSFunctionExpression *e;

    e = [[[NSFunctionExpression alloc] 
	     initWithExpressionType:NSFunctionExpressionType] autorelease];
    e->funcname   = [_f copy];
    e->parameters = [_a retain];
    return e;
}

+ (NSExpression *)expressionForKeyPath:(NSString *)_keyPath
{
    NSKeyPathExpression *e;
    
    e = [[[NSKeyPathExpression alloc] 
	     initWithExpressionType:NSKeyPathExpressionType] autorelease];
    e->keyPath = [_keyPath copy];
    return e;
}

+ (NSExpression *)expressionForVariable:(NSString *)_varName
{
    NSVariableExpression *e;

    e = [[[NSVariableExpression alloc] 
	     initWithExpressionType:NSVariableExpressionType] autorelease];
    e->varname = [_varName copy];
    return e;
}


- (id)initWithExpressionType:(NSExpressionType)_type
{
    if ((self = [super init]) != nil) {
    }
    return self;
}
- (id)init
{
    return [self initWithExpressionType:NSConstantValueExpressionType];
}

/* accessors */

- (NSExpressionType)expressionType
{
    return NSConstantValueExpressionType;
}

- (NSExpression *)operand
{
    // TODO: explain
    return nil;
}

- (id)constantValue
{
    return nil;
}

- (NSString *)keyPath
{
    return nil;
}

- (NSString *)variable
{
    return nil;
}

- (NSString *)function
{
    return nil;
}
- (NSArray *)arguments
{
    return nil;
}

/* evaluation */

- (id)expressionValueWithObject:(id)_obj context:(NSMutableDictionary *)_ctx
{
    return nil;
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)aCoder
{
}
- (id)initWithCoder:(NSCoder*)aDecoder
{
    return self;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)zone
{
    /* NSExpression objects are immutable! */
    return [self retain];
}

@end /* NSExpression */


@implementation NSSelfExpression

/* evaluation */

- (id)expressionValueWithObject:(id)_obj context:(NSMutableDictionary *)_ctx
{
    return _obj;
}

@end /* NSSelfExpression */


@implementation NSConstantValueExpression

- (void)dealloc
{
    [self->value release];
    [super dealloc];
}

/* accessors */

- (id)constantValue
{
    return self->value;
}

/* evaluation */

- (id)expressionValueWithObject:(id)_obj context:(NSMutableDictionary *)_ctx
{
    return self->value;
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:self->value];
}
- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]) != nil) {
	self->value = [[aDecoder decodeObject] retain];
    }
    return self;
}

@end /* NSConstantValueExpression */


@implementation NSKeyPathExpression

- (void)dealloc
{
    [self->keyPath release];
    [super dealloc];
}

/* accessors */

- (NSString *)keyPath
{
    return self->keyPath;
}

/* evaluation */

- (id)expressionValueWithObject:(id)_obj context:(NSMutableDictionary *)_ctx
{
    return [_obj valueForKeyPath:self->keyPath];
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:self->keyPath];
}
- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]) != nil) {
	self->keyPath = [[aDecoder decodeObject] copy];
    }
    return self;
}

@end /* NSKeyPathExpression */


@implementation NSVariableExpression

- (void)dealloc
{
    [self->varname release];
    [super dealloc];
}

/* evaluation */

- (id)expressionValueWithObject:(id)_obj context:(NSMutableDictionary *)_ctx
{
    // TODO: correct? Remove support for ctx pathes?
    return [_ctx valueForKeyPath:self->varname];
}

/* accessors */

- (NSString *)variable
{
    return self->varname;
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:self->varname];
}
- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]) != nil) {
	self->varname = [[aDecoder decodeObject] copy];
    }
    return self;
}

@end /* NSVariableExpression */


@implementation NSFunctionExpression

- (void)dealloc
{
    [self->funcname   release];
    [self->parameters release];
    [super dealloc];
}

/* accessors */

- (NSString *)function
{
    return self->funcname;
}
- (NSArray *)arguments
{
    return self->parameters;
}

/* evaluation */

- (id)expressionValueWithObject:(id)_obj context:(NSMutableDictionary *)_ctx
{
    return [self notImplemented:_cmd];
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:self->funcname];
    [aCoder encodeObject:self->parameters];
}
- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]) != nil) {
	self->funcname   = [[aDecoder decodeObject] copy];
	self->parameters = [[aDecoder decodeObject] retain];
    }
    return self;
}

@end /* NSFunctionExpression */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
