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

#include "NGMimeHeaderFieldGenerator.h"
#include "NGMimeHeaderFields.h"
#include "common.h"

@implementation NGMimeStringHeaderFieldGenerator

+ (int)version {
  return 2;
}

- (NSData *)generateDataForHeaderFieldNamed:(NSString *)_headerField
  value:(id)_value
{
  if (_value == nil)
    return [NSData data];

  if ([_value isKindOfClass:[NSData class]])
    return _value;

  if (![_value isKindOfClass:[NSString class]])
    _value = [_value stringValue];

#if APPLE_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
  return [_value dataUsingEncoding:NSISOLatin1StringEncoding];
#else
  return [_value dataUsingEncoding:NSISOLatin9StringEncoding];
#endif
}

@end /* NGMimeStringHeaderFieldGenerator */
