/*
**  OracleAdaptorContext.m
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

#import "OracleAdaptorContext.h"

#import "OracleAdaptorChannel.h"

#define DEFAULT_TRANSACTION_TIMEOUT 60

//
//
//
@implementation OracleAdaptorContext

- (id) copyWithZone: (NSZone *) theZone
{
  return [self retain];
}

//
//
//
- (BOOL) canNestTransactions
{
  return NO;
}

//
//
//
- (void) channelDidInit: (id) theChannel
{
  if ([[self channels] count] > 0)
    {
      [NSException raise: @"OracleContextException"
		   format: @"Channel already initiated for the actual context"];
    }

  [super channelDidInit: theChannel];
}

//
//
//
- (EOAdaptorChannel *) createAdaptorChannel
{
  return AUTORELEASE([[OracleAdaptorChannel alloc] initWithAdaptorContext: self]);
}

//
//
//
- (id) initWithAdaptor: (EOAdaptor *) theAdaptor
{
  self = [super initWithAdaptor: theAdaptor];
  
  _autocommit = YES;

  return self;
}

//
//
//
- (BOOL) primaryBeginTransaction
{
  id o;
  
  o = [[self channels] lastObject];

  return (OCITransStart([o serviceContext], [o errorHandle], (uword)DEFAULT_TRANSACTION_TIMEOUT, OCI_TRANS_NEW) == OCI_ERROR ? NO : YES);
}

//
//
//
- (BOOL) primaryCommitTransaction
{
  id o;
  
  o = [[self channels] lastObject];

  return (OCITransCommit([o serviceContext], [o errorHandle], OCI_DEFAULT) == OCI_ERROR ? NO : YES);
}

//
//
//
- (BOOL) primaryRollbackTransaction
{
  id o;
  
  o = [[self channels] lastObject];
  
  return (OCITransRollback([o serviceContext], [o errorHandle], OCI_DEFAULT) == OCI_ERROR ? NO : YES);
}

//
//
//
- (BOOL) autoCommit
{
  return _autocommit;
}

//
//
//
- (void) setAutoCommit: (BOOL) theBOOL
{
  _autocommit = theBOOL;
}

@end
