/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

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
// $Id$

#include "JSBridgeTests.h"
#include "JSArchivingTests.h"
#include "common.h"
#include <NGExtensions/NGExtensions.h>
#include "globals.h"

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  NGJavaScriptBridge_TRACK_FINALIZATION = YES;
  NGJavaScriptBridge_TRACK_MEMORY       = YES;
  NGJavaScriptBridge_TRACK_FORGET       = YES;

  NS_DURING {
    [JSBridgeTests    runSuite];
    //[JSArchivingTests runSuite];
  }
  NS_HANDLER
    abort();
  NS_ENDHANDLER;
  
  [pool release];
  [NGExtensions class];
  return 0;
}
