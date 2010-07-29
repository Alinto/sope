/* 
   EODatabaseFaultResolver.h

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
   Date: 1996

   Author: Helge Hess <helge.hess@mdlink.de>
   Date: 1999
   
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

#ifndef __EODatabaseFaultResolver_h__
#define __EODatabaseFaultResolver_h__

#import <GDLAccess/EOFault.h>

@class EODatabaseChannel;
@class EOSQLQualifier;
@class EOEntity;

@interface EODatabaseFaultResolver : EOFaultHandler
{
@public
  EODatabaseChannel *channel;
}

- (id)initWithDatabaseChannel:(EODatabaseChannel*)aChannel
  zone:(NSZone*)zone  
  targetClass:(Class)targetClass;

- (Class)targetClass;
- (NSDictionary *)primaryKey;
- (EOEntity *)entity;
- (EOSQLQualifier *)qualifier;
- (NSArray *)fetchOrder;
- (EODatabaseChannel *)databaseChannel;

@end /* EODatabaseFaultResolver */

@interface EOArrayFault : EODatabaseFaultResolver
{
  EOSQLQualifier *qualifier;
  NSArray        *fetchOrder;
}

- (id)initWithQualifier:(EOSQLQualifier *)qualifier
  fetchOrder:(NSArray *)fetchOrder 
  databaseChannel:(EODatabaseChannel *)channel 
  zone:(NSZone *)zone  
  targetClass:(Class)targetClass;

- (EOEntity *)entity;
- (EOSQLQualifier *)qualifier;
- (NSArray *)fetchOrder;

@end

@interface EOObjectFault : EODatabaseFaultResolver
{
  EOEntity     *entity;
  NSDictionary *primaryKey;
}

- (id)initWithPrimaryKey:(NSDictionary *)key
  entity:(EOEntity *)entity 
  databaseChannel:(EODatabaseChannel *)channel 
  zone:(NSZone *)zone  
  targetClass:(Class)targetClass ;

- (NSDictionary*)primaryKey;
- (EOEntity*)entity;

@end

#endif          /* __EODatabaseFaultResolver_h__ */
