/* 
   EODatabaseFault.h

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
   Date: 1996

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

#ifndef __eoaccess_EODatabaseFault_h__
#define __eoaccess_EODatabaseFault_h__

#import <GDLAccess/EOFault.h>

@class EOSQLQualifier, EOEntity, EODatabaseChannel;
@class NSArray, NSDictionary, NSString;

/*
 * EODatabaseFault class
 */

@interface EODatabaseFault : EOFault

// Creating a fault

+ (id)objectFaultWithPrimaryKey:(NSDictionary*)key
  entity:(EOEntity*)entity 
  databaseChannel:(EODatabaseChannel*)channel
  zone:(NSZone*)zone;

+ (NSArray *)arrayFaultWithQualifier:(EOSQLQualifier*)qualifier 
  fetchOrder:(NSArray*)fetchOrder 
  databaseChannel:(EODatabaseChannel*)channel
  zone:(NSZone*)zone;
+ (NSArray *)gcArrayFaultWithQualifier:(EOSQLQualifier*)qualifier 
  fetchOrder:(NSArray*)fetchOrder 
  databaseChannel:(EODatabaseChannel*)channel
  zone:(NSZone*)zone;

+ (NSDictionary*)primaryKeyForFault:fault;
+ (EOEntity*)entityForFault:fault;
+ (EOSQLQualifier*)qualifierForFault:fault;
+ (NSArray*)fetchOrderForFault:fault;
+ (EODatabaseChannel*)databaseChannelForFault:fault;

@end /* EODatabaseFault */

/*
 * Informal protocol that informs an instance that a to-one
 * relationship could not be resoved to get data for self.
 * Its implementation in NSObject raises NSObjectNotAvailableException. 
 */

@interface NSObject(EOUnableToFaultToOne)
- (void)unableToFaultWithPrimaryKey:(NSDictionary*)key 
  entity:(EOEntity*)entity 
  databaseChannel:(EODatabaseChannel*)channel;
@end

#endif  /* __eoaccess_EODatabaseFault_h__ */
