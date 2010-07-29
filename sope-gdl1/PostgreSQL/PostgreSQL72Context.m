/* 
   PostgreSQL72Context.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess
   Copyright (C) 2007 Helge Hess

   Author: Helge Hess (helge@mdlink.de)

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

#import "PostgreSQL72Context.h"
#import "PostgreSQL72Channel.h"
#include "common.h"

@implementation PostgreSQL72Context

- (void)channelDidInit:_channel {
  if ([channels count] > 0) {
    [NSException raise:@"TooManyOpenChannelsException"
                 format:@"SybaseAdaptor10 only supports one channel per context"];
  }
  [super channelDidInit:_channel];
}

- (BOOL)primaryBeginTransaction {
  NSException *error;

  error = [[[channels lastObject]
                      nonretainedObjectValue]
                      evaluateExpressionX:@"BEGIN TRANSACTION"];
  if (error == nil)
    return YES;
  
  NSLog(@"%s: could not begin transaction: %@", __PRETTY_FUNCTION__, error);
  return NO;
}

- (BOOL)primaryCommitTransaction {
  NSException *error;

  error = [[[channels lastObject]
                      nonretainedObjectValue]
                      evaluateExpressionX:@"COMMIT TRANSACTION"];

  if (error == nil)
    return YES;
  
  NSLog(@"%s: could not commit transaction: %@", __PRETTY_FUNCTION__, error);
  return NO;
}

- (BOOL)primaryRollbackTransaction {
  NSException *error;

  error = [[[channels lastObject]
                      nonretainedObjectValue]
                      evaluateExpressionX:@"ROLLBACK TRANSACTION"];

  if (error == nil)
    return YES;
  
  NSLog(@"%s: could not rollback transaction: %@", __PRETTY_FUNCTION__, error);
  return NO;
}

- (BOOL)canNestTransactions {
  return NO;
}

/* NSCopying methods */

- (id)copyWithZone:(NSZone *)zone {
  // called when the object is used in some datastructures?
  return [self retain];
}

@end /* PostgreSQL72Context */

void __link_PostgreSQL72Context() {
  // used to force linking of object file
  __link_PostgreSQL72Context();
}
