/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#include "NGImap4EnvelopeAddress.h"
#include "imCommon.h"

@implementation NGImap4EnvelopeAddress

- (id)initWithPersonalName:(NSString *)_pname sourceRoute:(NSString *)_route
  mailbox:(NSString *)_mbox host:(NSString *)_host
{
  /* Note: we expect NSNull for unset values! */
  if (_pname == nil || _route == nil || _mbox == nil || _host == nil) {
    [self release];
    return nil;
  }
  
  if ((self = [super init])) {
    if ([_pname isNotNull]) self->personalName = [_pname copy];
    if ([_route isNotNull]) self->sourceRoute  = [_route copy];
    if ([_mbox  isNotNull]) self->mailbox      = [_mbox  copy];
    if ([_host  isNotNull]) self->host         = [_host  copy];
  }
  return self;
}
- (id)init {
  return [self initWithPersonalName:nil sourceRoute:nil mailbox:nil host:nil];
}

- (id)initWithString:(NSString *)_str {
  // TODO: properly parse string using NGMailAddressParser
  return [self initWithPersonalName:nil 
	       sourceRoute:nil 
	       mailbox:_str host:nil];
}

- (id)initWithBodyStructureInfo:(NSDictionary *)_info {
  if (![_info isNotNull]) {
    [self release];
    return nil;
  }
  return [self initWithPersonalName:[_info valueForKey:@"personalName"]
	       sourceRoute:[_info valueForKey:@"sourceRoute"]
	       mailbox:[_info valueForKey:@"mailboxName"]
	       host:[_info valueForKey:@"hostName"]];
}

- (void)dealloc {
  [self->personalName release];
  [self->sourceRoute  release];
  [self->mailbox      release];
  [self->host         release];
  [super dealloc];
}

/* accessors */

- (NSString *)personalName {
  return self->personalName;
}
- (NSString *)sourceRoute {
  return self->sourceRoute;
}
- (NSString *)mailbox {
  return self->mailbox;
}
- (NSString *)host {
  return self->host;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  /* we are immutable */
  return [self retain];
}

/* derived accessors */

- (NSString *)baseEMail {
  NSString *t;
  
  if (![self->mailbox isNotEmpty])
    return nil;
  if (![self->host isNotEmpty])
    return self->mailbox;
  
  t = [self->mailbox stringByAppendingString:@"@"];
  return [t stringByAppendingString:self->host];
}
- (NSString *)email {
  NSString *t;
  
  if (![self->personalName isNotEmpty])
    return [self baseEMail];
  if ((t = [self baseEMail]) == nil)
    return self->personalName;
  
  t = [[self->personalName
	    stringByAppendingString:@" <"] stringByAppendingString:t];
  return [t stringByAppendingString:@">"];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  if (self->personalName) [ms appendFormat:@" name='%@'", self->personalName];
  if (self->sourceRoute)  [ms appendFormat:@" source='%@'", self->sourceRoute];
  if (self->mailbox)      [ms appendFormat:@" mailbox='%@'", self->mailbox];
  if (self->host)         [ms appendFormat:@" host='%@'",    self->host];
  
  [ms appendString:@">"];
  return ms;
}

@end /* NGImap4EnvelopeAddress */
