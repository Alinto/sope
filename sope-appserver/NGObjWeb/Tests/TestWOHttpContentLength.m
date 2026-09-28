/* TestWOHttpContentLength.m - this file is part of SOPE
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; see the file COPYING.  If not, write to the
 * Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
 * 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <fcntl.h>
#include <unistd.h>
#include <NGStreams/NGStreams.h>
#include "WOHttpAdaptor/WOHttpTransaction.h"
#include <NGObjWeb/WOResponse.h>

@interface FakeLargeFileHandle : NSObject
{
  int fd;
  unsigned long long fakeSize;
}

- (id) initWithFakeSize: (unsigned long long) size;

@end

@implementation FakeLargeFileHandle

- (id) initWithFakeSize: (unsigned long long) size
{
  if ((self = [super init]))
    {
      fd = open ("/dev/null", O_RDONLY);
      if (fd < 0)
        {
          [self release];
          return nil;
        }
      fakeSize = size;
    }

  return self;
}

- (void) dealloc
{
  if (fd >= 0)
    close (fd);
  [super dealloc];
}

- (unsigned long long) seekToEndOfFile
{
  return fakeSize;
}

- (int) fileDescriptor
{
  return fd;
}

- (void) closeFile
{
  if (fd >= 0)
    close (fd);
  fd = -1;
}

@end

static NSString *
DeliverResponseWithFileSize (unsigned long long size)
{
  WOHttpTransaction *transaction;
  WOResponse *response;
  NGDataStream *sink;
  NSString *http;

  transaction = [[WOHttpTransaction alloc] init];
  response = [[[WOResponse alloc] init] autorelease];
  [response setStatus: 200];
  [response setHeader: @"text/plain" forKey: @"content-type"];
  [response setContentFile: [[[FakeLargeFileHandle alloc]
                              initWithFakeSize: size] autorelease]];

  sink = [[NGDataStream alloc] initWithData: [NSMutableData data] mode: NGStreamMode_writeOnly];

  NS_DURING
    [transaction deliverResponse: response
                       toRequest: nil
                        onStream: sink];
  NS_HANDLER
    printf ("EXCEPTION: %s\n", [[localException description] UTF8String]);
  NS_ENDHANDLER

  http = [[[NSString alloc] initWithData: [sink data]
                                encoding: NSISOLatin1StringEncoding] autorelease];

  [sink release];
  [transaction release];

  return http;
}

static int
Check (BOOL condition, const char *description)
{
  if (!condition)
    {
      printf ("FAIL: %s\n", description);
      return 1;
    }

  return 0;
}

int
main (void)
{
  NSAutoreleasePool *pool;
  NSString *http;
  int failures;

  pool = [[NSAutoreleasePool alloc] init];

  failures = 0;

  http = DeliverResponseWithFileSize (3ull * 1024 * 1024 * 1024);
  failures += Check ([http rangeOfString: @"content-length: 3221225472"].location
                     != NSNotFound,
                     "3 GiB export must report a positive 64-bit Content-Length");
  failures += Check ([http rangeOfString: @"content-length: -"].location
                     == NSNotFound,
                     "Content-Length must never be negative");
  failures += Check ([http rangeOfString: @" 200 "].location != NSNotFound,
                     "status line must be delivered");

  http = DeliverResponseWithFileSize (42);
  failures += Check ([http rangeOfString: @"content-length: 42"].location
                     != NSNotFound,
                     "small exports keep their exact size");

  [pool release];

  if (failures)
    printf ("%d failure(s)\n", failures);
  else
    printf ("all tests passed\n");

  return failures ? 1 : 0;
}
