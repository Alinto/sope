/* 
   EOSQLExpression.m

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

#include "EOSQLExpression.h"
#include "EOAttribute.h"
#include "EOAdaptor.h"
#include "common.h"

#if LIB_FOUNDATION_LIBRARY
#  include <extensions/DefaultScannerHandler.h>
#  include <extensions/PrintfFormatScanner.h>
#else
#  include "DefaultScannerHandler.h"
#  include "PrintfFormatScanner.h"
#endif

@interface EOSelectScannerHandler : DefaultScannerHandler
{
    EOAttribute *attribute;
    EOAdaptor   *adaptor;
    NSString    *alias;
}

- (void)setAttribute:(EOAttribute*)attribute
  adaptor:(EOAdaptor*)adaptor
  alias:(NSString*)alias;

@end


@implementation EOSelectSQLExpression

- (NSString *)expressionValueForAttribute:(EOAttribute *)attribute
  context:(id)context
{
    NSString *alias;
    NSString *columnName;
  
    alias = [entitiesAndPropertiesAliases objectForKey:context];
  
    //NSLog(@"entitiesAndPropertiesAliases: %@", entitiesAndPropertiesAliases);
  
    columnName = adaptor
      ? (NSString *)[adaptor formatAttribute:attribute]
      : [attribute columnName];

    if (alias) {
      return [([[NSString alloc] initWithFormat:@"%@.%@",
				 alias, columnName]) autorelease];
    }
    
    return columnName;
}

@end /* EOSelectSQLExpression */


@implementation EOSelectScannerHandler

- (id)init {
  if ((self = [super init]) != nil) {
    specHandler['A']
      = [self methodForSelector:@selector(convertAttribute:scanner:)];
  }
  return self;
}

- (void)dealloc {
  [self->attribute release];
  [self->adaptor   release];
  [self->alias     release];
  [super dealloc];
}

- (void)setAttribute:(EOAttribute*)_attribute
  adaptor:(EOAdaptor*)_adaptor
  alias:(NSString*)_alias
{
    ASSIGN(self->attribute, _attribute);
    ASSIGN(self->adaptor,   _adaptor);
    ASSIGN(self->alias,     _alias);
}

- (NSString *)convertAttribute:(va_list *)pString
  scanner:(FormatScanner *)scanner
{
  NSString *columnName;

  columnName = (adaptor)
    ? (NSString *)[adaptor formatAttribute:self->attribute]
    : [self->attribute columnName];

  if (alias)
    return [NSString stringWithFormat:@"%@.%@", alias, columnName];

  return columnName;
}

@end /* EOSelectScannerHandler */
