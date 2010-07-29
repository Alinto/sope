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

#include <NGObjWeb/WOApplication.h>
#include "common.h"

NGObjWeb_DECLARE
int WOApplicationMain(NSString *_appClassName, int argc, const char *argv[])
{
#if !LIB_FOUNDATION_BOEHM_GC
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
#endif
#if LIB_FOUNDATION_LIBRARY || defined(GS_PASS_ARGUMENTS)
  extern char **environ;
  [NSProcessInfo initializeWithArguments:(void*)argv count:argc
                 environment:(void*)environ];
#endif
  NGInitTextStdio();
  {
    WOApplication *app;
    
    app = [[NSClassFromString(_appClassName) alloc] init];

    [app run];
    [app release]; app = nil;
  }
  [pool release]; pool = nil;
  return 0;
}
