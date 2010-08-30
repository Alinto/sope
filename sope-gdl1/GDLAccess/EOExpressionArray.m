/* 
   EOExpressionArray.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: September 1996

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#import "common.h"
#import "EOExpressionArray.h"
#import "EOAttribute.h"
#import "EOEntity.h"
#import "EORelationship.h"

@implementation EOExpressionArray

- (id)init {
    [super init];
    self->array  = [[NSMutableArray allocWithZone:[self zone]] init];
    return self;
}

- (id)initWithPrefix:(NSString *)_prefix
  infix:(NSString *)_infix
  suffix:(NSString *)_suffix
{
    [super init];
    ASSIGN(self->prefix, _prefix);
    ASSIGN(self->infix,  _infix);
    ASSIGN(self->suffix, _suffix);
    RELEASE(self->array);
    self->array = [[NSMutableArray allocWithZone:[self zone]] init];
    return self;
}

- (void)dealloc {
    RELEASE(self->array);
    RELEASE(self->prefix);
    RELEASE(self->infix);
    RELEASE(self->suffix);
    [super dealloc];
}

- (BOOL)referencesObject:(id)anObject {
    return [self indexOfObject:anObject] != NSNotFound;
}

- (NSString *)expressionValueForContext:(id<EOExpressionContext>)ctx {
    if(ctx && [self count] && 
	[[self objectAtIndex:0] isKindOfClass:[EORelationship class]])
	    return [ctx expressionValueForAttributePath:self->array];
    else {
	int i, count;
	id  result;
	SEL sel;
	IMP imp;

        count  = [self count];
        result = [NSMutableString stringWithCapacity:256];
        sel    = @selector(appendString:);
        imp    = [result methodForSelector:sel];
        
	if (self->prefix)
	    [result appendString:self->prefix];

	if (count) {
            id o;

            o = [self objectAtIndex:0];
            
	    (*imp)(result, sel, [o expressionValueForContext:ctx]);
	    for (i = 1 ; i < count; i++) {
		if (self->infix)
		    (*imp)(result, sel, self->infix);

                o = [self objectAtIndex:i];
		(*imp)(result, sel, [o expressionValueForContext:ctx]);
	    }
	}

	if (self->suffix)
	    [result appendString:self->suffix];

	return result;
    }
}

- (void)setPrefix:(NSString *)_prefix {
    ASSIGNCOPY(self->prefix, _prefix);
}
- (void)setInfix:(NSString *)_infix {
    ASSIGNCOPY(self->infix, _infix);
}
- (void)setSuffix:(NSString *)_suffix {
    ASSIGNCOPY(self->suffix, _suffix);
}

- (NSString *)prefix {
    return self->prefix;
}
- (NSString *)infix {
    return self->infix;
}
- (NSString *)suffix {
    return self->suffix;
}

+ (EOExpressionArray *)parseExpression:(NSString *)expression
  entity:(EOEntity *)entity
  replacePropertyReferences:(BOOL)replacePropertyReferences
{
    return [EOExpressionArray parseExpression:expression
                              entity:entity
                              replacePropertyReferences:
                                replacePropertyReferences
                              relationshipPaths:nil];
}

+ (EOExpressionArray *)parseExpression:(NSString *)expression
  entity:(EOEntity *)entity
  replacePropertyReferences:(BOOL)replacePropertyReferences
  relationshipPaths:(NSMutableArray *)relationshipPaths  
{
    EOExpressionArray *exprArray;
    unsigned char buf[[expression cStringLength] + 4]; // TODO: not too good
    const unsigned char *s, *start;
    id objectToken;
    NSAutoreleasePool *pool;
    
    exprArray = [[EOExpressionArray new] autorelease];
    pool = [[NSAutoreleasePool alloc] init];
    [expression getCString:(char *)buf];
    s = buf;
    
    /* Divide the expression string in alternating substrings that obey the
       following simple grammar: 

	    I = [a-zA-Z0-9@_#]([a-zA-Z0-9@_.#$])+
	    O = \'.*\' | \".*\" | [^a-zA-Z0-9@_#]+
	    S -> I S | O S | nothing
    */
    while(*s) {
	/* Determines an I token. */
	if(isalnum((int)*s) || *s == '@' || *s == '_' || *s == '#') {
	    start = s;
	    for(++s; *s; s++)
		if(!isalnum((int)*s) && *s != '@' && *s != '_'
			&& *s != '.' && *s != '#' && *s != '$')
		    break;

	    objectToken = [NSString stringWithCString:(char *)start
				    length:(unsigned)(s - start)];
	    if (replacePropertyReferences) {
		id property = [entity propertyNamed:objectToken];
		if(property) {
                    if ([objectToken isNameOfARelationshipPath] &&
                        relationshipPaths) {
                        [relationshipPaths addObject:
					       [entity relationshipsNamed:
							   objectToken]];
                    }
		    objectToken = property;
                }
	    }
	    [exprArray addObject:objectToken];
	}
	
	/* Determines an O token. */
	start = s;
	for(; *s && !isalnum((int)*s) && *s != '@' && *s != '_' && *s != '#'; 
	    s++) {
	    if(*s == '\'' || *s == '"') {
		unsigned char quote = *s;
		
		for(++s; *s; s++)
		    if(*s == quote)
			break;
		    else if(*s == '\\')
			s++; /* Skip the escaped characters */
		if(!*s) {
		    [NSException raise:@"SyntaxErrorException"
				 format:@"unterminated character string"];
		}
	    }
	}
	if (s != start) {
	    objectToken = [NSString stringWithCString:(char *)start
				    length:(unsigned)(s - start)];
	    [exprArray addObject:objectToken];
	}
    }
    
    [pool release];
    return exprArray;
}

/* NSMutableCopying */

- (id)copyWithZone:(NSZone *)_zone {
    return [self mutableCopyWithZone:_zone];
}
- (id)mutableCopyWithZone:(NSZone *)_zone {
    EOExpressionArray *new;

    new = [[EOExpressionArray allocWithZone:_zone]
                              initWithPrefix:self->prefix
                              infix:self->infix
                              suffix:self->suffix];
    RELEASE(new->array); new->array = nil;
    new->array = [self->array mutableCopyWithZone:_zone];

    return new;
}

/* NSArray compatibility */

- (void)addObjectsFromExpressionArray:(EOExpressionArray *)_array {
    [self->array addObjectsFromArray:_array->array];
}

- (void)insertObject:(id)_obj atIndex:(unsigned int)_idx {
    [self->array insertObject:_obj atIndex:_idx];
}
- (void)addObjectsFromArray:(NSArray *)_array {
    [self->array addObjectsFromArray:_array];
}

- (void)addObject:(id)_object {
    [self->array addObject:_object];
}

- (unsigned int)indexOfObject:(id)_object {
    return [self->array indexOfObject:_object];
}

- (id)objectAtIndex:(unsigned int)_idx {
    return [self->array objectAtIndex:_idx];
}
- (id)lastObject {
    return [self->array lastObject];
}
- (NSUInteger)count {
    return [self->array count];
}
- (BOOL)isNotEmpty {
    return [self->array count] > 0 ? YES : NO;
}

- (NSEnumerator *)objectEnumerator {
    return [self->array objectEnumerator];
}
- (NSEnumerator *)reverseObjectEnumerator {
    return [self->array reverseObjectEnumerator];
}

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  if (self->array)  [ms appendFormat:@" array=%@", self->array];
  if (self->prefix) [ms appendFormat:@" prefix='%@'", self->prefix];
  if (self->infix)  [ms appendFormat:@" infix='%@'",  self->infix];
  if (self->suffix) [ms appendFormat:@" suffix='%@'", self->suffix];
  
  [ms appendString:@">"];
  return ms;
}

@end /* EOExpressionArray */

@implementation NSObject(EOExpression)

- (NSString *)expressionValueForContext:(id<EOExpressionContext>)ctx {
    if([self respondsToSelector:@selector(stringValue)])
	    return [(id)self stringValue];

    return [self description];
}

@end /* NSObject(EOExpression) */

@implementation NSString(EOExpression)

/* 
   Avoid returning the description in case of NSString because if the string
   contains whitespaces it will be quoted. Particular adaptors have to override
   -formatValue:forAttribute: and they have to quote with the specific
   database character the returned string. 
*/
- (NSString *)expressionValueForContext:(id<EOExpressionContext>)ctx {
    return self;
}

@end /* NSString(EOExpression) */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
