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

@implementation NGMimeRFC822DateHeaderFieldGenerator

+ (int)version {
  return 2;
}

- (NSData *)generateDataForHeaderFieldNamed:(NSString *)_headerField
  value:(id)_value
{
  NSCalendarDate *date       = nil;
  NSString       *dateString = nil;
  
  if ([_value isKindOfClass:[NSString class]])
    return [_value dataUsingEncoding:NSUTF8StringEncoding];
  
  date = _value;

  if (date == nil)
    return [NSData data];
  
  if ([date respondsToSelector:@selector(descriptionWithCalendarFormat:)]) {
    // TODO: do not use -descriptionWithCalendarFormat: !
    //       - slow
    //       - does not necessarily encode an English dayname!
    dateString = [date descriptionWithCalendarFormat:
                         @" %a, %d %b %Y %H:%M:%S %z"];
  }
  else
    dateString = [date stringValue];
  
  return [dateString dataUsingEncoding:NSUTF8StringEncoding];
}

@end /* NGMimeRFC822DateHeaderFieldGenerator */
