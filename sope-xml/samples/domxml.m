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

#include <SaxObjC/SaxObjC.h>
#include "common.h"
#include <DOM/DOMBuilderFactory.h>
#include <DOM/DOMXMLOutputter.h>
#include <DOM/DOMPYXOutputter.h>
#include <DOM/DOMSaxBuilder.h>

/*
  Usage
  
    domxml [options] files
      -repeat <n-times>
      -xml|-pyx         - output in XML or PYX format ...
*/

int main(int argc, char **argv, char **env) {
  NSEnumerator      *paths;
  NSString          *path;
  NSAutoreleasePool *pool;
  id<DOMBuilder>    builder;
  id                out;
  unsigned          repeat;
  
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  pool = [[NSAutoreleasePool alloc] init];

  out    = nil;
  repeat = 1;

  builder = [[DOMBuilderFactory standardDOMBuilderFactory]
                                createDOMBuilder];
  if (builder == nil) {
    fprintf(stderr, "could not create DOM builder !\n");
    exit(2);
  }
  
  /* parse */

  paths = [[[NSProcessInfo processInfo] arguments] objectEnumerator];
  [paths nextObject]; // skip toolname
  while ((path = [paths nextObject])) {
    NSAutoreleasePool *pool;
    NSDate            *date;
    NSTimeInterval    duration;
    unsigned          i;
    id doc;
    
    if ([path hasPrefix:@"-"]) {
      if ([path isEqualToString:@"-pyx"]) {
        out = [[[NGDOMPYXOutputter alloc] init] autorelease];
      }
      else if ([path isEqualToString:@"-xml"]) {
        out = [[[DOMXMLOutputter alloc] init] autorelease];
      }
      else if ([path isEqualToString:@"-repeat"]) {
        repeat = [[paths nextObject] intValue];
      }
      else {
        // a default ? skip the value
        [paths nextObject];
      }
      
      continue;
    }
    
    pool = [[NSAutoreleasePool alloc] init];

    if (repeat > 1)
      NSLog(@"repeat %i times ...", repeat);

    doc = nil;
    for (i = 0; i < repeat; i++) {
      NSAutoreleasePool *pool2;
      
      pool2 = [[NSAutoreleasePool alloc] init];
      [doc release]; doc = nil;
      
      date = [NSDate date];
      doc = [(id)builder buildFromContentsOfFile:path];
      duration = [[NSDate date] timeIntervalSinceDate:date];
      if (doc)
	NSLog(@"doc(%i) is %@, parsed in %.3fs", i, doc, duration);
      else if (doc == nil) {
        NSLog(@"couldn't build DOM from path '%@' (%.3fs)", path, duration);
        [pool release]; pool = nil;
        break;
      }
      
      doc = [doc retain];
      [pool2 release];
    }
    
    //NSLog(@"doc is %@, parsed in %.3fs", doc, duration);
    
    if (doc == nil)
      continue;
    
    [out outputDocument:doc to:nil];
    
    [pool release];
  }
  
  [pool release];

  exit(0);
  return 0;
}
