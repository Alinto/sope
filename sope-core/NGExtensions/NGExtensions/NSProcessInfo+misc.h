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

#ifndef __NSProcessInfo_misc_H__
#define __NSProcessInfo_misc_H__

#import <Foundation/NSProcessInfo.h>

@interface NSProcessInfo(misc)

/* arguments */

- (NSArray *)argumentsWithoutDefaults;

/* create temp file name */

- (NSString *)temporaryFileName:(NSString *)_prefix;
- (NSString *)temporaryFileName;

/* return process-id (pid on Unix) */
- (id)processId;

/* return path to proc directory for this process */
- (NSString *)procDirectoryPathForProcess;

/* returns contents of /proc/pid/status */
- (NSDictionary *)procStatusDictionary;

/* returns contents of /proc/pid/stat mapped as in 'man 5 proc' */
- (NSDictionary *)procStatDictionary;

/* wrappers */
- (unsigned int)virtualMemorySize;
- (unsigned int)residentSetSize;
- (unsigned int)residentSetSizeLimit;

@end

#endif /* __NSProcessInfo_misc_H__ */
