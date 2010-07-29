/* 
   EOAdaptorChannel.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: October 1996

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/
// $Id: EOOrQualifier+SQL.m 1 2004-08-20 10:38:46Z znek $

#import "EOSQLQualifier.h"
#include "common.h"

@implementation EOOrQualifier(SQLQualifier)

/* SQL qualifier generation */

- (EOSQLQualifier *)sqlQualifierForEntity:(EOEntity *)_entity {
  unsigned cc = [self->qualifiers count];

  if (cc == 0)
    return nil;
  else if (cc == 1)
    return [[self->qualifiers objectAtIndex:0] sqlQualifierForEntity:_entity];
  else if (cc == 2) {
    id left;
    id right;

    left  = [[self->qualifiers objectAtIndex:0] sqlQualifierForEntity:_entity];
    right = [[self->qualifiers objectAtIndex:1] sqlQualifierForEntity:_entity];
    [left disjoinWithQualifier:right];
    return left;
  }
  else {
    EOSQLQualifier *masterQ;
    unsigned i;

    for (i = 0, masterQ = nil; i < cc; i++) {
      EOSQLQualifier *q;

      q = [[self->qualifiers objectAtIndex:i]
                             sqlQualifierForEntity:_entity];
      if (masterQ == nil)
        masterQ = q;
      else
        [masterQ disjoinWithQualifier:q];
    }
    return masterQ;
  }
}

@end /* EOOrQualifier */
