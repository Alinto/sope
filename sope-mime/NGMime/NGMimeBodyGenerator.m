/*
  Copyright (C) 2000-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess

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

#include "NGMimeBodyGenerator.h"
#include "NGMimePartGenerator.h"
#include "common.h"

@implementation NGMimeBodyGenerator

static BOOL debugOn = NO;

+ (int)version {
  return 2;
}
+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  debugOn = [ud boolForKey:@"NGMimeGeneratorDebugEnabled"];
  if (debugOn)
    NSLog(@"WARNING[%@]: NGMimeGeneratorDebugEnabled is enabled!", self);
}

/* generate data for body */

- (NSData *)generateBodyOfPart:(id<NGMimePart>)_part
  additionalHeaders:(NGMutableHashMap *)_addHeaders
  delegate:(id)_delegate
{
  NSData *data, *input;
  
  input = [_part body];
  data  = [self encodeData:input
                forPart:_part
                additionalHeaders:_addHeaders];
  if (debugOn) {
    [self debugWithFormat:@"encoded %d bytes to %d bytes (same=%s, class=%@)",
	  [input length], [data length], 
	  input == data ? "yes" : "no", 
	  NSStringFromClass([data class])];
  }
  return data;
}

/* properly encode data for transfer (eg to 7bit for email) */

- (NSData *)encodeData:(NSData *)_data
  forPart:(id<NGMimePart>)_part
  additionalHeaders:(NGMutableHashMap *)_addHeaders
{
  return _data;
}

/* manage data storage */

- (void)setUseMimeData:(BOOL)_b {
  self->useMimeData = _b;
}
- (BOOL)useMimeData {
  return self->useMimeData;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* NGMimeBodyGenerator */
