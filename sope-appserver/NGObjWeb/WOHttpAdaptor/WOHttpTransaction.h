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

#ifndef __WOHttpTransaction_H__
#define __WOHttpTransaction_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>
#include <NGStreams/NGActiveSocket.h>
#include <NGStreams/NGBufferedStream.h>

@class NSException, NSNotificationCenter;
@class NGHttpRequest;
@class WOCoreApplication, WORequest, WOResponse;
@class WORecordRequestStream;

/*
  This object represents a single HTTP transaction (request+response).
  
  Note that multiple HTTP transactions can be active at a single point of
  time, this isn't done by threading, but by using the runloop.
  
  Since WOApplications are synchronous by nature, we define a "special" HTTP
  response with status code "20001" meaning "response not yet ready". If
  the transaction gets this response, it puts itself into a pending state
  and waits for a notification targetting the async-object token given in
  the user-info of the response.
  (Eg this is used in the skysystemd to be able to fork and process multiple
  system commands at the same time)
*/

extern int      WOAsyncResponseStatus;
extern NSString *WOAsyncResponseTokenKey;
extern NSString *WOAsyncResponseReadyNotificationName;

@interface WOHttpTransaction : NSObject
{
@public
  WOCoreApplication     *application;
  id<NGActiveSocket>    socket;
  WORecordRequestStream *log;
  NGBufferedStream      *io;
  WORequest      *woRequest;
  WOResponse     *woResponse;
  NSTimeInterval t;
  NSDate         *startDate;
  NSException    *lastException;
  NSTimeInterval requestFinishTime;
  NSTimeInterval dispatchFinishTime;
  NSString       *asyncResponseToken;
}

- (id)initWithSocket:(id<NGActiveSocket>)_socket
  application:(WOCoreApplication *)_app;

- (void)reset;

/* running */

- (NSException *)lastException;
- (BOOL)run;
- (NSNotificationCenter *)notificationCenter;

/* event handler stuff */

- (NGHttpRequest *)parseRequestFromStream:(id<NGStream>)_in;
- (void)deliverResponse:(WOResponse *)_response
  toRequest:(WORequest *)_request
  onStream:(id<NGStream>)_out;
- (void)logResponse:(WOResponse *)_response
  toRequest:(WORequest *)_request
  connection:(id<NGActiveSocket>)_connection;

@end

#endif /* __WOHttpTransaction_H__ */
