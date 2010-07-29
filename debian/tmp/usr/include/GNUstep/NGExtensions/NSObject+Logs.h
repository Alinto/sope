/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#ifndef __NGExtensions_NSObject_Logs_H__
#define __NGExtensions_NSObject_Logs_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface NSObject(NGLogs)

/* default loggers for object */
- (id)logger;
- (id)debugLogger;

/* "end user" methods, variable argument logging methods .. */
- (void)debugWithFormat:(NSString *)_fmt, ...;
- (void)logWithFormat:(NSString *)_fmt, ...;
- (void)warnWithFormat:(NSString *)_fmt, ...;
- (void)errorWithFormat:(NSString *)_fmt, ...;
- (void)fatalWithFormat:(NSString *)_fmt, ...;

/* prefix, override that, to make a special logging prefix */
- (NSString *)loggingPrefix;

/* says whether debugging is enabled for object ... */
- (BOOL)isDebuggingEnabled;

/*"designated" logging methods */
- (void)debugWithFormat:(NSString *)_fmt arguments:(va_list)_va;
- (void)logWithFormat:(NSString *)_fmt   arguments:(va_list)_va;
- (void)warnWithFormat:(NSString *)_fmt  arguments:(va_list)_va;
- (void)errorWithFormat:(NSString *)_fmt arguments:(va_list)_va;
- (void)fatalWithFormat:(NSString *)_fmt arguments:(va_list)_va;

@end

#endif /* __NGExtensions_NSObject_Logs_H__ */
