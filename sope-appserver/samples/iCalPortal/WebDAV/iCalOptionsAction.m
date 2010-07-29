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

#include "iCalOptionsAction.h"
#include <NGObjWeb/WEClientCapabilities.h>
#include "common.h"

@implementation iCalOptionsAction

- (void)dealloc {
  [super dealloc];
}

- (WOResponse *)run {
  WEClientCapabilities *cc;
  WORequest  *rq;
  WOResponse *r;
  NSString   *allow;
  
  rq = [self request];
  cc = [rq clientCapabilities];
  r  = [WOResponse responseWithRequest:rq];
  [r setStatus:200];
  [r setHeader:@"text/plain" forKey:@"content-type"];

  if ([cc isWebFolder])
    [r setHeader:@"DAV" forKey:@"MS-Author-Via"];
  
  /* this is send by Apache */
  [r setHeader:@"1,2,<http://apache.org/dav/propset/fs/1>" 
     forKey:@"DAV"];
  
  /* now the methods */
#if FULL_DAV
  allow =
    @"OPTIONS, GET, HEAD, POST, DELETE, TRACE, "
    @"PROPFIND, PROPPATCH, COPY, MOVE, LOCK, UNLOCK, PUT";
#else
  allow = @"GET, HEAD, POST, DELETE, PUT";
#endif
  
  [r setHeader:allow forKey:@"allow"];
  
  return r;
}  

@end /* iCalOptionsAction */
