/* 
   EOAdaptorDataSource.m
   
   Copyright (C) SKYRIX Software AG and Helge Hess

   Date:   1999-2005

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

/*
  column-names must have small letterso
  hints:
    EOPrimaryKeyAttributeNamesHint - name of primary key attributes
    EOPrimaryKeyAttributesHint     - primary key attributes
    EOFetchResultTimeZone          - NSTimeZone object for dates
*/

#define EOAdaptorDataSource_DEBUG 0

#include <NGExtensions/NGExtensions.h>
#include <GDLAccess/GDLAccess.h>
#include <EOControl/EOControl.h>
#include "common.h"

NSString *EOPrimaryKeyAttributeNamesHint = @"EOPrimaryKeyAttributeNamesHint";
NSString *EOPrimaryKeyAttributesHint     = @"EOPrimaryKeyAttributesHint";
NSString *EOFetchResultTimeZone          = @"EOFetchResultTimeZoneHint";

@interface NSObject(Private)
- (NSString *)newKeyExpression;
- (NSArray *)_primaryKeyAttributesForTableName:(NSString *)_entityName
  channel:(EOAdaptorChannel *)_adChannel;
- (NSArray *)_primaryKeyAttributeNamesForTableName:(NSString *)_entityName
  channel:(EOAdaptorChannel *)_adChannel;
@end

static EONull *null = nil;

@interface EOAdaptorChannel(Internals)
- (NSArray *)_sortAttributesForSelectExpression:(NSArray *)_attrs;
@end /* EOAdaptorChannel(Internals) */

@interface EOQualifier(SqlExpression)
- (NSString *)sqlExpressionWithAdaptor:(EOAdaptor *)_adaptor
                            attributes:(NSArray *)_attrs;
@end /* EOQualifier(SqlExpression) */

@interface EOAdaptorDataSource(Private)

- (NSMutableString *)_selectListWithChannel:(EOAdaptorChannel *)_adChan;
- (NSString *)_whereExprWithChannel:(EOAdaptorChannel *)_adChan;
- (NSString *)_whereClauseForGlobaID:(EOKeyGlobalID *)_gid
  adaptor:(EOAdaptor *)_adaptor channel:(EOAdaptorChannel *)_adChan;

- (NSString *)_orderByExprForAttributes:(NSArray *)_attrs 
  andPatchSelectList:(NSMutableString *)selectList
  withChannel:(EOAdaptorChannel *)_adChan;

- (NSDictionary *)_mapAttrsWithValues:(NSDictionary *)_keyValues
  tableName:(NSString *)_tableName channel:(EOAdaptorChannel *)_adChan;

@end /* EOAdaptorDataSource(Private) */

@interface EOAdaptorDataSource(Internals)
- (id)initWithAdaptorChannel:(EOAdaptorChannel *)_channel
  connectionDictionary:(NSDictionary *)_connDict;
@end /* EOAdaptorDataSource(Internals) */

@interface EODataSource(Notificiations)
- (void)postDataSourceChangedNotification;
@end

@implementation EOAdaptorDataSource

static Class NSCalendarDateClass = nil;
static NSNotificationCenter *nc = nil;

static NSNotificationCenter *getNC(void ) {
  if (nc == nil)
    nc = [[NSNotificationCenter defaultCenter] retain];
  return nc;
}

+ (void)initialize {
  NSAssert2([super version] == 1,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);

  null = [[EONull null] retain];
  NSCalendarDateClass = [NSCalendarDate class];
}
+ (int)version {
  return [super version] + 1; /* v2 */
}

- (id)initWithAdaptorName:(NSString *)_adName
  connectionDictionary:(NSDictionary *)_dict
  primaryKeyGenerationDictionary:(NSDictionary *)_pkGen
{
  EOAdaptor        *ad  = nil;
  EOAdaptorContext *ctx = nil;
  EOAdaptorChannel *adc = nil;

  ad  = [EOAdaptor adaptorWithName:_adName];
  [ad setConnectionDictionary:_dict];
  [ad setPkeyGeneratorDictionary:_pkGen];
  ctx = [ad createAdaptorContext];
  adc = [ctx createAdaptorChannel];
  
  return [self initWithAdaptorChannel:adc connectionDictionary:_dict];
}

- (id)initWithAdaptorChannel:(EOAdaptorChannel *)_channel {
  return [self initWithAdaptorChannel:_channel connectionDictionary:nil];
}

- (id)initWithAdaptorChannel:(EOAdaptorChannel *)_channel
  connectionDictionary:(NSDictionary *)_connDict
{
  if ((self = [super init])) {
    self->adChannel            = [_channel retain];
    self->connectionDictionary = [_connDict copy];
    self->commitTransaction    = NO;
    
    [getNC()
          addObserver:self selector:@selector(_adDataSourceChanged:)
          name:@"EOAdaptorDataSourceChanged" object:nil];
  }
  return self;
}

- (void)dealloc {
  [getNC() removeObserver:self];
  [self->fetchSpecification   release];
  [self->connectionDictionary release];
  [self->adChannel            release];
  [self->__attributes         release];
  [self->__qualifier          release];
  [super dealloc];
}

/* notifications */

- (void)postDataSourceItselfChangedNotification {
  [super postDataSourceChangedNotification];
}

- (void)postDataSourceChangedNotification {
  [getNC() postNotificationName:@"EOAdaptorDataSourceChanged" object:self];
  [self postDataSourceItselfChangedNotification];
}

- (void)_adDataSourceChanged:(NSNotification *)_notification {
  EOAdaptorDataSource *ads;
  
  if ((ads = [_notification object]) == self)
    return;
  if (ads == nil)
    return;
  
  [self postDataSourceItselfChangedNotification];
  
#if 0
  if (![ads->connectionDictionary isEqual:self->connectionDictionary])
    /* different database ... */
    return;
  
  if ((ads->fetchSpecification == nil) || (self->fetchSpecification == nil)) {
    [self postDataSourceChangedNotification];
    return;
  }
  
  /* check fspecs for entity ... */
  if ([[ads->fetchSpecification entityName]
                                isEqualToString:
                                  [self->fetchSpecification entityName]]) {
    [self postDataSourceChangedNotification];
    return;
  }
#endif
}

/* fetching */

- (EOAdaptorChannel *)beginTransaction {
  EOAdaptorContext *ctx = nil;

  [self openChannel];
  ctx = [self->adChannel adaptorContext];
  if ([ctx hasOpenTransaction] == NO) {
    [ctx beginTransaction];
    self->commitTransaction = YES;
  }
  return self->adChannel;
}
  
- (void)commitTransaction {
  if (self->commitTransaction) {
    [[self->adChannel adaptorContext] commitTransaction];
    //    [self->adChannel closeChannel];
    self->commitTransaction = NO;
  }
}

- (void)rollbackTransaction {
  [[self->adChannel adaptorContext] rollbackTransaction];
  //  [self->adChannel closeChannel];  
  self->commitTransaction = NO;
}

- (void)openChannel {
  if (![self->adChannel isOpen]) {
    [self->adChannel openChannel];
  }
}

- (void)closeChannel {
  if (![self->adChannel isOpen])
    return;

  if ([[self->adChannel adaptorContext] transactionNestingLevel]) {
    NSLog(@"%s was called while transaction in progress, rollback will called",
	  __PRETTY_FUNCTION__);
    [self rollbackTransaction];
  }
  [self->adChannel closeChannel];
}

- (NSArray *)fetchObjects {
  // TODO: split up this HUGE method!
  // TODO: all the SQL gen code should be moved to an appropriate object
  NSString         *entityName  = nil;
  NSString         *whereExpr   = nil;
  NSString         *orderByExpr = nil;
  NSMutableString  *selectList  = nil;  
  NSMutableString  *expression  = nil;
  NSMutableArray   *result      = nil;
  NSArray          *attrs       = nil;
  EOAdaptor        *adaptor     = nil;
  NSArray          *pKeys       = nil;
  EOQualifier      *qual        = nil;
  EOAdaptorChannel *adChan      = nil;
  int              pKeyCnt      = 0;
  NSTimeZone       *tz          = nil;
  BOOL             localComTrans;

  if (self->fetchSpecification == nil) {
    // TODO: make that a lastException and just return nil
    [NSException raise:NSInvalidArgumentException
		 format:@"fetchSpecification required for table name"];
    return nil;
  }
  
  entityName = [self->fetchSpecification entityName];
  
  if (entityName == nil || [entityName length] == 0) {
    [NSException raise:NSInvalidArgumentException
		 format:@"missing entity name"];
  }
  localComTrans = [[self->adChannel adaptorContext] hasOpenTransaction]
    ? NO : YES;
  
  adChan  = [self beginTransaction];
  pKeys   = [self _primaryKeyAttributeNamesForTableName:entityName
                  channel:adChan];

  if ((pKeyCnt = [pKeys count]) == 0) {
    NSLog(@"ERROR[%s]: missing primary keys for table %@",
          __PRETTY_FUNCTION__, entityName);
    return nil;
  }
  qual  = [self->fetchSpecification qualifier];
  
  if (qual == nil)
    qual = [EOQualifier qualifierWithQualifierFormat:@"1=1"];
  
  ASSIGN(self->__qualifier, qual);
  
  attrs = [adChan attributesForTableName:entityName];
    
  if (attrs == nil) {
    RELEASE(self->__qualifier); self->__qualifier = nil;

    NSLog(@"ERROR[%s]: could not find table '%@' in database.",
          __PRETTY_FUNCTION__, entityName);
    [self rollbackTransaction];
    return nil;
  }
  if ([attrs count] == 0) {
    RELEASE(self->__qualifier); self->__qualifier = nil;
      
    NSLog(@"ERROR[%s]: missing columns in table '%@'.",
          __PRETTY_FUNCTION__, entityName);
    [self rollbackTransaction];
    return nil;
  }
  tz = [[self->fetchSpecification hints] objectForKey:EOFetchResultTimeZone];
    
  ASSIGN(self->__attributes, attrs);
  adaptor = [[adChan adaptorContext] adaptor];
  {
    NSArray *a;
    NSSet *tableKeys     = nil;
    NSSet *qualifierKeys = nil;
    
    a = [[[qual allQualifierKeys] allObjects] map:@selector(lowercaseString)];
    qualifierKeys = [[NSSet alloc] initWithArray:a];
    a = [[attrs map:@selector(columnName)] map:@selector(lowercaseString)];
    tableKeys     = [[NSSet alloc] initWithArray:a];
    
    if ([qualifierKeys isSubsetOfSet:tableKeys] == NO) {
      NSString *format = nil;
        
      format = [NSString stringWithFormat:
                         @"EOAdaptorDataSource: using unmapped key in "
                         @"qualifier tableKeys <%@>  qualifierKeys <%@> "
                         @"qualifier <%@>",
                         tableKeys, qualifierKeys, qual];
        
      RELEASE(self->__attributes); self->__attributes = nil;
      RELEASE(self->__qualifier);  self->__qualifier  = nil;
      RELEASE(tableKeys);          tableKeys          = nil;
      [self rollbackTransaction];
      [[[InvalidQualifierException alloc] initWithFormat:format] raise];
    }
    RELEASE(tableKeys);     tableKeys     = nil;
    RELEASE(qualifierKeys); qualifierKeys = nil;
  }
  
  whereExpr   = [self _whereExprWithChannel:adChan];
  selectList  = [self _selectListWithChannel:adChan];
  orderByExpr = [self _orderByExprForAttributes:attrs
		      andPatchSelectList:selectList
		      withChannel:adChan];
  
  expression = [[NSMutableString alloc] initWithCapacity:256];
  [expression appendString:@"SELECT "];

  if ([self->fetchSpecification usesDistinct])
    [expression appendString:@"DISTINCT "];

  [expression appendString:selectList];
  [expression appendString:@" FROM "];
  [expression appendString:entityName];
  if ([whereExpr length] > 0) {
    [expression appendString:@" WHERE "];
    [expression appendString:whereExpr];
  }
  if (orderByExpr != nil && [orderByExpr length] > 0) {
    [expression appendString:@" ORDER BY "];
    [expression appendString:orderByExpr];
  }
  
  if (![adChan evaluateExpression:expression]) {
    RELEASE(self->__attributes); self->__attributes = nil;
    RELEASE(self->__qualifier);  self->__qualifier  = nil;
    AUTORELEASE(expression);
    [adChan cancelFetch];
    [self rollbackTransaction];
    [[[EOAdaptorException alloc]
       initWithFormat:@"evaluateExpression of %@ failed", expression] raise];
  }
  result = [NSMutableArray arrayWithCapacity:64];
  {
    NSMutableDictionary *row = nil;
    unsigned fetchCnt   = 0;
    unsigned fetchLimit = 0;
    unsigned attrCnt    = 0;
    id       *values    = NULL;
    id       *keys      = NULL;
    
    /* Note: those are reused in the inner loop */
    attrCnt    = [attrs count];
    values     = calloc(attrCnt + 2, sizeof(id));
    keys       = calloc(attrCnt + 2, sizeof(id));
    fetchLimit = [self->fetchSpecification fetchLimit];
    
    while ((row = [adChan fetchAttributes:attrs withZone:NULL]) != nil) {
      NSEnumerator        *enumerator = nil;
      id                  attr        = nil;
      int                 rowCnt      = 0;
      NSDictionary        *r          = nil;
      id                  *pKeyVs     = NULL;
      int                 pKeyVCnt    = 0;

      pKeyVs     = calloc(pKeyCnt, sizeof(id));
      enumerator = [attrs objectEnumerator];
      
      while ((attr = [enumerator nextObject]) != nil) {
        id       obj;
        NSString *cn;

        obj = [row objectForKey:[(EOAttribute *)attr name]];
	
        if (obj == nil)
          continue;
	
        if (tz != nil && [obj isKindOfClass:NSCalendarDateClass])
	  [obj setTimeZone:tz];
	
        cn             = [[attr columnName] lowercaseString];
        values[rowCnt] = obj;
        keys[rowCnt]   = cn;
        rowCnt++;

        if ([pKeys containsObject:cn]) {
          int idx;

          idx = [pKeys indexOfObject:cn]; 
          NSAssert4(idx <= (pKeyCnt - 1) && pKeyVs[idx] == nil,
                    @"internal inconsistency in EOAdaptorDataSource "
                    @"while fetch idx[%d] > (pKeyCnt - 1)[%d] "
                    @"pKeyVs[idx] (%@[%d]);", idx, (pKeyCnt - 1),
                    pKeyVs[idx], idx);

          pKeyVs[idx] = obj;
          pKeyVCnt++;
        }
      }
      if (pKeyCnt != pKeyVCnt)
        NSAssert(NO, @"internal inconsistency in EOAdaptorDataSource "
                 @"while fetch");
      
      {
        EOGlobalID *gid;

        gid = [EOKeyGlobalID globalIDWithEntityName:entityName
                             keys:pKeyVs keyCount:pKeyVCnt zone:NULL];

        if (self->connectionDictionary) {
          gid = [[EOAdaptorGlobalID alloc] initWithGlobalID:gid
                                           connectionDictionary:
                                           self->connectionDictionary];
          AUTORELEASE(gid);
        }
        values[rowCnt] = gid;
        keys[rowCnt]   = @"globalID";
        rowCnt++;
      }
      fetchCnt++;
      r = [[NSMutableDictionary alloc]
	    initWithObjects:values forKeys:keys count:rowCnt];
      [result addObject:r];
      [r release]; r = nil;
      if (pKeyVs) free(pKeyVs); pKeyVs = NULL;
      if (fetchLimit == fetchCnt)
        break;
    }
    if (values) free(values); values = NULL;
    if (keys)   free(keys);   keys   = NULL;
  }
  [adChan cancelFetch];
  if (localComTrans)
    [self commitTransaction];
  
  [expression         release]; expression         = nil;
  [self->__qualifier  release]; self->__qualifier  = nil;
  [self->__attributes release]; self->__attributes = nil;
  return result;
}

- (id)createObject {
  return [NSMutableDictionary dictionary];
}

- (void)insertObject:(id)_obj {
  NSString         *key        = nil;
  NSString         *tableName  = nil;
  NSMutableString  *expression = nil;
  EOAdaptor        *adaptor    = nil;
  NSArray          *pKeys      = nil;
  id               obj         = nil;
  EOAdaptorChannel *adChan     = nil;
  
  int      oVCnt                = 0;
  NSString **objectKeyAttrValue = NULL;

  NSEnumerator *enumerator = nil;
  id           pKey        = nil;

  BOOL         localComTrans;

  if ([[self->adChannel adaptorContext] hasOpenTransaction])
    localComTrans = NO;
  else
    localComTrans = YES;

  adChan  = [self beginTransaction];
  adaptor = [[adChan adaptorContext] adaptor];

  if ((tableName = [self->fetchSpecification entityName]) == nil) {
    [self rollbackTransaction];
    [NSException raise:NSInvalidArgumentException
		 format:@"couldn`t insert obj %@ missing entityName in "
		 @"fetchSpecification", _obj];
  }
  
  /* create or apply primary keys */
#if EOAdaptorDataSource_DEBUG
  NSLog(@"insert obj %@", _obj);
#endif  
  
  pKeys = [self _primaryKeyAttributeNamesForTableName:tableName channel:adChan];

#if EOAdaptorDataSource_DEBUG  
  NSLog(@"got primary keys %@", pKeys);
#endif
  
  objectKeyAttrValue = calloc([pKeys count], sizeof(id));
  enumerator         = [pKeys objectEnumerator];
  
  while ((pKey = [enumerator nextObject])) {
    id pKeyObj;
    
    pKeyObj = [_obj valueForKey:pKey];

#if EOAdaptorDataSource_DEBUG
    NSLog(@"pk in obj %@:<%@> ", pKey, pKeyObj);
#endif
    
    if (![pKeyObj isNotNull]) {
      /* try to build primary key */
      NSString     *newKeyExpr = nil;
      NSDictionary *row        = nil;

#if EOAdaptorDataSource_DEBUG
      NSLog(@"pKeyObj !isNotNull");
#endif      
      
      if ([pKeys count] != 1) {
        [self rollbackTransaction];
	[NSException raise:NSInternalInconsistencyException
		     format:@"more than one primary key, "
		     @"and primary key for %@ is not set", pKey];
      }
      if (![adaptor respondsToSelector:@selector(newKeyExpression)]) {
        [self rollbackTransaction];
	[NSException raise:NSInternalInconsistencyException
		     format:@"got no newkey expression, insert failed"];
      }
      newKeyExpr = [(id)adaptor newKeyExpression];
      if (newKeyExpr == nil) {
        [self rollbackTransaction];
	[NSException raise:NSInternalInconsistencyException
		     format:@"missing newKeyExpression for adaptor[%@] %@...",
		       NSStringFromClass([adaptor class]), adaptor];
      }
      if (![adChan evaluateExpression:newKeyExpr]) {
        [adChan cancelFetch];
        [self rollbackTransaction];
        [[[EOAdaptorException alloc]
                 initWithFormat:@"couldn`t evaluate new key expression %@",
                 newKeyExpr] raise];
      }
      row = [adChan fetchAttributes:[adChan describeResults]
                    withZone:NULL];
      [adChan cancelFetch];
      if ((key = [[row objectEnumerator] nextObject]) == nil) {
        [self rollbackTransaction];
        [[[EOAdaptorException alloc]
                        initWithFormat:@"couldn`t fetch primary key"] raise];;
      }
      objectKeyAttrValue[oVCnt++] = key;
      [_obj takeValue:key forKey:pKey];
#if EOAdaptorDataSource_DEBUG
      NSLog(@"_obj %@ after takeValue:%@ forKey:%@", _obj, key, pKey);
#endif      
    }
    else {
      objectKeyAttrValue[oVCnt++] = pKeyObj;
#if EOAdaptorDataSource_DEBUG
      NSLog(@"objectKeyAttrValue takeValue %@ for idx %d", pKeyObj, oVCnt);
#endif      
    }
  }

  /* construct SQL INSERT expression .. */
  
  expression = [[NSMutableString alloc] initWithCapacity:256];
  [expression appendString:@"INSERT INTO "];
  [expression appendString:tableName];
  [expression appendString:@"("];
  {
    NSDictionary *objects    = nil;
    NSEnumerator *enumerator = nil;
    NSArray      *allKeys    = nil;
    BOOL         isFirst     = YES;
    
    objects    = [self _mapAttrsWithValues:_obj
                       tableName:tableName
                       channel:adChan];
    allKeys    = [objects allKeys];
    enumerator = [allKeys objectEnumerator];
    while ((obj = [enumerator nextObject])) {
      if (isFirst) 
	isFirst = NO;
      else 
	[expression appendString:@", "];
      [expression appendString:[adaptor formatAttribute:obj]];
    }
    [expression appendString:@") VALUES ("];
    enumerator = [allKeys objectEnumerator];
    isFirst = YES;
    while ((obj = [enumerator nextObject])) {
      id value;
        
      if (isFirst)
	isFirst = NO;
      else
	[expression appendString:@", "];
      value = [objects objectForKey:obj];
      if (value == nil) value = null;
      [expression appendString:[adaptor formatValue:value forAttribute:obj]];
    }
  }
  [expression appendString:@")"];

  /* execute insert in SQL server .. */
  
  if (![adChan evaluateExpression:expression]) {
    [adChan cancelFetch];
    enumerator = [pKeys objectEnumerator];
    while ((pKey = [enumerator nextObject])) {
      [_obj takeValue:[EONull null] forKey:pKey];
    }
    [self rollbackTransaction];
    AUTORELEASE(expression);
    [[[EOAdaptorException alloc]
       initWithFormat:@"evaluateExpression %@ failed", expression] raise];
  }
  [adChan cancelFetch];
  if (localComTrans)
    [self commitTransaction];

  /* construct new global id for record */
  
  {
    EOGlobalID *gid;
      
    gid = [EOKeyGlobalID globalIDWithEntityName:tableName
                         keys:objectKeyAttrValue keyCount:oVCnt zone:NULL];
    if (self->connectionDictionary != nil) {
      EOAdaptorGlobalID *agid = nil;

      agid = [[EOAdaptorGlobalID alloc] initWithGlobalID:gid
                                        connectionDictionary:
                                        self->connectionDictionary];
      AUTORELEASE(agid);
      gid = agid;
    }
    [_obj takeValue:gid forKey:@"globalID"];
  }
  
  RELEASE(expression); expression = NULL;
  
  /* mark datasource as changed */
  
  [self postDataSourceChangedNotification];
}

- (void)updateObject:(id)_obj {
  NSString         *whereClause = nil;
  NSMutableString  *expression  = nil;
  EOAdaptor        *adaptor     = nil;
  EOKeyGlobalID    *gid         = nil;
  NSEnumerator     *enumerator  = nil;
  NSString         *tableName   = nil;
  EOAttribute      *attr        = nil;
  BOOL             isFirst      = YES;
  NSDictionary     *objects     = nil;
  EOAdaptorChannel *adChan      = nil;

  BOOL localComTrans;
  
  if ((gid = [_obj valueForKey:@"globalID"]) == nil) {
    [NSException raise:NSInvalidArgumentException
		 format:@"missing globalID, couldn`t update"];
  }
  if ([gid isKindOfClass:[EOAdaptorGlobalID class]]) {
    NSDictionary *conD = nil;

    conD = [(EOAdaptorGlobalID *)gid connectionDictionary];
    if (![conD isEqualToDictionary:self->connectionDictionary]) {
      [NSException raise:NSInvalidArgumentException
		   format:@"try to update object %@ in "
		   @"wrong AdaptorDataSource %@", _obj, self];
    }
    gid = (EOKeyGlobalID *)[(EOAdaptorGlobalID *)gid globalID];
  }
  if ([[self->adChannel adaptorContext] hasOpenTransaction])
    localComTrans = NO;
  else
    localComTrans = YES;

  adChan      = [self beginTransaction];
  tableName   = [gid entityName];
  adaptor     = [[adChan adaptorContext] adaptor];
  whereClause = [self _whereClauseForGlobaID:gid adaptor:adaptor
                      channel:adChan];
  if (whereClause == nil) {
    [self rollbackTransaction];
    return;
  }
  expression = [[NSMutableString alloc] initWithCapacity:256];
  [expression appendString:@"UPDATE "];
  [expression appendString:[gid entityName]];
  [expression appendString:@" SET "];

  objects    = [self _mapAttrsWithValues:_obj tableName:tableName
                     channel:adChan];
  enumerator = [objects keyEnumerator];

  while ((attr = [enumerator nextObject])) {
    id value;
      
    if (isFirst)
      isFirst = NO;
    else
      [expression appendString:@", "];
    [expression appendString:[adaptor formatAttribute:attr]];
    [expression appendString:@"="];
      
    value = [objects objectForKey:attr];
    if (value == nil) value = null;
      
    [expression appendString:[adaptor formatValue:value forAttribute:attr]];
  }
  [expression appendString:@" WHERE "];
  [expression appendString:whereClause];
  if (![adChan evaluateExpression:expression]) {
    [adChan cancelFetch];
    [self rollbackTransaction];
    AUTORELEASE(expression);
    [[[EOAdaptorException alloc]
       initWithFormat:@"evaluate expression %@ failed", expression] raise];
  }
  [adChan cancelFetch];
  if (localComTrans)
    [self commitTransaction];
  
  RELEASE(expression); expression = nil;

  {
    EOGlobalID   *newGID;
    NSArray      *attrs;
    NSEnumerator *enumerator;
    id           *objs;
    int          objCnt;
    NSString     *attr;

    attrs      = [self _primaryKeyAttributeNamesForTableName:[gid entityName]
                       channel:adChan];
    enumerator = [attrs objectEnumerator];
    objCnt     = 0;
    objs       = calloc([attrs count], sizeof(id));
    
    while ((attr = [enumerator nextObject])) {
      objs[objCnt] = [_obj valueForKey:attr];
      objCnt++;
    }
    newGID = [EOKeyGlobalID globalIDWithEntityName:[gid entityName]
                            keys:objs keyCount:objCnt zone:NULL];
    if (self->connectionDictionary != nil) {
      newGID = [[EOAdaptorGlobalID alloc] initWithGlobalID:newGID
                                          connectionDictionary:
                                          self->connectionDictionary];
      [newGID autorelease];
    }
    [(NSMutableDictionary *)_obj setObject:newGID forKey:@"globalID"];
  }
  [self postDataSourceChangedNotification];  
}

- (void)deleteObject:(id)_obj {
  NSString         *whereClause = nil;
  NSMutableString  *expression  = nil;
  EOKeyGlobalID    *gid         = nil;
  EOAdaptorChannel *adChan      = nil;

  BOOL localComTrans;

  if ((gid = [_obj valueForKey:@"globalID"]) == nil) {
    [NSException raise:NSInvalidArgumentException
		 format:@"missing globalID, could not delete"];
  }
  if ([gid isKindOfClass:[EOAdaptorGlobalID class]]) {
    NSDictionary *conD = nil;

    conD = [(EOAdaptorGlobalID *)gid connectionDictionary];
    if (![conD isEqualToDictionary:self->connectionDictionary]) {
      [NSException raise:NSInvalidArgumentException
		   format:@"try to delete object %@ in wrong "
		   @"AdaptorDataSource %@", _obj, self];
    }
    gid = (EOKeyGlobalID *)[(EOAdaptorGlobalID *)gid globalID];
  }
  
  if ([[self->adChannel adaptorContext] hasOpenTransaction])
    localComTrans = NO;
  else
    localComTrans = YES;
  
  adChan      = [self beginTransaction];
  whereClause = [self _whereClauseForGlobaID:gid
                      adaptor:[[adChan adaptorContext] adaptor] channel:adChan];
  if (whereClause == nil) {
    [self rollbackTransaction];
    return;
  }
  expression = [[NSMutableString alloc] initWithCapacity:256];
  [expression appendString:@"DELETE FROM "];
  [expression appendString:[gid entityName]];
  [expression appendString:@" WHERE "];
  [expression appendString:whereClause];
  if (![adChan evaluateExpression:expression]) {
    [adChan cancelFetch];
    [self rollbackTransaction];
    AUTORELEASE(expression);
    [[[EOAdaptorException alloc]
       initWithFormat:@"couldn`t evaluate expression %@ failed",
       expression] raise];
  }
  [adChan cancelFetch];
  if (localComTrans)
    [self commitTransaction];
  RELEASE(expression); expression = nil;
  [self postDataSourceChangedNotification];    
}

- (void)setFetchSpecification:(EOFetchSpecification *)_fs {
  if (![self->fetchSpecification isEqual:_fs]) {
#if DEBUG && 0
    NSLog(@"%s: 0x%p: fetch-spec mismatch:\n%@\n%@",
          __PRETTY_FUNCTION__, self,
          self->fetchSpecification, _fs);
#endif
    
    ASSIGNCOPY(self->fetchSpecification, _fs);
    
    [self postDataSourceItselfChangedNotification];
  }
#if DEBUG && 0
  else {
    NSLog(@"%s: 0x%p: no fetch-spec mismatch:\n%@\n%@\n",
          __PRETTY_FUNCTION__, self,
          self->fetchSpecification, _fs);
  }
#endif
}

- (EOFetchSpecification *)fetchSpecification {
  /* 
     Note: the copy is intended, since the fetchspec is mutable, the consumer
           could otherwise modify it "behind the scenes"
  */
  return [[self->fetchSpecification copy] autorelease];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<%@[0x%p]:", NSStringFromClass([self class]), self];

  if (self->fetchSpecification != nil)
    [ms appendFormat:@" fspec=%@", self->fetchSpecification];
  if (self->adChannel != nil)
    [ms appendFormat:@" channel=%@", self->adChannel];
  
  [ms appendString:@">"];
  return ms;
}

@end /* EOAdaptorDataSource */

@implementation EOAdaptorDataSource(Private)

- (NSArray *)_primaryKeyAttributeNamesForTableName:(NSString *)_entityName
  channel:(EOAdaptorChannel *)_adChannel
{
  NSDictionary *hints;
  NSArray *attrs;
  
  hints = [self->fetchSpecification hints];
  attrs = [hints objectForKey:EOPrimaryKeyAttributeNamesHint];
  if (attrs)
    return attrs;
  
  attrs = [hints objectForKey:EOPrimaryKeyAttributesHint];
  
  if (attrs == nil) {
    if (!(attrs = [_adChannel primaryKeyAttributesForTableName:_entityName])) {
      attrs = [_adChannel attributesForTableName:_entityName];
    }
  }
  
  attrs = [[attrs map:@selector(columnName)] map:@selector(lowercaseString)];
  attrs = [attrs sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
  
  return attrs;
}

- (NSArray *)_primaryKeyAttributesForTableName:(NSString *)_entityName
  channel:(EOAdaptorChannel *)_adChannel
{
  NSArray      *attrs;
  NSDictionary *hints;

  hints = [self->fetchSpecification hints];

  attrs = [hints objectForKey:EOPrimaryKeyAttributesHint];
  if (attrs != nil)
    return attrs;
  
  attrs = [hints objectForKey:EOPrimaryKeyAttributeNamesHint];
  if (attrs != nil) {
    NSArray      *allAttrs;
    NSEnumerator *enumerator;
    id           *objs;
    int          objCnt;
    id           obj;

    allAttrs   = [_adChannel attributesForTableName:_entityName];
    objs       = malloc(sizeof(id) * [allAttrs count]);
    enumerator = [allAttrs objectEnumerator];

    objCnt = 0;
    
    while ((obj = [enumerator nextObject])) {
      if ([attrs containsObject:[[obj columnName] lowercaseString]]) {
        objs[objCnt++] = obj;
      }
    }
    attrs = [NSArray arrayWithObjects:objs count:objCnt];
    free(objs); objs = NULL;
    return attrs;
  }
  if (!(attrs = [_adChannel primaryKeyAttributesForTableName:_entityName])) {
    attrs = [_adChannel attributesForTableName:_entityName];
  }
  return attrs;
}

- (NSString *)_whereExprWithChannel:(EOAdaptorChannel *)_adChan {
  EOQualifier *qual       = nil;
  NSArray     *attrs      = nil;
  NSString    *entityName = nil;
  EOAdaptor   *adaptor;

  entityName = [self->fetchSpecification entityName];
  
  if ((attrs = self->__attributes) == nil)
    attrs = [_adChan attributesForTableName:entityName];
  
  if ((qual = self->__qualifier) == nil)
    qual = [self->fetchSpecification qualifier];

  if (qual == nil)
    return nil;
  
  adaptor = [[_adChan adaptorContext] adaptor];

  return [qual sqlExpressionWithAdaptor:adaptor attributes:attrs];
}

- (NSException *)_couldNotFindSortAttributeInAttributes:(NSArray *)_attrs
  forSortOrdering:(EOSortOrdering *)_so
{
  return [[InvalidAttributeException alloc]
	   initWithFormat:@"could not find EOAttribute for SortOrdering"
	   @" %@ Attributes %@", _so, _attrs];
}

- (EOAttribute *)findAttributeForKey:(NSString *)key 
  inAttributes:(NSArray *)_attrs
{
  NSEnumerator *en;
  EOAttribute  *obj;
  
  key = [key lowercaseString];
  en  = [_attrs objectEnumerator];
  while ((obj = [en nextObject]) != nil) {
    if ([[[obj columnName] lowercaseString] isEqualToString:key])
      break;
  }
  return obj;
}

- (NSString *)_orderByExprForAttributes:(NSArray *)_attrs 
  andPatchSelectList:(NSMutableString *)selectList
  withChannel:(EOAdaptorChannel *)_adChan
{
  NSMutableString *orderByExpr;
  NSEnumerator   *enumerator   = nil;
  EOSortOrdering *sortOrdering = nil;
  int            orderCnt      = 0;
  EOAdaptor      *adaptor;

  adaptor = [[_adChan adaptorContext] adaptor];
  
  orderByExpr = nil;
  enumerator = [[self->fetchSpecification sortOrderings] objectEnumerator];
  while ((sortOrdering = [enumerator nextObject]) != nil) {
      SEL         selector    = NULL;
      NSString    *key        = nil;
      EOAttribute *keyAttr    = nil;
      int         order       = 0; /* 0 - not used; 1 - asc; 2 - desc */
      BOOL        inSensitive = NO;
      NSString    *orderTmp   = nil;

      if (orderByExpr == nil)
        orderByExpr = [NSMutableString stringWithCapacity:64];
      else
        [orderByExpr appendString:@", "];
      
      if ((selector = [sortOrdering selector])) {
        if (SEL_EQ(selector, EOCompareAscending))
          order = 1;
        else if (SEL_EQ(selector, EOCompareDescending))
          order = 2;
        else if (SEL_EQ(selector, EOCompareCaseInsensitiveAscending)) {
	  order       = 1;
	  inSensitive = YES;
	}
        else if (SEL_EQ(selector, EOCompareCaseInsensitiveDescending)) {
	  order       = 2;
	  inSensitive = YES;
	}
      }
      key = [sortOrdering key];
      
      if (key == nil || [key length] == 0) {
        NSLog(@"WARNING[%s]: no key in sortordering %@",
	      __PRETTY_FUNCTION__, key);
        continue;
      }
      {
        EOAttribute  *obj;
	
        key = [key lowercaseString];
	obj = [self findAttributeForKey:key inAttributes:_attrs];
        if (obj == nil) {
          [self->__attributes release]; self->__attributes = nil;
          [self->__qualifier  release]; self->__qualifier  = nil;
#if 0 // TODO: memleak in error case
          [expression         release]; expression         = nil;
#endif
          [self rollbackTransaction];
	  
	  [[self _couldNotFindSortAttributeInAttributes:_attrs
		 forSortOrdering:sortOrdering] raise];
	  return nil;
        }
	
        keyAttr = obj;
      }
      key      = [adaptor formatAttribute:keyAttr];
      orderTmp = [NSString stringWithFormat:@"order%d", orderCnt];
      orderCnt++;
      [orderByExpr appendString:orderTmp];
      if (order == 1)
        [orderByExpr appendString:@" ASC"];
      else if (order == 2)
        [orderByExpr appendString:@" DESC"];
      
      /* manipulate select expr */
      if (inSensitive) {
          if ([[keyAttr valueClassName] isEqualToString:@"NSString"]) {
              key = [NSString stringWithFormat:@"LOWER(%@)", key];
          }
          else
            NSLog(@"WARNING[%s]: inSensitive expression for no text attribute",
                  __PRETTY_FUNCTION__);
      }
      {
	NSString *str = nil;

	str = [key stringByAppendingString:@" AS "];
	str = [str stringByAppendingString:orderTmp];
	str = [str stringByAppendingString:@", "];
	
	[selectList insertString:str atIndex:0];
      }
  }
  return orderByExpr;
}

- (NSMutableString *)_selectListWithChannel:(EOAdaptorChannel *)_adChan {
  NSArray         *attrs      = nil;
  NSEnumerator    *enumerator = nil;
  EOAttribute     *attribute  = nil;
  BOOL            first       = YES;
  NSMutableString *select     = nil;
  EOAdaptor       *adaptor    = nil;
  NSString        *entityName = nil;
  
  adaptor    = [[_adChan adaptorContext] adaptor];
  entityName = [self->fetchSpecification entityName];
    
  if ((attrs = self->__attributes) == nil)
    attrs = [_adChan attributesForTableName:entityName];

  attrs  = [_adChan _sortAttributesForSelectExpression:attrs];
  select = [NSMutableString stringWithCapacity:128];
  enumerator = [attrs objectEnumerator];
  while ((attribute = [enumerator nextObject])) {
    if (first)
      first = NO;
    else
      [select appendString:@", "];

    [select appendString:[adaptor formatAttribute:attribute]];
  }
  return select;
}

- (NSString *)_whereClauseForGlobaID:(EOKeyGlobalID *)_gid
  adaptor:(EOAdaptor *)_adaptor
  channel:(EOAdaptorChannel *)_adChan
{
  NSEnumerator    *enumerator;
  NSMutableString *result;
  NSArray         *pKeys;
  NSArray         *pkAttrs;
  NSString        *pKey;
  int             pkCnt;


  pKeys   = [self _primaryKeyAttributeNamesForTableName:[_gid entityName]
                  channel:_adChan];
  pkAttrs = [self _primaryKeyAttributesForTableName:[_gid entityName]
                  channel:_adChan];
  

  if ([pKeys count] != [_gid keyCount]) {
    NSLog(@"ERROR[%s]: internal inconsitency pkeys %@ gid %@",
          __PRETTY_FUNCTION__, pKeys, _gid);
    return nil;
  }
  enumerator = [pKeys objectEnumerator];

  pkCnt  = 0;
  result = nil;
  while ((pKey = [enumerator nextObject])) {
    EOAttribute *attr;
    id          value;

    if (result == nil)
      result = [NSMutableString stringWithCapacity:128];
    else
      [result appendString:@" AND "];

    {
      NSEnumerator *enumerator;

      enumerator = [pkAttrs objectEnumerator];
      while ((attr = [enumerator nextObject])) {
        if ([[[attr columnName] lowercaseString] isEqual:pKey])
          break;
      }
      NSAssert2(attr != nil, @"missing attribute for pkName %@ attrs %@",
                pKey, pkAttrs);
    }
    [result appendString:[_adaptor formatAttribute:attr]];

    
    value = [(EOKeyGlobalID *)_gid keyValues][pkCnt++];
    if (value == nil) value = null;
    
    [result appendString:[value isNotNull] ? @"=" : @" IS "];
    [result appendString:[_adaptor formatValue:value forAttribute:attr]];
  }
  return result;
}

- (NSDictionary *)_mapAttrsWithValues:(NSDictionary *)_keyValues
  tableName:(NSString *)_tableName
  channel:(EOAdaptorChannel *)_adChan
{
  id           *keys, *values;
  int          mapCnt;
  NSEnumerator *en;
  EOAttribute  *attr;
  NSDictionary *result;
  NSArray      *attrs;

  attrs  = [_adChan attributesForTableName:_tableName];
  mapCnt = [attrs count];  
  keys   = calloc(mapCnt + 1, sizeof(id));
  values = calloc(mapCnt + 1, sizeof(id));
  en     = [attrs objectEnumerator];
  mapCnt = 0;
  
  while ((attr = [en nextObject])) {
    id v;

    v = (v = [_keyValues valueForKey:[[attr columnName] lowercaseString]])
      ? v : (id)null;
    
    keys[mapCnt]   = attr;
    values[mapCnt] = v;
    mapCnt++;
  }
  result = [[NSDictionary alloc]
                          initWithObjects:values forKeys:keys count:mapCnt];
  free(keys);   keys   = NULL;
  free(values); values = NULL;
  return [result autorelease];
}

@end /* EOAdaptorDataSource(Private) */

@implementation EOAndQualifier(SqlExpression)

- (NSString *)sqlExpressionWithAdaptor:(EOAdaptor *)_adaptor
  attributes:(NSArray *)_attributes
{
  NSMutableString *str        = nil;
  NSEnumerator    *enumerator = nil;
  EOQualifier     *qual       = nil;
  BOOL            isFirst     = YES;
  NSString        *result     = nil;

  str = [[NSMutableString alloc] initWithCapacity:128];

  enumerator = [self->qualifiers objectEnumerator];
  while ((qual = [enumerator nextObject])) {
    NSString *s;
    
    s = [qual sqlExpressionWithAdaptor:_adaptor attributes:_attributes];
    if (isFirst) {
      [str appendFormat:@"(%@)", s];
      isFirst = NO;
    }
    else
      [str appendFormat:@" AND (%@)", s];
  }
  result = [str copy];
  [str release]; str = nil;
  return [result autorelease];
}
@end /* EOAndQualifier(SqlExpression) */

@implementation EOOrQualifier(SqlExpression)

- (NSString *)sqlExpressionWithAdaptor:(EOAdaptor *)_adaptor
  attributes:(NSArray *)_attributes
{
  NSMutableString *str        = nil;
  NSEnumerator    *enumerator = nil;
  EOQualifier     *qual       = nil;
  BOOL            isFirst     = YES;
  NSString        *result     = nil;

  str = [[NSMutableString alloc] initWithCapacity:128];

  enumerator = [self->qualifiers objectEnumerator];
  while ((qual = [enumerator nextObject])) {
    NSString *s;

    s = [qual sqlExpressionWithAdaptor:_adaptor attributes:_attributes];
    if (isFirst) {
      [str appendFormat:@"(%@)", s];
      isFirst = NO;
    }
    else
      [str appendFormat:@" OR (%@)", s];
  }
  result = [str copy];
  [str release]; str = nil;
  return [result autorelease];
}

@end /* EOOrQualifier(SqlExpression) */

@implementation EOKeyValueQualifier(SqlExpression)

+ (NSString *)sqlStringForOperatorSelector:(SEL)_sel {
  static NSMapTable *selectorToOperator = NULL;
  NSString *s, *ss;
  
  if ((s = NSStringFromSelector(_sel)) == nil)
    return nil;

  if (selectorToOperator == NULL) {
    selectorToOperator = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                          NSObjectMapValueCallBacks,
                                          10);
    NSMapInsert(selectorToOperator,
                NSStringFromSelector(EOQualifierOperatorEqual),
                @"=");
    NSMapInsert(selectorToOperator,
                NSStringFromSelector(EOQualifierOperatorNotEqual),
                @"<>");
    NSMapInsert(selectorToOperator,
                NSStringFromSelector(EOQualifierOperatorLessThan),
                @"<");
    NSMapInsert(selectorToOperator,
                NSStringFromSelector(EOQualifierOperatorGreaterThan),
                @">");
    NSMapInsert(selectorToOperator,
                NSStringFromSelector(EOQualifierOperatorLessThanOrEqualTo),
                @"<=");
    NSMapInsert(selectorToOperator,
                NSStringFromSelector(EOQualifierOperatorGreaterThanOrEqualTo),
                @">=");
  }
  
  if ((ss = NSMapGet(selectorToOperator, s)))
    return ss;
  
  return nil;
}

- (NSString *)sqlExpressionWithAdaptor:(EOAdaptor *)_adaptor
  attributes:(NSArray *)_attributes
{
  EOAttribute  *attr = nil;
  NSEnumerator *en   = nil;
  NSString     *k    = nil;
  NSString     *sql  = nil;
  NSString     *sqlKey, *sqlValue;

  k  = [self->key lowercaseString];
  en = [_attributes objectEnumerator];
  
  while ((attr = [en nextObject])) {
    if ([[[attr columnName] lowercaseString] isEqualToString:k]) {
      break;
    }
  }
  if (!attr) {
    en = [_attributes objectEnumerator];
    while ((attr = [en nextObject])) {
      if ([[attr name] isEqualToString:self->key])
        break;
    }
  }
  if (!attr) {
    NSLog(@"WARNING[%s]: missing attribute [%@] for qualifier %@",
          __PRETTY_FUNCTION__,
          _attributes, self);
    return @"1=2";
  }
  
  sqlKey   = [_adaptor formatAttribute:attr];

  sqlValue = [_adaptor formatValue:(self->value ? self->value : (id)null)
                       forAttribute:attr];

  sql = nil;
  
  if (SEL_EQ(EOQualifierOperatorEqual, self->operator)) {
    if ([self->value isNotNull])
      sql = [NSString stringWithFormat:@"%@ = %@", sqlKey, sqlValue];
    else
      sql = [NSString stringWithFormat:@"%@ IS NULL", sqlKey];
  }
  else if (SEL_EQ(EOQualifierOperatorNotEqual, self->operator)) {
    if ([self->value isNotNull])
      sql = [NSString stringWithFormat:@"NOT (%@ = %@)", sqlKey, sqlValue];
    else
      sql = [NSString stringWithFormat:@"%@ IS NOT NULL", sqlKey];
  }
  else if (SEL_EQ(EOQualifierOperatorLessThan, self->operator)) {
    sql = [NSString stringWithFormat:@"%@ < %@", sqlKey, sqlValue];
  }
  else if (SEL_EQ(EOQualifierOperatorLessThanOrEqualTo, self->operator)) {
    sql = [NSString stringWithFormat:@"%@ <= %@", sqlKey, sqlValue];
  }
  else if (SEL_EQ(EOQualifierOperatorGreaterThan, self->operator)) {
    sql = [NSString stringWithFormat:@"%@ > %@", sqlKey, sqlValue];
  }
  else if (SEL_EQ(EOQualifierOperatorGreaterThanOrEqualTo, self->operator)) {
    sql = [NSString stringWithFormat:@"%@ >= %@", sqlKey, sqlValue];
  }
  else if (SEL_EQ(EOQualifierOperatorLike, self->operator)) {
    sqlValue = [[self->value stringValue]
                             stringByReplacingString:@"*" withString:@"%"];
    sqlValue = [_adaptor formatValue:sqlValue forAttribute:attr];
    
    sql = [NSString stringWithFormat:@"%@ LIKE %@", sqlKey, sqlValue];
  }
  else if (SEL_EQ(EOQualifierOperatorCaseInsensitiveLike, self->operator)) {
    sqlValue = [[self->value stringValue]
                             stringByReplacingString:@"*" withString:@"%"];
    sqlValue = [sqlValue lowercaseString];
    sqlValue = [_adaptor formatValue:sqlValue forAttribute:attr];
    
    sql = [NSString stringWithFormat:@"LOWER(%@) LIKE %@", sqlKey, sqlValue];
  }
#if 0
  else if (SEL_EQ(EOQualifierOperatorLessThanOrEqualTo, self->operator)) {
  }
  else if (SEL_EQ(EOQualifierOperatorGreaterThanOrEqualTo, self->operator)) {
  }
#endif
  else {
    NSLog(@"ERROR(%s): unsupported SQL operator: %@", __PRETTY_FUNCTION__,
          [EOQualifier stringForOperatorSelector:self->operator]);
    [self notImplemented:_cmd];
    return nil;
  }
  
  return sql;
}

@end /* EOKeyValueQualifier(SqlExpression) */

@implementation EONotQualifier(SqlExpression)

- (NSString *)sqlExpressionWithAdaptor:(EOAdaptor *)_adaptor
  attributes:(NSArray *)_attributes
{
  NSString *s;
  
  s = [self->qualifier sqlExpressionWithAdaptor:_adaptor 
	               attributes:_attributes];
  return [NSString stringWithFormat:@"NOT(%@)", s];
}

@end /* EONotQualifier(SqlExpression) */

@implementation EOKeyComparisonQualifier(SqlExpression)

- (NSString *)sqlExpressionWithAdaptor:(EOAdaptor *)_adaptor
  attributes:(NSArray *)_attributes
{
  NSLog(@"ERROR(%s): subclass needs to override this method!", 
	__PRETTY_FUNCTION__);
  return nil;
}

@end /* EOKeyComparisonQualifier(SqlExpression) */
