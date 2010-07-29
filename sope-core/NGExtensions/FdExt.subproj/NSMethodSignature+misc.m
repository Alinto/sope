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

#import "common.h"
#import "NSMethodSignature+misc.h"

@implementation NSMethodSignature(misc)

#if NeXT_Foundation_LIBRARY
- (NSString *)objCTypes {
#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
  return [NSString stringWithCString:self->_types];
#else
  #warning Missing implementation for Leopard!
  return nil;
#endif
}
#else
- (NSString *)objCTypes {
  char buf[256], *bufPos = buf;
  int  argCount = [self numberOfArguments];
  char *pos1    = NULL, *pos2 = NULL;
  
  // return type
#if GNUSTEP_BASE_LIBRARY
  pos1 = (char *)[self methodType];
#else
  pos1 = (char *)[self types];
#endif
  pos2 = (char *)objc_skip_typespec(pos1);
  strncpy(bufPos, pos1, pos2 - pos1);
  bufPos += pos2 - pos1;
  //*bufPos = '\0';
  pos1 = (char *)objc_skip_offset(pos2);

  // arguments
  {
    register int i;

    for (i = 0; i < argCount; i++) {
      pos2 = (char *)objc_skip_typespec(pos1); // forward to offset
      strncpy(bufPos, pos1, pos2 - pos1);
      bufPos += pos2 - pos1;
      //*bufPos = '\0';
      pos1 = (char *)objc_skip_offset(pos2);   // forward to next type
    }
  }
  *bufPos = '\0';

  return [NSString stringWithCString:buf];
}
#endif

@end /* NSMethodSignature(misc) */

void __link_NSMethodSignature_misc() {
  __link_NSMethodSignature_misc();
}
