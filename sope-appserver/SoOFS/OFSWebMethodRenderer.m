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

#include "OFSWebMethodRenderer.h"
#include "OFSWebMethod.h"
#include <NGObjWeb/WOResponse.h>
#include "common.h"

@interface OFSWebMethod(Privates)
- (WOComponent *)componentInContext:(WOContext *)_ctx;
@end

@implementation OFSWebMethodRenderer

+ (id)sharedRenderer {
  static OFSWebMethodRenderer *singleton = nil;
  if (singleton == nil)
    singleton = [[OFSWebMethodRenderer alloc] init];
  return singleton;
}

/* rendering */

- (NSException *)renderComponent:(WOComponent *)_c inContext:(WOContext *)_ctx{
  WOResponse *r = [_ctx response];
  
  [r setHeader:@"text/html" forKey:@"content-type"];
  [_ctx setPage:_c];
  [_ctx enterComponent:_c content:nil];
  [_c appendToResponse:r inContext:_ctx];
  [_ctx leaveComponent:_c];
  return nil;
}

- (NSException *)renderObject:(id)_object inContext:(WOContext *)_ctx {
  WOComponent *component;
  
  if (![_object isOFSWebMethod])
    return [NSException exceptionWithHTTPStatus:500 /* server error */];
  
  if ((component = [_object componentInContext:_ctx]) == nil)
    return [NSException exceptionWithHTTPStatus:500 /* server error */];
  
  return [self renderComponent:component inContext:_ctx];
}

- (BOOL)canRenderObject:(id)_object inContext:(WOContext *)_ctx {
  return [_object isOFSWebMethod];
}

/* debugging */

- (NSString *)loggingPrefix {
  return @"[so-component-renderer]";
}

@end /* OFSWebMethodRenderer */
