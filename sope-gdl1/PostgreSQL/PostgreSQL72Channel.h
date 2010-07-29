/* 
   PostgreSQL72Channel.h

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess
   Copyright (C) 2000-2004 SKYRIX Software AG and Helge Hess

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

#ifndef ___PostgreSQL72_Channel_H___
#define ___PostgreSQL72_Channel_H___

#include <GDLAccess/EOAdaptorChannel.h>
#include <libpq-fe.h>

@class NSArray, NSString, NSMutableDictionary;
@class PGConnection, PGResultSet;

typedef struct {
  const char *name;
  Oid        type;
  int        size;
  int        modification;
} PostgreSQL72FieldInfo;

@interface PostgreSQL72Channel : EOAdaptorChannel
{
  // connection is valid after an openChannel call
  PGConnection *connection;
  
  // valid during -evaluateExpression:
  PGResultSet *resultSet;
  int      tupleCount;
  int      fieldCount;
  BOOL     containsBinaryData;
  PostgreSQL72FieldInfo *fieldInfo;
  NSString *cmdStatus;
  NSString *cmdTuples;
  int      currentTuple;

  // turns on/off channel debugging
  BOOL isDebuggingEnabled;

  NSMutableDictionary *_attributesForTableName;
  NSMutableDictionary *_primaryKeysNamesForTableName;
  
  int      *fieldIndices;
  NSString **fieldKeys;
  id       *fieldValues;
}

- (void)setDebugEnabled:(BOOL)_flag;
- (BOOL)isDebugEnabled;

@end

@interface NSObject(Sybase10ChannelDelegate)

- (NSArray*)postgreSQLChannel:(PostgreSQL72Channel *)channel
  willFetchAttributes:(NSArray *)attributes;

- (BOOL)postgreSQLChannel:(PostgreSQL72Channel *)channel
  willReturnRow:(NSDictionary *)row;

@end

#endif /* ___PostgreSQL72_Channel_H___ */
