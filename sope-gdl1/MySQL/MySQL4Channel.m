/* 
   MySQL4Channel.m

   Copyright (C) 2003-2005 SKYRIX Software AG

   Author: Helge Hess (helge.hess@skyrix.com)

   This file is part of the MySQL4 Adaptor Library

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
#include "MySQL4Channel.h"
#include "MySQL4Adaptor.h"
#include "MySQL4Exception.h"
#include "NSString+MySQL4.h"
#include "MySQL4Values.h"
#include "EOAttribute+MySQL4.h"
#include "common.h"
#include <mysql/mysql.h>

#ifndef MIN
#  define MIN(x, y) ((x > y) ? y : x)
#endif

#define MAX_CHAR_BUF 16384

@implementation MySQL4Channel

static EONull *null = nil;

+ (void)initialize {
  if (null == NULL) null = [[EONull null] retain];
}

- (id)initWithAdaptorContext:(EOAdaptorContext*)_adaptorContext {
  if ((self = [super initWithAdaptorContext:_adaptorContext])) {
    [self setDebugEnabled:[[NSUserDefaults standardUserDefaults]
                                           boolForKey:@"MySQL4DebugEnabled"]];
    
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
                     integerForKey:@"MySQL4MaxOpenConnectionCount"];
  if (MaxOpenConnectionCount == 0)
    MaxOpenConnectionCount = 150;
  return MaxOpenConnectionCount;
}

- (BOOL)openChannel {
  const char *cDBName;
  MySQL4Adaptor *adaptor;
  NSString *host, *socket;
  void *rc;
  
  if (self->_connection != NULL) {
    NSLog(@"%s: Connection already open !!!", __PRETTY_FUNCTION__);
    return NO;
  }
  
  adaptor = (MySQL4Adaptor *)[adaptorContext adaptor];
  
  if (![super openChannel])
    return NO;
  
  if (openConnectionCount > [self maxOpenConnectionCount]) {
    [MySQL4CouldNotOpenChannelException 
	raise:@"NoMoreConnections"
	format:@"cannot open a additional connection !"];
    return NO;
  }

  cDBName = [[adaptor databaseName] UTF8String];
  
  if ((self->_connection = mysql_init(NULL)) == NULL) {
    NSLog(@"ERROR(%s): could not allocate MySQL4 connection!");
    return NO;
  }
  
  // TODO: could change options using mysql_options()
  
  host = [adaptor serverName];
  if ([host hasPrefix:@"/"]) { /* treat hostname as Unix socket path */
    socket = host;
    host   = nil;
  }
  else
    socket = nil;
  
  rc = mysql_real_connect(self->_connection, 
			  [host UTF8String],
			  [[adaptor loginName]     UTF8String],
			  [[adaptor loginPassword] UTF8String],
			  cDBName,
			  [[adaptor port] intValue],
			  [socket cString],
			  0);
  if (rc == NULL) {
    NSLog(@"ERROR: could not open MySQL4 connection to database '%@': %s",
          [adaptor databaseName], mysql_error(self->_connection));
    mysql_close(self->_connection); 
    self->_connection = NULL;
    return NO;
  }
  
  if (mysql_query(self->_connection, "SET CHARACTER SET utf8") != 0) {
    NSLog(@"WARNING(%s): could not put MySQL4 connection into UTF-8 mode: %s",
	  __PRETTY_FUNCTION__, mysql_error(self->_connection));
#if 0
    mysql_close(self->_connection); 
    self->_connection = NULL;
    return NO;
#endif
  }
  
  if (isDebuggingEnabled)
    NSLog(@"MySQL4 connection established 0x%p", self->_connection);

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
    NSLog(@"MySQL4 channel 0x%p opened (connection=0x%p,%s)",
          self, self->_connection, cDBName);
  }
  return YES;
}

- (void)primaryCloseChannel {
  if ([self isFetchInProgress])
    [self cancelFetch];
  
  if (self->_connection != NULL) {
    mysql_close(self->_connection);
#if 0
    NSLog(@"---------- %s: %@ close channel count[%d]", __PRETTY_FUNCTION__,
          self, openConnectionCount);
#endif
    openConnectionCount--;
    
    if (isDebuggingEnabled) {
      fprintf(stderr, 
	      "MySQL4 connection dropped 0x%p (channel=0x%p)\n",
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

- (void)cancelFetch {
  self->fields = NULL; /* apparently we do not need to free those */
  
  if (self->results != NULL) {
    mysql_free_result(self->results);
    self->results = NULL;
  }
  [super cancelFetch];
}

- (MYSQL_FIELD *)_fetchFields {
  if (self->results == NULL)
    return NULL;
  
  if (self->fields != NULL)
    return self->fields;
  
  self->fields     = mysql_fetch_fields(self->results);
  self->fieldCount = mysql_num_fields(self->results);
  return self->fields;
}

- (NSArray *)describeResults:(BOOL)_beautifyNames {
  // TODO: make exception-less method
  MYSQL_FIELD         *mfields;
  int                 cnt;
  NSMutableArray      *result    = nil;
  NSMutableDictionary *usedNames = nil;
  NSNumber            *yesObj;
  
  yesObj = [NSNumber numberWithBool:YES];
  
  if (![self isFetchInProgress]) {
    [MySQL4Exception raise:@"NoFetchInProgress"
		     format:@"No fetch in progress (channel=%@)", self];
    return nil;
  }
  
  if ((mfields = [self _fetchFields]) == NULL) {
    [MySQL4Exception raise:@"NoFieldInfo"
		     format:@"Failed to fetch field info (channel=%@)", self];
    return nil;
  }
  
  result    = [[NSMutableArray      alloc] initWithCapacity:fieldCount];
  usedNames = [[NSMutableDictionary alloc] initWithCapacity:fieldCount];

  for (cnt = 0; cnt < fieldCount; cnt++) {
    EOAttribute *attribute  = nil;
    NSString    *columnName = nil;
    NSString    *attrName   = nil;
    
    columnName = [NSString stringWithUTF8String:mfields[cnt].name];
    attrName   = _beautifyNames
      ? [columnName _mySQL4ModelMakeInstanceVarName] 
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
    
    [attribute setAllowsNull:
		 (mfields[cnt].flags & NOT_NULL_FLAG) ? NO : YES];
    
    /*
      We also know whether a field:
        is primary
        is unique
	is auto-increment
	is zero-fill
	is unsigned
    */
    switch (mfields[cnt].type) {
    case FIELD_TYPE_STRING:
      [attribute setExternalType:@"CHAR"];
      [attribute setValueClassName:@"NSString"];
      // TODO: length etc
      break;
    case FIELD_TYPE_VAR_STRING:
      [attribute setExternalType:@"VARCHAR"];
      [attribute setValueClassName:@"NSString"];
      // TODO: length etc
      break;
      
    case FIELD_TYPE_TINY:
      if ((mfields[cnt].flags & UNSIGNED_FLAG)) {
        [attribute setExternalType:@"TINY UNSIGNED"];
        [attribute setValueClassName:@"NSNumber"];
        [attribute setValueType:@"C"];
      }
      else {
        [attribute setExternalType:@"TINY"];
        [attribute setValueClassName:@"NSNumber"];
        [attribute setValueType:@"c"];
      }
      break;
    case FIELD_TYPE_SHORT:
      if ((mfields[cnt].flags & UNSIGNED_FLAG)) {
        [attribute setExternalType:@"SHORT UNSIGNED"];
        [attribute setValueClassName:@"NSNumber"];
        [attribute setValueType:@"S"];
      }
      else {
        [attribute setExternalType:@"SHORT"];
        [attribute setValueClassName:@"NSNumber"];
        [attribute setValueType:@"s"];
      }
      break;
    case FIELD_TYPE_LONG:
      if ((mfields[cnt].flags & UNSIGNED_FLAG)) {
        [attribute setExternalType:@"LONG UNSIGNED"];
        [attribute setValueClassName:@"NSNumber"];
        [attribute setValueType:@"L"];
      }
      else {
        [attribute setExternalType:@"LONG"];
        [attribute setValueClassName:@"NSNumber"];
        [attribute setValueType:@"l"];
      }
      break;
    case FIELD_TYPE_INT24:
      if ((mfields[cnt].flags & UNSIGNED_FLAG)) {
        [attribute setExternalType:@"INT UNSIGNED"];
        [attribute setValueClassName:@"NSNumber"];
        [attribute setValueType:@"I"];
      }
      else {
        [attribute setExternalType:@"INT"];
        [attribute setValueClassName:@"NSNumber"];
        [attribute setValueType:@"i"]; // bumped
      }
      break;
    case FIELD_TYPE_LONGLONG:
      if ((mfields[cnt].flags & UNSIGNED_FLAG)) {
        [attribute setExternalType:@"LONGLONG UNSIGNED"];
        [attribute setValueClassName:@"NSNumber"];
        [attribute setValueType:@"Q"];
      }
      else {
        [attribute setExternalType:@"LONGLONG"];
        [attribute setValueClassName:@"NSNumber"];
        [attribute setValueType:@"q"];
      }
      break;
    case FIELD_TYPE_DECIMAL:
      [attribute setExternalType:@"DECIMAL"];
      [attribute setValueClassName:@"NSNumber"];
      [attribute setValueType:@"f"]; // TODO: need NSDecimalNumber here ...
      break;
    case FIELD_TYPE_FLOAT:
      [attribute setExternalType:@"FLOAT"];
      [attribute setValueClassName:@"NSNumber"];
      [attribute setValueType:@"f"];
      break;
    case FIELD_TYPE_DOUBLE:
      [attribute setExternalType:@"DOUBLE"];
      [attribute setValueClassName:@"NSNumber"];
      [attribute setValueType:@"d"];
      break;

    case FIELD_TYPE_TIMESTAMP:
      [attribute setExternalType:@"TIMESTAMP"];
      [attribute setValueClassName:@"NSCalendarDate"];
      break;
    case FIELD_TYPE_DATE:
      [attribute setExternalType:@"DATE"];
      [attribute setValueClassName:@"NSCalendarDate"];
      break;
    case FIELD_TYPE_DATETIME:
      [attribute setExternalType:@"DATETIME"];
      [attribute setValueClassName:@"NSCalendarDate"];
      break;
      
    case FIELD_TYPE_BLOB:
    case FIELD_TYPE_TINY_BLOB:
    case FIELD_TYPE_MEDIUM_BLOB:
    case FIELD_TYPE_LONG_BLOB:
      // TODO: length etc
      if (mfields[cnt].flags & BINARY_FLAG) {
	[attribute setExternalType:@"BLOB"];
	[attribute setValueClassName:@"NSData"];
      }
      else {
	[attribute setExternalType:@"TEXT"];
	[attribute setValueClassName:@"NSString"];
      }
      break;
      
    case FIELD_TYPE_NULL: // TODO: whats that?
    case FIELD_TYPE_TIME:
    case FIELD_TYPE_YEAR:
    case FIELD_TYPE_SET:
    case FIELD_TYPE_ENUM:
    default:
	NSLog(@"ERROR(%s): unexpected MySQL4 type at column %i: %@", 
	      __PRETTY_FUNCTION__, cnt, attribute);
	break;
    }
    
    [result addObject:attribute];
    [attribute release];
  }

  [usedNames release];
  usedNames = nil;
  
  return [result autorelease];
}
- (NSArray *)describeResults {
  return [self describeResults:NO];
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
  MYSQL_ROW rawRow;
  NSMutableDictionary *row = nil;
  unsigned attrCount = [_attributes count];
  unsigned cnt;
  unsigned long *lengths;
  
  if (self->results == NULL) {
    NSLog(@"ERROR(%s): no fetch in progress?", __PRETTY_FUNCTION__);
    [self cancelFetch];
    return nil;
  }

  /* raw fetch */
  
  if ((rawRow = mysql_fetch_row(self->results)) == NULL) {
    // TODO: might need to close channel on connect exceptions
    unsigned int merrno;
    
    if ((merrno = mysql_errno(self->_connection)) != 0) {
      const char *error;
      
      error = mysql_error(self->_connection);
      [MySQL4Exception raise:@"FetchFailed" 
		       format:@"%@",[NSString stringWithUTF8String:error]];
      return nil;
    }
    
    /* regular end of result set */
    [self cancelFetch];
    return nil;
  }

  /* ensure field info */
  
  if ([self _fetchFields] == NULL) {
    [self cancelFetch];
    [MySQL4Exception raise:@"FetchFailed" 
		     format:@"could not fetch field info!"];
    return nil;
  }
  
  if ((lengths = mysql_fetch_lengths(self->results)) == NULL) {
    [self cancelFetch];
    [MySQL4Exception raise:@"FetchFailed" 
		     format:@"could not fetch field lengths!"];
    return nil;
  }
  
  /* build row */
  
  row = [NSMutableDictionary dictionaryWithCapacity:attrCount];
  
  for (cnt = 0; cnt < attrCount; cnt++) {
    EOAttribute *attribute;
    NSString    *attrName;
    id          value      = nil;
    MYSQL_FIELD mfield;
    
    attribute = [_attributes objectAtIndex:cnt];
    attrName  = [attribute name];
    mfield    = ((MYSQL_FIELD *)self->fields)[cnt];
    
    if (rawRow[cnt] == NULL) {
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

      value = [[valueClass alloc] initWithMySQL4Field:&mfield
				  value:rawRow[cnt] length:lengths[cnt]];
      
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
  BOOL       result;
  const char *s;
  int  rc;

  *(&result) = YES;
  
  if (_expression == nil) {
    return [NSException exceptionWithName:@"InvalidArgumentException"
                        reason:
                          @"parameter for evaluateExpression: must not be null"
                        userInfo:nil];
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
    return [MySQL4Exception exceptionWithName:@"ChannelNotOpenException"
			    reason:@"MySQL4 connection is not open"
			    userInfo:nil];
  }
  if (self->results != NULL) {
    return [MySQL4Exception exceptionWithName:@"CommandInProgressException"
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
  
  /* start query */
  
  s  = [sql UTF8String];
  if ((rc = mysql_real_query(self->_connection, s, strlen(s))) != 0) {
    // TODO: might need to close channel on connect exceptions
    const char *error;
    
    error = mysql_error(self->_connection);
    if (isDebuggingEnabled)
      NSLog(@"%@   ERROR: %s", self, error);
    
    return [MySQL4Exception exceptionWithName:@"ExecutionFailed" 
                            reason:[NSString stringWithUTF8String:error]
			    userInfo:nil];
  }
  
  /* fetch */
  
  if ((self->results = mysql_use_result(self->_connection)) != NULL) {
    if (isDebuggingEnabled)
      NSLog(@"%@   query has results, entering fetch-mode.", self);
    self->isFetchInProgress = YES;
  }
  else {
    /* error _OR_ statement without result-set */
    unsigned int merrno;

    if ((merrno = mysql_errno(self->_connection)) != 0) {
      const char *error;
      
      error = mysql_error(self->_connection);
      if (isDebuggingEnabled)
        NSLog(@"%@   cannot use result: '%s'", self, error);
      
      return [MySQL4Exception exceptionWithName:@"FetchFailed" 
                              reason:[NSString stringWithUTF8String:error]
                              userInfo:nil];
    }
    
    if (isDebuggingEnabled)
      NSLog(@"%@   query has no results.", self);
  }
  
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

  NSLog(@"ERROR eval '%@': %@", _sql, e);
  
  [e raise];
  return NO;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<%@[0x%p] connection=0x%p",
        NSStringFromClass([self class]), self, self->_connection];
  [ms appendString:@">"];
  return ms;
}

/* PrimaryKeyGeneration */

- (NSDictionary *)primaryKeyForNewRowWithEntity:(EOEntity *)_entity {
  NSException   *error;
  NSArray       *pkeys;
  MySQL4Adaptor *adaptor;
  NSString      *seqName, *seq;
  NSArray       *seqs;
  NSDictionary  *pkey;
  unsigned      i, count;
  id key;
  
  pkeys   = [_entity primaryKeyAttributeNames];
  adaptor = (id)[[self adaptorContext] adaptor];
  seqName = [adaptor primaryKeySequenceName];
  pkey    = nil;
  seq     = nil;
  
  if ([seqName length] > 0) {
    // TODO: if we do this, we also need to make the 'id' configurable ...
    seq = [@"UPDATE " stringByAppendingString:seqName];
    seq = [seq stringByAppendingString:@" SET id=LAST_INSERT_ID(id+1)"];
    seqs = [NSArray arrayWithObjects:
                      seq, @"SELECT_LAST_INSERT_ID()", nil];
  }
  else
    seqs = [[adaptor newKeyExpression] componentsSeparatedByString:@";"];

  if ((count = [seqs count]) == 0) {
    NSLog(@"ERROR(%@): got no primary key expressions %@: %@", 
          self, seqName, _entity);
    return nil;
  }

  for (i = 0; i < count - 1; i++) {
    if ((error = [self evaluateExpressionX:[seqs objectAtIndex:i]]) != nil) {
      NSLog(@"ERROR(%@): could not prepare next pkey value %@: %@", 
            self, [seqs objectAtIndex:i], error);
      return nil;
    }
  }
  
  seq = [seqs lastObject];
  if ((error = [self evaluateExpressionX:seq]) != nil) {
    NSLog(@"ERROR(%@): could not select next pkey value from sequence %@: %@", 
          self, seqName, error);
    return nil;
  }
  
  if (![self isFetchInProgress]) {
    NSLog(@"ERROR(%@): primary key expression returned no result: '%@'",
          self, seq);
    return nil;
  }
  
  // TODO: this is kinda slow
  key  = [self describeResults];
  pkey = [self fetchAttributes:key withZone:NULL];
  
  [self cancelFetch];
  
  if (pkey != nil) {
    pkey = [[pkey allValues] lastObject];
    pkey = [NSDictionary dictionaryWithObject:pkey
                         forKey:[pkeys objectAtIndex:0]];
  }
  
  return pkey;
}

@end /* MySQL4Channel */

void __link_MySQL4Channel() {
  // used to force linking of object file
  __link_MySQL4Channel();
}
