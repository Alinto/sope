/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __WOHttpAdaptor_H__
#define __WOHttpAdaptor_H__

#include <NGObjWeb/WOAdaptor.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSLock.h>
#include <NGStreams/NGPassiveSocket.h>

@class NSMutableArray;
@class NGActiveSocket;

@interface WOHttpAdaptor : WOAdaptor
{
@protected
  id<NGPassiveSocket>    socket;
  NGActiveSocket *controlSocket;
  NSTimeInterval         sendTimeout;
  NSTimeInterval         receiveTimeout;

  unsigned short         maxThreadCount;
  unsigned short         activeThreadCount;
  id<NSObject,NSLocking> lock;
  BOOL                   isTerminated;

  id<NGSocketAddress>    address;

  NSMutableArray         *delayedResponses;
}

+ (BOOL)optionLogPerf;

@end

#endif /* __WOHttpAdaptor_H__ */
