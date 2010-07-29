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

#ifndef __NGObjWeb_WOAdaptor_H__
#define __NGObjWeb_WOAdaptor_H__

#import <Foundation/NSObject.h>

@class NSString, NSDictionary;
@class WOCoreApplication;

typedef enum {
  WOChildMessageAccept = 0,
  WOChildMessageReady,
  WOChildMessageShutdown,
  WOChildMessageMax
} WOChildMessage;

@interface WOAdaptor : NSObject
{
@protected
  NSString          *name;
  WOCoreApplication *application; // not retained
}

/*
  Note: Arguments is a NSDictionary since WO4
*/
- (id)initWithName:(NSString *)_name
  arguments:(NSDictionary *)_args
  application:(WOCoreApplication *)_application;

// register

- (void)registerForEvents;
- (void)unregisterForEvents;

@end

#endif /* __NGObjWeb_WOAdaptor_H__ */
