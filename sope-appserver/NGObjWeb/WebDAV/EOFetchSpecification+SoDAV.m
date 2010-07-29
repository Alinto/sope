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

#include "EOFetchSpecification+SoDAV.h"
#include "SoDAVSQLParser.h"
#import <EOControl/EOControl.h>
#include "common.h"

@implementation EOFetchSpecification(SoDAV)

+ (EOFetchSpecification *)parseWebDAVSQLString:(NSString *)_sql {
  EOFetchSpecification *fs;
  static SoDAVSQLParser *parser = nil;
  
  /* parse SQL */
  
  if (parser == nil)
    parser = [[SoDAVSQLParser alloc] init];
  
  if ((fs = [parser parseSQLSelectStatement:_sql]) == nil)
    return nil;
  
  /* morph attribute names ? */
  return fs;
}

- (NSArray *)selectedWebDAVPropertyNames {
  return [[self hints] objectForKey:@"attributes"];
}

- (NSString *)scopeOfWebDAVQuery {
  NSString *scope;
  
  scope = [[self hints] objectForKey:@"scope"];
  return [scope isNotNull] ? scope : (NSString *)@"flat";
}

- (BOOL)queryWebDAVPropertyNamesOnly {
  id v;
  
  if ((v = [[self hints] objectForKey:@"namesOnly"]) != nil)
    return [v boolValue];
  return NO;
}

- (NSArray *)davBulkTargetKeys {
  return [[self hints] objectForKey:@"bulkTargetKeys"];
}

@end /* EOFetchSpecification(SoDAV) */
