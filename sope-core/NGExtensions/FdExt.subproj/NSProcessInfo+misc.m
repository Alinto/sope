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

#include "NSProcessInfo+misc.h"
#include "common.h"
#include <time.h>

#if !LIB_FOUNDATION_LIBRARY && !GNUSTEP_BASE_LIBRARY
#  import <NGExtensions/NSString+Ext.h>
#endif

@implementation NSProcessInfo(misc)

/* arguments */

- (NSArray *)argumentsWithoutDefaults {
  NSMutableArray *ma;
  NSArray  *a;
  unsigned count, i;
  BOOL     foundDefault;
  
  a = [self arguments];
  if ((count = [a count]) == 0) return nil;
  if (count == 1) return a;
  
  ma = [NSMutableArray arrayWithCapacity:count];
  [ma addObject:[a objectAtIndex:0]]; // tool name
  
  for (i = 1, foundDefault = NO; i < count; i++) {
    NSString *arg;
    
    arg = [a objectAtIndex:i];
    if ([arg hasPrefix:@"-"] && ([arg length] > 1)) {
      /* a default .. */
      i++; /* consume value */
      foundDefault = YES;
      continue;
    }
    
    [ma addObject:arg];
  }
  
  return foundDefault ? (NSArray *)ma : a;
}

/* create temp file name */

- (NSString *)temporaryFileName:(NSString *)_prefix {
  static int cnt = 0;
  NSString *s;
  cnt++;
  s = [NSString stringWithFormat:
                  @"%04X%X%02X.tmp", getpid(), time(NULL),
                  cnt];
  return [_prefix stringByAppendingString:s];
}
- (NSString *)temporaryFileName {
  NSString *prefix;
  
  prefix = [@"/tmp/" stringByAppendingPathComponent:[self processName]];
  return [self temporaryFileName:prefix];
}

/* return process-id (pid on Unix) */

- (id)processId {
  int pid;
#if defined(__MINGW32__)
  pid = (int)GetCurrentProcessId();
#else                     
  pid = (int)getpid();
#endif
  return [NSNumber numberWithInt:pid];
}

- (NSString *)procDirectoryPathForProcess {
  NSString *p;
  BOOL isDir;
  
  p = [@"/proc/" stringByAppendingString:[[self processId] stringValue]];
  if (![[NSFileManager defaultManager] fileExistsAtPath:p isDirectory:&isDir])
    return nil;
  
  return isDir ? p : (NSString *)nil;
}

- (NSDictionary *)procStatusDictionary {
  NSMutableDictionary *dict;
  NSString     *procStatusPath;
  NSString     *s;
  NSEnumerator *lines;
  NSString     *line;
  
  procStatusPath =
    [[self procDirectoryPathForProcess]
           stringByAppendingPathComponent:@"status"];
  
  s = [[NSString alloc] initWithContentsOfFile:procStatusPath];
  if (s == nil) return nil;
  
  dict = [NSMutableDictionary dictionaryWithCapacity:32];
  
  lines = [[s componentsSeparatedByString:@"\n"] objectEnumerator];
  while ((line = [lines nextObject])) {
    NSString *key;
    NSRange  r;
    id value;
    
    r = [line rangeOfString:@":"];
    if (r.length == 0) continue;
    
    key   = [line substringToIndex:r.location];
    value = [[line substringFromIndex:(r.location + r.length)] 
	           stringByTrimmingSpaces];
    
    if (value == nil)
      value = [NSNull null];
    
    [dict setObject:value forKey:key];
  }
  
  return [[dict copy] autorelease];
}

static NSNumber *_int(int i) __attribute__((unused));
static NSNumber *_uint(unsigned int i) __attribute__((unused));

static NSNumber *_int(int i) {
  return [NSNumber numberWithInt:i];
}
static NSNumber *_uint(unsigned int i) {
  return [NSNumber numberWithUnsignedInt:i];
}

#define NG_GET_PROC_INFO \
    FILE          *fh;\
    char          pp[256];\
    int           res;\
    int           pid, ppid, pgrp, session, tty, tpgid;\
    unsigned int  flags, minflt, cminflt, majflt, cmajflt;\
    int           utime, stime, cutime, cstime, counter;\
    unsigned char comm[256];\
    char          state = 0;\
    int           priority, starttime;\
    unsigned int  timeout, itrealvalue, vsize, rss, rlim, startcode, endcode;\
    unsigned int  startstack, kstkesp, kstkeip;\
    int           signal, blocked, sigignore, sigcatch;\
    unsigned int  wchan;\
    \
    pid = getpid();\
    snprintf(pp, 255, "/proc/%i/stat", pid);\
    fh = fopen(pp, "r");\
    if (fh == NULL)\
      res = -1;\
    else\
      res = fscanf(fh,\
                 "%d %255s %c %d %d %d %d %d "\
                 "%u %u %u %u %u "\
                 "%d %d %d %d %d "\
                 "%d %u %u %d "\
                 "%u %u %u %u %u"\
                 "%u %u %u "\
                 "%d %d %d %d "\
                 "%u"\
                 ,\
                 &pid, &(comm[0]), &state, &ppid, &pgrp, &session, &tty, \
                 &tpgid,\
                 &flags, &minflt, &cminflt, &majflt, &cmajflt,\
                 &utime, &stime, &cutime, &cstime, &counter,\
                 &priority, &timeout, &itrealvalue, &starttime,\
                 &vsize, &rss, &rlim, &startcode, &endcode,\
                 &startstack, &kstkesp, &kstkeip,\
                 &signal, &blocked, &sigignore, &sigcatch,\
                 &wchan\
                 );\
    fclose(fh); fh = NULL;

- (unsigned int)virtualMemorySize {
#ifdef __linux__
  NG_GET_PROC_INFO;
  return vsize;
#else
  return 0;
#endif
}
- (unsigned int)residentSetSize {
#ifdef __linux__
  NG_GET_PROC_INFO;
  return rss;
#else
  return 0;
#endif
}
- (unsigned int)residentSetSizeLimit {
#ifdef __linux__
  NG_GET_PROC_INFO;
  return rlim;
#else
  return 0;
#endif
}

- (NSDictionary *)procStatDictionary {
#ifdef __linux__
  /* see 'man 5 proc' */
  NSMutableDictionary *dict;
  NG_GET_PROC_INFO;
  
  if (res > 0) {
    dict = [NSMutableDictionary dictionaryWithCapacity:res];
    
    if (res >  0) [dict setObject:_int(pid)          forKey:@"pid"];
    if (res >  1) [dict setObject:[NSString stringWithCString:(char *)comm]
                        forKey:@"comm"];
    if (res >  2) [dict setObject:[NSString stringWithCString:&state length:1]
                        forKey:@"state"];
    if (res >  3) [dict setObject:_int(ppid)         forKey:@"ppid"];
    if (res >  4) [dict setObject:_int(pgrp)         forKey:@"pgrp"];
    if (res >  5) [dict setObject:_int(session)      forKey:@"session"];
    if (res >  6) [dict setObject:_int(tty)          forKey:@"tty"];
    if (res >  7) [dict setObject:_int(tpgid)        forKey:@"tpgid"];
    if (res >  8) [dict setObject:_uint(flags)       forKey:@"flags"];
    if (res >  9) [dict setObject:_uint(minflt)      forKey:@"minflt"];
    if (res > 10) [dict setObject:_uint(cminflt)     forKey:@"cminflt"];
    if (res > 11) [dict setObject:_uint(majflt)      forKey:@"majflt"];
    if (res > 12) [dict setObject:_uint(cmajflt)     forKey:@"cmajflt"];
    if (res > 13) [dict setObject:_int(utime)        forKey:@"utime"];
    if (res > 14) [dict setObject:_int(stime)        forKey:@"stime"];
    if (res > 15) [dict setObject:_int(cutime)       forKey:@"cutime"];
    if (res > 16) [dict setObject:_int(cstime)       forKey:@"cstime"];
    if (res > 17) [dict setObject:_int(counter)      forKey:@"counter"];
    if (res > 18) [dict setObject:_int(priority)     forKey:@"priority"];
    if (res > 19) [dict setObject:_uint(timeout)     forKey:@"timeout"];
    if (res > 20) [dict setObject:_uint(itrealvalue) forKey:@"itrealvalue"];
    if (res > 21) [dict setObject:_int(starttime)    forKey:@"starttime"];
    if (res > 22) [dict setObject:_uint(vsize)       forKey:@"vsize"];
    if (res > 23) [dict setObject:_uint(rss)         forKey:@"rss"];
    if (res > 24) [dict setObject:_uint(rlim)        forKey:@"rlim"];
    if (res > 25) [dict setObject:_uint(startcode)   forKey:@"startcode"];
    if (res > 26) [dict setObject:_uint(endcode)     forKey:@"endcode"];
    if (res > 27) [dict setObject:_uint(startstack)  forKey:@"startstack"];
    if (res > 28) [dict setObject:_uint(kstkesp)     forKey:@"kstkesp"];
    if (res > 29) [dict setObject:_uint(kstkeip)     forKey:@"kstkeip"];
    if (res > 30) [dict setObject:_int(signal)       forKey:@"signal"];
    if (res > 31) [dict setObject:_int(blocked)      forKey:@"blocked"];
    if (res > 32) [dict setObject:_int(sigignore)    forKey:@"sigignore"];
    if (res > 33) [dict setObject:_int(sigcatch)     forKey:@"sigcatch"];
    if (res > 34) [dict setObject:_uint(wchan)       forKey:@"wchan"];
    
    return dict;
  }
  else {
    NSLog(@"%s: couldn't scan /proc-info ...", __PRETTY_FUNCTION__);
    dict = nil;
  }
  
  return [[dict copy] autorelease];
#else
  return nil;
#endif
}

@end /* NSProcessInfo(misc) */

// linking

void __link_NSProcessInfo_misc(void) {
  __link_NSProcessInfo_misc();
}
