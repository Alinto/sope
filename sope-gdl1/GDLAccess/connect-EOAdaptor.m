/* 
   EOAdaptorChannel.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: October 1996

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/
// $Id: connect-EOAdaptor.m 1 2004-08-20 10:38:46Z znek $

#import <Foundation/Foundation.h>
#include <GDLAccess/EOAdaptor.h>
#include <GDLAccess/EOAdaptorContext.h>
#include <GDLAccess/EOAdaptorChannel.h>
#include <stdio.h>

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  NSArray      *args;
  NSString     *adaptorName;
  NSString     *condictstr;
  NSDictionary *condict;
  EOAdaptor    *adaptor;
  EOAdaptorContext *adctx;
  EOAdaptorChannel *adch;
  BOOL ok;
  
  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  args = [[NSProcessInfo processInfo] arguments];
  if ([args count] < 3) {
    fprintf(stderr, "usage: %s adaptorname condict\n", argv[0]);
    exit(10);
  }
  
  adaptorName = [args objectAtIndex:1];
  condictstr  = [args objectAtIndex:2];

  /* load adaptor */
  
  NS_DURING {
    adaptor = [EOAdaptor adaptorWithName:adaptorName];
  }
  NS_HANDLER {
    fprintf(stderr, "ERROR: %s: %s\n",
	    [[localException name]   cString],
	    [[localException reason] cString]);
    adaptor = nil;
  }
  NS_ENDHANDLER;
  
  if (adaptor == nil) {
    fprintf(stderr, "ERROR: failed to load adaptor '%s'.\n", 
	    [adaptorName cString]);
    exit(1);
  }
  
  printf("did load adaptor: %s\n", [[adaptor name] cString]);

  /* setup connection dictionary */
  
  if ((condict = [condictstr propertyList]) == nil) {
    fprintf(stderr, "ERROR: invalid connection dictionary '%s'.\n", 
	    [condictstr cString]);
    exit(2);
  }
  [adaptor setConnectionDictionary:condict];

  /* setup connection */
  
  if ((adctx = [adaptor createAdaptorContext]) == nil) {
    fprintf(stderr, "ERROR: could not create adaptor context.");
    exit(3);
  }
  if ((adch = [adctx createAdaptorChannel]) == nil) {
    fprintf(stderr, "ERROR: could not create adaptor channel.");
    exit(4);
  }
  
  /* connect */

  ok = NO;
  NS_DURING {
    ok = [adch openChannel];
  }
  NS_HANDLER {
    fprintf(stderr, "ERROR: could not connect to database %s: %s\n",
	    [[localException name]   cString],
	    [[localException reason] cString]);
    exit(5);
  }
  NS_ENDHANDLER;
  
  if (!ok) {
    fprintf(stderr, "ERROR: could not connect to database.\n");
    exit(6);
  }
  else
    printf("connection could be established.\n");
  
  [adch closeChannel];
  
  exit(0);
  return 0;
}
