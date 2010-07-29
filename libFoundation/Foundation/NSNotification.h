/* 
   NSNotification.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#ifndef __NSNotification_h__
#define __NSNotification_h__

#include <Foundation/NSObject.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSMapTable.h>

@class NSMutableDictionary;
@class NSDictionary;
@class NSMutableArray;
@class NSArray;

/*
 * NSNotification	
 */

@interface NSNotification : NSObject <NSCoding>

+ (NSNotification*)notificationWithName:(NSString *)name object:object;
+ (NSNotification*)notificationWithName:(NSString *)aName
  object:(id)anObject userInfo:(NSDictionary *)userInfo;

- (id)initWithName:(NSString *)aName object:(id)anObject 
  userInfo:(NSDictionary *)anUserInfo;

- (NSString *)notificationName;    
- (NSString *)name;    
- (id)notificationObject;
- (id)object;
- (NSDictionary *)userInfo;

@end

/*
 * NSNotificationCenter	
 */

struct _NSNotificationRegistrationList;

@interface NSNotificationCenter : NSObject 
{
    NSMapTable *nameToObjects;
    id         nullNameToObjects;
}

+ (NSNotificationCenter *)defaultCenter;

// Posting Notifications
- (void)postNotification:(NSNotification *)notification;
- (void)postNotificationName:(NSString *)notificationName object:(id)object;
- (void)postNotificationName:(NSString *)notificationName object:(id)object
  userInfo:(NSDictionary *)userInfo;

// Adding and Removing Observers

- (void)addObserver:(id)observer selector:(SEL)selector 
  name:(NSString *)name object:object;
- (void)removeObserver:(id)observer 
  name:(NSString *)name object:(id)object;
- (void)removeObserver:(id)observer;

@end

#endif /* __NSNotification_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
