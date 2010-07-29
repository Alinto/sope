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
#include <DOM/DOMSaxBuilder.h>
#include <DOM/DOMXMLOutputter.h>
#include <DOM/DOMPYXOutputter.h>
#include <DOM/NSObject+QPEval.h>
#include <string.h>

/*
  Usage
  
    testqp [options] files
      -xml|-pyx         - output in XML or PYX format ...
*/

int main(int argc, char **argv, char **env) {
  NSEnumerator      *paths;
  NSString          *path;
  NSAutoreleasePool *pool;
  Class             builderClass;
  DOMSaxBuilder     *builder;
  id                out;
  
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  pool = [[NSAutoreleasePool alloc] init];

  out = nil;
  
  builderClass = Nil;
  if ((builder = [[DOMSaxBuilder alloc] init]) == nil) {
    fprintf(stderr, "could not load a SAX driver bundle !\n");
    exit(2);
  }
  [builder autorelease];
  
  /* parse */

  paths = [[[NSProcessInfo processInfo] arguments] objectEnumerator];
  [paths nextObject]; // skip toolname
  while ((path = [paths nextObject])) {
    NSAutoreleasePool *pool;
    NSDate            *date;
    NSTimeInterval    duration;
    id doc;
    
    if ([path hasPrefix:@"-"]) {
      if ([path isEqualToString:@"-pyx"]) {
        out = [[[NGDOMPYXOutputter alloc] init] autorelease];
      }
      else if ([path isEqualToString:@"-xml"]) {
        out = [[[DOMXMLOutputter alloc] init] autorelease];
      }
      else {
        // a default ? skip the value
        [paths nextObject];
      }
      
      continue;
    }
    
    pool = [[NSAutoreleasePool alloc] init];

    date = [NSDate date];
    doc = [builder buildFromContentsOfFile:path];
    duration = [[NSDate date] timeIntervalSinceDate:date];
    
    if (doc == nil) {
      NSLog(@"couldn't build DOM from path '%@'", path);
      [pool release]; pool = nil;
    }
    else {
      [out outputDocument:doc to:nil];
      NSLog(@"doc is %@, parsed in %.3fs", doc, duration);
      
      while (1) {
        NSAutoreleasePool *pool;
        char buf[4096];
        
        pool = [[NSAutoreleasePool alloc] init];
        printf("enter query path: ");
        fflush(stdout);
        
        fgets(buf, 4000, stdin);
        
        if (buf[0] == '\n' || buf[0] == 0) {
          printf("... exit\n");
          break;
        }
        else {
          NSString *s;
          volatile id res;

          buf[strlen(buf) - 1] = '\0';
          s = [NSString stringWithCString:buf];
          NSLog(@"eval: '%@'", s);

          NS_DURING
            if ((res = [doc evaluateQueryPath:s])) 
              NSLog(@"result: %@", res);
            else
              NSLog(@"no rresult ...");
          NS_HANDLER {
            fprintf(stderr, "%s\n", [[localException description] cString]);
            abort();
          }
          NS_ENDHANDLER;
        }
        
        [pool release];
      }
    }
    
    [pool release];
  }
  
  [pool release];

  exit(0);
  return 0;
}
