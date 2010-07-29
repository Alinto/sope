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
#if 0

#include <sys/time.h>

#define TIME_START(_timeDescription) \
{ \
  struct timeval tv; \
  double ti; \
  char *timeDescription; \
  unsigned int vm, vm1, rss, rss1; \
  static double AddedTime = 0; \
  static NSProcessInfo *ProcessInfo = nil; \
  static int CountCalls = 0; \
  \
  if (ProcessInfo == nil) \
    ProcessInfo = [[NSProcessInfo processInfo] retain]; \
  \
  *(&vm)  = 0; \
  *(&rss) = 0; \
  *(&ti)  = 0; \
  {\
    NSAutoreleasePool *p__1; \
    p__1 = [NSAutoreleasePool new]; \
    vm   = [ProcessInfo virtualMemorySize]; \
    rss  = [ProcessInfo residentSetSize] * 4096; \
    [p__1 release];\
  }\
  timeDescription = _timeDescription; \
  gettimeofday(&tv, NULL); \
  ti =  (double)tv.tv_sec + ((double)tv.tv_usec / 1000000.0 ); \
  fprintf(stderr, "{"); \


#define TIME_END gettimeofday(&tv, NULL); \
  gettimeofday(&tv, NULL); \
  { \
    NSAutoreleasePool *p__1 = [NSAutoreleasePool new]; \
    vm1  = [ProcessInfo virtualMemorySize]; \
    rss1 = [ProcessInfo residentSetSize] * 4096; \
    [p__1 release]; \
  }; \
  ti = (double)tv.tv_sec + ((double)tv.tv_usec / 1000000.0) - ti; \
  AddedTime += ti; \
  CountCalls++; \
  fprintf(stderr,\
          "}%s: <%s>[%d] : \n" \
          "  time needed:           %4.4fs (%4.4fs) \n"\
          "  memory wasted virtual: %d absolut %d \n" \
          "  resident set size:     %d absolute %d\n", \
          __PRETTY_FUNCTION__, timeDescription, CountCalls,\
          ti < 0.0 ? -1.0 : ti, AddedTime, vm1 - vm, vm1, rss1 - rss, rss1); \
}

#else

#define TIME_START(_timeDescription)

#define TIME_END

#endif

