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

#ifndef __NGExtensions_NGStringScanEnumerator_H__
#define __NGExtensions_NGStringScanEnumerator_H__

#import <Foundation/NSEnumerator.h>
#import <Foundation/NSData.h>

/*
  NGStringScanEnumerator

  This class is used to scan (binary) NSData objects for printable strings,
  pretty much like the "strings" Unix program.
  
  Example:
  
    NSData *data = [NSData dataWithContentsOfMappedFile:@"/bin/ls"];
    NSEnumerator *e;
    NSString *s;
    
    e = [data stringScanEnumerator];
    while ((s = [e nextObject])) {
      if ([s hasPrefix:@"4"] && [s length] > 5) {
        NSLog(@"ls version: %@", s);
        break;
      }
    }
*/

@interface NGStringScanEnumerator : NSEnumerator
{
  unsigned int curPos;
  NSData       *data;
  unsigned int maxLength;
}

+ (id)enumeratorWithData:(NSData *)_data maxLength:(unsigned int)_maxLength;

@end /* StringEnumerator */

@interface NSData(NGStringScanEnumerator)

/* scan strings with up to 256 chars length */
- (NSEnumerator *)stringScanEnumerator;

- (NSEnumerator *)stringScanEnumeratorWithMaxStringLength:(unsigned int)_max;

@end

#endif /* __NGExtensions_NGStringScanEnumerator_H__ */
