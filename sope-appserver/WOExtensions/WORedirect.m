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

#include "WORedirect.h"
#include "common.h"

@implementation WORedirect

- (void)dealloc {
  [self->url release];
  [super dealloc];
}

/* accessors */

- (void)setURL:(id)_url {
  [self setUrl:_url];
}

- (void)setUrl:(id)_url {
  ASSIGNCOPY(self->url, _url);
}
- (id)url {
  return self->url;
}

/* handling requests (do nothing, avoid loading of template) */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
}
- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  [self warnWithFormat:@"called %s on WORedirect!", 
          __PRETTY_FUNCTION__];
  return nil;
}

/* generating the response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *loc;
  
  if (![self->url isNotNull]) {
    [self errorWithFormat:@"missing URL for redirect!"];
    return;
  }
  
  if ([self->url isKindOfClass:[NSURL class]])
    loc = [self->url absoluteString];
  else
    loc = [self->url stringValue];

  if ([loc length] == 0) {
    [self errorWithFormat:@"got invalid URL for redirect: '%@'(%@)", 
            self->url, NSStringFromClass([self->url class])];
    return;
  }
  
  [_response setStatus:302 /* temporarily moved */];
  [_response setHeader:loc forKey:@"location"];
}

@end /* WORedirect */
