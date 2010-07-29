/* 
   PGConnection.h

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

#ifndef ___PostgreSQL72_PGConnection_H___
#define ___PostgreSQL72_PGConnection_H___

#import <Foundation/NSObject.h>

@class NSString, NSException;
@class PGResultSet;

@interface PGConnection : NSObject
{
@public
  void *_connection;
}

- (id)initWithHostName:(NSString *)_host port:(NSString *)_port
  options:(NSString *)_options tty:(NSString *)_tty 
  database:(NSString *)_dbname 
  login:(NSString *)_login password:(NSString *)_pwd;

/* accessors */

- (BOOL)isValid;

/* connect operations */

- (NSException *)startConnectWithInfo:(NSString *)_conninfo; // async

- (NSException *)connectWithInfo:(NSString *)_conninfo;
- (NSException *)connectWithHostName:(NSString *)_host port:(NSString *)_port
  options:(NSString *)_options tty:(NSString *)_tty 
  database:(NSString *)_dbname 
  login:(NSString *)_login password:(NSString *)_pwd;

- (void)finish;

- (BOOL)isConnectionOK;

/* message callbacks */

- (BOOL)setNoticeProcessor:(void *)_callback context:(void *)_ctx;

/* settings */

- (BOOL)setClientEncoding:(NSString *)_encoding;

/* errors */

- (NSString *)errorMessage;

/* queries */

- (void *)rawExecute:(NSString *)_sql;
- (void)clearRawResults:(void *)_ptr;
- (PGResultSet *)execute:(NSString *)_sql;

/* support */

- (const char *)_cstrFromString:(NSString *)_s;
- (NSString *)_stringFromCString:(const char *)_cstr;

@end



@interface PGResultSet : NSObject
{
@protected
  PGConnection *connection;
@public
  void         *results;
}

- (id)initWithConnection:(PGConnection *)_con handle:(void *)_handle;

/* accessors */

- (BOOL)isValid;

- (BOOL)containsBinaryTuples;
- (NSString *)commandStatus;
- (NSString *)commandTuples;

/* fields */

- (unsigned)fieldCount;
- (NSString *)fieldNameAtIndex:(unsigned int)_idx;
- (int)indexOfFieldNamed:(NSString *)_name;
- (int)fieldSizeAtIndex:(unsigned int)_idx;
- (int)modifierAtIndex:(unsigned int)_idx;

/* tuples */

- (unsigned int)tupleCount;
- (BOOL)isNullTuple:(int)_tuple atIndex:(unsigned int)_idx;
- (void *)rawValueOfTuple:(int)_tuple atIndex:(unsigned int)_idx;
- (int)lengthOfTuple:(int)_tuple atIndex:(unsigned int)_idx;

/* operations */

- (void)clear;

@end

#endif /* ___PostgreSQL72_PGConnection_H___ */
