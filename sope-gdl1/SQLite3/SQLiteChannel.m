/* 
   SQLiteChannel.m

   Copyright (C) 2003-2005 SKYRIX Software AG

   Author: Helge Hess (helge.hess@skyrix.com)

   This file is part of the SQLite Adaptor Library

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

#include <ctype.h>
#include <string.h>
#include <strings.h>
#include "SQLiteChannel.h"
#include "SQLiteAdaptor.h"
#include "SQLiteException.h"
#include "NSString+SQLite.h"
#include "SQLiteValues.h"
#include "EOAttribute+SQLite.h"
#include "common.h"

#ifndef MIN
#  define MIN(x, y) ((x > y) ? y : x)
#endif

#define MAX_CHAR_BUF 16384

@implementation SQLiteChannel

static EONull *null = nil;

+ (void)initialize {
  if (null == NULL) null = [[EONull null] retain];
}

- (id)initWithAdaptorContext:(EOAdaptorContext*)_adaptorContext {
  if ((self = [super initWithAdaptorContext:_adaptorContext])) {
    [self setDebugEnabled:[[NSUserDefaults standardUserDefaults]
                                           boolForKey:@"SQLiteDebugEnabled"]];
    
    self->_attributesForTableName = 
      [[NSMutableDictionary alloc] initWithCapacity:16];
    self->_primaryKeysNamesForTableName =
      [[NSMutableDictionary alloc] initWithCapacity:16];
  }
  return self;
}

- (void)_adaptorWillFinalize:(id)_adaptor {
}

- (void)dealloc {
  if ([self isOpen])
    [self closeChannel];
  [self->_attributesForTableName       release];
  [self->_primaryKeysNamesForTableName release];
  [super dealloc];
}

/* NSCopying methods */

- (id)copyWithZone:(NSZone *)zone {
  return [self retain];
}

// debugging

- (void)setDebugEnabled:(BOOL)_flag {
  self->isDebuggingEnabled = _flag;
}
- (BOOL)isDebugEnabled {
  return self->isDebuggingEnabled;
}

- (void)receivedMessage:(NSString *)_message {
  NSLog(@"%@: message %@.", _message);
}

/* open/close */

static int openConnectionCount = 0;

- (BOOL)isOpen {
  return (self->_connection != NULL) ? YES : NO;
}

- (int)maxOpenConnectionCount {
  static int MaxOpenConnectionCount = -1;
    
  if (MaxOpenConnectionCount != -1)
    return MaxOpenConnectionCount;

  MaxOpenConnectionCount =
    [[NSUserDefaults standardUserDefaults]
                     integerForKey:@"SQLiteMaxOpenConnectionCount"];
  if (MaxOpenConnectionCount == 0)
    MaxOpenConnectionCount = 150;
  return MaxOpenConnectionCount;
}

- (BOOL)openChannel {
  const char *cDBName;
  SQLiteAdaptor *adaptor;
  int rc;
  
  if (self->_connection) {
    NSLog(@"%s: Connection already open !!!", __PRETTY_FUNCTION__);
    return NO;
  }
  
  adaptor = (SQLiteAdaptor *)[adaptorContext adaptor];
  
  if (![super openChannel])
    return NO;

  if (openConnectionCount > [self maxOpenConnectionCount]) {
    [SQLiteCouldNotOpenChannelException 
	raise:@"NoMoreConnections"
	format:@"cannot open a additional connection !"];
    return NO;
  }

  cDBName = [[adaptor databaseName] UTF8String];
  
  rc = sqlite3_open(cDBName, (void *)&(self->_connection));
  if (rc != SQLITE_OK) {
    // could not login ..
    // Note: connection *is* set! (might be required to deallocate)
    NSLog(@"WARNING: could not open SQLite connection to database '%@': %s",
          [adaptor databaseName], sqlite3_errmsg(self->_connection));
    sqlite3_close(self->_connection);
    return NO;
  }
  
  if (isDebuggingEnabled)
    NSLog(@"SQLite connection established 0x%p", self->_connection);

#if 0
  NSLog(@"---------- %s: %@ opens channel count[%d]", __PRETTY_FUNCTION__,
        self, openConnectionCount);
#endif
  openConnectionCount++;
  
#if LIB_FOUNDATION_BOEHM_GC
  [GarbageCollector registerForFinalizationObserver:self
                    selector:@selector(_adaptorWillFinalize:)
                    object:[[self adaptorContext] adaptor]];
#endif

  if (isDebuggingEnabled) {
    NSLog(@"SQLite channel 0x%p opened (connection=0x%p,%s)",
          self, self->_connection, cDBName);
  }
  return YES;
}

- (void)primaryCloseChannel {
  if (self->statement != NULL) {
    sqlite3_finalize(self->statement);
    self->statement = NULL;
  }
  
  if (self->_connection != NULL) {
    sqlite3_close(self->_connection);
#if 0
    NSLog(@"---------- %s: %@ close channel count[%d]", __PRETTY_FUNCTION__,
          self, openConnectionCount);
#endif
    openConnectionCount--;
    
    if (isDebuggingEnabled) {
      fprintf(stderr, 
	      "SQLite connection dropped 0x%p (channel=0x%p)\n",
              self->_connection, self);
    }
    self->_connection = NULL;
  }
}

- (void)closeChannel {
  [super closeChannel];
  [self primaryCloseChannel];
}

/* fetching rows */

- (NSException *)_makeSQLiteStep {
  NSString *r;
  const char *em;
  int rc;
  
  rc = sqlite3_step(self->statement);
#if 0
  NSLog(@"STEP: %i (row=%i, done=%i, mis=%i)", rc,
	SQLITE_ROW, SQLITE_DONE, SQLITE_MISUSE);
#endif
  
  if (rc == SQLITE_ROW) {
    self->hasPendingRow = YES;
    self->isDone        = NO;
    return nil /* no error */;
  }
  if (rc == SQLITE_DONE) {
    self->hasPendingRow = NO;
    self->isDone        = YES;
    return nil /* no error */;
  }

  if (rc == SQLITE_ERROR)
    r = [NSString stringWithUTF8String:sqlite3_errmsg(self->_connection)];
  else if (rc == SQLITE_MISUSE)
    r = @"The SQLite step function was called in an incorrect way";
  else if (rc == SQLITE_BUSY)
    r = @"The SQLite is busy.";
  else
    r = [NSString stringWithFormat:@"Unexpected SQLite error: %i", rc];

  if ((em = sqlite3_errmsg(self->_connection)) != NULL)
    r = [r stringByAppendingFormat:@": %s", em];
  
  return [SQLiteException exceptionWithName:@"FetchFailed"
			  reason:r userInfo:nil];
}

- (void)cancelFetch {
  if (self->statement != NULL) {
    sqlite3_finalize(self->statement);
    self->statement = NULL;
  }
  self->isDone        = NO;
  self->hasPendingRow = NO;
  [super cancelFetch];
}

- (NSArray *)describeResults:(BOOL)_beautifyNames {
  // TODO: make exception-less method
  int                 cnt, fieldCount;
  NSMutableArray      *result    = nil;
  NSMutableDictionary *usedNames = nil;
  NSNumber            *yesObj;
  
  yesObj = [NSNumber numberWithBool:YES];
  
  if (![self isFetchInProgress]) {
    [SQLiteException raise:@"NoFetchInProgress"
		     format:@"No fetch in progress (channel=%@)", self];
  }

  /* we need to fetch a row to get the info */

  if (!self->hasPendingRow) {
    NSException *error;
    
    if ((error = [self _makeSQLiteStep]) != nil) {
      [self cancelFetch];
      [error raise]; // raise error, TODO: make exception-less method
      return nil;
    }
  }
  if (!self->hasPendingRow) /* no rows available */
    return nil;
  
  fieldCount = sqlite3_column_count(self->statement);
  
  /* old code below */
  
  result    = [[NSMutableArray      alloc] initWithCapacity:fieldCount];
  usedNames = [[NSMutableDictionary alloc] initWithCapacity:fieldCount];

  for (cnt = 0; cnt < fieldCount; cnt++) {
    EOAttribute *attribute  = nil;
    NSString    *columnName = nil;
    NSString    *attrName   = nil;
    
    columnName = [NSString stringWithCString:
			     sqlite3_column_name(self->statement, cnt)];
    attrName   = _beautifyNames
      ? [columnName _sqlite3ModelMakeInstanceVarName]
      : columnName;
    
    if ([[usedNames objectForKey:attrName] boolValue]) {
      int      cnt2 = 0;
      char     buf[64];
      NSString *newAttrName = nil;

      for (cnt2 = 2; cnt2 < 100; cnt2++) {
	NSString *s;
        sprintf(buf, "%i", cnt2);
	
	// TODO: unicode
	s = [[NSString alloc] initWithCString:buf];
        newAttrName = [attrName stringByAppendingString:s];
	[s release];
        
        if (![[usedNames objectForKey:newAttrName] boolValue]) {
          attrName = newAttrName;
          break;
        }
      }
    }
    [usedNames setObject:yesObj forKey:attrName];

    attribute = [[EOAttribute alloc] init];
    [attribute setName:attrName];
    [attribute setColumnName:columnName];
    
    switch (sqlite3_column_type(self->statement, cnt)) {
      case SQLITE_INTEGER:
	[attribute setExternalType:@"INTEGER"];
	[attribute setValueClassName:@"NSNumber"];
	[attribute setValueType:@"d"];
	break;
      case SQLITE_FLOAT:
	[attribute setExternalType:@"REAL"];
	[attribute setValueClassName:@"NSNumber"];
	[attribute setValueType:@"f"];
	break;
      case SQLITE_TEXT:
	[attribute setExternalType:@"TEXT"];
	[attribute setValueClassName:@"NSString"];
	break;
      case SQLITE_BLOB:
	[attribute setExternalType:@"BLOB"];
	[attribute setValueClassName:@"NSData"];
	break;
      case SQLITE_NULL:
	NSLog(@"WARNING(%s): got SQLite NULL type at column %i, can't derive "
	      @"type information.",
	      __PRETTY_FUNCTION__, cnt);
	[attribute setExternalType:@"NULL"];
	[attribute setValueClassName:@"NSNull"];
	break;
      default:
	NSLog(@"ERROR(%s): unexpected SQLite type at column %i", 
	      __PRETTY_FUNCTION__, cnt);
	break;
    }
    
    [result addObject:attribute];
    [attribute release];
  }

  [usedNames release];
  usedNames = nil;
  
  return [result autorelease];
}

- (BOOL)isColumnNullInCurrentRow:(int)_column {
  /* 
     Note: NULL in SQLite is represented as empty strings ..., don't know
           what to do about that?
	   At least Sybase 10 doesn't support empty strings strings as well
	   and converts them to a single space. So maybe it is reasonable to
	   map empty strings to NSNull?
	   
	   Or is this column-type SQLITE_NULL? If so, thats rather weird,
	   since the type query does not take a row.
  */
  return NO;
}

- (NSMutableDictionary *)primaryFetchAttributes:(NSArray *)_attributes
  withZone:(NSZone *)_zone
{
  /*
    Note: we expect that the attributes match the generated SQL. This is
          because auto-generated SQL can contain SQL table prefixes (like
	  alias.column-name which cannot be detected using the attributes
	  schema)
  */
  // TODO: add a primaryFetchAttributesX method?
  NSMutableDictionary *row = nil;
  NSException *error;
  unsigned attrCount = [_attributes count];
  unsigned cnt;
  
  if (self->statement == NULL) {
    NSLog(@"ERROR: no fetch in progress?");
    [self cancelFetch];
    return nil;
  }
  
  if (!self->hasPendingRow && !self->isDone) {
    if ((error = [self _makeSQLiteStep]) != nil) {
      [self cancelFetch];
      [error raise]; // raise error, TODO: make exception-less method
      return nil;
    }
  }
  if (self->isDone) { /* step was fine, but we are at the end */
    [self cancelFetch];
    return nil;
  }
  
  self->hasPendingRow = NO; /* consume the row */
  
  /* build row */
  
  row = [NSMutableDictionary dictionaryWithCapacity:attrCount];

  for (cnt = 0; cnt < attrCount; cnt++) {
    EOAttribute *attribute;
    NSString    *attrName;
    id          value      = nil;
    
    attribute = [_attributes objectAtIndex:cnt];
    attrName  = [attribute name];

    if ([self isColumnNullInCurrentRow:cnt]) {
      value = [null retain];
    }
    else {
      Class valueClass;
      
      valueClass = NSClassFromString([attribute valueClassName]);
      if (valueClass == Nil) {
        NSLog(@"ERROR(%s): %@: got no value class for column:\n"
              @"  attribute=%@\n  type=%@",
              __PRETTY_FUNCTION__, self,
              attrName, [attribute externalType]);
        value = null;
	continue;
      }
      
      switch (sqlite3_column_type(self->statement, cnt)) {
      case SQLITE_INTEGER:
	value = [[valueClass alloc] 
		  initWithSQLiteInt:sqlite3_column_int(self->statement, cnt)];
	break;
      case SQLITE_FLOAT:
	value = [[valueClass alloc] 
		  initWithSQLiteDouble:
		    sqlite3_column_double(self->statement, cnt)];
	break;
      case SQLITE_TEXT:
	value = [[valueClass alloc] 
		  initWithSQLiteText:
		    sqlite3_column_text(self->statement, cnt)];
	break;
      case SQLITE_BLOB:
	value = [[valueClass alloc] 
		  initWithSQLiteData:
		    sqlite3_column_blob(self->statement, cnt)
		  length:sqlite3_column_bytes(self->statement, cnt)];
	break;
      case SQLITE_NULL:
	value = [null retain];
	break;
      default:
	NSLog(@"ERROR(%s): unexpected SQLite type at column %i", 
	      __PRETTY_FUNCTION__, cnt);
	continue;
      }
      
      if (value == nil) {
        NSLog(@"ERROR(%s): %@: got no value for column:\n"
              @"  attribute=%@\n  valueClass=%@\n  type=%@",
              __PRETTY_FUNCTION__, self,
              attrName, NSStringFromClass(valueClass), 
	      [attribute externalType]);
	continue;
      }
    }
    
    if (value != nil) {
      [row setObject:value forKey:attrName];
      [value release];
    }
  }
  
  return row;
}

/* sending SQL to server */

- (NSException *)evaluateExpressionX:(NSString *)_expression {
  NSMutableString *sql;
  NSException *error;
  BOOL       result;
  const char *s;
  const char *tails = NULL;
  int  rc;

  *(&result) = YES;
  
  if (_expression == nil) {
    [NSException raise:@"InvalidArgumentException"
		 format:@"parameter for evaluateExpression: "
                        @"must not be null (channel=%@)", self];
  }
  
  sql = [[_expression mutableCopy] autorelease];
  [sql appendString:@";"];

  /* ask delegate */
  
  if (delegateRespondsTo.willEvaluateExpression) {
    EODelegateResponse response;
    
    response = [delegate adaptorChannel:self willEvaluateExpression:sql];
    
    if (response == EODelegateRejects) {
      return [NSException exceptionWithName:@"EODelegateRejects"
			  reason:@"delegate rejected insert"
			  userInfo:nil];
    }
    if (response == EODelegateOverrides)
      return nil;
  }

  /* check some preconditions */
  
  if (![self isOpen]) {
    return [SQLiteException exceptionWithName:@"ChannelNotOpenException"
			    reason:@"SQLite connection is not open"
			    userInfo:nil];
  }
  if (self->statement != NULL) {
    return [SQLiteException exceptionWithName:@"CommandInProgressException"
			    reason:@"an evaluation is in progress"
			    userInfo:nil];
    return NO;
  }
  
  if ([self isFetchInProgress]) {
    NSLog(@"WARNING: a fetch is still in progress: %@", self);
    [self cancelFetch];
  }
  
  if (isDebuggingEnabled)
    NSLog(@"%@ SQL: %@", self, sql);

  /* reset environment */
  
  self->isFetchInProgress = NO;
  self->isDone        = NO;
  self->hasPendingRow = NO;
  
  s  = [sql UTF8String];
  rc = sqlite3_prepare(self->_connection, s, strlen(s), 
		       (void *)&(self->statement), &tails);
  
  if (rc != SQLITE_OK) {
    NSString *r;
    
    [self cancelFetch];
    // TODO: improve error

    r = [NSString stringWithFormat:@"could not parse SQL statement: %s",
		  sqlite3_errmsg(self->_connection)];
    return [SQLiteException exceptionWithName:@"ExecutionFailed" 
			    reason:r userInfo:nil];
  }
  
  /* step to first row */
  
  if ([sql hasPrefix:@"SELECT"] || [sql hasPrefix:@"select"]) {
    self->isFetchInProgress = YES;
    NSAssert(self->statement, @"missing statement");
  }
  else {
    if ((error = [self _makeSQLiteStep]) != nil) {
      [self cancelFetch];
      return error;
    }
  
    self->isFetchInProgress = self->hasPendingRow;
    if (!self->isFetchInProgress) {
      sqlite3_finalize(self->statement); 
      self->statement = NULL;
    }
  }
  
  /* only on empty results? */
  if (delegateRespondsTo.didEvaluateExpression)
    [delegate adaptorChannel:self didEvaluateExpression:sql];
  
  return nil /* everything is OK */;
}
- (BOOL)evaluateExpression:(NSString *)_sql {
  NSException *e;
  NSString *n;
  
  if ((e = [self evaluateExpressionX:_sql]) == nil)
    return YES;
  
  /* for compatibility with non-X methods, translate some errors to a bool */
  n = [e name];
  if ([n isEqualToString:@"EOEvaluationError"])
    return NO;
  if ([n isEqualToString:@"EODelegateRejects"])
    return NO;
  
  [e raise];
  return NO;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<%@[0x%p] connection=0x%p",
                     NSStringFromClass([self class]),
                     self, self->_connection];
  [ms appendString:@">"];
  return ms;
}

@end /* SQLiteChannel */

@implementation SQLiteChannel(PrimaryKeyGeneration)

- (NSDictionary *)primaryKeyForNewRowWithEntity:(EOEntity *)_entity {
  NSArray       *pkeys;
  SQLiteAdaptor *adaptor;
  NSString      *seqName, *seq;
  NSDictionary  *pkey;

  pkeys   = [_entity primaryKeyAttributeNames];
  adaptor = (id)[[self adaptorContext] adaptor];
  seqName = [adaptor primaryKeySequenceName];
  pkey    = nil;
  seq     = nil;
  
  seq = ([seqName length] > 0)
    ? [NSString stringWithFormat:@"SELECT NEXTVAL ('%@')", seqName]
    : (id)[adaptor newKeyExpression];
  
  NS_DURING {
    if ([self evaluateExpression:seq]) {
      id key = nil;
      
      NSLog(@"ERROR: new key creation is not implemented in SQLite yet!");
      if ([self isFetchInProgress]) {
	NSLog(@"Primary key eval returned results ..");
      }
      // TODO
      NSLog(@"%s: PKEY GEN NOT IMPLEMENTED!", __PRETTY_FUNCTION__);
      [self cancelFetch];

      if (key != nil) {
        pkey = [NSDictionary dictionaryWithObject:key
                             forKey:[pkeys objectAtIndex:0]];
      }
    }
  }
  NS_HANDLER {
    pkey = nil;
  }
  NS_ENDHANDLER;

  return pkey;
}

@end /* SQLiteChannel(PrimaryKeyGeneration) */

void __link_SQLiteChannel() {
  // used to force linking of object file
  __link_SQLiteChannel();
}
