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

#include "NGTerminalSupport.h"
#include "NGFileStream.h"
#include "NGFilterStream.h"
#include "NGCTextStream.h"
#include "NGDescriptorFunctions.h"

@implementation NGStream(NGTerminalSupport)

- (BOOL)isAssociatedWithTerminalDevice {
  return NO;
}

- (NSString *)nameOfAssociatedTerminalDevice {
  return nil;
}

@end

@implementation NGFileStream(NGTerminalSupport)

- (BOOL)isAssociatedWithTerminalDevice {
#if defined(WIN32)
  return NO;
#else
  return [self isOpen] ? NGDescriptorIsAtty(self->fd) : NO;
#endif
}

- (NSString *)nameOfAssociatedTerminalDevice {
#if defined(WIN32)
  return nil;
#else
  return [self isOpen] ? NGDescriptorGetTtyName(self->fd) : (NSString *)nil;
#endif
}

@end /* NGFileStream(NGTerminalSupport) */


@implementation NGFilterStream(NGTerminalSupport)

- (BOOL)isAssociatedWithTerminalDevice {
  id src = [self source];
  
  return [src respondsToSelector:_cmd]
    ? [src isAssociatedWithTerminalDevice]
    : NO;
}

- (NSString *)nameOfAssociatedTerminalDevice {
  id src = [self source];
  
  return [src respondsToSelector:_cmd]
    ? [src nameOfAssociatedTerminalDevice]
    : NO;
}

@end /* NGFilterStream(NGTerminalSupport) */


@implementation NGTextStream(NGTerminalSupport)

- (BOOL)isAssociatedWithTerminalDevice {
  return NO;
}
- (NSString *)nameOfAssociatedTerminalDevice {
  return nil;
}

@end /* NGTextStream(NGTerminalSupport) */


@implementation NGCTextStream(NGTerminalSupport)

- (BOOL)isAssociatedWithTerminalDevice {
  id src = [self source];
  
  return [src respondsToSelector:_cmd]
    ? [src isAssociatedWithTerminalDevice]
    : NO;
}

- (NSString *)nameOfAssociatedTerminalDevice {
  id src = [self source];
  
  return [src respondsToSelector:_cmd]
    ? [src nameOfAssociatedTerminalDevice]
    : NO;
}

@end /* NGCTextStream(NGTerminalSupport) */

void __link_NGStreams_NGTerminalSupport(void) {
  __link_NGStreams_NGTerminalSupport();
}
