/*
  Copyright (C) 2005 Helge Hess

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

#import <NGObjWeb/WODirectAction.h>

@interface WEPrototypeScriptAction : WODirectAction
@end

#include "common.h"

@implementation WEPrototypeScriptAction

static NSString *etag = nil;
static NSString *script =
#include "WEPrototypeScript.jsm"
      ;

+ (void)initialize {
  if (etag == nil) {
    etag = [[NSString alloc] initWithFormat:@"\"sope/%i.%i-wep+%03i\"",
			     SOPE_MAJOR_VERSION, SOPE_MINOR_VERSION,
			     WEP_SUBMINOR_VERSION];
  }
}

- (id)defaultAction {
  WOResponse *r;
  NSString *s;
  
  r = [[self context] response];
  [r setHeader:@"application/x-javascript" forKey:@"content-type"];
  [r setHeader:etag                        forKey:@"etag"];
  
  /* check preconditions */
  
  if ((s = [[[self context] request] headerForKey:@"if-none-match"]) != nil) {
    if ([s rangeOfString:etag].length > 0) {
      /* client already has the proper entity */
      [r setStatus:304 /* Not Modified */];
      return r;
    }
  }
  
  /* send script */
  
  [r setStatus:200 /* OK */];
  [r appendContentString:script];
  return r;
}

@end /* WEPrototypeScriptAction */
