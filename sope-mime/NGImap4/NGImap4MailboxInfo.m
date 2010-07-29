/*
  Copyright (C) 2005 SKYRIX Software AG

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

#include "NGImap4MailboxInfo.h"
#include "imCommon.h"

@implementation NGImap4MailboxInfo

- (id)initWithURL:(NSURL *)_url folderName:(NSString *)_name
  selectDictionary:(NSDictionary *)_dict
{
  if (_dict == nil || (_url == nil && _name == nil)) {
    [self release];
    return nil;
  }
  
  if ((self = [super init])) {
    self->timestamp    = [[NSDate alloc] init];
    self->url          = [_url  copy];
    self->name         = [_name copy];
    self->allowedFlags = [[_dict objectForKey:@"flags"]  copy];
    self->access       = [[_dict objectForKey:@"access"] copy];
    self->recent       = [[_dict objectForKey:@"recent"] unsignedIntValue];
  }
  return self;
}
- (id)init {
  return [self initWithURL:nil folderName: nil selectDictionary:nil];
}

- (void)dealloc {
  [self->timestamp    release];
  [self->url          release];
  [self->name         release];
  [self->allowedFlags release];
  [self->access       release];
  [super dealloc];
}

/* accessors */

- (NSDate *)timestamp {
  return self->timestamp;
}
- (NSURL *)url {
  return self->url;
}
- (NSString *)name {
  return self->name;
}
- (NSArray *)allowedFlags {
  return self->allowedFlags;
}
- (NSString *)access {
  return self->access;
}
- (unsigned int)recent {
  return self->recent;
}

/* description */

- (void)appendAttributesToDescription:(NSMutableString *)_ms {
  if (self->name)   [_ms appendFormat:@" name=%@",  self->name];
  if (self->access) [_ms appendFormat:@" access=%@",  self->access];
  
  if (self->recent != 0) [_ms appendFormat:@" recent=%d", self->recent];

  [_ms appendFormat:@" flags=%@", 
       [[self allowedFlags] componentsJoinedByString:@","]];
}

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [self appendAttributesToDescription:ms];
  [ms appendString:@">"];
  return ms;
}

@end /* NGImap4MailboxInfo */
