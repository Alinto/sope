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
// $Id: load-EOAdaptor.m 1 2004-08-20 10:38:46Z znek $

#import <Foundation/Foundation.h>
#include <GDLAccess/EOAdaptor.h>
#include <stdio.h>

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  NSArray   *args;
  NSString  *adaptorName;
  EOAdaptor *adaptor;
  
  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  args = [[NSProcessInfo processInfo] arguments];
  if ([args count] < 2) {
    fprintf(stderr, "usage: %s adaptorname\n", argv[0]);
    exit(10);
  }
  
  adaptorName = [args objectAtIndex:1];
  
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

  if (adaptor) {
    printf("did load adaptor: %s\n", [[adaptor name] cString]);
    exit(0);
  }
  
  fprintf(stderr, "ERROR: failed to load adaptor '%s'.\n", 
	  [adaptorName cString]);
  
  exit (1);
  return 1;
}
