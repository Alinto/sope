/* 
   MySQL4Context.m

   Copyright (C) 2003-2005 SKYRIX Software AG

   Author: Helge Hess (helge.hess@skyrix.com)

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

#include "MySQL4Context.h"
#include "MySQL4Channel.h"
#include "common.h"

/*
  Note: MySQL doesn't know 'BEGIN TRANSACTION'. It prefers 'START TRANSACTION'
        which was added in 4.0.11, which is why we use just 'BEGIN' (available
	since 3.23.17)
*/

@implementation MySQL4Context

- (void)channelDidInit:_channel {
  if ([channels count] > 0) {
    [NSException raise:@"TooManyOpenChannelsException"
                 format:@"MySQL4 only supports one channel per context"];
  }
  [super channelDidInit:_channel];
}

- (BOOL)primaryBeginTransaction {
  BOOL result;
  
  result = [[[channels lastObject]
                       nonretainedObjectValue]
                       evaluateExpression:@"BEGIN"];
  
  return result;
}

- (BOOL)primaryCommitTransaction {
  BOOL result;

  result = [[[channels lastObject]
                       nonretainedObjectValue]
                       evaluateExpression:@"COMMIT"];

  return result;
}

- (BOOL)primaryRollbackTransaction {
  BOOL result;

  result = [[[channels lastObject]
                       nonretainedObjectValue]
                       evaluateExpression:@"ROLLBACK"];
  return result;
}

- (BOOL)canNestTransactions {
  return NO;
}

// NSCopying methods

- (id)copyWithZone:(NSZone *)zone {
  return [self retain];
}

@end /* MySQL4Context */

void __link_MySQL4Context() {
  // used to force linking of object file
  __link_MySQL4Context();
}
