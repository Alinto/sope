/*
  Copyright (C) 2012 Inverse inc
 
  Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>

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

#import "NSData+RFC822.h"

@implementation NSData (NGRFC822)

- (NSData *) dataByEnsuringCRLFLineEndings
{
  NSData *newData;
  const char *bytesOld;
  char *bytesNew;
  NSUInteger lenOld, cntOld, cntNew;

  bytesOld = [self bytes];
  lenOld = [self length];

  bytesNew = NSZoneMalloc (NULL, lenOld * 2);
  cntNew = 0;

  for (cntOld = 0; cntOld < lenOld; cntOld++)
    if (bytesOld[cntOld] != '\r')
      {
        if (bytesOld[cntOld] == '\n')
          {
            bytesNew[cntNew] = '\r';
            cntNew++;
          }
        bytesNew[cntNew] = bytesOld[cntOld];
        cntNew++;
      }

  newData = [NSData dataWithBytesNoCopy: bytesNew
                                 length: cntNew
                           freeWhenDone: YES];

  return newData;
}

@end
