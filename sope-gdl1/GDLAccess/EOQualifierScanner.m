/* 
   EOQualifierScanner.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
           Helge Hess <helge.hess@mdlink.de>
   Date:   September 1996
           November  1999

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
// $Id: EOQualifierScanner.m 1 2004-08-20 10:38:46Z znek $

#import "common.h"
#include "EOQualifierScanner.h"
#include "EOFExceptions.h"
#include "EOEntity.h"
#include "EOSQLQualifier.h"
#include <EOControl/EONull.h>

#if LIB_FOUNDATION_LIBRARY
#  import <extensions/DefaultScannerHandler.h>
#  import <extensions/PrintfFormatScanner.h>
#else
#  import "DefaultScannerHandler.h"
#  import "PrintfFormatScanner.h"
#endif

@implementation EOQualifierScannerHandler

- (id)init {
    [super init];

    specHandler['d'] = [self methodForSelector:@selector(convertInt:scanner:)];
    specHandler['f']
            = [self methodForSelector:@selector(convertFloat:scanner:)];
    specHandler['s']
            = [self methodForSelector:@selector(convertCString:scanner:)];
    specHandler['A']
            = [self methodForSelector:@selector(convertProperty:scanner:)];
    specHandler['@']
            = [self methodForSelector:@selector(convertObject:scanner:)];
    return self;
}

- (void)setEntity:(EOEntity *)_entity
{
    ASSIGN(self->entity, _entity);
}

- (void)dealloc {
    RELEASE(self->entity);
    [super dealloc];
}

/* conversions */

- (NSString *)convertInt:(va_list *)pInt scanner:(FormatScanner*)scanner {
    char buffer[256];
    sprintf(buffer, [scanner currentSpecifier], va_arg(*pInt, int));
    return [NSString stringWithCString:buffer];
}

- (NSString*)convertFloat:(va_list *)pFloat scanner:(FormatScanner*)scanner {
    char buffer[256];
    sprintf(buffer, [scanner currentSpecifier], va_arg(*pFloat, double));
    return [NSString stringWithCString:buffer];
}

- (NSString*)convertCString:(va_list *)pString scanner:(FormatScanner*)scanner {
    char *string;
    string = va_arg(*pString, char*);
    return string ? [NSString stringWithCString:string] : (id)@"";
}

- (NSString*)convertProperty:(va_list*)pString scanner:(FormatScanner*)scanner {
    NSString *propertyName;
    id property;

    propertyName = va_arg(*pString, id);
    property     = [entity propertyNamed:propertyName];
    
    if(property == nil) {
        [[[InvalidPropertyException alloc]
                    initWithName:propertyName entity:entity] raise];
    }
    return propertyName;
}

- (NSString *)convertObject:(va_list *)pId scanner:scanner {
  id object = va_arg(*pId, id);
  if (object == nil) object = [NSNull null];
  return [object expressionValueForContext:nil];
}

@end /* EOQualifierScannerHandler */

@implementation EOQualifierEnumScannerHandler

- (id)init {
    [super init];

    specHandler['d'] = [self methodForSelector:@selector(convertInt:scanner:)];
    specHandler['f']
            = [self methodForSelector:@selector(convertFloat:scanner:)];
    specHandler['s']
            = [self methodForSelector:@selector(convertCString:scanner:)];
    specHandler['A']
            = [self methodForSelector:@selector(convertProperty:scanner:)];
    specHandler['@']
            = [self methodForSelector:@selector(convertObject:scanner:)];
    return self;
}

- (void)setEntity:(EOEntity *)_entity {
    ASSIGN(self->entity, _entity);
}

- (void)dealloc {
    RELEASE(self->entity);
    [super dealloc];
}

- (NSString *)convertInt:(NSEnumerator **)pInt scanner:(FormatScanner*)scanner {
    char buffer[256];
    sprintf(buffer, [scanner currentSpecifier], [[*pInt nextObject] intValue]);
    return [NSString stringWithCString:buffer];
}

- (NSString *)convertFloat:(NSEnumerator **)pFloat
  scanner:(FormatScanner *)scanner
{
    char buffer[256];
    sprintf(buffer, [scanner currentSpecifier],
            [[*pFloat nextObject] doubleValue]);
    return [NSString stringWithCString:buffer];
}

- (NSString *)convertCString:(NSEnumerator **)pString
  scanner:(FormatScanner *)scanner
{
  id str;
  
  if ((str = [*pString nextObject]) == nil)
    str = @"";
  else if ([str isKindOfClass:[NSString class]])
      ;
  else if ([str respondsToSelector:@selector(stringValue)])
    str = [str stringValue];
  else
    str = [str description];

  return (str == nil) ? (id)@"" : str;
}

- (NSString *)convertProperty:(NSEnumerator **)pString
  scanner:(FormatScanner *)scanner
{
    NSString *propertyName;
    id property;

    propertyName = [*pString nextObject];
    property     = [entity propertyNamed:propertyName];
    
    if(property == nil) {
        [[[InvalidPropertyException alloc]
                    initWithName:propertyName entity:entity] raise];
    }
    return propertyName;
}

- (NSString *)convertObject:(NSEnumerator **)pId scanner:(id)scanner {
    id object;
    object = [*pId nextObject];
    return [object expressionValueForContext:nil];
}

@end /* EOQualifierEnumScannerHandler */
