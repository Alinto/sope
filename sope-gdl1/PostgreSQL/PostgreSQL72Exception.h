/* 
   PostgreSQL72Exception.h

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

#ifndef ___PostgreSQL72_Exception_H___
#define ___PostgreSQL72_Exception_H___

#import <Foundation/NSException.h>

@interface PostgreSQL72Exception : NSException
{
}

+ (void)raiseWithFormat:(NSString *)_format, ...;

@end

@interface PostgreSQL72CouldNotOpenChannelException : PostgreSQL72Exception
{
}
@end

@interface PostgreSQL72CouldNotConnectException : PostgreSQL72CouldNotOpenChannelException
{
}
@end

@interface PostgreSQL72CouldNotBindException : PostgreSQL72Exception
{
}
@end

#endif
