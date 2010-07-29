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

#include "NGNetUtilities.h"
#include "NGInternetSocketAddress.h"
#include "NGLocalSocketAddress.h"
#include "common.h"

id<NGSocketAddress> NGSocketAddressFromString(NSString *_string) {
  const unsigned char *cstr = (unsigned char *)[_string cString];
  if (cstr == NULL)         return nil;
  if ([_string length] < 1) return nil;

  {
    const unsigned char *tmp = (unsigned char *)index((char *)cstr, ':');
    
    if (tmp) { // INET socket
      NSString *hostName = nil;

      if (((tmp - cstr) == 1) && (*cstr == '*'))
        hostName = nil; // wildcard host
      else {
        hostName = [NSString stringWithCString:(char *)cstr
			     length:(tmp - cstr)];
      }

      // check what comes after colon
      if (isdigit(tmp[1])) {
        // a port
        int port = atoi((char *)tmp + 1);
        return [NGInternetSocketAddress addressWithPort:port onHost:hostName];
      }
      else {
        // a service or 'auto' for auto-assigned ports
        const unsigned char *tmp2;
        NSString *protocol = @"tcp";
        NSString *service;
	
	tmp2 = (unsigned char *)index((char *)(tmp + 1), '/');
        tmp++;

        if (tmp2 == NULL)
          service  = [NSString stringWithCString:(char *)tmp];
        else {
          service  = [NSString stringWithCString:(char *)tmp
			       length:(tmp2 - tmp)];
          protocol = [NSString stringWithCString:(char *)(tmp2 + 1)];
        }

        if ([service isEqualToString:@"auto"])
          return [NGInternetSocketAddress addressWithPort:0
                                          onHost:hostName];
        
        return [NGInternetSocketAddress addressWithService:service
                                        onHost:hostName
                                        protocol:protocol];
      }
    }

#if !defined(WIN32)
    if ([_string isAbsolutePath])
      return [NGLocalSocketAddress addressWithPath:_string];
#endif
  }
  return nil;
}
