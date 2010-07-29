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

/*
  check whether the quoted printable MIME decoding works ...
*/

#include <NGMail/NGMimeMessageParser.h>
#include "common.h"

static void test(void) {
  static unsigned char *fields[] = {
    "attachment; filename=\"Mappe langerp=?iso-8859-15?q?=FC=E4=F6=20Name=F6=F6=F6=201234456=2Exls?=\"",
    "Umlaute: =?iso-8859-15?q?=FC=E4=F6?=",
    "keine Umlaute: =?iso-8859-15?q?keine Umlaute?=",
    "=?iso-8859-15?q?keine Umlaute?=",
    "=?iso-8859-15?q?=FC=E4=F6?=",
    "",
    "hello world !",
    "??doit??",
    NULL
  };
  unsigned char *field;
  int i;
  
  for (i = 0; (field = fields[i]); i++) {
    NSData *fieldData;
    id result;
    
    NSLog(@"decoding field: '%s'", field);
    fieldData = [NSData dataWithBytes:field length:strlen(field)];
    NSLog(@"  length: %i", [fieldData length]);
    
    result = [fieldData decodeQuotedPrintableValueOfMIMEHeaderField:
			  @"content-disposition"];
    
    if (result == nil) {
      NSLog(@"  got no result for field data %@ !!!", fieldData);
    }
    else if ([result isKindOfClass:[NSData class]]) {
      NSLog(@"  got a data, length %i: %@", [result length], result);
    }
    else if ([result isKindOfClass:[NSString class]]) {
      NSLog(@"  got a string, length %i: '%@'", [result length], result);
    }
    else {
      NSLog(@"  got an unexpected object, class %@: %@",
	    NSStringFromClass([result class]), result);
    }
  }
}

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  
  pool = [NSAutoreleasePool new];
  
#if LIB_FOUNDATION_LIBRARY  
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  test();
  
  [pool release];
  exit(0);
  /* static linking */
  [NGExtensions class];
  return 0;
}
