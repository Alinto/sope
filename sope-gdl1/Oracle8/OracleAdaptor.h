/*
**  OracleAdaptor.h
**
**  Copyright (c) 2007  Inverse groupe conseil inc. and Ludovic Marcotte
**
**  Author: Ludovic Marcotte <ludovic@inverse.ca>
**
**  This library is free software; you can redistribute it and/or
**  modify it under the terms of the GNU Lesser General Public
**  License as published by the Free Software Foundation; either
**  version 2.1 of the License, or (at your option) any later version.
**
**  This library is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
**  Lesser General Public License for more details.
**
**  You should have received a copy of the GNU Lesser General Public
**  License along with this library; if not, write to the Free Software
**  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*/

#ifndef _OracleAdaptor_H
#define _OracleAdaptor_H

#import <Foundation/Foundation.h>
#import <GDLAccess/EOAdaptor.h>

@interface OracleAdaptor : EOAdaptor
{
}

- (NSString *) serverName;
- (NSString *) loginName;
- (NSString *) loginPassword;
- (NSString *) databaseName;
- (NSString *) port;

@end

#endif
