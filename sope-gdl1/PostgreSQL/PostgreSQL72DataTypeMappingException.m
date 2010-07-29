/* 
   PostgreSQL72Values.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge@mdlink.de)

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

#import "PostgreSQL72Values.h"
#import "common.h"

#if !LIB_FOUNDATION_LIBRARY
@interface PostgreSQL72DataTypeMappingException(Privates)
- (void)setName:(NSString *)_name;
- (void)setReason:(NSString *)_reason;
- (void)setUserInfo:(NSDictionary *)_ui;
@end
#endif

@implementation PostgreSQL72DataTypeMappingException

- (id)initWithObject:(id)_obj
  forAttribute:(EOAttribute *)_attr
  andPostgreSQLType:(NSString *)_dt
  inChannel:(PostgreSQL72Channel *)_channel;
{  
  NSString *typeName = nil;

  typeName = _dt;

  if (typeName == nil)
    typeName = [NSString stringWithFormat:@"Oid[%i]", _dt];
  
  // TODO: fix for Cocoa/gstep Foundation?
  [self setName:@"DataTypeMappingNotSupported"];
  [self setReason:[NSString stringWithFormat:
                              @"mapping between %@<Class:%@> and "
                              @"postgres type %@ is not supported",
                              [_obj description],
                              NSStringFromClass([_obj class]),
                              typeName]];

  [self setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                    _attr,    @"attribute",
                                    _channel, @"channel",
                                    _obj,     @"object",
                                    nil]];
  return self;
}

@end /* PostgreSQL72DataTypeMappingException */


void __link_PostgreSQL72Values() {
  // used to force linking of object file
  __link_PostgreSQL72Values();
}
