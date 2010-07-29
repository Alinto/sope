/* 
   EOAdaptorChannel.h

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: October 1996

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

#ifndef __EOAdaptorChannel_h__
#define __EOAdaptorChannel_h__

#import <Foundation/NSObject.h>

@class NSArray, NSMutableArray, NSDictionary, NSMutableDictionary, NSString;
@class NSMutableString, NSCalendarDate, NSException;

@class EOModel, EOEntity, EOAttribute, EOSQLQualifier, EOAdaptorContext;

/* 
   The EOAdaptorChannel class can be subclassed in a database adaptor. You have
   to override only those methods marked in this header with `override'.
*/

@interface EOAdaptorChannel : NSObject
{
@protected
  EOAdaptorContext *adaptorContext;
  id               delegate;    // not retained
  
  /* Flags that determine the state of the adaptor */
  BOOL          isFetchInProgress;
  BOOL          isOpen;
  BOOL          debugEnabled;

  /* Flags used to check if the delegate responds to several messages */
  struct {
    BOOL willInsertRow:1;
    BOOL didInsertRow:1;
    BOOL willUpdateRow:1;
    BOOL didUpdateRow:1;
    BOOL willDeleteRows:1;
    BOOL didDeleteRows:1;
    BOOL willSelectAttributes:1;
    BOOL didSelectAttributes:1;
    BOOL willFetchAttributes:1;
    BOOL didFetchAttributes:1;
    BOOL didChangeResultSet:1;
    BOOL didFinishFetching:1;
    BOOL willEvaluateExpression:1;
    BOOL didEvaluateExpression:1;
  } delegateRespondsTo;
}

+ (NSCalendarDate*)dateForAttribute:(EOAttribute*)attr 
  year:(int)year month:(unsigned)month day:(unsigned)day 
  hour:(unsigned)hour minute:(unsigned)minute second:(unsigned)second 
  zone:(NSZone*)zone;

/* Initializing an adaptor context */
- (id)initWithAdaptorContext:(EOAdaptorContext*)adaptorContext;

/* Getting the adaptor context */
- (EOAdaptorContext*)adaptorContext;

/* Opening and closing a channel */
- (BOOL)isOpen;
- (BOOL)openChannel;
- (void)closeChannel;

/* Modifying rows, new world methods */
- (NSException *)insertRowX:(NSDictionary *)_row forEntity:(EOEntity *)_entity;
- (NSException *)updateRowX:(NSDictionary*)aRow
  describedByQualifier:(EOSQLQualifier*)aQualifier;
- (NSException *)deleteRowsDescribedByQualifierX:(EOSQLQualifier*)aQualifier;

/* Modifying rows, old world methods (DEPRECATED) */
- (BOOL)insertRow:(NSDictionary *)aRow forEntity:(EOEntity *)anEntity;
- (BOOL)updateRow:(NSDictionary *)aRow
  describedByQualifier:(EOSQLQualifier *)aQualifier;
- (BOOL)deleteRowsDescribedByQualifier:(EOSQLQualifier *)aQualifier;

/* Fetching rows */
- (BOOL)selectAttributes:(NSArray *)attributes
  describedByQualifier:(EOSQLQualifier *)aQualifier
  fetchOrder:(NSArray *)aFetchOrder
  lock:(BOOL)aLockFlag;
- (NSException *)selectAttributesX:(NSArray *)attributes
  describedByQualifier:(EOSQLQualifier *)aQualifier
  fetchOrder:(NSArray *)aFetchOrder
  lock:(BOOL)aLockFlag;
- (NSArray *)describeResults:(BOOL)_beautifyNames;              // override
- (NSArray *)describeResults;
- (NSMutableDictionary*)fetchAttributes:(NSArray *)attributes 
  withZone:(NSZone *)zone;
- (BOOL)isFetchInProgress;
- (void)cancelFetch;                                            // override
- (NSMutableDictionary *)dictionaryWithObjects:(id *)objects 
  forAttributes:(NSArray *)attributes zone:(NSZone *)zone;
- (NSMutableDictionary *)primaryFetchAttributes:(NSArray *)attributes 
  withZone:(NSZone *)zone;                                       // override

/* Sending SQL to the server */
- (BOOL)evaluateExpression:(NSString *)_anExpression;           // override
- (NSException *)evaluateExpressionX:(NSString*)_sql;

/* Getting schema information */
- (EOModel*)describeModelWithTableNames:(NSArray*)tableNames;   // override
- (NSArray*)describeTableNames;                                 // override
- (BOOL)readTypesForEntity:(EOEntity*)anEntity;                 // override
- (BOOL)readTypeForAttribute:(EOAttribute*)anAttribute;         // override

/* Debugging */
- (void)setDebugEnabled:(BOOL)flag;
- (BOOL)isDebugEnabled;

/* Setting the channel's delegate */
- (id)delegate;
- (void)setDelegate:aDelegate;

@end /* EOAdaptorChannel*/

@interface EOAdaptorChannel(PrimaryKeyGeneration) // new in EOF2

- (NSDictionary *)primaryKeyForNewRowWithEntity:(EOEntity *)_entity;

@end

@class EOEntity, EOFetchSpecification;

@interface EOAdaptorChannel(EOF2Additions)

- (void)selectAttributes:(NSArray *)_attributes
  fetchSpecification:(EOFetchSpecification *)_fspec
  lock:(BOOL)_flag
  entity:(EOEntity *)_entity;

- (void)setAttributesToFetch:(NSArray *)_attributes;
- (NSArray *)attributesToFetch;

- (NSMutableDictionary *)fetchRowWithZone:(NSZone *)_zone;

@end

#import <GDLAccess/EODelegateResponse.h>

@interface NSObject(EOAdaptorChannelDelegation)

- (EODelegateResponse)adaptorChannel:aChannel
  willInsertRow:(NSMutableDictionary*)aRow
  forEntity:(EOEntity*)anEntity;
- (void)adaptorChannel:channel
  didInsertRow:(NSDictionary*)aRow
  forEntity:(EOEntity*)anEntity;
- (EODelegateResponse)adaptorChannel:aChannel
  willUpdateRow:(NSMutableDictionary*)aRow
  describedByQualifier:(EOSQLQualifier*)aQualifier;
- (void)adaptorChannel:aChannel
  didUpdateRow:(NSDictionary*)aRow
  describedByQualifier:(EOSQLQualifier*)aQualifier;
- (EODelegateResponse)adaptorChannel:aChannel
  willDeleteRowsDescribedByQualifier:(EOSQLQualifier*)aQualifier;
- (void)adaptorChannel:aChannel
  didDeleteRowsDescribedByQualifier:(EOSQLQualifier*)aQualifier;
- (EODelegateResponse)adaptorChannel:aChannel
  willSelectAttributes:(NSMutableArray*)attributes
  describedByQualifier:(EOSQLQualifier*)aQualifier
  fetchOrder:(NSMutableArray*)aFetchOrder
  lock:(BOOL)aLockFlag;
- (void)adaptorChannel:aChannel
  didSelectAttributes:(NSArray*)attributes
  describedByQualifier:(EOSQLQualifier*)aQualifier
  fetchOrder:(NSArray*)aFetchOrder
  lock:(BOOL)aLockFlag;
- (NSMutableDictionary*)adaptorChannel:aChannel
  willFetchAttributes:(NSArray*)attributes
  withZone:(NSZone*)zone;
- (NSMutableDictionary*)adaptorChannel:aChannel
  didFetchAttributes:(NSMutableDictionary*)attributes
  withZone:(NSZone*)zone;
- (void)adaptorChannelDidChangeResultSet:aChannel;
- (void)adaptorChannelDidFinishFetching:aChannel;
- (EODelegateResponse)adaptorChannel:aChannel 
  willEvaluateExpression:(NSMutableString*)anExpression;
- (void)adaptorChannel:aChannel
  didEvaluateExpression:(NSString*)anExpression;

@end /* NSObject(EOAdaptorChannelDelegation) */

#endif /* __EOAdaptorChannel_h__ */
