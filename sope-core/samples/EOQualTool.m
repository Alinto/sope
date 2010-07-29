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

#import "EOQualTool.h"
#import "common.h"
#include <EOControl/EOControl.h>
#include <EOControl/EOSQLParser.h>

@interface dateTime : NSDate
@end

@implementation dateTime

- (id)initWithString:(NSString *)_s {
  NSCalendarDate *date;
  NSString *fmt = @"%Y-%m-%dT%H:%M:%SZ";
  [self release];
  date = [NSCalendarDate dateWithString:_s calendarFormat:fmt];
  [date setCalendarFormat:@"%Y-%m-%d %H:%M %Z"];
  return [date retain];
}

@end

@implementation EOQualTool

/* ops */

- (void)indent:(int)_level {
  int i;
  for (i = 0; i < _level; i++)
    printf("  ");
}

- (void)printQualifiers:(NSArray *)_qs nesting:(int)_level {
  NSEnumerator *e;
  EOQualifier *q;

  e = [_qs objectEnumerator];
  while ((q = [e nextObject]))
    [self printQualifier:q nesting:_level];
}

- (void)printQualifier:(EOQualifier *)_q nesting:(int)_level {
  [self indent:_level];
  
  if ([_q isKindOfClass:[EOAndQualifier class]]) {
    printf("AND\n");
    [self printQualifiers:[(EOAndQualifier *)_q qualifiers] 
	  nesting:_level + 1];
  }
  else if ([_q isKindOfClass:[EOOrQualifier class]]) {
    printf("OR\n");
    [self printQualifiers:[(EOOrQualifier *)_q qualifiers] nesting:_level + 1];
  }
  else if ([_q isKindOfClass:[EONotQualifier class]]) {
    printf("NOT\n");
    [self printQualifier:[(EONotQualifier *)_q qualifier] nesting:_level + 1];
  }
  else if ([_q isKindOfClass:[EOKeyValueQualifier class]]) {
    id v = [(EOKeyValueQualifier *)_q value];
    printf("key OP value\n");
    _level++;
    [self indent:_level];
    printf("key:   %s\n", [[(EOKeyValueQualifier *)_q key] cString]);
    [self indent:_level];
    printf("value: '%s' (class=%s)\n",
	   [[v stringValue] cString],
	   [NSStringFromClass([v class]) cString]);
    [self indent:_level];
    printf("OP:    %s\n", 
	   [NSStringFromSelector([(EOKeyValueQualifier *)_q selector]) 
				 cString]);
    _level--;
  }
  else if ([_q isKindOfClass:[EOKeyComparisonQualifier class]]) {
    printf("key1 OP key1\n");
    _level++;
    [self indent:_level];
    printf("left:  %s\n", [[(EOKeyComparisonQualifier *)_q leftKey] cString]);
    [self indent:_level];
    printf("right: %s\n", [[(EOKeyComparisonQualifier *)_q rightKey] cString]);
    [self indent:_level];
    printf("OP:    %s\n",
	   [NSStringFromSelector([(EOKeyComparisonQualifier *)_q selector]) 
				cString]);
    _level--;
  }
  else
    printf("unknown: %s\n", [NSStringFromClass([_q class]) cString]);
}

- (void)processQualifier:(NSString *)_qs {
  EOQualifier *q;
  NSArray *args = nil;
  
  printf("qualifier: '%s'\n", [_qs cString]);
  
  if ((q = [EOQualifier qualifierWithQualifierFormat:_qs arguments:args])) {
    printf("  parsed: %s\n", [[q description] cString]);

    [self printQualifier:q nesting:1];
  }
  else
    printf("  parsing failed !\n");
}

- (void)testExQualifier {
  [self processQualifier:
		 @"\"DAV:iscollection\" = False     and "
	       @"\"http://schemas.microsoft.com/mapi/proptag/x0c1e001f\" = "
	       @"'SMTP'        and "
	       @"\"http://schemas.microsoft.com/mapi/proptag/x0e230003\" > 0"];
}
- (void)testComplexCastQualifier {
  [self processQualifier:
	       @"\"DAV:getlastmodified\" < "
	       @"  cast(\"1970-01-01T00:00:00Z\" as 'dateTime')  "
	       @" and \"DAV:contentclass\" = 'urn:content-classes:appointment'"
	       @" and (\"urn:schemas:calendar:instancetype\" = 0 "
	       @" or \"urn:schemas:calendar:instancetype\" = 1)"];
}

- (void)testQualifiers {
  [self testExQualifier];
  [self testComplexCastQualifier];
}

- (void)testSQL:(NSString *)_sql {
  EOSQLParser *parser;
  EOFetchSpecification *fs;

  if ([_sql hasPrefix:@"test"]) {
    SEL s;
    
    s = NSSelectorFromString(_sql);
    if ([EOSQLParser respondsToSelector:s]) {
      [EOSQLParser performSelector:s];
      return;
    }
  }
  
  parser = [EOSQLParser sharedSQLParser];
  
  [self logWithFormat:@"parse SQL: %@", _sql];
  [self logWithFormat:@"parser: %@", parser];
  
  fs = [parser parseSQLSelectStatement:_sql];
  [self logWithFormat:@"got fs: %@", fs];
}

/* tool operation */

- (int)usage {
  fprintf(stderr, "usage: eoqual <quals>\n");
  return 1;
}

- (int)runWithArguments:(NSArray *)_args {
  NSUserDefaults *ud;
  unsigned i;
  
  _args = [_args subarrayWithRange:NSMakeRange(1, [_args count] - 1)];
  if ([_args count] == 0)
    return [self usage];
  
  ud = [NSUserDefaults standardUserDefaults];
  
  for (i = 0; i < [_args count]; i++) {
    NSString *q;
    
    q = [_args objectAtIndex:i];
    if ([q hasPrefix:@"sql:"])
      [self testSQL:[q stringWithoutPrefix:@"sql:"]];
    else if ([q isEqualToString:@"test"])
      [self testQualifiers];
    else
      [self processQualifier:q];
  }
  
  return 0;
}

@end /* EOQualTool */
