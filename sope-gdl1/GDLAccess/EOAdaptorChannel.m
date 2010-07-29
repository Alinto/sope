/* 
   EOAdaptorChannel.m

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

#import "common.h"
#import "EOAdaptorChannel.h"
#import "EOAttribute.h"
#import "EOAdaptor.h"
#import "EOAdaptorContext.h"
#import "EOSQLExpression.h"
#import "EOFExceptions.h"

@interface EOAdaptorChannel(Internals)
- (NSArray *)_sortAttributesForSelectExpression:(NSArray *)_attrs;
@end /* EOAdaptorChannel(Internals) */

@implementation EOAdaptorChannel

+ (NSCalendarDate*)dateForAttribute:(EOAttribute*)attr 
  year:(int)year month:(unsigned)month day:(unsigned)day 
  hour:(unsigned)hour minute:(unsigned)minute second:(unsigned)second 
  zone:(NSZone*)zone
{
  NSTimeZone     *serverTimeZone = [attr serverTimeZone];
  NSTimeZone     *clientTimeZone = [attr clientTimeZone];
  NSCalendarDate *date;
  NSString       *fmt;

  if (serverTimeZone == nil) serverTimeZone = [NSTimeZone localTimeZone];
  if (clientTimeZone == nil) clientTimeZone = [NSTimeZone localTimeZone];
    
  date = AUTORELEASE([[NSCalendarDate allocWithZone:zone]
		       initWithYear:year month:month day:day hour:hour
		       minute:minute second:second timeZone:serverTimeZone]);
  [date setTimeZone:clientTimeZone];
  fmt = [attr calendarFormat];
  [date setCalendarFormat:fmt ? fmt : [EOAttribute defaultCalendarFormat]];
  return date;
}

- (id)initWithAdaptorContext:(EOAdaptorContext*)_adaptorContext {
    ASSIGN(self->adaptorContext, _adaptorContext);
    
    NS_DURING
        [self->adaptorContext channelDidInit:self];
    NS_HANDLER {
      AUTORELEASE(self);
      [localException raise];
    }
    NS_ENDHANDLER;
    
    return self;
}

- (void)dealloc {
  [self->adaptorContext channelWillDealloc:self];
  RELEASE(self->adaptorContext);
  [super dealloc];
}

/* open/close channel */

- (BOOL)openChannel {
  if(self->isOpen)
    return NO;
  self->isOpen = YES;

  return YES;
}

- (void)closeChannel {
  if ([self isFetchInProgress])
    [self cancelFetch];
  self->isOpen = NO;
}

/* modifications */

- (Class)_adaptorExpressionClass {
  return [[self->adaptorContext adaptor] expressionClass];
}

- (BOOL)_isNoRaiseOnModificationException:(NSException *)_exception {
  /* for compatibility with non-X methods, translate some errors to a bool */
  NSString *n;
  
  n = [_exception name];
  if ([n isEqualToString:@"EOEvaluationError"])
    return YES;
  if ([n isEqualToString:@"EODelegateRejects"])
    return YES;

  return NO;
}

- (NSException *)insertRowX:(NSDictionary *)row forEntity:(EOEntity *)entity {
  EOSQLExpression     *sqlexpr;
  NSMutableDictionary *mrow = (id)row;
  NSException         *ex;
    
  if (!isOpen)
    return [[ChannelIsNotOpenedException new] autorelease];
  
  if ((row == nil) || (entity == nil)) {
    return [NSException exceptionWithName:NSInvalidArgumentException
			reason:@"row and entity arguments for "
			  @"insertRow:forEntity: must not be the nil object"
			userInfo:nil];
  }
    
  if ([self isFetchInProgress])
    return [AdaptorIsFetchingException exceptionWithAdaptor:self];
  
  if ([self->adaptorContext transactionNestingLevel] == 0)
    return [NoTransactionInProgressException exceptionWithAdaptor:self];
  
  if (delegateRespondsTo.willInsertRow) {
    EODelegateResponse response;
	
    mrow = AUTORELEASE([row mutableCopyWithZone:[row zone]]);
    response = [delegate adaptorChannel:self
			 willInsertRow:mrow
			 forEntity:entity];
    if (response == EODelegateRejects) {
      return [NSException exceptionWithName:@"EODelegateRejects"
			  reason:@"delegate rejected insert"
			  userInfo:nil];
    }
    if (response == EODelegateOverrides)
      return nil;
  }

  sqlexpr = [[[self->adaptorContext adaptor]
                              expressionClass]
                              insertExpressionForRow:mrow
                              entity:entity
                              channel:self];
  
  ex = [self evaluateExpressionX:[sqlexpr expressionValueForContext:nil]];
  if (ex != nil)
    return ex;

  if(delegateRespondsTo.didInsertRow)
    [delegate adaptorChannel:self didInsertRow:mrow forEntity:entity];

  return nil;
}

- (NSException *)updateRowX:(NSDictionary *)row
  describedByQualifier:(EOSQLQualifier *)qualifier
{
  EOSQLExpression     *sqlexpr = nil;
  NSMutableDictionary *mrow    = (id)row;
  NSException *ex;

  if (!isOpen)
    return [[ChannelIsNotOpenedException new] autorelease];

  if (row == nil) {
    return [NSException exceptionWithName:NSInvalidArgumentException
			reason:
			  @"row argument for updateRow:describedByQualifier: "
                          @"must not be the nil object"
			userInfo:nil];
  }
  
  if ([self isFetchInProgress])
    return [AdaptorIsFetchingException exceptionWithAdaptor:self];

  if ([self->adaptorContext transactionNestingLevel] == 0)
    return [NoTransactionInProgressException exceptionWithAdaptor:self];

  if (delegateRespondsTo.willUpdateRow) {
    EODelegateResponse response;
    
    mrow = AUTORELEASE([row mutableCopyWithZone:[row zone]]);
    response = [delegate adaptorChannel:self
                         willUpdateRow:mrow
			 describedByQualifier:qualifier];
    if (response == EODelegateRejects) {
      return [NSException exceptionWithName:@"EODelegateRejects"
			  reason:@"delegate rejected update"
			  userInfo:nil];
    }
    if (response == EODelegateOverrides)
      return nil;
  }

  sqlexpr = [[self _adaptorExpressionClass]
                   updateExpressionForRow:mrow
                   qualifier:qualifier
                   channel:self];
  
  ex = [self evaluateExpressionX:[sqlexpr expressionValueForContext:nil]];
  if (ex != nil) return ex;
  
  if (delegateRespondsTo.didUpdateRow) {
    [delegate adaptorChannel:self
	      didUpdateRow:mrow
	      describedByQualifier:qualifier];
  }
  return nil;
}

- (NSException *)deleteRowsDescribedByQualifierX:(EOSQLQualifier *)qualifier {
  EOSQLExpression *sqlexpr = nil;
  NSException *ex;
  
  if (!isOpen)
    return [[ChannelIsNotOpenedException new] autorelease];
  
  if ([self isFetchInProgress])
    return [AdaptorIsFetchingException exceptionWithAdaptor:self];
  
  if ([self->adaptorContext transactionNestingLevel] == 0)
    return [NoTransactionInProgressException exceptionWithAdaptor:self];
  
  if (delegateRespondsTo.willDeleteRows) {
    EODelegateResponse response;
    
    response = [delegate adaptorChannel:self
                         willDeleteRowsDescribedByQualifier:qualifier];
    if (response == EODelegateRejects) {
      return [NSException exceptionWithName:@"EODelegateRejects"
			  reason:@"delegate rejected delete"
			  userInfo:nil];
    }
    if (response == EODelegateOverrides)
      return nil;
  }
  
  sqlexpr = [[self _adaptorExpressionClass]
                   deleteExpressionWithQualifier:qualifier
                   channel:self];
  
  ex = [self evaluateExpressionX:[sqlexpr expressionValueForContext:nil]];
  if (ex != nil) return ex;
  
  if (delegateRespondsTo.didDeleteRows)
    [delegate adaptorChannel:self didDeleteRowsDescribedByQualifier:qualifier];
  
  return nil;
}

/* compatibility methods (DEPRECATED, use the ...X methods  */

- (BOOL)selectAttributes:(NSArray *)attributes
  describedByQualifier:(EOSQLQualifier *)qualifier
  fetchOrder:(NSArray *)fetchOrder
  lock:(BOOL)lockFlag
{
  NSException *ex;
  
  ex = [self selectAttributesX:attributes describedByQualifier:qualifier
	     fetchOrder:fetchOrder lock:lockFlag];
  if (ex == nil)
    return YES;
  if ([self _isNoRaiseOnModificationException:ex])
    return NO;
  [ex raise];
  return NO;
}

- (BOOL)insertRow:(NSDictionary *)_row forEntity:(EOEntity *)_entity {
  NSException *ex;
  
  ex = [self insertRowX:_row forEntity:_entity];
  if (ex == nil)
    return YES;
  if ([self _isNoRaiseOnModificationException:ex])
    return NO;
  [ex raise];
  return NO;
}

- (BOOL)updateRow:(NSDictionary *)_row 
  describedByQualifier:(EOSQLQualifier *)_q
{
  NSException *ex;
  
  ex = [self updateRowX:_row describedByQualifier:_q];
  if (ex == nil)
    return YES;
  if ([self _isNoRaiseOnModificationException:ex])
    return NO;
  [ex raise];
  return NO;
}

- (BOOL)deleteRowsDescribedByQualifier:(EOSQLQualifier *)_qualifier {
  NSException *ex;
  
  ex = [self deleteRowsDescribedByQualifierX:_qualifier];
  if (ex == nil)
    return YES;
  if ([self _isNoRaiseOnModificationException:ex])
    return NO;
  [ex raise];
  return NO;
}

/* fetch operations */

- (NSException *)selectAttributesX:(NSArray *)attributes
  describedByQualifier:(EOSQLQualifier *)qualifier
  fetchOrder:(NSArray *)fetchOrder
  lock:(BOOL)lockFlag
{
  NSException     *ex;
  EOSQLExpression *sqlexpr = nil;
  NSMutableArray  *mattrs  = (NSMutableArray *)attributes;
  NSMutableArray  *mfetch  = (NSMutableArray *)fetchOrder;

  if (!isOpen)
    return [[ChannelIsNotOpenedException new] autorelease];

  if (attributes == nil) {
    return [NSException exceptionWithName:NSInvalidArgumentException
			reason:
			  @"attributes argument for selectAttributes:"
			  @"describedByQualifier:fetchOrder:lock: "
			  @"must not be the nil object"
			userInfo:nil];
  }
  
  if ([self isFetchInProgress])
    return [AdaptorIsFetchingException exceptionWithAdaptor:self];
  
  if ([self->adaptorContext transactionNestingLevel] == 0)
    return [NoTransactionInProgressException exceptionWithAdaptor:self];
  
  if (delegateRespondsTo.willSelectAttributes) {
    EODelegateResponse response;
        
    mattrs = [[attributes mutableCopy] autorelease];
    mfetch = [[fetchOrder mutableCopy] autorelease];

    response = [delegate adaptorChannel:self
			 willSelectAttributes:mattrs
			 describedByQualifier:qualifier
			 fetchOrder:mfetch
			 lock:lockFlag];
    if (response == EODelegateRejects) {
      return [NSException exceptionWithName:@"EODelegateRejects"
			  reason:@"delegate rejected select"
			  userInfo:nil];
    }
    if (response == EODelegateOverrides)
      return nil;
  }

#if 0
#warning DEBUG LOG, REMOVE!
  [self logWithFormat:@"fetch qualifier: %@", qualifier];
#endif

  sqlexpr = [[[self->adaptorContext adaptor]
                                expressionClass]
                                selectExpressionForAttributes:attributes
                                lock:lockFlag
                                qualifier:qualifier
                                fetchOrder:fetchOrder
                                channel:self];
    
  ex = [self evaluateExpressionX:[sqlexpr expressionValueForContext:nil]];
  if (ex != nil)
    return ex;
  
  if (delegateRespondsTo.didSelectAttributes) {
    [delegate adaptorChannel:self
	      didSelectAttributes:mattrs
	      describedByQualifier:qualifier
	      fetchOrder:mfetch
	      lock:lockFlag];
  }
  return nil;
}

- (NSArray *)describeResults:(BOOL)_beautifyNames {
  [self subclassResponsibility:_cmd];
  return nil;
}
- (NSArray *)describeResults {
  return [self describeResults:YES];
}

- (NSMutableDictionary *)fetchAttributes:(NSArray *)attributes
  withZone:(NSZone *)_zone
{
    NSMutableDictionary *row = nil;

    if (!self->isOpen)
      [[ChannelIsNotOpenedException new] raise];

    if (_zone == NULL)
        _zone = NSDefaultMallocZone();

    if(![self isFetchInProgress])
      [[AdaptorIsNotFetchingException exceptionWithAdaptor:self] raise];

    if(delegateRespondsTo.willFetchAttributes) {
        row = [delegate adaptorChannel:self
                        willFetchAttributes:attributes
                        withZone:_zone];
    }

    /* NOTE: primaryFetchAttributes:withZone: have to set the isFetchInProgress
       status */
    if(row == nil)
        row = [self primaryFetchAttributes:attributes withZone:_zone];

    if(row) {
        if(delegateRespondsTo.didFetchAttributes)
            row = [delegate adaptorChannel:self
                            didFetchAttributes:row
                            withZone:_zone];
        if(delegateRespondsTo.didChangeResultSet)
            [delegate adaptorChannelDidChangeResultSet:self];
    }
    else {
        /* Do not set here the isFetchInProgress status since only subclasses
           can know whether there are more SELECT commands to be executed.
           Setting the status here to NO will overwrite the adaptor subclass
           intention. */
        if(delegateRespondsTo.didFinishFetching)
            [delegate adaptorChannelDidFinishFetching:self];
    }
    return row;
}

- (BOOL)isFetchInProgress {
    return self->isFetchInProgress;
}

- (void)cancelFetch {
    if (!isOpen)
      [[ChannelIsNotOpenedException new] raise];

    self->isFetchInProgress = NO;
}

- (NSMutableDictionary *)dictionaryWithObjects:(id *)objects 
  forAttributes:(NSArray *)attributes zone:(NSZone *)zone
{
    [self notImplemented:_cmd];
    return nil;
}

- (NSMutableDictionary*)primaryFetchAttributes:(NSArray *)attributes 
  withZone:(NSZone *)zone
{
  [self subclassResponsibility:_cmd];
  return nil;
}

- (BOOL)evaluateExpression:(NSString *)anExpression {
  [self subclassResponsibility:_cmd];
  return NO;
}
- (NSException *)evaluateExpressionX:(NSString *)_sql {
  NSException *ex;
  BOOL ok;
  
  ex = nil;
  ok = NO;
  NS_DURING
    ok = [self evaluateExpression:_sql];
  NS_HANDLER
    ex = [localException retain];
  NS_ENDHANDLER;
  
  if (ex) return [ex autorelease];
  if (ok) return nil;
  
  return [NSException exceptionWithName:@"EOEvaluationError"
		      reason:@"could not evaluate SQL expression"
		      userInfo:nil];
}

- (EOAdaptorContext *)adaptorContext {
  return self->adaptorContext;
}

- (EOModel *)describeModelWithTableNames:(NSArray *)tableNames {
  [self subclassResponsibility:_cmd];
  return nil;
}

- (NSArray *)describeTableNames {
  [self subclassResponsibility:_cmd];
  return nil;
}

- (BOOL)readTypesForEntity:(EOEntity*)anEntity {
  [self subclassResponsibility:_cmd];
  return NO;
}

- (BOOL)readTypeForAttribute:(EOAttribute*)anAttribute {
  [self subclassResponsibility:_cmd];
  return NO;
}

// delegate

- (id)delegate {
    return self->delegate;
}

- (void)setDelegate:(id)_delegate {
    self->delegate = _delegate;

    delegateRespondsTo.willInsertRow = 
        [delegate respondsToSelector:
                @selector(adaptorChannel:willInsertRow:forEntity:)];
    delegateRespondsTo.didInsertRow = 
        [delegate respondsToSelector:
                @selector(adaptorChannel:didInsertRow:forEntity:)];
    delegateRespondsTo.willUpdateRow =
        [delegate respondsToSelector:
                @selector(adaptorChannel:willUpdateRow:describedByQualifier:)];
    delegateRespondsTo.didUpdateRow =
        [delegate respondsToSelector:
                @selector(adaptorChannel:didUpdateRow:describedByQualifier:)];
    delegateRespondsTo.willDeleteRows =
        [delegate respondsToSelector:
                @selector(adaptorChannel:willDeleteRowsDescribedByQualifier:)];
    delegateRespondsTo.didDeleteRows =
        [delegate respondsToSelector:
                @selector(adaptorChannel:didDeleteRowsDescribedByQualifier:)];
    delegateRespondsTo.willSelectAttributes =
        [delegate respondsToSelector:
                @selector(adaptorChannel:willSelectAttributes:
                          describedByQualifier:fetchOrder:lock:)];
    delegateRespondsTo.didSelectAttributes =
        [delegate respondsToSelector:
                @selector(adaptorChannel:didSelectAttributes:
                          describedByQualifier:fetchOrder:lock:)];
    delegateRespondsTo.willFetchAttributes =
        [delegate respondsToSelector:
                @selector(adaptorChannel:willFetchAttributes:withZone:)];
    delegateRespondsTo.didFetchAttributes =
        [delegate respondsToSelector:
                @selector(adaptorChannel:didFetchAttributes:withZone:)];
    delegateRespondsTo.didChangeResultSet =
        [delegate respondsToSelector:
                @selector(adaptorChannelDidChangeResultSet:)];
    delegateRespondsTo.didFinishFetching =
        [delegate respondsToSelector:
                @selector(adaptorChannelDidFinishFetching:)];
    delegateRespondsTo.willEvaluateExpression =
        [delegate respondsToSelector:
                @selector(adaptorChannel:willEvaluateExpression:)];
    delegateRespondsTo.didEvaluateExpression =
        [delegate respondsToSelector:
                @selector(adaptorChannel:didEvaluateExpression:)];
}

- (void)setDebugEnabled:(BOOL)flag {
    self->debugEnabled = flag;
}

- (BOOL)isDebugEnabled {
    return self->debugEnabled;
}
- (BOOL)isOpen {
    return self->isOpen;
}

@end /* EOAdaptorChannel */

#import <EOControl/EOFetchSpecification.h>

@implementation EOAdaptorChannel(PrimaryKeyGeneration) // new in EOF2

- (NSDictionary *)primaryKeyForNewRowWithEntity:(EOEntity *)_entity {
  return nil;
}

@end /* EOAdaptorChannel(PrimaryKeyGeneration) */

@implementation EOAdaptorChannel(EOF2Additions)

- (void)selectAttributes:(NSArray *)_attributes
  fetchSpecification:(EOFetchSpecification *)_fspec
  lock:(BOOL)_flag
  entity:(EOEntity *)_entity
{
  EOSQLQualifier *q;
  BOOL isOk;
  
  q = (EOSQLQualifier *)[_fspec qualifier];
  
  isOk = [self selectAttributes:_attributes
               describedByQualifier:q
               fetchOrder:[_fspec sortOrderings]
               lock:_flag];
  if (!isOk) {
    [NSException raise:@"Select failed"
                 format:@"could not select attributes for fetch spec"];
  }
}

- (void)setAttributesToFetch:(NSArray *)_attributes {
  [self notImplemented:_cmd];
}
- (NSArray *)attributesToFetch {
  NSLog(@"ERROR(%s): subclasses must override this method!", 
	__PRETTY_FUNCTION__);
  return nil;
}

- (NSMutableDictionary *)fetchRowWithZone:(NSZone *)_zone {
  return [self fetchAttributes:[self attributesToFetch] withZone:_zone];
}

@end /* EOAdaptorChannel(EOF2Additions) */

@implementation EOAdaptorChannel(Internals)

- (NSArray *)_sortAttributesForSelectExpression:(NSArray *)_attrs {
  return _attrs;
}

@end /* EOAdaptorChannel(Internals) */
