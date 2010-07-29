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

#include "NSException+misc.h"
#import <Foundation/NSNull.h>
#include "common.h"

@implementation NSObject(NSExceptionNGMiscellaneous)

- (BOOL)isException {
  return NO;
}
- (BOOL)isExceptionOrNull {
  return NO;
}

@end /* NSObject(NSExceptionNGMiscellaneous) */

@implementation NSNull(NSExceptionNGMiscellaneous)

- (BOOL)isException {
  return NO;
}
- (BOOL)isExceptionOrNull {
  return YES;
}

@end /* NSNull(NSExceptionNGMiscellaneous) */

@implementation NSException(NGMiscellaneous)

- (BOOL)isException {
  return YES;
}
- (BOOL)isExceptionOrNull {
  return YES;
}

- (id)initWithReason:(NSString *)_reason {
  return [self initWithReason:_reason userInfo:nil];
}
- (id)initWithReason:(NSString *)_reason userInfo:(id)_userInfo {
  return [self initWithName:NSStringFromClass([self class])
               reason:_reason
               userInfo:_userInfo];
}

- (id)initWithFormat:(NSString *)_format,... {
  NSString *tmp = nil;
  va_list  ap;
  
  if (_format == nil)
    NSLog(@"ERROR(%s): missing format!", __PRETTY_FUNCTION__);
  
  va_start(ap, _format);
  tmp = [[NSString alloc] initWithFormat:
			    _format ? _format : (NSString *)@"Exception"
			  arguments:ap];
  va_end(ap);

  self = [self initWithReason:tmp userInfo:nil];
  [tmp release]; tmp = nil;
  return self;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  // TODO: should make a real copy?
  return [self retain];
}

@end /* NSException(NGMiscellaneous) */

#if COCOA_Foundation_LIBRARY || NeXT_Foundation_LIBRARY

@implementation NSException (NGLibFoundationCompatibility)
- (void)setReason:(NSString *)_reason {
  [_reason retain];
  [self->reason release];
  self->reason = _reason;
}
@end

#elif GNUSTEP_BASE_LIBRARY

@implementation NSException (NGLibFoundationCompatibility)
- (void)setReason:(NSString *)_reason {
  [_reason retain];
  [self->_e_reason release];
  self->_e_reason = _reason;
}
@end

#endif

void __link_NGExtensions_NSExceptionMisc() {
  __link_NGExtensions_NSExceptionMisc();
}
