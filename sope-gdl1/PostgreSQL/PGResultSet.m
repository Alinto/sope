/* 
   PGConnection.m

   Copyright (C) 2004-2006 SKYRIX Software AG and Helge Hess

   Author: Helge Hess (helge.hess@opengroupware.org)
   
   This file is part of the PostgreSQL72 Adaptor Library

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

#include "PGConnection.h"
#include "common.h"
#include <libpq-fe.h>
#include "pgconfig.h"

@implementation PGResultSet

/* wraps PGresult */

- (id)initWithConnection:(PGConnection *)_con handle:(void *)_handle {
  if (_handle == NULL) {
    [self release];
    return nil;
  }
  if ((self = [super init])) {
    self->connection = [_con retain];
    self->results    = _handle;
  }
  return self;
}

- (void)dealloc {
  [self clear];
  [self->connection release];
  [super dealloc];
}

/* accessors */

- (BOOL)isValid {
  return self->results != NULL ? YES : NO;
}

- (BOOL)containsBinaryTuples {
#if NG_HAS_BINARY_TUPLES
  if (self->results == NULL) return NO;
  return PQbinaryTuples(self->results) ? YES : NO;
#else
  return NO;
#endif
}

- (NSString *)commandStatus {
  char *cstr;
  
  if (self->results == NULL)
    return nil;
  if ((cstr = PQcmdStatus(self->results)) == NULL)
    return nil;
  return [self->connection _stringFromCString:cstr];
}

- (NSString *)commandTuples {
  char *cstr;
  
  if (self->results == NULL)
    return nil;
  if ((cstr = PQcmdTuples(self->results)) == NULL)
    return nil;
  return [self->connection _stringFromCString:cstr];
}

/* fields */

- (unsigned)fieldCount {
  return self->results != NULL ? PQnfields(self->results) : 0;
}

- (NSString *)fieldNameAtIndex:(unsigned int)_idx {
  // TODO: charset
  if (self->results == NULL) return nil;
  return [self->connection _stringFromCString:PQfname(self->results, _idx)];
}

- (int)indexOfFieldNamed:(NSString *)_name {
#if LIB_FOUNDATION_LIBRARY
  // TBD: might be wrong even in this case?
  return PQfnumber(self->results, [_name cString]);
#else
  return PQfnumber(self->results, [_name UTF8String]);
#endif
}

- (int)fieldSizeAtIndex:(unsigned int)_idx {
  if (self->results == NULL) return 0;
  return PQfsize(self->results, _idx);
}

- (int)modifierAtIndex:(unsigned int)_idx {
  if (self->results == NULL) return 0;
#if NG_HAS_FMOD
  return PQfmod(self->results, _idx);
#else
  return 0;
#endif
}

/* tuples */

- (unsigned int)tupleCount {
  if (self->results == NULL) return 0;
  return PQntuples(self->results);
}

- (BOOL)isNullTuple:(int)_tuple atIndex:(unsigned int)_idx {
  if (self->results == NULL) return NO;
  return PQgetisnull(self->results, _tuple, _idx) ? YES : NO;
}

- (void *)rawValueOfTuple:(int)_tuple atIndex:(unsigned int)_idx {
  if (self->results == NULL) return NULL;
  return PQgetvalue(self->results, _tuple, _idx);
}

- (int)lengthOfTuple:(int)_tuple atIndex:(unsigned int)_idx {
  if (self->results == NULL) return 0;
  return PQgetlength(self->results, _tuple, _idx);
}

/* operations */

- (void)clear {
  if (self->results == NULL) return;
  PQclear(self->results);
  self->results = NULL;
}

@end /* PGResultSet */
