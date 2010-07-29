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


#import "common.h"
#import "NSBundle+misc.h"

#ifndef LIB_FOUNDATION_LIBRARY

@implementation NSBundle(misc)

- (NSString*)pathForResource:(NSString*)name ofType:(NSString*)ext
  inDirectory:(NSString*)directory
  forLocalizations:(NSArray*)localizationNames
{
  if(!localizationNames) {
    return [self pathForResource:name ofType:ext inDirectory:directory];
  }
  else {
    unsigned i, count;
    
    count = [localizationNames count];
    for(i = 0; i < count; i++) {
      NSString *lname, *path;
      
      lname = [localizationNames objectAtIndex:i];
      path = [self pathForResource:name ofType:ext inDirectory:directory
                   forLocalization:lname];
      if(path)
        return path;
    }
  }
  return nil;
}

@end /* NSBundle(misc) */
#endif
