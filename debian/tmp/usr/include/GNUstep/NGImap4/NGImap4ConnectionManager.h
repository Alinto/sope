/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __NGImap4ConnectionManager_H__
#define __NGImap4ConnectionManager_H__

#import <Foundation/NSObject.h>

/*
  NGImap4ConnectionManager
  
  This class manages and pools NGImap4Connection objects.
*/

@class NSString, NSTimer, NSMutableDictionary, NSURL;
@class NGImap4Connection, NGImap4Client;

@interface NGImap4ConnectionManager : NSObject
{
  NSMutableDictionary *urlToEntry;
  NSTimer *gcTimer;
}

+ (id)defaultConnectionManager;

/* client object */

- (NGImap4Connection *)connectionForURL:(NSURL *)_url password:(NSString *)_p;

- (NGImap4Client *)imap4ClientForURL:(NSURL *)_url password:(NSString *)_pwd;

- (void)flushCachesForURL:(NSURL *)_url;

@end

#endif /* __NGImap4ConnectionManager_H__ */
