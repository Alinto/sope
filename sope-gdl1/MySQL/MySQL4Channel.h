/* 
   MySQL4Channel.h

   Copyright (C) 2003-2005 Helge Hess

   Author: Helge Hess (helge.hess@opengroupware.org)

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

#ifndef ___MySQL4_Channel_H___
#define ___MySQL4_Channel_H___

#import <GDLAccess/EOAdaptorChannel.h>

@class NSArray, NSString, NSMutableDictionary;

@interface MySQL4Channel : EOAdaptorChannel
{
  // connection is valid after an openChannel call
  void *_connection;
  void *results;
  void *fields;
  int  fieldCount;

#if 0
  int      tupleCount;
  BOOL     containsBinaryData;
  NSString *cmdStatus;
  NSString *cmdTuples;
  NSString *oidStatus;
  int      currentTuple;
#endif

  // turns on/off channel debugging
  BOOL isDebuggingEnabled;

  NSMutableDictionary *_attributesForTableName;
  NSMutableDictionary *_primaryKeysNamesForTableName;
}

- (void)setDebugEnabled:(BOOL)_flag;
- (BOOL)isDebugEnabled;

- (BOOL)isOpen;
- (BOOL)openChannel;
- (void)closeChannel;

- (NSMutableDictionary *)primaryFetchAttributes:(NSArray *)_attributes
  withZone:(NSZone *)_zone;

- (BOOL)evaluateExpression:(NSString *)_expression;

// cancelFetch is always called to terminate a fetch
// (even by primaryFetchAttributes)
// it frees all fetch-local variables
- (void)cancelFetch;

// uses dataFormat type information to create EOAttribute objects
- (NSArray *)describeResults;

@end

@interface NSObject(Sybase10ChannelDelegate)

- (NSArray*)sqlite3Channel:(MySQL4Channel *)channel
  willFetchAttributes:(NSArray *)attributes;

- (BOOL)sqlite3Channel:(MySQL4Channel *)channel
  willReturnRow:(NSDictionary *)row;

@end

#endif /* ___MySQL4_Channel_H___ */
