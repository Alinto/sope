/* 
   FBChannel.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge.hess@mdlink.de)

   This file is part of the FB Adaptor Library

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
// $Id: FBChannel.m 1 2004-08-20 10:38:46Z znek $

#include <ctype.h>
#include <string.h>
#if HAVE_STRINGS_H
#include <strings.h>
#endif
#import "common.h"
#include "FBBlobHandle.h"
#include <NGExtensions/NSString+misc.h>

#include <FBCAccess/FBCDigestPassword.h>
#include <GDLAccess/EORecordDictionary.h>
#import <EOControl/EOSortOrdering.h>

//#define BLOB_DEBUG 1

@implementation FrontBaseChannel

static EONull *null = nil;

+ (void)initialize {
  if (null == NULL) null = [[EONull null] retain];
}

#ifdef __MINGW32__
extern __declspec(import) void fbcInitialize(void);
#endif

- (id)initWithAdaptorContext:(EOAdaptorContext*)_adaptorContext {
  static BOOL didInit = NO;
  if (!didInit) {
    didInit = YES;
#ifdef __MINGW32__
    fbcInitialize();
#endif
#ifdef __APPLE__
    fbcInitialize();
#endif
  }
  
  if ((self = [super initWithAdaptorContext:_adaptorContext])) {
    [self setDebugEnabled:[[NSUserDefaults standardUserDefaults]
                                           boolForKey:@"FBDebugEnabled"]];
    sqlLogFile = [[[NSUserDefaults standardUserDefaults]
                                   stringForKey:@"FBLogFile"]
                                   copyWithZone:[self zone]];
    self->_primaryKeysNamesForTableName = [[NSMutableDictionary alloc] init];
    self->_attributesForTableName       = [[NSMutableDictionary alloc] init];
  }
  return self;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  if ([self isOpen]) {
    [self cancelFetch];
    [self closeChannel];
  }
  RELEASE(self->sqlLogFile);
  RELEASE(self->_primaryKeysNamesForTableName);
  RELEASE(self->_attributesForTableName);
  [super dealloc];
}
#endif

// NSCopying methods 

- (id)copyWithZone:(NSZone *)zone {
  return RETAIN(self);// copy is needed during creation of NSNotification object
}

// debugging

- (void)setDebugEnabled:(BOOL)_flag {
  self->isDebuggingEnabled = _flag;
}
- (BOOL)isDebugEnabled {
  return self->isDebuggingEnabled;
}

// open/close

- (BOOL)isOpen {
  return self->fbdc != NULL ? YES : NO;
}

- (BOOL)openChannel {
  FrontBase2Adaptor *adaptor;
  FBCMetaData *md;
  BOOL        result = NO;
  NSString    *txIsoLevel;
  NSString    *locking;
  NSString    *expr;
  const char  *password;
  char        pwdDigest[17];

  //  [self setDebugEnabled:YES];

  adaptor = (FrontBase2Adaptor *)[[self adaptorContext] adaptor];
  
  if (![super openChannel])
    return NO;

  /* digest the database password */

  if ((password = [[adaptor databasePassword] cString])) {
    if (fbcDigestPassword("_SYSTEM", (char *)password, pwdDigest) == NULL) {
      NSLog(@"%@: Couldn't digest password !", self);
      pwdDigest[0] = '\0';
    }
  }
  else
    pwdDigest[0] = '\0';
  
  /* connect to database */

  if (isDebuggingEnabled)
    NSLog(@"Open fb-channel[%p]: db=%@, server=%@", self,
          [adaptor databaseName], [adaptor serverName]);
  
  self->fbdc =
    fbcdcConnectToDatabase((char *)[[adaptor databaseName]     cString],
                           (char *)[[adaptor serverName]       cString],
                           (char *)pwdDigest);
  if (self->fbdc == NULL) {
    if (isDebuggingEnabled) {
      NSLog(@"FrontBase channel 0x%p (db=%@, server=%@, digest=%s) "
            @"could not be opened: %s ..", self,
            [adaptor databaseName], [adaptor serverName],
            pwdDigest /* ? "yes" : "no"*/,
            fbcdcClassErrorMessage());
    }
    return NO;
  }
  
  fbcdcSetRollbackAfterError(self->fbdc, True);

  /* digest the user password */
#if 0
  if ((password = [[adaptor loginPassword] cString])) {
    if (fbcDigestPassword((char *)[[adaptor loginName] cString],
                          (char *)password, pwdDigest) == NULL) {
      NSLog(@"%@: Couldn't digest password !", self);
      pwdDigest[0] = '\0';
    }
  }
  else
    pwdDigest[0] = '\0';
#else
  if (!(password = [[adaptor loginPassword] cString]))
    password = "\0";
#endif
  
  /* create session */

  md = fbcdcCreateSession(self->fbdc,
                          (char *)[[NSString stringWithFormat:
                                               @"GDL<0x%p>", self]
                                             cString],
                          (char *)[[adaptor loginName] cString],
                          //                          pwdDigest,
                          (char *)password,                          
                          (char *)[NSUserName() cString]);
  if (md == NULL) {
    if (isDebuggingEnabled) {
      NSLog(@"FrontBase session (channel=0x%p) couldn't be created, "
            @" login=%@ password=%s user=%@: %s.",
            self,
            [adaptor loginName], [adaptor loginPassword],
            [adaptor loginName],
            fbcdcClassErrorMessage());
    }
    fbcdcClose(self->fbdc); self->fbdc = NULL;
    return NO;
  }

  if (fbcmdErrorCount(md) > 0) {
    if (isDebuggingEnabled) {
      FBCErrorMetaData *emd;
      int i, count;
      
      emd = fbcdcErrorMetaData(self->fbdc, md);

      NSLog(@"FrontBase session (channel=0x%p) couldn't be created:", self);
      
      for (i = 0, count = fbcemdErrorCount(emd); i < count; i++) {
        unsigned   code;
        const char *errorKind;
        const char *emsg;

        code      = fbcemdErrorCodeAtIndex(emd, i);
        errorKind = fbcemdErrorKindAtIndex(emd, i);
        emsg      = fbcemdErrorMessageAtIndex(emd, i);

        NSLog(@"  code=%i", code);
        NSLog(@"  kind=%s", errorKind);
        NSLog(@"  msdg=%s", emsg);
#if 0        
        free((void *)errorKind);
#endif        
        free((void *)emsg);
      }
      fbcemdRelease(emd); emd = NULL;
    }
    fbcdcClose(self->fbdc); self->fbdc = NULL;
    fbcmdRelease(md); md = NULL;
    return NO;
  }
  
  fbcmdRelease(md); md = NULL;

  result = YES;

  /* apply session level setting (locking & tx levels) */

  if ((txIsoLevel = [adaptor transactionIsolationLevel]) == nil)
    txIsoLevel = @"READ COMMITTED";
  if ((locking = [adaptor lockingDiscipline]) == nil)
    locking = @"OPTIMISTIC";

  expr = [NSString stringWithFormat:
                     @"SET TRANSACTION ISOLATION LEVEL %s, LOCKING %s",
                     [txIsoLevel cString], [locking cString]];
  if (![self evaluateExpression:expr]) {
    if (isDebuggingEnabled)
      NSLog(@"%@: couldn't apply tx iso level '%@' and locking '%@'..",
            self, txIsoLevel, locking);
  }

#if LIB_FOUNDATION_BOEHM_GC
  [GarbageCollector registerForFinalizationObserver:self
                    selector:@selector(_adaptorWillFinalize:)
                    object:[[self adaptorContext] adaptor]];
#endif

  if (isDebuggingEnabled)
    NSLog(@"FrontBase channel 0x%p opened ..", self);
  
  return result;
}

- (void)primaryCloseChannel {
  /* release all resources */
  
  if (self->fbdc) {
    if (isDebuggingEnabled) {
      id ad;

      ad = [[self adaptorContext] adaptor];
      NSLog(@"Close fb-channel[%p]: db=%@, server=%@", self,
            ad, [ad serverName]);
    }

    fbcdcClose(self->fbdc);
    self->fbdc = NULL;
  }
  
  RELEASE(self->selectedAttributes); self->selectedAttributes = nil;
}

- (void)closeChannel {
  [super closeChannel];
  [self primaryCloseChannel];
}

// fetching rows

- (void)cancelFetch {
  if (![self isOpen]) {
    [FrontBaseException raise:@"ChannelNotOpenException"
                        format:@"No fetch in progress, fb connection is not"
                           @" open (channel=%@)", self];
  }

  if (self->fetchHandle) {
    FBCMetaData *md;
    if ((md = fbcdcCancelFetch(self->fbdc, self->fetchHandle))) {
      fbcmdRelease(md); md = NULL;
    }
    self->fetchHandle = NULL;
  }

  if (self->datatypeCodes) {
    free(self->datatypeCodes);
    self->datatypeCodes = NULL;
  }

  if (self->rowHandler) {
    fbcrhRelease(self->rowHandler);
    self->rowHandler = NULL;
    self->rawRows    = NULL;
  }
  else {
    NSAssert(self->rawRows == NULL, @"raw rows set, but no row handler ! ..");
  }
  
  if (self->cmdMetaData) {
    fbcmdRelease(self->cmdMetaData);
    self->cmdMetaData = NULL;
  }

  NSAssert(self->rowHandler == NULL, @"row handler still set ..");
  NSAssert(self->rawRows    == NULL, @"raw row still set ..");
  
  [super cancelFetch];

  self->currentRow      = 0;
  self->numberOfColumns = 0;
  RELEASE(self->selectedAttributes); self->selectedAttributes = nil;
}

- (NSArray *)describeResults {
  int                 cnt;
  NSMutableArray      *result    = nil;
  NSMutableDictionary *usedNames = nil;
  NSNumber            *yesObj    = [NSNumber numberWithBool:YES];

  if (![self isFetchInProgress]) {
    [FrontBaseException raise:@"NoFetchInProgress"
                        format:@"No fetch in progress (channel=%@)", self];
  }

  NSAssert(self->cmdMetaData, @"no cmd-meta-data ..");

  result    =
    [[NSMutableArray alloc] initWithCapacity:self->numberOfColumns + 1];
  usedNames =
    [[NSMutableDictionary alloc] initWithCapacity:self->numberOfColumns + 1];

  for (cnt = 0; cnt < self->numberOfColumns; cnt++) {
    const FBCColumnMetaData *cmd;
    EOAttribute *attribute  = nil;
    NSString    *columnName = nil;
    NSString    *attrName   = nil;

    cmd = fbcmdColumnMetaDataAtIndex(self->cmdMetaData,   cnt);
    
    if (cmd) {
      const char *s;

      if ((s = fbccmdLabelName(cmd)))
        columnName = [NSString stringWithCString:s];
      else if ((s = fbccmdColumnName(cmd)))
        columnName = [NSString stringWithCString:s];
    }

    if ([columnName length] == 0) {
      columnName = [NSString stringWithFormat:@"column%i", cnt];
      attrName   = [NSString stringWithFormat:@"column%i", cnt];
    }
    else
      attrName = [columnName _sybModelMakeInstanceVarName];

    if ([[usedNames objectForKey:attrName] boolValue]) {
      int      cnt2 = 0;
      char     buf[64];
      NSString *newAttrName = nil;

      for (cnt2 = 2; cnt2 < 100; cnt2++) {
        sprintf(buf, "%i", cnt2);
        
        newAttrName = [attrName stringByAppendingString:
                                  [NSString stringWithCString:buf]];
        
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
    [attribute loadValueClassAndTypeFromFrontBaseType:self->datatypeCodes[cnt]];
    [result addObject:attribute];
    RELEASE(attribute); attribute = nil;
  }

  RELEASE(usedNames);
  usedNames = nil;
  
  return AUTORELEASE(result);
}

- (int)batchSize {
  return 1000;
}

- (BOOL)_nextBatch {
  if (self->rowHandler) {
    fbcrhRelease(self->rowHandler);
    self->rowHandler = NULL;
    self->rawRows = NULL;
  }

  //NSLog(@"fetching new batch ..");
  NSAssert(self->fetchHandle, @"missing fetch handle ..");
  self->rawRows = fbcdcFetch(self->fbdc, [self batchSize], self->fetchHandle);

  if (self->rawRows) {
    self->rowHandler = fbcrhInitWith(self->rawRows, self->cmdMetaData);
    self->isFirstInBatch = YES;
    //NSLog(@"fetched new batch %i rows ..", fbcrhRowCount(self->rowHandler));
  }
  else {
    /* no more fetch data, finish fetch op */
    [self cancelFetch];
    self->isFetchInProgress = NO;
    return NO;
  }

  return YES;
}

- (NSMutableDictionary *)primaryFetchAttributes:(NSArray *)_attributes
  withZone:(NSZone *)_zone
{
  NSMutableDictionary *record;
  void **rawRow;
  int  i;

  record = nil;
  
  if (!self->isFetchInProgress)
    return nil;

  if (self->rawRows == NULL) {
    if (![self _nextBatch])
      return nil;
  }
    
  if (self->selectedAttributes == nil) {
    self->selectedAttributes = RETAIN([self describeResults]);
  }

  if ([_attributes count] < [self->selectedAttributes count])
    _attributes = self->selectedAttributes;
  
  NSAssert(self->rowHandler, @"missing row handler ..");

  rawRow = self->isFirstInBatch
    ? fbcrhFirstRow(self->rowHandler)
    : fbcrhNextRow(self->rowHandler);

  if (rawRow == NULL) {
    /* no more rows available in fetch-buffer, get next batch */
    if (![self _nextBatch])
      return nil;

    rawRow = self->isFirstInBatch
      ? fbcrhFirstRow(self->rowHandler)
      : fbcrhNextRow(self->rowHandler);
  }
  self->isFirstInBatch = NO;

  if (rawRow == NULL) {
    /* no rows were in batch and no new batch could be fetched, so we finished */
    [self cancelFetch];
    self->isFetchInProgress = NO;
    return nil;
  }

  /* deconstruct raw row */

  {
    id objects[self->numberOfColumns];
    id keys[self->numberOfColumns];
    
    for (i = 0; i < self->numberOfColumns; i++) {
      EOAttribute *attribute;
      register void *rawValue;
      Class    valueClass;
      NSString *attrName;
      id value;

      objects[i] = NULL;
      keys[i]    = NULL;
      
      if (self->datatypeCodes[i] < 1)
        continue;

#if 1
      if (!(attribute  = [_attributes objectAtIndex:i])) {
        attribute  = [self->selectedAttributes objectAtIndex:i];
      }
#endif
      
      attrName   = [attribute name];
      valueClass = NSClassFromString([attribute valueClassName]);

#if DEBUG
      NSAssert3(valueClass,
                @"no valueClass for attribute %@ entity %@ name %@ ..",
                attribute, [attribute entity], [attribute valueClassName]);
#endif
    
      if (attrName == nil)
        attrName = [NSString stringWithFormat:@"column%i", i];

      rawValue = rawRow[i];
      if (rawValue == NULL) {
        value = null;
      }
      else {
        FBCBlobHandle *handle = NULL;
        unsigned int len = 4;
      
        switch (self->datatypeCodes[i]) {
          case FB_Boolean:
            len = sizeof(unsigned char);
            break;
          
          case FB_Character:
            len = strlen(rawValue);
            break;
          case FB_VCharacter:
            len = strlen(rawValue);
            break;
          case FB_Date:
            NSLog(@"handling date ..");
            len = strlen(rawValue);
            break;
          case FB_Timestamp:
            NSLog(@"handling timestamp ..");
            len = strlen(rawValue);
            break;
          case FB_TimestampTZ:
            len = strlen(rawValue);
            if (len != 25) {
              NSLog(@"handling timestamp with TZ with length=%i ..", len);
            }
            break;

          case FB_SmallInteger:
            len = sizeof(short);
            break;
          
          case FB_Integer:
          case FB_YearMonth:
            len = sizeof(int);
            break;

          case FB_Double:
          case FB_Real:
          case FB_Numeric:
          case FB_Decimal:
          case FB_DayTime:
            len = sizeof(double);
            break;

          case FB_Float:
            len = sizeof(float);
            break;

          case FB_CLOB:
          case FB_BLOB:
            /*
              CLOB/BLOB are a bit more tricky, mainly because values of up to a
              given size are inlined in the fetch result, i.e. no need for a
              round trip to the server. 
            */
            if ((*(unsigned char *)rawValue) == 0) {
              /* blob via handle */
#if BLOB_DEBUG
              NSLog(@"blob via handle %s",
                    ((FBCBlobIndirect *)rawValue)->handleAsString);
#endif

              handle =
                fbcbhInitWithHandle(((FBCBlobIndirect *)rawValue)->handleAsString);
              len    = fbcbhBlobSize(handle);

              rawValue = fbcdcReadBLOB(self->fbdc, handle);
            }
            else {
              /* blob inline */
              FBCBlobDirect *blob;

#if BLOB_DEBUG
              NSLog(@"blob inline");
#endif
              blob     = rawValue;
              rawValue = blob->blobData;
              len      = blob->blobSize;
            }
#if BLOB_DEBUG
            NSLog(@"  size=%d", len);
#endif
            break;
        }

        /* make an object value from the data */

#if DEBUG
        NSAssert3(valueClass,
                  @"lost valueClass for attribute %@ entity %@ name %@ ..",
                  attribute, [attribute entity], [attribute valueClassName]);
#endif
      
        value = [valueClass valueFromBytes:rawValue length:len
                            frontBaseType:self->datatypeCodes[i]
                            attribute:attribute
                            adaptorChannel:self];

#if DEBUG
        if (value == nil) {
          NSAssert4(value,
                    @"no value for attribute %@ entity %@ "
                    @"valueClass %@, record %@ ..",
                    attribute, [attribute entity],
                    NSStringFromClass(valueClass), record);
        }
#endif
      
        /* free BLOB handle if one was allocated */
      
        if (handle) {
          fbcbhRelease(handle);
          handle = NULL;
        }
      }

#if DEBUG
      NSAssert2(value, @"no value for attribute %@ entity %@ ..",
                attribute, [attribute entity]);
#endif

      objects[i] = value;
      keys[i]    = [attribute name];
    }
    {
      static Class EORecordDictionaryClass = nil;

      if (EORecordDictionaryClass == nil)
        EORecordDictionaryClass = [EORecordDictionary class];
      
      record = (id)NSAllocateObject(EORecordDictionaryClass,
                                sizeof(EORecordDictionary) *
                                self->numberOfColumns, nil);
      record = [record initWithObjects:objects forKeys:keys
                       count:self->numberOfColumns];
      AUTORELEASE(record);
    }
  }
  return record;
}

/* sending sql to server */

- (BOOL)evaluateExpression:(NSString *)_expression {
  BOOL result;
#if DEBUG
  static Class NSDateClass = Nil;
  NSDate *startDate;
#endif

  *(&result) = YES;
  NSAssert(self->rowHandler  == NULL, @"raw handler still available ..");
  NSAssert(self->rawRows     == NULL, @"raw rows still available ..");
  NSAssert(self->fetchHandle == NULL, @"fetch handle still available ..");

  if (_expression == nil) {
    [InvalidArgumentException raise:@"InvalidArgumentException"
                              format:@"parameter for evaluateExpression: "
                                @"must not be null (channel=%@)", self];
  }
  
  *(&_expression) = AUTORELEASE([_expression mutableCopy]);

  if (delegateRespondsTo.willEvaluateExpression) {
    EODelegateResponse response =
      [delegate adaptorChannel:self
                willEvaluateExpression:(NSMutableString *)_expression];
    
    if (response == EODelegateRejects)
      return NO;
    else if (response == EODelegateOverrides)
      return YES;
  }

  if (isDebuggingEnabled)
    NSLog(@"SQL[%p]: %@", self, _expression);
  

  if (![self isOpen]) {
    [FrontBaseException raise:@"ChannelNotOpenException"
                       format:@"FrontBase connection is not open (channel=%@)",
                         self];
  }
  if (self->cmdMetaData != NULL) {
    [FrontBaseException raise:@"CommandInProgressException"
                        format:@"command data already set up"
                          @" (channel=%@)", self];
  }
  
  _expression = [_expression stringByAppendingString:@";"];
  
  if (self->sqlLogFile) {
    FILE *fh;
    if ((fh = fopen([self->sqlLogFile cString], "a"))) {
      fprintf(fh, "%s\n", [_expression cString]);
      fflush(fh);
      fclose(fh);
    }
  }
  
  /* execute expression */

#if DEBUG
  if (NSDateClass == Nil) NSDateClass = [NSDate class];
  startDate = [NSDateClass date];
#endif
  
  self->cmdMetaData = fbcdcExecuteDirectSQL(self->fbdc,
                                            (char *)[_expression cString]);
  if (self->cmdMetaData == NULL) {
    NSLog(@"%@: could not execute SQL: %@", self, _expression);
    return NO;
  }

  /* check for errors */
  
  if (fbcmdErrorCount(self->cmdMetaData) > 0) {
    FBCErrorMetaData *emd;
    char *msg;
    NSString *error;
    int i, count;

    emd = fbcdcErrorMetaData(self->fbdc, self->cmdMetaData);
    
    for (i = 0, count = fbcemdErrorCount(emd); i < count; i++) {
      unsigned   code;
      const char *errorKind;
      const char *emsg;

      code      = fbcemdErrorCodeAtIndex(emd, i);
      errorKind = fbcemdErrorKindAtIndex(emd, i);
      emsg      = fbcemdErrorMessageAtIndex(emd, i);

      NSLog(@"  code=%i", code);
      NSLog(@"  kind=%s", errorKind);
      NSLog(@"  msdg=%s", emsg);
#if 0
      free((void *)errorKind);
#endif
      free((void *)emsg);
    }
    
    if ((msg = fbcemdAllErrorMessages(emd)))
      error = [NSString stringWithCString:msg];
    else
      error = @"unknown";
    free(msg); msg = NULL;
    fbcemdRelease(emd); emd = NULL;
    fbcmdRelease(self->cmdMetaData); self->cmdMetaData = NULL;
    
    if (self->sqlLogFile) {
      FILE *fh;
      if ((fh = fopen([self->sqlLogFile cString], "a"))) {
        fprintf(fh, "# failed: %s\n",
                [[error stringByApplyingCEscaping] cString]);
        fflush(fh);
        fclose(fh);
      }
    }
    
    NSLog(@"%@: could not execute SQL: %@\n  reason: %@",
          self, _expression,
          error);
    return NO;
  }

  /* init common results */

  NSAssert(self->cmdMetaData, @"missing command-meta-data");
  self->numberOfColumns   = fbcmdColumnCount(self->cmdMetaData);
  self->rowsAffected      = fbcmdRowCount(self->cmdMetaData);
  self->txVersion         = fbcmdTransactionVersion(self->cmdMetaData);
  self->isFetchInProgress = NO;

  if ((self->fetchHandle = fbcmdFetchHandle(self->cmdMetaData)))
    self->isFetchInProgress = YES;

  if (self->numberOfColumns > 0) {
    int i;
    
    self->datatypeCodes = calloc(self->numberOfColumns, sizeof(int));
    for (i = 0; i < self->numberOfColumns; i++) {
      const FBCDatatypeMetaData *dmd;

      if ((dmd = fbcmdDatatypeMetaDataAtIndex(self->cmdMetaData, i)))
        self->datatypeCodes[i] = fbcdmdDatatypeCode(dmd);
      else
        self->datatypeCodes[i] = FB_VCharacter;
    }
  }

  if (!self->isFetchInProgress) {
    fbcmdRelease(self->cmdMetaData);
    self->cmdMetaData = NULL;
  }
#if DEBUG
  else {
    /* some constraints */
    if ([_expression hasPrefix:@"INSERT"]) {
      NSLog(@"an insert shouldn't start a fetch ! ..");
    }
    else if ([_expression hasPrefix:@"DELETE"]) {
      NSLog(@"a delete shouldn't start a fetch ! ..");
    }
    else if ([_expression hasPrefix:@"UPDATE"]) {
      NSLog(@"an update shouldn't start a fetch ! ..");
    }
  }
#endif

  /* setup row handler */
  
  if (result) {
    if (delegateRespondsTo.didEvaluateExpression)
      [delegate adaptorChannel:self didEvaluateExpression:_expression];
  }
  else {
    [self cancelFetch];
  }

  if (self->sqlLogFile) {
    FILE *fh;
    if ((fh = fopen([self->sqlLogFile cString], "a"))) {
#if DEBUG
      fprintf(fh, "# %s %3.3g\n", result ? "yes" : "no",
              -[startDate timeIntervalSinceNow]);
#else
      fprintf(fh, "# %s\n", result ? "yes" : "no");
#endif
      fflush(fh);
      fclose(fh);
    }
  }

  return result;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@[0x%p]: open=%s fetching=%s>",
                     NSStringFromClass([self class]),
                     self,
                     [self isOpen] ? "yes" : "no",
                     [self isFetchInProgress] ? "yes" : "no"];
}

@end /* FrontBaseChannel */

@implementation FrontBaseChannel(PrimaryKeyGeneration)

- (NSDictionary *)primaryKeyForNewRowWithEntity:(EOEntity *)_entity {
  NSArray          *pkeys;
  FrontBase2Adaptor *adaptor;
  NSString         *newKeyExpr;
  NSDictionary     *pkey;

  pkeys      = [_entity primaryKeyAttributeNames];
  adaptor    = (id)[[self adaptorContext] adaptor];
  newKeyExpr = [adaptor newKeyExpression];

  if (newKeyExpr == nil) {
    NSLog(@"ERROR: missing newkey expression, can't gen pkey for %@",
          [_entity name]);
    return nil;
  }

  if ([pkeys count] != 1) {
    NSLog(@"no pkeys configured for entity %@", [_entity name]);
    return nil;
  }

  *(&pkey) = nil;

  NS_DURING {
    if ([self evaluateExpression:newKeyExpr]) {
      NSDictionary *row;
      NSArray *attrs;
      id key;

      attrs = [self describeResults];
      row = [self fetchAttributes:attrs withZone:NULL];
      [self cancelFetch];

      if ((key = [[row objectEnumerator] nextObject])) {
        pkey = [NSDictionary dictionaryWithObject:
                               [NSNumber numberWithInt:[key intValue]]
                             forKey:[pkeys objectAtIndex:0]];
      }
    }
    else {
      NSLog(@"could not evaluate newkey expression: %@", newKeyExpr);
    }
  }
  NS_HANDLER {
    fprintf(stderr, "newkey failed: %s\n",
            [[localException description] cString]);
    fflush(stderr);
    pkey = nil;
  }
  NS_ENDHANDLER;
  
  return pkey;
}

@end /* FrontBaseChannel(PrimaryKeyGeneration) */

@implementation FrontBaseChannel(BlobHandling)

- (NSDictionary *)_extractBlobsFromRow:(NSMutableDictionary *)_mrow
  entity:(EOEntity *)_entity
{
  /*
    Search for BLOB attributes.
    If a BLOB attribute is found, remove it from mrow and add it's data to
    blobRow.
  */
  FrontBase2Adaptor    *adaptor;
  NSMutableDictionary *blobRow;
  NSEnumerator *keys;
  NSString     *key;

  adaptor = (FrontBase2Adaptor *)[[self adaptorContext] adaptor];
#if DEBUG
  NSAssert(adaptor, @"missing adaptor ..");
#endif

  /* must use allKeys since we are going to modify mrow */
  keys = [[_mrow allKeys] objectEnumerator];
  blobRow = nil;

  while ((key = [keys nextObject])) {
    EOAttribute *attribute;
    int fbType;

    attribute = [_entity attributeNamed:key];
    fbType = [adaptor typeCodeForExternalName:[attribute externalType]];

    if ((fbType == FB_BLOB) || (fbType == FB_CLOB)) {
      NSData *data;
      id value;

      value = [_mrow objectForKey:key];
      data  = [value dataValueForFrontBaseType:fbType
                     attribute:attribute];
      if (data == nil) // EONull
        continue;
        
      if (blobRow == nil)
        blobRow = [NSMutableDictionary dictionaryWithCapacity:4];

      [blobRow setObject:data forKey:key];
      [_mrow   removeObjectForKey:key];
    }
    else if (fbType == FB_VCharacter) {
      /* check for large VARCHARs and handle them like BLOBs.. */
      id value;
      
      value = [_mrow objectForKey:key];
      
      if ([value isKindOfClass:[NSString class]]) {
        if ([value length] > 2000) {
          NSData *data;

          data = [value dataValueForFrontBaseType:fbType
                        attribute:attribute];
          if (data == nil)
            continue;

          if (blobRow == nil)
            blobRow = [NSMutableDictionary dictionaryWithCapacity:4];

          [blobRow setObject:data forKey:key];
          [_mrow   removeObjectForKey:key];
        }
      }
      else if ([value isKindOfClass:[NSData class]]) {
        if ([value length] > 60) {
          NSData *data;

          data = [value dataValueForFrontBaseType:fbType
                        attribute:attribute];
          if (data == nil)
            continue;

          if (blobRow == nil)
            blobRow = [NSMutableDictionary dictionaryWithCapacity:4];

          [blobRow setObject:data forKey:key];
          [_mrow   removeObjectForKey:key];
        }
      }
    }
#if 0
    else {
      NSLog(@"%@ is *not* a BLOB attribute (type=%i) ..", attribute, fbType);
    }
#endif
  }
  return blobRow;
}

- (BOOL)_writeBlobs:(NSDictionary *)_blobs ofRow:(NSMutableDictionary *)_mrow {
  /*
    This method writes the blobs and set's the appropriate handle-keys in
    the row.
  */
  if (_blobs) {
    NSEnumerator *keyEnum;
    NSString *key;

    keyEnum = [_blobs keyEnumerator];
    while ((key = [keyEnum nextObject])) {
      NSData        *value;
      FBCBlobHandle *blob;
      
      value = [_blobs objectForKey:key];

#if BLOB_DEBUG
      NSLog(@"writing blob %@ of size %i ...", key, [value length]);
#endif
      
      if ((blob = fbcdcWriteBLOB(self->fbdc,
                                 (char*)[value bytes],
                                 [value length]))) {
        char     blobid[FBBlobHandleByteSize + 4];
        NSString *blobKey;
        FBBlobHandle *handle;
        
        fbcbhGetHandle(blob, blobid);
        
        blobKey = [NSString stringWithCString:blobid
                            length:FBBlobHandleByteSize + 3];
#if BLOB_DEBUG
        NSLog(@"  got id %@ for blob %@ ...", blobKey, key);
#endif
        if (blobKey == nil) {
          if (blob)
            fbcbhRelease(blob);
          return NO;
        }

        fbcbhRelease(blob); blob = NULL;

        handle = [[FBBlobHandle alloc] initWithBlobID:blobKey];
        [_mrow setObject:handle forKey:key];
        RELEASE(handle); handle = nil;
      }
      else {
        NSLog(@"%@: writing of BLOB %@ failed !", self, key);
        return NO;
      }
    }
    return YES;
  }
  else
    return YES;
}

- (BOOL)insertRow:(NSDictionary *)row forEntity:(EOEntity *)entity {
  EOSQLExpression     *sqlexpr     = nil;
  NSMutableDictionary *mrow        = nil;
  NSDictionary        *blobRow     = nil;

  mrow = AUTORELEASE([row mutableCopyWithZone:[row zone]]);
  
  if (!isOpen)
    [[ChannelIsNotOpenedException new] raise];

  if((row == nil) || (entity == nil)) {
    [[[InvalidArgumentException alloc]
             initWithFormat:@"row and entity arguments for insertRow:forEntity:"
                            @"must not be the nil object"] raise];
  }

  if([self isFetchInProgress])
    [[AdaptorIsFetchingException exceptionWithAdaptor:self] raise];

  if(![adaptorContext transactionNestingLevel])
    [[NoTransactionInProgressException exceptionWithAdaptor:self] raise];

  if(delegateRespondsTo.willInsertRow) {
    EODelegateResponse response;

    response = [delegate adaptorChannel:self
                         willInsertRow:mrow
                         forEntity:entity];
    if(response == EODelegateRejects)
      return NO;
    else if(response == EODelegateOverrides)
      return YES;
  }

  /* extract BLOB attributes */

  blobRow = [self _extractBlobsFromRow:mrow entity:entity];
  
  /* upload BLOBs */

  if (![self _writeBlobs:blobRow ofRow:mrow])
    return NO;
  
  /* insert non-BLOB attributes */
  
  sqlexpr = [[[adaptorContext adaptor]
                              expressionClass]
                              insertExpressionForRow:mrow
                              entity:entity
                              channel:self];
    
  if(![self evaluateExpression:[sqlexpr expressionValueForContext:nil]])
    return NO;
  
  if(delegateRespondsTo.didInsertRow)
    [delegate adaptorChannel:self didInsertRow:mrow forEntity:entity];

  return YES;
}

- (BOOL)updateRow:(NSDictionary *)row
  describedByQualifier:(EOSQLQualifier *)qualifier
{
  /*
    FrontBaseChannel's -updateRow:describedByQualifier: differs from the
    EOAdaptorChannel one in that it updates BLOB columns seperatly.
  */
  FrontBase2Adaptor    *adaptor   = (FrontBase2Adaptor *)[adaptorContext adaptor];
  EOEntity            *entity     = [qualifier entity];
  EOSQLExpression     *sqlexpr    = nil;
  NSMutableDictionary *mrow       = nil;
  NSDictionary        *blobRow    = nil;

  self->rowsAffected = 0;

  mrow = AUTORELEASE([row mutableCopyWithZone:[row zone]]);
  
  if (!isOpen)
    [[ChannelIsNotOpenedException new] raise];

  if(row == nil) {
    [[[InvalidArgumentException alloc]
             initWithFormat:@"row argument for updateRow:describedByQualifier: "
       @"must not be the nil object"] raise];
  }

  if([self isFetchInProgress])
    [[AdaptorIsFetchingException exceptionWithAdaptor:self] raise];

  if(![adaptorContext transactionNestingLevel])
    [[NoTransactionInProgressException exceptionWithAdaptor:self] raise];

  if(delegateRespondsTo.willUpdateRow) {
    EODelegateResponse response;

    response = [delegate adaptorChannel:self
                         willUpdateRow:mrow
                         describedByQualifier:qualifier];
    if(response == EODelegateRejects)
      return NO;
    else if(response == EODelegateOverrides)
      return YES;
  }

  /* extract BLOB attributes */

  blobRow = [self _extractBlobsFromRow:mrow entity:entity];
  
  /* upload BLOBs */

  if (![self _writeBlobs:blobRow ofRow:mrow])
    return NO;
  
  /* update non-BLOB attributes */

  if ([mrow count] > 0) {
    sqlexpr = [[adaptor expressionClass]
                        updateExpressionForRow:mrow
                        qualifier:qualifier
                        channel:self];
    
    if(![self evaluateExpression:[sqlexpr expressionValueForContext:nil]])
      return NO;

    if (self->rowsAffected != 1) {
      NSLog(@"%s: rows affected: %i", __PRETTY_FUNCTION__, self->rowsAffected);
      return NO;
    }
  }

  /* inform delegate about sucess */
  
  if(delegateRespondsTo.didUpdateRow) {
    [delegate adaptorChannel:self
              didUpdateRow:mrow
              describedByQualifier:qualifier];
  }
  return YES;
}

- (BOOL)selectAttributes:(NSArray *)attributes
  describedByQualifier:(EOSQLQualifier *)qualifier
  fetchOrder:(NSArray *)fetchOrder
  lock:(BOOL)lockFlag
{
  static Class EOSortOrderingClass = Nil;
  NSMutableArray *mattrs;
  NSEnumerator *fetchOrders;
  id fo;

  /* automatically add attributes used in fetchOrderings (required by FB) */
  
  if (EOSortOrderingClass == Nil)
    EOSortOrderingClass = [EOSortOrdering class];
  
  mattrs = nil;
  fetchOrders = [fetchOrder objectEnumerator];
  while ((fo = [fetchOrders nextObject])) {
    EOAttribute *attr;

    attr = nil;
    if ([fo isKindOfClass:EOSortOrderingClass]) {
      NSString    *attrName;
      
      attrName = [fo key];
      attr = [[qualifier entity] attributeNamed:attrName];
    }
    else {
      /* EOAttributeOrdering */
      attr = [fo attribute];
    }

    if (attr == nil) {
      NSLog(@"ERROR(%s): could not resolve attribute of sort ordering %@ !",
            __PRETTY_FUNCTION__, fo);
      continue;
    }
    
    if (mattrs) {
      if (![mattrs containsObject:attr])
        [mattrs addObject:attr];
    }
    else if (![attributes containsObject:attr]) {
      mattrs = [[NSMutableArray alloc] initWithArray:attributes];
      [mattrs addObject:attr];
    }
  }
  
  if (mattrs) {
    attributes = [mattrs copy];
    RELEASE(mattrs);
    AUTORELEASE(attributes);
  }

  /* continue usual select .. */
  
  ASSIGN(self->selectedAttributes, attributes);
  
  return [super selectAttributes:attributes
                describedByQualifier:qualifier
                fetchOrder:fetchOrder
                lock:lockFlag];
}

@end /* FrontBaseChannel(BlobHandling) */

void __link_FBChannel() {
  // used to force linking of object file
  __link_FBChannel();
}
