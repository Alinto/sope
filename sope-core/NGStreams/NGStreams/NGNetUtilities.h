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

#ifndef __NGNet_NGNetUtilities_H__
#define __NGNet_NGNetUtilities_H__

#import <Foundation/NSObject.h>
#include <NGStreams/NGSocketProtocols.h>

/*
  Some supporting functions
*/

/*
  This function tried to 'guess' the appropriate socket address from _string.
  It currently creates an internet domain address if a ':' is encountered and
  a local domain address if the string returns true on -isAbsolutePath.
  The function returns nil if the string argument is nil or empty.

  Examples are:

    INET:   "*:20000"           // wildcard IP, port 20000
            "localhost:1000"    // localhost, port 1000
            "*:echo/udp"        // wildcard IP, echo service on UDP
            "*:echo"            // wildcard IP, echo service on TCP (TCP=default)
            
    LOCAL:  "/tmp/mySocket"
*/
id<NGSocketAddress> NGSocketAddressFromString(NSString *_string);

#endif /* __NGNet_NGNetUtilities_H__ */
