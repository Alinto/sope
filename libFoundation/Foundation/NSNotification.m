/* 
   NSNotification.m

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

#include <Foundation/common.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSCoder.h>

/*
 * Concrete notification
 */

@interface NSConcreteNotification : NSNotification
{
    NSString* name;
    id object;
    NSDictionary* userInfo;
}
- (id)initWithName:(NSString*)aName object:(id)anObject 
  userInfo:(NSDictionary*)anUserInfo;
- (NSString *)notificationName;    
- notificationObject;
- (NSDictionary *)userInfo;
@end

@implementation NSConcreteNotification

- (id)initWithName:(NSString*)aName object:(id)anObject 
  userInfo:(NSDictionary*)anUserInfo
{
    NSZone* zone = [self zone];
    
    name = [aName copyWithZone:zone];
    userInfo = [anUserInfo copyWithZone:zone];
    object = RETAIN(anObject);
    return self;
}

- (void)dealloc
{
    RELEASE(name);
    RELEASE(userInfo);
    RELEASE(object);
    [super dealloc];
}

- (NSString *)notificationName
{
    return name;
}

- (NSString *)name { return name; }

- notificationObject
{
    return object;
}

- object { return object; }

- (NSDictionary *)userInfo
{
    return userInfo;
}

// NSCopying

- copyWithZone:(NSZone*)zone
{
    if (NSShouldRetainWithZone(self, zone))
	return RETAIN(self);
    else
	return [[[self class] alloc]
	    initWithName:name object:object userInfo:userInfo];
}

@end

/*
 * NSNotification
 */

@implementation NSNotification

/* Methods */

+ allocWithZone:(NSZone *)zone
{
    return NSAllocateObject( (self == [NSNotification class])
			     ? [NSConcreteNotification class] : (Class)self, 
			     0, zone);
}

+ (NSNotification *)notificationWithName:(NSString *)name object:object
{
    return AUTORELEASE([[self alloc] 
                           initWithName:(NSString*)name 
                           object:object 
                           userInfo:nil]);
}

+ (NSNotification *)notificationWithName:(NSString *)aName
  object:(id)anObject userInfo:(NSDictionary *)anUserInfo
{
    return AUTORELEASE([[self alloc] 
                           initWithName:(NSString*)aName 
                           object:anObject 
                           userInfo:anUserInfo]);
}

- (id)initWithName:(NSString*)_name object:(id)_object 
  userInfo:(NSDictionary*)anUserInfo
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- (NSString *)notificationName
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- (NSString *)name
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- notificationObject;
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- object;
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- (NSDictionary *)userInfo
{
    [self subclassResponsibility:_cmd];
    return nil;
}

/* NSCopying protocol */

- (id)copyWithZone:(NSZone*)zone
{
    [self subclassResponsibility:_cmd];
    return nil;
}

/* NSCodinging protocol */

- (Class)classForCoder
{
    return [NSNotification class];
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    id name = [self notificationName];
    id object = [self notificationObject];
    id info = [self userInfo];

    [coder encodeObject:name];
    [coder encodeObject:object];
    [coder encodeObject:info];
}

- initWithCoder:(NSCoder*)coder
{
    id name, object, info;

    name = [coder decodeObject];
    object = [coder decodeObject];
    info = [coder decodeObject];
    [self initWithName:name object:object userInfo:info];
    return self;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"<NSNotification:\n  name = %@\n"
				      @"  object = %@\n  userInfo = %@\n>",
				      [self notificationName],
				      [self notificationObject],
				      [self userInfo]];
}

@end /* NSNotification */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
