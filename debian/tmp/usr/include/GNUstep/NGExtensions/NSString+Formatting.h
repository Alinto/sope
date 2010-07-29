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

#ifndef __NGExtensions_NSString_Formatting_H__
#define __NGExtensions_NSString_Formatting_H__

#import <Foundation/NSString.h>

// category

@interface NSString(XSFormatting)

+ (id)stringWithCFormat:(const char *)_format arguments:(va_list)_ap;
+ (id)stringWithCFormat:(const char *)_format, ...;

@end

@interface NSMutableString(XSFormatting)

- (void)appendFormat:(NSString *)_format arguments:(va_list)_ap;
- (void)appendFormat:(NSString *)_format, ...;

@end

// C support functions

static inline int 
xs_vsnprintf(char *_str, size_t max, const char *fmt, va_list _ap) 
{
  NSString *obj = [NSString stringWithCFormat:_str arguments:_ap];
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1040
  [obj getCString:_str maxLength:(max - 1)
       encoding:[NSString defaultCStringEncoding]];
  return strlen(_str);
#else
  [obj getCString:_str maxLength:(max - 1)];
  return [obj cStringLength]; // return the len the string would have consumed
#endif
}

static inline int xs_vsprintf (char *_str, const char *_fmt, va_list _ap) {
  NSString *obj = [NSString stringWithCFormat:_str arguments:_ap];
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1040
  [obj getCString:_str maxLength:65535 /* no limit ... */
       encoding:[NSString defaultCStringEncoding]];
  return strlen(_str);
#else
  [obj getCString:_str];
  return [obj cStringLength]; // return the length of the string
#endif
}

/*
  Could use formats ..
     //     __attribute__ ((format (printf, 2, 3)));
     //     __attribute__ ((format (printf, 3, 4)));
*/
int xs_sprintf (char *str, const char *format, ...);
int xs_snprintf(char *str, size_t size, const char *format, ...);

#endif /* __NGExtensions_NSString_Formatting_H__ */
