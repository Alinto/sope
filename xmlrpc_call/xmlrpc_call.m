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
  xmlrpc_call
  
  A neat tool to call XML-RPC servers from the shell.

  Defaults:
    login     - string
    password  - string
    forceauth - bool   - send the credentials in the first request!
*/

#include <NGXmlRpc/NGXmlRpcClient.h>

#include <NGExtensions/NSString+Ext.h>
#include <NGStreams/NGStreams.h>
#include <NGStreams/NGNet.h>

#if !LIB_FOUNDATION_LIBRARY
#  include <NGObjWeb/UnixSignalHandler.h>
#endif

#include "common.h"

@class WOResponse;

#include "XmlRpcClientTool.h"
#include "HandleCredentialsClient.h"
#include <NGObjWeb/WOResponse.h>

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  XmlRpcClientTool  *client;
  NSArray           *arguments;
  int               exitCode;
  
  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY || defined(GS_PASS_ARGUMENTS)
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  /* our sockets need to know, if the PIPE is broken */
  signal(SIGPIPE, SIG_IGN);

  arguments = [[NSProcessInfo processInfo] argumentsWithoutDefaults];
  if ((client = [[XmlRpcClientTool alloc] initWithArguments:arguments]) == nil)
    exitCode = 2;
  else
    exitCode =  [client run];
  
  [client release];
  [pool   release];
  
  exit(exitCode);
  return exitCode;
}
