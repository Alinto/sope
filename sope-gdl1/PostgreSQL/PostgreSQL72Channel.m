/* 
   PostgreSQL72Channel.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess
   Copyright (C) 2000-2008 SKYRIX Software AG and Helge Hess

   Author: Helge Hess (helge.hess@opengroupware.org)

   This file is part of the PostgreSQL72 Adaptor Library

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
#import "common.h"
#import "PostgreSQL72Channel.h"
#import "PostgreSQL72Adaptor.h"
#import "PostgreSQL72Exception.h"
#import "NSString+PostgreSQL72.h"
#import "PostgreSQL72Values.h"
#import "EOAttribute+PostgreSQL72.h"
#include "PGConnection.h"

#include "pgconfig.h"

#ifndef MIN
#  define MIN(x, y) ((x > y) ? y : x)
#endif

// TODO: what does this do?
#define MAX_CHAR_BUF 16384

@interface PostgreSQL72Channel(Privates)
- (void)_resetEvaluationState;
@end

@implementation PostgreSQL72Channel

#if NG_SET_CLIENT_ENCODING
static NSString *PGClientEncoding = @"UTF8";
#endif
static int      MaxOpenConnectionCount = -1;
static BOOL     debugOn     = NO;
static NSNull   *null       = nil;
static NSNumber *yesObj     = nil;
static Class    StringClass = Nil;
static Class    MDictClass  = Nil;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  if (null   == nil) null   = [[NSNull null] retain];
  if (yesObj == nil) yesObj = [[NSNumber numberWithBool:YES] retain];
  
  StringClass = [NSString            class];
  MDictClass  = [NSMutableDictionary class];
  
  MaxOpenConnectionCount = [ud integerForKey:@"PGMaxOpenConnectionCount"];
  if (MaxOpenConnectionCount < 2)
    MaxOpenConnectionCount = 50;
  
  debugOn = [ud boolForKey:@"PGDebugEnabled"];
}

- (id)initWithAdaptorContext:(EOAdaptorContext*)_adaptorContext {
  if ((self = [super initWithAdaptorContext:_adaptorContext])) {
    [self setDebugEnabled:debugOn];
    
    self->_attributesForTableName = [[MDictClass alloc] initWithCapacity:16];
    self->_primaryKeysNamesForTableName =
      [[MDictClass alloc] initWithCapacity:16];
  }
  return self;
}

/* collection */

- (void)dealloc {
  [self _resetEvaluationState];
  
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

/* debugging */

- (void)setDebugEnabled:(BOOL)_flag {
  self->isDebuggingEnabled = _flag;
}
- (BOOL)isDebugEnabled {
  return self->isDebuggingEnabled;
}

- (void)receivedMessage:(NSString *)_message {
  NSLog(@"%@: message: %@", self, _message);
}

static void _pgMessageProcessor(void *_channel, const char *_msg)
     __attribute__((unused));

static void _pgMessageProcessor(void *_channel, const char *_msg) {
  [(id)_channel receivedMessage:
       _msg ? [StringClass stringWithUTF8String:_msg] : nil];
}

/* cleanup */

- (void)_resetResults {
  [self->resultSet clear];
  [self->resultSet release];
  self->resultSet = nil;
}

/* open/close */

static int openConnectionCount = 0;

- (BOOL)isOpen {
  return [self->connection isValid];
}

- (BOOL)openChannel {
  PostgreSQL72Adaptor *adaptor;

  if ([self->connection isValid]) {
    NSLog(@"%s: Connection already open !!!", __PRETTY_FUNCTION__);
    return NO;
  }
  
  adaptor = (PostgreSQL72Adaptor *)[adaptorContext adaptor];

  if (![super openChannel])
    return NO;

#if HEAVY_DEBUG
  NSLog(@"+++++++++ %s: openConnectionCount %d", __PRETTY_FUNCTION__,
        openConnectionCount);
#endif
    
  if (openConnectionCount > MaxOpenConnectionCount) {
    [PostgreSQL72CouldNotOpenChannelException raise:@"NoMoreConnections"
                                              format:
                              @"cannot open a additional connection !"];
    return NO;
  }
  
  self->connection =
    [[PGConnection alloc] initWithHostName:[adaptor serverName]
			  port:[(id)[adaptor port] stringValue]
			  options:[adaptor options]
			  tty:[adaptor tty] database:[adaptor databaseName]
			  login:[adaptor loginName]
			  password:[adaptor loginPassword]];
  
  if (![self->connection isValid]) {
    // could not login ..
    NSLog(@"WARNING: could not open pgsql channel to %@@%@ host %@:%@",
	  [adaptor loginName],
          [adaptor databaseName], [adaptor serverName], [adaptor port]);
    return NO;
  }

  /* PQstatus */
  if (![self->connection isConnectionOK]) {
    NSLog(@"could not open channel to %@@%@",
          [adaptor databaseName], [adaptor serverName]);
    [self->connection finish];
    [self->connection release];
    self->connection = nil;
    return NO;
  }
  
  /* set message callback */
  [self->connection setNoticeProcessor:_pgMessageProcessor context:self];
  
  /* set client encoding */
#if NG_SET_CLIENT_ENCODING
  if (![self->connection setClientEncoding:PGClientEncoding]) {
    NSLog(@"WARNING: could not set client encoding to: '%s'", 
	  PGClientEncoding);
  }
#endif
  
  /* log */
  
  if (isDebuggingEnabled)
    NSLog(@"PostgreSQL72 connection established: %@", self->connection);

#if HEAVY_DEBUG
  NSLog(@"---------- %s: %@ opens channel count[%d]", __PRETTY_FUNCTION__,
        self, openConnectionCount);
#endif
  
  openConnectionCount++;

  if (isDebuggingEnabled) {
    NSLog(@"PostgreSQL72 channel 0x%p opened (connection=%@)",
          self, self->connection);
  }
  return YES;
}

- (void)primaryCloseChannel {
  self->tupleCount = 0;
  self->fieldCount = 0;
  self->containsBinaryData = NO;
    
  if (self->fieldInfo) {
    free(self->fieldInfo);
    self->fieldInfo = NULL;
  }

  [self _resetResults];
  
  [self->cmdStatus release]; self->cmdStatus = nil;
  [self->cmdTuples release]; self->cmdTuples = nil;
  
  if (self->connection) {
    [self->connection finish];
#if HEAVY_DEBUG
    NSLog(@"---------- %s: %@ close channel count[%d]", __PRETTY_FUNCTION__,
          self, openConnectionCount);
#endif
    openConnectionCount--;
    
    if (isDebuggingEnabled) {
      fprintf(stderr, 
	      "PostgreSQL72 connection dropped 0x%p (channel=0x%p)\n",
              self->connection, self);
    }
    [self->connection release];
    self->connection = nil;
  }
}

- (void)closeChannel {
  [super closeChannel];
  [self primaryCloseChannel];
}

/* fetching rows */

- (void)cancelFetch {
  if (![self isOpen]) {
    [PostgreSQL72Exception raise:@"ChannelNotOpenException"
                         format:@"No fetch in progress, connection is not open"
                           @" (channel=%@)", self];
  }

#if HEAVY_DEBUG
  NSLog(@"canceling fetch (%i tuples remaining).",
        (self->tupleCount - self->currentTuple));
#endif
  
  self->tupleCount   = 0;
  self->currentTuple = 0;
  self->fieldCount   = 0;
  self->containsBinaryData = NO;
    
  if (self->fieldInfo) {
    free(self->fieldInfo);
    self->fieldInfo = NULL;
  }
  [self _resetResults];
  
  [self->cmdStatus release]; self->cmdStatus = nil;
  [self->cmdTuples release]; self->cmdTuples = nil;
  
  /* new caches which require a constant _attributes argument */
  if (self->fieldIndices) free(self->fieldIndices); self->fieldIndices = NULL;
  if (self->fieldKeys)    free(self->fieldKeys);    self->fieldKeys    = NULL;
  if (self->fieldValues)  free(self->fieldValues);  self->fieldValues  = NULL;
  
  [super cancelFetch];
}

- (NSArray *)describeResults:(BOOL)_beautifyNames {
  int                 cnt;
  NSMutableArray      *result;
  NSMutableDictionary *usedNames;
  
  if (![self isFetchInProgress]) {
    [PostgreSQL72Exception raise:@"NoFetchInProgress"
                         format:@"No fetch in progress (channel=%@)", self];
  }
  
  result    = [[NSMutableArray alloc] initWithCapacity:self->fieldCount];
  usedNames = [[MDictClass     alloc] initWithCapacity:self->fieldCount];
  
  for (cnt = 0; cnt < self->fieldCount; cnt++) {
    EOAttribute *attribute  = nil;
    NSString    *columnName;
    NSString    *attrName;
    
    columnName = 
      [[StringClass alloc] initWithUTF8String:self->fieldInfo[cnt].name];

    attrName   = _beautifyNames
      ? [columnName _pgModelMakeInstanceVarName]
      : columnName;
    
    if ([[usedNames objectForKey:attrName] boolValue]) {
      // TODO: move name generation code to different method!
      int      cnt2 = 0;
      char     buf[64];
      NSString *newAttrName = nil;
      
      for (cnt2 = 2; cnt2 < 100; cnt2++) {
        NSString *s;
        
        sprintf(buf, "%i", cnt2);
        
        s = [[StringClass alloc] initWithUTF8String:buf];
        newAttrName = [attrName stringByAppendingString:s];
        [s release]; s= nil;
        
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
    
    //NSLog(@"column: %@", columnName);
    
    [attribute loadValueClassAndTypeUsingPostgreSQLType:
                 self->fieldInfo[cnt].type
               size:self->fieldInfo[cnt].size
               modification:self->fieldInfo[cnt].modification
               binary:self->containsBinaryData];
    
    [result addObject:attribute];
    
    [columnName release]; columnName = nil;
    [attribute  release]; attribute = nil;
  }

  [usedNames release];
  usedNames = nil;
  
  return [result autorelease];
}

- (void)_fillFieldNamesForAttributes:(NSArray *)_attributes 
  count:(unsigned)attrCount
{
  // Note: this optimization requires that the "_attributes" array does
  //       note change between invocations!
  // TODO: should add a sanity check for that!
  NSMutableArray *fieldNames;
  unsigned       nFields, i;
  unsigned       cnt;
  
  if (self->fieldIndices)
    return;
  
  self->fieldIndices = calloc(attrCount + 2, sizeof(int));
  
  // TODO: we could probably cache the field-name array for much more speed !
  fieldNames = [[NSMutableArray alloc] initWithCapacity:32];
  nFields    = [self->resultSet fieldCount];
  for (i = 0; i < nFields; i++)
    [fieldNames addObject:[self->resultSet fieldNameAtIndex:i]];
  
  for (cnt = 0; cnt < attrCount; cnt++) {
    EOAttribute *attribute;
    
    attribute = [_attributes objectAtIndex:cnt];
#if GDL_USE_PQFNUMBER_INDEX
    self->fieldIndices[cnt] = 
      [self->resultSet indexOfFieldNamed:[attribute columnName]];
#else
    self->fieldIndices[cnt] = 
      [fieldNames indexOfObject:[attribute columnName]];
#endif
    
    if (self->fieldIndices[cnt] == NSNotFound) {
      [PostgreSQL72Exception raiseWithFormat:
                               @"attribute %@ not covered by query",
                             attribute];
    }
    [fieldNames replaceObjectAtIndex:self->fieldIndices[cnt] withObject:null];
  }
  [fieldNames release]; fieldNames = nil;
}

- (NSMutableDictionary *)primaryFetchAttributes:(NSArray *)_attributes
  withZone:(NSZone *)_zone
{
  NSMutableDictionary *row;
  unsigned     attrCount;
  int          *indices;
  unsigned     cnt, fieldDictCount;
  
  if (self->currentTuple == self->tupleCount) {
    if (self->resultSet != nil) [self cancelFetch];
    return nil;
  }
  
  attrCount = [_attributes count];
  [self _fillFieldNamesForAttributes:_attributes count:attrCount];
  indices = self->fieldIndices;
  
  if (self->fieldKeys == NULL)
    self->fieldKeys = calloc(attrCount + 1, sizeof(NSString *));
  if (self->fieldValues == NULL)
    self->fieldValues = calloc(attrCount + 1, sizeof(id));
  fieldDictCount = 0;
  
  for (cnt = 0; cnt < attrCount; cnt++) {
    EOAttribute *attribute;
    NSString    *attrName;
    id          value      = nil;
    Class       valueClass = Nil;
    const char  *pvalue;
    int         vallen;

    attribute = [_attributes objectAtIndex:cnt];
    attrName  = [attribute name];

    if ([self->resultSet isNullTuple:self->currentTuple atIndex:indices[cnt]]){
      self->fieldKeys[fieldDictCount]   = attrName;
      self->fieldValues[fieldDictCount] = null;
      fieldDictCount++;
      continue;
    }
    
    valueClass = NSClassFromString([attribute valueClassName]);
    if (valueClass == Nil) {
      NSLog(@"ERROR(%s): %@: got no value class for column:\n"
            @"  attribute=%@\n  type=%@",
            __PRETTY_FUNCTION__, self,
            attrName, [attribute externalType]);
      continue;
    }
      
    pvalue = [self->resultSet rawValueOfTuple:self->currentTuple 
		              atIndex:indices[cnt]];
    vallen = [self->resultSet lengthOfTuple:self->currentTuple 
		              atIndex:indices[cnt]];
    
    if (self->containsBinaryData) {
        // pvalue is stored in internal representation

        value = [valueClass valueFromBytes:pvalue length:vallen
                            postgreSQLType:[attribute externalType]
                            attribute:attribute
                            adaptorChannel:self];
    }
    else {
        // pvalue is ascii string
        
        value = [valueClass valueFromCString:pvalue length:vallen
                            postgreSQLType:[attribute externalType]
                            attribute:attribute
                            adaptorChannel:self];
    }
    if (value == nil) {
      NSLog(@"ERROR(%s): %@: got no value for column:\n"
            @"  attribute=%@\n  valueClass=%@\n  type=%@",
            __PRETTY_FUNCTION__, self,
            attrName, NSStringFromClass(valueClass), 
            [attribute externalType]);
      continue;
    }

    /* add to dictionary */
    self->fieldKeys[fieldDictCount]   = attrName;
    self->fieldValues[fieldDictCount] = value;
    fieldDictCount++;
  }
  
  self->currentTuple++;

  // TODO: we would need to have a copy on write dict here, ideally with
  //       the keys being reused for each fetch-loop
  row = [[MDictClass alloc] initWithObjects:self->fieldValues
                            forKeys:self->fieldKeys
                            count:fieldDictCount];
  return [row autorelease];
}

/* sending sql to server */

- (void)_resetEvaluationState {
  self->isFetchInProgress = NO;
  self->tupleCount   = 0;
  self->fieldCount   = 0;
  self->currentTuple = 0;
  self->containsBinaryData = NO;
  if (self->fieldInfo) {
    free(self->fieldInfo);
    self->fieldInfo = NULL;
  }
  
  /* new caches which require a constant _attributes argument */
  if (self->fieldIndices) free(self->fieldIndices); self->fieldIndices = NULL;
  if (self->fieldKeys)    free(self->fieldKeys);    self->fieldKeys    = NULL;
  if (self->fieldValues)  free(self->fieldValues);  self->fieldValues  = NULL;
}

- (NSException *)_processEvaluationTuplesOKForExpression:(NSString *)_sql {
  int i;
  
  self->isFetchInProgress = YES;
  
  self->tupleCount         = [self->resultSet tupleCount];
  self->fieldCount         = [self->resultSet fieldCount];
  self->containsBinaryData = [self->resultSet containsBinaryTuples];
  
  self->fieldInfo = 
    calloc(self->fieldCount + 1, sizeof(PostgreSQL72FieldInfo));
  for (i = 0; i < self->fieldCount; i++) {
    self->fieldInfo[i].name = PQfname(self->resultSet->results, i);
    self->fieldInfo[i].type = PQftype(self->resultSet->results, i);
    self->fieldInfo[i].size = [self->resultSet fieldSizeAtIndex:i];
    self->fieldInfo[i].modification = [self->resultSet modifierAtIndex:i];
  }
  
  self->cmdStatus = [[self->resultSet commandStatus] copy];
  self->cmdTuples = [[self->resultSet commandTuples] copy];
  
  if (delegateRespondsTo.didEvaluateExpression)
    [delegate adaptorChannel:self didEvaluateExpression:_sql];
  
#if HEAVY_DEBUG
  NSLog(@"tuples %i fields %i status %@",
        self->tupleCount, self->fieldCount, self->cmdStatus);
#endif
  return nil;
}

- (NSException *)_handleBadResponseError {
  NSString *s;

  [self _resetResults];

  s = [NSString stringWithFormat:@"bad pgsql response (channel=%@): %@", 
		self, [self->connection errorMessage]];
  return [PostgreSQL72Exception exceptionWithName:@"PostgreSQL72BadResponse"
				reason:s userInfo:nil];
}
- (NSException *)_handleNonFatalEvaluationError {
  NSString *s;
  
  [self _resetResults];
  
  s = [NSString stringWithFormat:@"pgsql error (channel=%@): %@",
		self, [self->connection errorMessage]];
  return [PostgreSQL72Exception exceptionWithName:@"PostgreSQL72Error"
				reason:s userInfo:nil];
}
- (NSException *)_handleFatalEvaluationError {
  NSString *s;
  
  [self _resetResults];
  
  s = [NSString stringWithFormat:@"fatal pgsql error (channel=%@): %@",
		self, [self->connection errorMessage]];
  return [PostgreSQL72Exception exceptionWithName:@"PostgreSQL72FatalError"
				reason:s userInfo:nil];
}

- (NSException *)evaluateExpressionX:(NSString *)_expression {
  BOOL result;

  *(&result) = YES;

  if (_expression == nil) {
    return [NSException exceptionWithName:NSInvalidArgumentException
			reason:@"parameter for evaluateExpression: "
			@"must not be null"
			userInfo:nil];
  }
  
  *(&_expression) = [[_expression mutableCopy] autorelease];

  if (delegateRespondsTo.willEvaluateExpression) {
    EODelegateResponse response;
    
    response = [delegate adaptorChannel:self
			 willEvaluateExpression:
			   (NSMutableString *)_expression];
    
    if (response == EODelegateRejects) {
      return [NSException exceptionWithName:@"EODelegateRejects"
			  reason:@"delegate rejected insert"
			  userInfo:nil];
    }
    if (response == EODelegateOverrides)
      return nil;
  }
  
  if (![self isOpen]) {
    return [PostgreSQL72Exception exceptionWithName:@"ChannelNotOpenException"
				  reason:
				    @"PostgreSQL72 connection is not open"
				  userInfo:nil];
  }
  if (self->resultSet != nil) {
    return [PostgreSQL72Exception exceptionWithName:
				    @"CommandInProgressException"
				  reason:@"an evaluation is in progress"
				  userInfo:nil];
  }

  if (isDebuggingEnabled)
    NSLog(@"PG0x%p SQL: %@", self, _expression);
  
  [self _resetEvaluationState];
  
  self->resultSet = [[self->connection execute:_expression] retain];
  if (self->resultSet == nil) {
    return [PostgreSQL72Exception exceptionWithName:@"ExecutionFailed"
				  reason:@"the PQexec() failed"
				  userInfo:nil];
  }

  /* process results */
  
  switch (PQresultStatus(self->resultSet->results)) {
    case PGRES_EMPTY_QUERY:
    case PGRES_COMMAND_OK:
      [self _resetResults];
      
      if (delegateRespondsTo.didEvaluateExpression)
        [delegate adaptorChannel:self didEvaluateExpression:_expression];
      return nil;
      
    case PGRES_TUPLES_OK:
      return [self _processEvaluationTuplesOKForExpression:_expression];
      
    case PGRES_COPY_OUT:
    case PGRES_COPY_IN:
      [self _resetResults];
      return [PostgreSQL72Exception exceptionWithName:@"UnsupportedOperation"
				    reason:@"copy(out|in) not supported"
				    userInfo:nil];
      
    case PGRES_BAD_RESPONSE:
      return [self _handleBadResponseError];
    case PGRES_NONFATAL_ERROR:
      return [self _handleNonFatalEvaluationError];
    case PGRES_FATAL_ERROR:
      return [self _handleFatalEvaluationError];
      
    default:
      return [NSException exceptionWithName:@"PostgreSQLEvalFailed"
			  reason:@"generic reason"
			  userInfo:nil];
  }
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

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  if (self->connection)
    [ms appendFormat:@" connection=%@", self->connection];
  else
    [ms appendString:@" not-connected"];
  [ms appendString:@">"];
  return ms;
}

@end /* PostgreSQL72Channel */

@implementation PostgreSQL72Channel(PrimaryKeyGeneration)

- (NSDictionary *)primaryKeyForNewRowWithEntity:(EOEntity *)_entity {
  NSArray             *pkeys;
  PostgreSQL72Adaptor *adaptor;
  NSString            *seqName, *seq;
  NSDictionary        *pkey;

  pkeys   = [_entity primaryKeyAttributeNames];
  adaptor = (id)[[self adaptorContext] adaptor];
  seqName = [adaptor primaryKeySequenceName];
  pkey    = nil;
  seq     = nil;

  seq = [seqName length] > 0
    ? [StringClass stringWithFormat:@"SELECT NEXTVAL ('%@')", seqName]
    : (id)[adaptor newKeyExpression];
  
  // TODO: since we use evaluateExpressionX, we should not see exceptions?
  NS_DURING {
    if ([self evaluateExpressionX:seq] == nil) {
      id key = nil;

      if (self->tupleCount > 0) {
	if ([self->resultSet isNullTuple:0 atIndex:0])
          key = [null retain];
        else {
          const char *pvalue;
          int         vallen;
          
          if (self->containsBinaryData) {
#if COCOA_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
            NSLog(@"%s: binary data not implemented!", __PRETTY_FUNCTION__);
#else
            [self notImplemented:_cmd];
#endif
          }
          
	  pvalue = [self->resultSet rawValueOfTuple:0 atIndex:0];
	  vallen = [self->resultSet lengthOfTuple:0   atIndex:0];
	  
          if (pvalue)
            key = [[NSNumber alloc] initWithInt:atoi(pvalue)];
        }
      }
      [self cancelFetch];

      if (key) {
        pkey = [NSDictionary dictionaryWithObject:key
                             forKey:[pkeys objectAtIndex:0]];
	[key release]; key = nil;
      }
    }
  }
  NS_HANDLER
    pkey = nil;
  NS_ENDHANDLER;

  return pkey;
}

@end /* PostgreSQL72Channel(PrimaryKeyGeneration) */

void __link_PostgreSQL72Channel() {
  // used to force linking of object file
  __link_PostgreSQL72Channel();
}
