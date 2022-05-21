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
  const char *cstr = [_string cString];
  if (cstr == NULL)         return nil;
  if ([_string length] < 1) return nil;

  {
    const char *colon = index(cstr, ':');

    if (colon) { // INET socket
      NSString *hostName = nil;

      if (*cstr == '[') {
        // ipv6
        cstr++;
        char *pos = index(cstr, ']');
        if (pos == 0) {
          [NSException raise:NSInvalidArgumentException
            format: @"Illegal Ipv6 address: %@", _string];
        }
        while (*pos != ']') {
            if (*pos != ':' && *pos != '.' && !isxdigit(*pos)) {
              [NSException raise:NSInvalidArgumentException
              format: @"Illegal Ipv6 address: %@", _string];
            }
            pos++;
        }
        colon = pos +1;
        if (*colon != ':') {
            [NSException raise:NSInvalidArgumentException
              format: @"Missing port on Ipv6 address: %@", _string];
        }
        hostName = [NSString stringWithCString:(char *)cstr
                             length:(pos - cstr)];
      }
      else {
        // ipv4
        if (((colon - cstr) == 1) && (*cstr == '*'))
          hostName = nil; // wildcard host
        else {
          hostName = [NSString stringWithCString:(char *)cstr
                              length:(colon - cstr)];
        }
      }

      // check what comes after colon
      if (isdigit(colon[1])) {
        // a port
        int port = atoi((char *)colon + 1);
        return [NGInternetSocketAddress addressWithPort:port onHost:hostName];
      }
      else {
        // a service or 'auto' for auto-assigned ports
        const char *slash;
        NSString *protocol = @"tcp";
        NSString *service;

        slash = index((colon + 1), '/');
        colon++;

        if (slash == NULL)
          service  = [NSString stringWithCString:colon];
        else {
          service  = [NSString stringWithCString:colon
                               length:(slash - colon)];
          protocol = [NSString stringWithCString:(slash + 1)];
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
