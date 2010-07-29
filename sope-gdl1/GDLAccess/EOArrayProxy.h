/* 
   EOArrayProxy.h

   Copyright (C) 1999 MDlink online service center GmbH, Helge Hess

   Author: Helge Hess (hh@mdlink.de)
   Date:   1999

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
// $Id: EOArrayProxy.h 1 2004-08-20 10:38:46Z znek $

#ifndef __eoaccess_EOArrayProxy_H__
#define __eoaccess_EOArrayProxy_H__

#import <Foundation/NSArray.h>

/*
 * EOArrayProxy class
 */

@class NSArray, NSString;
@class EODatabaseChannel, EOSQLQualifier, EOEntity;

@interface EOArrayProxy : NSArray
{
@private
  EODatabaseChannel *channel;
  EOSQLQualifier    *qualifier;
  NSArray           *fetchOrder;
  NSArray           *content;
}

+ (id)arrayProxyWithQualifier:(EOSQLQualifier *)_qualifier
  fetchOrder:(NSArray *)_fetchOrder
  channel:(EODatabaseChannel *)_channel;

// accessors

- (BOOL)isFetched;
- (EODatabaseChannel *)databaseChannel;
- (EOEntity *)entity;
- (NSArray *)fetchOrder;
- (EOSQLQualifier *)qualifier;

// operations

- (BOOL)fetch;

@end

#endif /* __eoaccess_EOArrayProxy_H__ */
