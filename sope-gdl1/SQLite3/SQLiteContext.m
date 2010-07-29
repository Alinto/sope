/* 
   SQLiteContext.m

   Copyright (C) 2003-2005 SKYRIX Software AG

   Author: Helge Hess (helge.hess@skyrix.com)

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

#include "SQLiteContext.h"
#include "SQLiteChannel.h"
#include "common.h"

@implementation SQLiteContext

- (void)channelDidInit:_channel {
  if ([channels count] > 0) {
    [NSException raise:@"TooManyOpenChannelsException"
                 format:@"SQLite3 only supports one channel per context"];
  }
  [super channelDidInit:_channel];
}

- (BOOL)primaryBeginTransaction {
  BOOL result;
  
  result = [[[channels lastObject]
                       nonretainedObjectValue]
                       evaluateExpression:@"BEGIN TRANSACTION"];
  
  return result;
}

- (BOOL)primaryCommitTransaction {
  BOOL result;

  result = [[[channels lastObject]
                       nonretainedObjectValue]
                       evaluateExpression:@"COMMIT TRANSACTION"];

  return result;
}

- (BOOL)primaryRollbackTransaction {
  BOOL result;

  result = [[[channels lastObject]
                       nonretainedObjectValue]
                       evaluateExpression:@"ROLLBACK TRANSACTION"];
  return result;
}

- (BOOL)canNestTransactions {
  return NO;
}

// NSCopying methods

- (id)copyWithZone:(NSZone *)zone {
  return [self retain];
}

@end /* SQLiteContext */

void __link_SQLiteContext() {
  // used to force linking of object file
  __link_SQLiteContext();
}
