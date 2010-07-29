/*
**  OracleAdaptorChannelController.m
**
**  Copyright (c) 2007  Inverse groupe conseil inc. and Ludovic Marcotte
**
**  Author: Ludovic Marcotte <ludovic@inverse.ca>
**
**  This library is free software; you can redistribute it and/or
**  modify it under the terms of the GNU Lesser General Public
**  License as published by the Free Software Foundation; either
**  version 2.1 of the License, or (at your option) any later version.
**
**  This library is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
**  Lesser General Public License for more details.
**
**  You should have received a copy of the GNU Lesser General Public
**  License along with this library; if not, write to the Free Software
**  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*/

#import "OracleAdaptorChannelController.h"

#include <oci.h>

#include "err.h"
#include "OracleAdaptorChannel.h"
#include "OracleAdaptorContext.h"

#import <Foundation/Foundation.h>
#import <GDLAccess/EOSQLExpression.h>

static BOOL debugOn = NO;

//
//
//
@interface OracleAdaptorChannelController (Private)

- (BOOL) _evaluateExpression: (NSString *) theExpression
			keys: (NSArray *) theKeys
		      values: (NSMutableDictionary *) theValues
		     channel: (id) theChannel;

@end

//
//
//
@implementation OracleAdaptorChannelController

+ (void) initialize
{
  NSUserDefaults *ud;

  ud = [NSUserDefaults standardUserDefaults];
  debugOn = [ud boolForKey: @"OracleAdaptorDebug"];
}

- (EODelegateResponse) adaptorChannel: (id) theChannel
                        willInsertRow: (NSMutableDictionary *) theRow
                            forEntity: (EOEntity *) theEntity
{
  NSMutableString *s;
  NSArray *keys;
  int i, c;

  if (debugOn)
    NSLog(@"willInsertRow: %@ %@", [theRow description], [theEntity description]);

  s = AUTORELEASE([[NSMutableString alloc] init]);

  [s appendFormat: @"INSERT INTO %@ (", [theEntity externalName]];
  keys = [theRow allKeys];
  c = [keys count];

  for (i = 0; i < c; i++)
    {
      [s appendString: [keys objectAtIndex: i]];
      
      if (i < c-1) [s appendString: @", "];
    }

  [s appendString: @") VALUES ("];

  for (i = 0; i < c; i++)
    {
      [s appendFormat: @":%d", i+1];
      
      if (i < c-1) [s appendString: @", "];
    }

  [s appendString: @")"];

  if ([self _evaluateExpression: s  keys: keys  values: theRow  channel: theChannel])
    {
      return EODelegateOverrides;
    }

  return EODelegateRejects;
}

//
//
//
- (EODelegateResponse) adaptorChannel: (id) theChannel
                        willUpdateRow: (NSMutableDictionary *) theRow
                 describedByQualifier: (EOSQLQualifier *) theQualifier
{
  NSMutableString *s;
  NSArray *keys;
  int i, c;

  if (debugOn)
    NSLog(@"willUpdateRow: %@ %@", [theRow description], [theQualifier description]);

  s = AUTORELEASE([[NSMutableString alloc] init]);

  [s appendFormat: @"UPDATE %@ SET ", [[theQualifier entity] externalName]];
  keys = [theRow allKeys];
  c = [keys count];

  for (i = 0; i < c; i++)
    {
      [s appendFormat: @"%@ = :%d", [keys objectAtIndex: i], i+1];
      
      if (i < c-1) [s appendString: @", "];
    }
  
  [s appendFormat: @" WHERE %@", [theQualifier expressionValueForContext: AUTORELEASE([[EOSQLExpression alloc] initWithEntity: [theQualifier entity]])]];;

  if ([self _evaluateExpression: s  keys: keys  values: theRow  channel: theChannel])
    {
      return EODelegateOverrides;
    }

  return EODelegateRejects;
}

@end

//
//
//
@implementation  OracleAdaptorChannelController (Private)

- (void) _cleanup: (NSArray *) theColumns
	statement: (OCIStmt *) theStatement
	  channel: (id) theChannel
{
  column_info *info;
  int c;

  c = [theColumns count];

  while (c--)
    {
      info = [[theColumns objectAtIndex: c] pointerValue];

      if (info->type == SQLT_INT)
	{
	  free(info->value);
	}
      else if (info->type == SQLT_CLOB)
	{
	  OCILobFreeTemporary([theChannel serviceContext], [theChannel errorHandle], info->value);
	  OCIDescriptorFree((dvoid *)info->value, (ub4)OCI_DTYPE_LOB);
	}
      free(info);
    }
  [theColumns release];

  OCIHandleFree(theStatement, OCI_HTYPE_STMT);
}

//
//
//
- (BOOL) _evaluateExpression: (NSString *) theExpression
			keys: (NSArray *) theKeys
		      values: (NSMutableDictionary *) theValues
		     channel: (id) theChannel
{
  NSMutableArray *columns;;

  OCIStmt* current_stm;
  OCIBind* bind;

  column_info *info;
  sword status;
  text *sql;
  int i,c;
  id v;

  sql = (text *)[theExpression UTF8String];

  // We alloc our statement handle
  if (OCIHandleAlloc((dvoid *)[theChannel environment], (dvoid **)&current_stm, (ub4)OCI_HTYPE_STMT, (CONST size_t) 0, (dvoid **) 0))
    {
      NSLog(@"Can't allocate statement.");
      return NO;
    }
  
  // We prepare the statement
  if (OCIStmtPrepare(current_stm, [theChannel errorHandle], sql, (ub4)strlen((char *)sql), (ub4) OCI_NTV_SYNTAX, (ub4) OCI_DEFAULT))
    {
      NSLog(@"FAILED: OCIStmtPrepare() insert\n");
      return NO;
  }

  columns = [[NSMutableArray alloc] init];
  c = [theKeys count];

  // We bind all input variables
  for (i = 0; i < c; i++)
    {
      info = (void *)malloc(sizeof(column_info));
      [columns addObject: [NSValue valueWithPointer: info]];
      
      v = [theValues objectForKey: [theKeys objectAtIndex: i]];
      bind = (OCIBind *)0;

      if ([v isKindOfClass: [NSString class]])
	{
	  const char *buf;
	  ub4 len;
	  
	  buf = [v UTF8String];
	  len = strlen(buf);
	  
	  if (len <= 4000)
	    {
	      info->type = SQLT_CHR;
	      info->value = (dvoid *)buf;
	      info->width = len;
	    }
	  else
	    {
	      info->type = SQLT_CLOB;
	      info->width = sizeof(OCILobLocator *);

	      if ((status = OCIDescriptorAlloc((dvoid *)[theChannel environment], &(info->value), (ub4)OCI_DTYPE_LOB, (size_t)0, (dvoid **)0)) != OCI_SUCCESS) 
	      	{
		  [self _cleanup: columns  statement: current_stm  channel: theChannel];
		  checkerr([theChannel errorHandle], status);
		  return NO;
		}
	      
	      OCILobCreateTemporary([theChannel serviceContext], [theChannel errorHandle], info->value, OCI_DEFAULT, SQLCS_IMPLICIT,
				    OCI_TEMP_CLOB, FALSE, OCI_DURATION_SESSION);

	      OCILobWrite([theChannel serviceContext], [theChannel errorHandle], info->value, &len, 1, (dvoid *)buf, len, OCI_ONE_PIECE,
			  (dvoid *)0, (sb4 (*)())0, (ub2)0, (ub1)SQLCS_IMPLICIT);
	    }
	}
      else
	{
	  int x;

	  info->type = SQLT_INT;
	  x = [v intValue];
	  info->width = sizeof(x);
	  info->value = calloc(info->width, 1);
	  *(int *)info->value = x;
	}
      
      if ((status = (OCIBindByPos(current_stm, &bind, [theChannel errorHandle], (ub4)i+1, (info->type == SQLT_CLOB ? &info->value : (dvoid *)info->value), 
				  (sb4)info->width, info->type, (dvoid *)0, (ub2 *)0, (ub2 *)0, (ub4)0, (ub4 *)0, (ub4)OCI_DEFAULT))) != OCI_SUCCESS)
	{
	  [self _cleanup: columns  statement: current_stm  channel: theChannel];
	  checkerr([theChannel errorHandle], status);
	  return NO;
	}
    }

  // We execute the statement
  if ((status = OCIStmtExecute([theChannel serviceContext], current_stm, [theChannel errorHandle], (ub4)1, (ub4)0, (CONST OCISnapshot*)0, (OCISnapshot*)0,
			       ([(OracleAdaptorContext *)[theChannel adaptorContext] autoCommit] ? OCI_COMMIT_ON_SUCCESS : OCI_DEFAULT))) != OCI_SUCCESS)
    {
      [self _cleanup: columns  statement: current_stm  channel: theChannel];
      checkerr([theChannel errorHandle], status);
      return NO;
    }

  [self _cleanup: columns  statement: current_stm  channel: theChannel];

  return YES;
}

@end
