/*
**  OracleAdaptorChannel.m
**
**  Copyright (c) 2007-2009  Inverse inc. and Ludovic Marcotte
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

#import "OracleAdaptorChannel.h"

#include "err.h"
#include "OracleAdaptor.h"
#include "OracleAdaptorChannelController.h"
#include "OracleAdaptorContext.h"
#include "EOAttribute+Oracle.h"

#import <NGExtensions/NSObject+Logs.h>

#include <unistd.h>

static BOOL debugOn = NO;
static int prefetchMemorySize;
static int maxTry = 3;
static int maxSleep = 500;
//
//
//
@interface OracleAdaptorChannel (Private)

- (void) _cleanup;

@end

@implementation OracleAdaptorChannel (Private)

- (void) _cleanup
{
  column_info *info;
  int c;
  sword result;

  [_resultSetProperties removeAllObjects];

  c = [_row_buffer count];

  while (c--)
    {
      info = [[_row_buffer objectAtIndex: c] pointerValue];

      // We free our LOB object. If it fails, it likely mean it isn't a LOB
      // so we just free the value instead.
      if (info->value)
	{
	  if (info->type == SQLT_CLOB
	      || info->type == SQLT_BLOB
	      || info->type == SQLT_BFILEE
	      || info->type == SQLT_CFILEE)
	    {
	      result = OCIDescriptorFree((dvoid *)info->value, (ub4) OCI_DTYPE_LOB);
	      if (result != OCI_SUCCESS)
		{
		  NSLog (@"value was not a LOB descriptor");
		  abort();
		}
	    }
	  else
	    free(info->value);
	  info->value = NULL;
	}
      else
	{
	  NSLog (@"trying to free an already freed value!");
	  abort();
	}
      free(info);

      [_row_buffer removeObjectAtIndex: c];
    }

  OCIHandleFree(_current_stm, OCI_HTYPE_STMT);
  _current_stm = (OCIStmt *)0;
}

@end


//
//
//
@implementation OracleAdaptorChannel

static void DBTerminate()
{
  if (OCITerminate(OCI_DEFAULT))
    NSLog(@"FAILED: OCITerminate()");
  else
    NSLog(@"Oracle8: environment shut down");
}

+ (void) initialize
{
  NSUserDefaults *ud;

  ud = [NSUserDefaults standardUserDefaults];
  debugOn = [ud boolForKey: @"OracleAdaptorDebug"];

  prefetchMemorySize = [ud integerForKey: @"OracleAdaptorPrefetchMemorySize"];
  if (!prefetchMemorySize)
    prefetchMemorySize = 16 * 1024; /* 16Kb */

  // We Initialize the OCI process environment.
  if (OCIInitialize((ub4)OCI_DEFAULT, (dvoid *)0,
                    (dvoid * (*)(dvoid *, size_t)) 0,
                    (dvoid * (*)(dvoid *, dvoid *, size_t))0,
                    (void (*)(dvoid *, dvoid *)) 0 ))
    NSLog(@"FAILED: OCIInitialize()");
  else
    {
      NSLog(@"Oracle8: environment initialized");
      atexit(DBTerminate);
    }
}

- (id) initWithAdaptorContext: (EOAdaptorContext *) theAdaptorContext
{
  if ((self = [super initWithAdaptorContext: theAdaptorContext]))
    {
      _resultSetProperties = [[NSMutableArray alloc] init];
      _row_buffer = [[NSMutableArray alloc] init];
  
      _oci_env = (OCIEnv *)0;
      _oci_err = (OCIError *)0;
      _current_stm = (OCIStmt *)0;

      // This will also initialize ivars in EOAdaptorChannel for
      // delegate calls so it's important to call -setDelegate:
      [self setDelegate: [[OracleAdaptorChannelController alloc] init]];
      
      return self;
    }

  return nil;
}

//
//
//
- (id) copyWithZone: (NSZone *) theZone
{
  return [self retain];
}

//
//
//
- (void) cancelFetch
{
  // Oracle's doc says: "If you call OCIStmtFetch2() with the nrows parameter set to 0, this cancels the cursor."
  if (OCIStmtFetch2(_current_stm, _oci_err, (ub4)0, (ub4)OCI_FETCH_NEXT, (sb4)0, (ub4)OCI_DEFAULT))
    {
      NSLog(@"Fetch cancellation failed");
    }
  
  [self _cleanup];
  [super cancelFetch];
}

//
//
//
- (void) closeChannel
{
  if ([self isOpen])
    {
      [super closeChannel];
    
      // We logoff from the database.
      if (!_oci_ctx || !_oci_err || OCILogoff(_oci_ctx, _oci_err))
	{
	  NSLog(@"FAILED: OCILogoff()");
	}

      if (_oci_ctx)
	OCIHandleFree(_oci_ctx, OCI_HTYPE_SVCCTX);

      if (_oci_err)
	OCIHandleFree(_oci_err, OCI_HTYPE_ERROR);
      
      // OCIHandleFree(_oci_env, OCI_HTYPE_ENV);

      _oci_ctx = (OCISvcCtx *)0;
      _oci_err = (OCIError *)0;
      _oci_env = (OCIEnv *)0;
    }
}

//
//
//
- (void) dealloc
{
  if (debugOn)
    NSLog(@"OracleAdaptorChannel: -dealloc");

  [self _cleanup];

  RELEASE(_resultSetProperties);
  RELEASE(delegate);

  [super dealloc];
}

//
// TODO later
//
- (EOModel*) describeModelWithTableNames: (NSArray *) theTableNames
{
  return nil;
}

//
// TODO later
//
- (NSArray *) describeTableNames
{
  return nil;
}

//
// This breaks EOF 4.5 support.
//
- (NSArray *) describeResults: (BOOL) theBOOL
{
  return [NSArray arrayWithArray: _resultSetProperties];
}

//
// This breaks EOF 4.5 support.
//
// We must: 1. send the database request
//          2. process the results
//          3. call -adaptorChannel:didEvaluateExpression:
//
- (BOOL) evaluateExpression: (NSString *) theExpression
{
  EOAttribute *attribute;
  OCIParam *param;
  int rCount;
  column_info *info;
  ub4 i, clen, count;
  text *sql, *cname;
  sword status;
  ub2 type;
  ub4 memory, prefetchrows;

  [self _cleanup];

  if (debugOn)
    [self logWithFormat: @"expression: %@", theExpression];

  if (!theExpression || ![theExpression length])
    {
      [NSException raise: @"OracleInvalidExpressionException"
		   format: @"Passed an invalid (nil or length == 0) SQL expression"];
    }

  if (![self isOpen])
    {
      [NSException raise: @"OracleChannelNotOpenException"
		   format: @"Called -evaluateExpression: prior to -openChannel"];
    }
  
  sql = (text *)[theExpression UTF8String];
 
 rCount = 0;
 retry:
  // We alloc our statement handle
  if ((status = OCIHandleAlloc((dvoid *)_oci_env, (dvoid **)&_current_stm, (ub4)OCI_HTYPE_STMT, (CONST size_t) 0, (dvoid **) 0)))
    {
      checkerr(_oci_err, status);
      NSLog(@"Can't allocate statement.");
      return NO;
    }

  prefetchrows = 100000; /* huge numbers here force a fallback on the memory limit below, which is what we really are interested in */
  if ((status = OCIAttrSet(_current_stm, (ub4)OCI_HTYPE_STMT, (dvoid *)&prefetchrows, (ub4) sizeof(ub4), (ub4)OCI_ATTR_PREFETCH_ROWS, _oci_err)))
    {
      checkerr(_oci_err, status);
      NSLog(@"Can't set prefetch rows (%d).", prefetchrows);
      return NO;
    }
  
  memory = prefetchMemorySize;
  if ((status = OCIAttrSet(_current_stm, (ub4)OCI_HTYPE_STMT, (dvoid *)&memory, (ub4) sizeof(ub4), (ub4)OCI_ATTR_PREFETCH_MEMORY, _oci_err)))
    {
      checkerr(_oci_err, status);
      NSLog(@"Can't set prefetch memory (%d).", memory);
      return NO;
    }

  // We prepare our statement
  if ((status = OCIStmtPrepare(_current_stm, _oci_err, sql, strlen((const char *)sql), OCI_NTV_SYNTAX, OCI_DEFAULT)))
    {
      checkerr(_oci_err, status);
      NSLog(@"Prepare failed: OCI_ERROR");
      return NO;
    }

  // We check if we're doing a SELECT and if so, we're fetching data!
  OCIAttrGet(_current_stm, OCI_HTYPE_STMT, &type, 0, OCI_ATTR_STMT_TYPE, _oci_err);
  self->isFetchInProgress = (type == OCI_STMT_SELECT ? YES : NO);
 
  // We execute our statement. Not that we _MUST_ set iter to 0 for non-SELECT statements.
  if ((status = OCIStmtExecute(_oci_ctx, _current_stm, _oci_err, (self->isFetchInProgress ? (ub4)0 : (ub4)1), (ub4)0, (CONST OCISnapshot *)NULL, (OCISnapshot *)NULL,
			       ([(OracleAdaptorContext *)[self adaptorContext] autoCommit] ? OCI_COMMIT_ON_SUCCESS : OCI_DEFAULT))))
    {
      ub4 serverStatus;
      
      checkerr(_oci_err, status);
      NSLog(@"Statement execute failed (OCI_ERROR): %@", theExpression);

      // We check to see if we lost connection and need to reconnect.
      serverStatus = 0;
      OCIAttrGet((dvoid *)_oci_env, OCI_HTYPE_SERVER, (dvoid *)&serverStatus, (ub4 *)0, OCI_ATTR_SERVER_STATUS, _oci_err);
      
      if (serverStatus == OCI_SERVER_NOT_CONNECTED)
	{
	  // We cleanup our previous handles
	  [self cancelFetch];
	  [self closeChannel];
	  
	  // We try to reconnect a couple of times before giving up...
	  while (rCount < maxTry)
	    {
	      usleep(maxSleep);
	      rCount++;

	      if ([self openChannel])
		{
		  NSLog(@"Connection re-established to Oracle - retrying to process the statement.");
		  goto retry;
		}
	    }
	}
      return NO;
    }

  // We check the number of params (ie., columns)
  if ((status = OCIAttrGet((dvoid *)_current_stm, OCI_HTYPE_STMT, (dvoid *)&count, (ub4 *)0, OCI_ATTR_PARAM_COUNT, _oci_err)))
    {
      checkerr(_oci_err, status);
      NSLog(@"Attribute get failed (OCI_ERROR): %@", theExpression);
      return NO;
    }

  // We decode the columns' types
  for (i = 1; i < count+1; i++)
    {
      // We alloc our info structure. This will hold the values being
      // read when we fetch data from the result set.
      info = (void *)malloc(sizeof(column_info));
      
      // We fetch the parameter
      status = OCIParamGet((dvoid *)_current_stm, OCI_HTYPE_STMT, _oci_err, (dvoid **)&param, (ub4)i);
      
      // We get the param's type
      status = OCIAttrGet((dvoid*)param, (ub4)OCI_DTYPE_PARAM, (dvoid*)&(info->type), (ub4 *)0, (ub4)OCI_ATTR_DATA_TYPE, (OCIError *)_oci_err);

      // We read the column's name (name of the param) and name's length
      clen = 0;
      status = OCIAttrGet((dvoid*)param, (ub4)OCI_DTYPE_PARAM, (dvoid**)&cname, (ub4 *)&clen, (ub4)OCI_ATTR_NAME, (OCIError *)_oci_err);
      
      // We read the maximum width of a column
      info->max_width = 0;
      status = OCIAttrGet((dvoid*)param, (ub4)OCI_DTYPE_PARAM, (dvoid*)&(info->max_width), (ub4 *)0, (ub4)OCI_ATTR_DATA_SIZE, (OCIError *)_oci_err);

      if (debugOn)
	NSLog(@"name: %s, type: %d", cname, info->type);
      attribute = [EOAttribute attributeWithOracleType: info->type  name: cname  length: clen  width: info->max_width];
      [_resultSetProperties addObject: attribute];

      // We now must bind our column name with a buffer in which we'll read into
      info->value = calloc(info->max_width, 1);
 
      //
      // Oracle's doc says: "SQLT_CHAR and SQLT_LNG can be specified for CLOB columns, and SQLT_BIN sand SQLT_LBI for BLOB columns."
      // Also, for LOB, it says: "The bind of more than 4 kilobytes of data to a LOB column uses space from the temporary tablespace."
      // 
      // For now, we read - SQLT_CLOB as SQLT_CHR
      //                  - SQLT_NUM as SQLT_INT
      //
      switch (info->type)
	{
	  case SQLT_CLOB:
	    //type = SQLT_CHR;
	    type = SQLT_CLOB;
	    free(info->value);
	    if (OCIDescriptorAlloc((dvoid *)_oci_env, &(info->value), (ub4)OCI_DTYPE_LOB, (size_t)0, (dvoid **)0) != OCI_SUCCESS) 
	      {
		NSLog(@"Unable to alloc descriptor");
		abort();
	      }
	    // "For descriptors, locators, or REFs, whose size is unknown to client applications, use the size of the structure you
	    // are passing in: for example, sizeof (OCILobLocator *).
	    info->max_width = sizeof(OCILobLocator *);
	    break;

	case SQLT_NUM:
	  type = SQLT_INT;
	  info->max_width = 4;
	  break;

	default:
	  type = info->type;
	} 

      //
      // Oracle's documentation says:"For a LOB, the buffer pointer must be a pointer to a LOB locator of type OCILobLocator.
      // Give the address of the pointer."
      //
      info->def = (OCIDefine*)0;

#warning cleanup
      if ((status = OCIDefineByPos(_current_stm, &(info->def), _oci_err, i, (info->type == SQLT_CLOB ? &info->value : (dvoid *)info->value), info->max_width, type,
      				   (dvoid *)0, (ub2 *)&(info->width), (ub2 *)0, OCI_DEFAULT)))
	{
	  NSLog(@"OCIDefineByPos FAILED");
	  abort();
	}

      [_row_buffer addObject: [NSValue valueWithPointer: info]];
      
      // We free up our param handle.
      OCIHandleFree((dvoid*)param, OCI_HTYPE_STMT);
    }

  return YES;
}

//
//
//
- (OCIError *) errorHandle
{
  return _oci_err;
}

//
//
//
- (BOOL) isOpen
{
  return (_oci_env ? YES : NO);
}

//
// This breaks EOF 4.5 support.
//
- (BOOL) openChannel
{
  OracleAdaptor *o;
  
  const char *username, *password, *database;
  sword status;

  if (![super openChannel] || [self isOpen])
    {
      return NO;
    }

  if (OCIEnvInit((OCIEnv **)&_oci_env, (ub4)OCI_DEFAULT, (size_t)0, (dvoid **)0))
    {
      NSLog(@"FAILED: OCIEnvInit()");
      [self closeChannel];
      return NO;
    }
  
  if (OCIHandleAlloc((dvoid *)_oci_env, (dvoid *)&_oci_err, (ub4)OCI_HTYPE_ERROR, (size_t)0, (dvoid **)0))
    {
      NSLog(@"FAILED: OCIHandleAlloc() on errhp");
      [self closeChannel];
      return NO;
    }
  
  o = (OracleAdaptor *)[[self adaptorContext] adaptor];
  username = [[o loginName] UTF8String];
  password = [[o loginPassword] UTF8String];

  // Under Oracle 10g, the third parameter of OCILogon() has the form: [//]host[:port][/service_name]
  // See http://download-west.oracle.com/docs/cd/B12037_01/network.101/b10775/naming.htm#i498306 for
  // all juicy details.
  if ([o serverName] && [o port])
    database = [[NSString stringWithFormat:@"%@:%@/%@", [o serverName], [o port], [o databaseName]] UTF8String];
  else
    database = [[o databaseName] UTF8String];

  // We logon to the database.
  if ((status = OCILogon(_oci_env, _oci_err, &_oci_ctx, (const OraText*)username, strlen(username),
	       (const OraText*)password, strlen(password), (const OraText*)database, strlen(database))))
    {
      NSLog(@"FAILED: OCILogon(). username = %s  password = %s"
	    @"  database = %s", username, password, database);
      checkerr(_oci_err, status);
	  [self closeChannel];
      return NO;
    }
  
  return YES;
}

//
// We map the attributes to the values.
//
// For now, we ignore the passed attributes and we initialize the full row.
//
- (NSMutableDictionary *) primaryFetchAttributes: (NSArray *) theAttributes
					withZone: (NSZone *) theZone
{
  sword status;
  
  // We check if our connection is open prior to trying to fetch any data. OCIStmtFetch2() returns
  // NO error code if the OCI environment is set up but the OCILogon() has failed.
  if (![self isOpen])
    return nil;

  status = OCIStmtFetch2(_current_stm, _oci_err, (ub4)1, (ub4)OCI_FETCH_NEXT, (sb4)0, (ub4)OCI_DEFAULT);

  if (status == OCI_NO_DATA)
    {
      self->isFetchInProgress = NO;
    }
  else
    {
      NSMutableDictionary *row;
      column_info *info;
      int i, c;
      id o;
    
      c = [_resultSetProperties count];
      row = [NSMutableDictionary dictionaryWithCapacity: c];
      
      // We decode all column values we got in our result set
      for (i = 0; i < c; i++)
	{
	  info = [[_row_buffer objectAtIndex: i] pointerValue];

	  //NSLog(@"========== NEW COLUMN ==============");
	  //NSLog(@"Read type %d, width %d at %d", info->type, info->width, info->value);
	  o = nil;
      
	  // On Oracle, if we've read a lenght of 0, it means that we got a NULL.
	  if (info->type != SQLT_CLOB && info->width == 0)
	    {
	      o = [NSNull null];
	    }
	  else
	    {
	      switch (info->type)
		{
		case SQLT_CHR:
		case SQLT_STR:
		  o = AUTORELEASE([[NSString alloc] initWithBytes: info->value  length: info->width  encoding: NSUTF8StringEncoding]);
		  break;

		case SQLT_CLOB:
		  {
		    ub4 len;
		    
		    status = OCILobGetLength(_oci_ctx, _oci_err, info->value, &len);
		    
		    // We might get a OCI_INVALID_HANDLE if we try to read a NULL CLOB.
		    // This would be avoided if folks using CLOB would use Oracle's empty_clob()
		    // function but instead of relying on this, we check for invalid handles.
		    if (status != OCI_INVALID_HANDLE && status != OCI_SUCCESS)
		      {
			checkerr(_oci_err, status);
			o = [NSString string];
		      }
		    else
		      {
			// We alloc twice the size of the LOB length. OCILobGetLength() returns us the LOB length in UTF-16 characters.
			o = calloc(len*2, 1);
			OCILobRead(_oci_ctx, _oci_err, info->value, &len, 1, o, len*2, (dvoid *)0, (sb4 (*)(dvoid *, CONST dvoid *, ub4, ub1))0, (ub2)0, (ub1)SQLCS_IMPLICIT);
			o = AUTORELEASE([[NSString alloc] initWithBytesNoCopy: o  length: len  encoding: NSUTF8StringEncoding  freeWhenDone: YES]);
		      }
		  }
		  break;
 
		case SQLT_DAT:
		  {
		    signed char *buf;

		    buf = (signed char*)info->value;
		    o = [NSCalendarDate dateWithYear: (buf[0]-100)*100+buf[1]-100
					month: buf[2]
					day: buf[3]
					hour: buf[4]-1
					minute: buf[5]-1
					second: buf[6]-1
					timeZone: [NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
				    
		  }
		  break;
		  
		case SQLT_INT:
		case SQLT_NUM:
		  switch (info->width)
		    {
		    case 1:
		      o = [NSNumber numberWithChar: *(char*)(info->value)];
		      break;
		    case 2:
		      o = [NSNumber numberWithShort: *(short*)(info->value)];
		      break;
		    case 8:
		      o = [NSNumber numberWithLongLong: *(long long*)(info->value)];
		      break;
		    case 4:
		    default:
		      o = [NSNumber numberWithInt: *(int*)(info->value)];
		      break;
		    }
		  break;

		case SQLT_TIMESTAMP:
		case SQLT_TIMESTAMP_TZ:
		case SQLT_TIMESTAMP_LTZ:
		  {
		    // FIXME implement
		    //o = [NSDate date];
		  }
		  break;
		  
		default:
		  NSLog(@"Unknown type! %d", info->type);
		}
	    }
	  
	  if (!o) o = [NSNull null];
	  [row setObject: o  forKey: [[_resultSetProperties objectAtIndex: i] name]];
	}
      
      return row;
    }

  return nil;
}

//
// TODO later
//
#if 0
- (NSDictionary *) primaryKeyForNewRowWithEntity: (EOEntity *) theEntity
{

}
#endif

//
// TODO later
//
#if 0
- (BOOL) readTypesForEntity: (EOEntity *) theEntity
{
  return NO;
}
#endif

//
// TODO later
//
#if 0
- (BOOL) readTypeForAttribute: (EOAttribute *) theAttribute
{
  return NO;
}
#endif

//
//
//
- (OCIEnv *) environment
{
  return _oci_env;
}

//
//
//
- (OCISvcCtx *) serviceContext
{
  return _oci_ctx;
}

@end
