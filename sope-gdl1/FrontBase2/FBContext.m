/* 
   FBContext.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge.hess@mdlink.de)

   This file is part of the FB Adaptor Library

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
// $Id: FBContext.m 1 2004-08-20 10:38:46Z znek $

#import "FBContext.h"
#import "FBChannel.h"
#import "common.h"

@implementation FBContext

static FBContext *context = nil;

+ (FBContext *)activeContext {
  return context;
}

- (void)channelDidInit:_channel {
  if ([channels count] > 0) {
    [NSException raise:@"TooManyOpenChannelsException"
                 format:@"SybaseAdaptor10 only supports one channel per context"];
  }
  [super channelDidInit:_channel];
}

- (BOOL)primaryBeginTransaction {
  return YES;
}

- (BOOL)primaryCommitTransaction {
  FrontBaseChannel *channel;
  BOOL result;
  
  context = self;
  channel = [[channels lastObject] nonretainedObjectValue];
  //NSLog(@"committing channel %@", channel);
  result  = [channel evaluateExpression:@"COMMIT"];
  context = nil;
  return result;
}

- (BOOL)primaryRollbackTransaction {
  FrontBaseChannel *channel;
  BOOL result;
  
  context = self;
  channel = [[channels lastObject] nonretainedObjectValue];
  //NSLog(@"rolling back channel %@", channel);
  result  = [channel evaluateExpression:@"ROLLBACK"];
  context = nil;
  return result;
}

- (BOOL)canNestTransactions {
  return YES;
}

// NSCopying methods

- (id)copyWithZone:(NSZone *)zone {
  // copy is needed during creation of NSNotification object
  return RETAIN(self);
}

@end

@implementation FrontBaseContext
@end

void __link_FBContext() {
  // used to force linking of object file
  __link_FBContext();
}
