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

#import <EOControl/EOKeyGlobalID.h>
#include "common.h"
#include <XmlRpc/XmlRpcCoder.h>

@implementation EOKeyGlobalID(XmlRpcCoding)

- (id)initWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  EOKeyGlobalID *globalID;
  NSString      *name;
  NSArray       *keyVals;
  int           i, cnt;
  id            *vals;

  name    = [_coder decodeStringForKey:@"entityName"];
  keyVals = [_coder decodeArrayForKey:@"keyValues"];
  cnt     = [keyVals count];

  vals = calloc(cnt, sizeof(id));
  
  for (i = 0; i < cnt; i++)
    vals[i] = [keyVals objectAtIndex:i];
  
  globalID = [EOKeyGlobalID globalIDWithEntityName:name
                            keys:vals
                            keyCount:cnt
                            zone:[self zone]];

  free(vals); vals = NULL;
  
  [self release];
  return [globalID retain];
}

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  [_coder encodeString:[self entityName]    forKey:@"entityName"];
  [_coder encodeArray:[self keyValuesArray] forKey:@"keyValues"];
}

@end /* EOKeyGlobalID(XmlRpcCoding) */
