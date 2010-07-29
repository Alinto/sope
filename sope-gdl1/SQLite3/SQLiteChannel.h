/* 
   SQLiteChannel.h

   Copyright (C) 2003-2005 Helge Hess

   Author: Helge Hess (helge.hess@opengroupware.org)

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

#ifndef ___SQLite_Channel_H___
#define ___SQLite_Channel_H___

#include <GDLAccess/EOAdaptorChannel.h>

@class NSArray, NSString, NSMutableDictionary;

@interface SQLiteChannel : EOAdaptorChannel
{
  // connection is valid after an openChannel call
  void *_connection;
  
  // valid during -evaluateExpression:
  void     *statement;
  BOOL     hasPendingRow;
  BOOL     isDone;
  
  void     *results;

  // turns on/off channel debugging
  BOOL isDebuggingEnabled;

  NSMutableDictionary *_attributesForTableName;
  NSMutableDictionary *_primaryKeysNamesForTableName;
}

- (void)setDebugEnabled:(BOOL)_flag;
- (BOOL)isDebugEnabled;

@end

@interface NSObject(Sybase10ChannelDelegate)

- (NSArray*)sqlite3Channel:(SQLiteChannel *)channel
  willFetchAttributes:(NSArray *)attributes;

- (BOOL)sqlite3Channel:(SQLiteChannel *)channel
  willReturnRow:(NSDictionary *)row;

@end

#endif /* ___SQLite_Channel_H___ */
