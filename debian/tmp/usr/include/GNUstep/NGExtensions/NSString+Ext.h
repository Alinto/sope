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

#ifndef __NGExtensions_NSString_Ext_H__
#define __NGExtensions_NSString_Ext_H__

#import <Foundation/NSString.h>

/* was specific to gstep-base and later removed, supported in libFoundation */

#if !LIB_FOUNDATION_LIBRARY

@interface NSString(GSAdditions)

#if !GNUSTEP
- (NSString *)stringWithoutPrefix:(NSString *)_prefix;
- (NSString *)stringWithoutSuffix:(NSString *)_suffix;

- (NSString *)stringByReplacingString:(NSString *)_orignal
  withString:(NSString *)_replacement;

- (NSString *)stringByTrimmingLeadSpaces;
- (NSString *)stringByTrimmingTailSpaces;
- (NSString *)stringByTrimmingSpaces;
#endif /* !GNUSTEP */

/* the following are not available in gstep-base 1.6 ? */
- (NSString *)stringByTrimmingLeadWhiteSpaces;
- (NSString *)stringByTrimmingTailWhiteSpaces;
- (NSString *)stringByTrimmingWhiteSpaces;

@end /* NSString(GSAdditions) */

#if !GNUSTEP

@interface NSMutableString(GNUstepCompatibility)

- (void)trimLeadSpaces;
- (void)trimTailSpaces;
- (void)trimSpaces;

@end /* NSMutableString(GNUstepCompatibility) */

#endif /* !GNUSTEP */

#endif

/* specific to libFoundation */

#if !LIB_FOUNDATION_LIBRARY

@interface NSString(lfNSURLUtilities)

- (BOOL)isAbsoluteURL;
- (NSString *)urlScheme;

@end

#endif

#endif /* __NGExtensions_NSString_Ext_H__ */
