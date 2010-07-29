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
// $Id: EONotQualifier+SQL.m 1 2004-08-20 10:38:46Z znek $

#import "EOSQLQualifier.h"
#include "common.h"

@implementation EONotQualifier(SQLQualifier)

/* SQL qualifier generation */

- (EOSQLQualifier *)sqlQualifierForEntity:(EOEntity *)_entity {
  EOSQLQualifier *q;

  q = [self->qualifier sqlQualifierForEntity:_entity];
  [q negate];
  return q;
}

@end /* EONotQualifier */
