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

/*
  read a MIME message file and output XML ...
*/

#import "Mime2XmlTool.h"
#include "common.h"

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  Mime2XmlTool *tool;
  int res;
  
  pool = [[NSAutoreleasePool alloc] init];
  
#if LIB_FOUNDATION_LIBRARY  
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  tool = [[Mime2XmlTool alloc] init];
  res = [tool runWithArguments:
		[[NSProcessInfo processInfo] argumentsWithoutDefaults]];
  [tool release];
  
  [pool release];
  exit(0);
  /* static linking */
  [NGExtensions class];
  return 0;
}
