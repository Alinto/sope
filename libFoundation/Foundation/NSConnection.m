/* 
   NSConnection.m

   Copyright (C) 2000 MDlink GmbH, Helge Hess.
   All rights reserved.

   Author: Helge Hess <helge.hess@mdlink.de>

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

#include <Foundation/NSConnection.h>
#include <Foundation/NSPortNameServer.h>
#include <Foundation/NSString.h>
#include <common.h>

LF_DECLARE NSString *NSConnectionDidDieNotification  = @"NSConnectionDidDieNotificationName";
LF_DECLARE NSString *NSFailedAuthenticationException = @"NSFailedAuthenticationExceptionName";

@implementation NSConnection

/* name service */

- (BOOL)registerName:(NSString *)_name
{
    return [self registerName:_name
                 withNameServer:[NSPortNameServer defaultPortNameServer]];
}
- (BOOL)registerName:(NSString *)_name withNameServer:(NSPortNameServer *)_ns
{
    [self notImplemented:_cmd];
    return NO;
}

+ (NSDistantObject *)rootProxyForConnectionWithRegisteredName:(NSString *)_name
  host:(NSString *)_hostName
  usingNameServer:(NSPortNameServer *)_ns
{
    return [self notImplemented:_cmd];
}
+ (NSDistantObject *)rootProxyForConnectionWithRegisteredName:(NSString *)_name
  host:(NSString *)_hostName
{
    return [self rootProxyForConnectionWithRegisteredName:_name
                 host:_hostName
                 usingNameServer:[NSPortNameServer defaultPortNameServer]];
}

/* object management */

- (void)setRootObject:(id)_object
{
    [self notImplemented:_cmd];
}
- (id)rootObject
{
    return [self notImplemented:_cmd];
}

@end /* NSConnection */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
