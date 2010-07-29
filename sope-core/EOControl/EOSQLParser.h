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

#ifndef __EOControl_EOSQLParser_H__
#define __EOControl_EOSQLParser_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

/*
  This is parser can be used to parse simple SQL statements. It's not a full
  SQL implementation, but should be sufficient for simple applications.

  Additional hints:
  - the selected attributes are added to the 'attributes' hint, if a
    wildcard select is used (*), the hint is not set
  - the depth of WebDAV scope from-queries are set in the depth-hint, valid
    values are "deep", "flat", "flat+self", "self"
  - if multiple entities are queried in the FROM, they are joined using ","
    and set as the entityName of the fetch spec
*/

@class EOFetchSpecification, EOQualifier;

@interface EOSQLParser : NSObject
{
}

+ (id)sharedSQLParser;

/* top level parser entry points */

- (EOFetchSpecification *)parseSQLSelectStatement:(NSString *)_sql;
- (EOQualifier *)parseSQLWhereExpression:(NSString *)_sql;

/* parsing parts (exported for overloading in subclasses) */

- (BOOL)parseSQL:(id *)result
  from:(unichar **)pos length:(unsigned *)len
  strict:(BOOL)beStrict;
- (BOOL)parseToken:(const unsigned char *)tk
  from:(unichar **)pos length:(unsigned *)len
  consume:(BOOL)consume;
- (BOOL)parseIdentifier:(NSString **)result
  from:(unichar **)pos length:(unsigned *)len
  consume:(BOOL)consume;
- (BOOL)parseQualifier:(EOQualifier **)result
  from:(unichar **)pos length:(unsigned *)len;
- (BOOL)parseScope:(NSString **)_scope:(NSString **)_entity
  from:(unichar **)pos length:(unsigned *)len;

- (BOOL)parseColumnName:(NSString **)result
  from:(unichar **)pos length:(unsigned *)len
  consume:(BOOL)consume;
- (BOOL)parseTableName:(NSString **)result
  from:(unichar **)pos length:(unsigned *)len
  consume:(BOOL)consume;
- (BOOL)parseIdentifierList:(NSArray **)result
  from:(unichar **)pos length:(unsigned *)len
  selector:(SEL)_sel;

@end

#endif /* __EOControl_EOSQLParser_H__ */
