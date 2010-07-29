/* 
   PostgreSQL72Channel.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess
   Copyright (C) 2000-2006 SKYRIX Software AG and Helge Hess

   Author: Helge Hess (helge.hess@opengroupware.org)

   This file is part of the PostgreSQL Adaptor Library

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

#ifndef PG_MAJOR_VERSION
/* PostgreSQL 7.4 and up do not have those versioning checks */


#define NG_HAS_NOTICE_PROCESSOR 1
#define NG_HAS_BINARY_TUPLES    1
#define NG_HAS_FMOD             1
#define NG_SET_CLIENT_ENCODING  1


#else /* PG_MAJOR_VERSION processing */


#if PG_MAJOR_VERSION >= 6 && PG_MINOR_VERSION > 3
#  define NG_HAS_NOTICE_PROCESSOR 1
#  define NG_HAS_BINARY_TUPLES    1
#  define NG_HAS_FMOD             1
#endif

#if PG_MAJOR_VERSION >= 7 && PG_MINOR_VERSION > 3
#  define NG_SET_CLIENT_ENCODING 1
#endif


#endif /* PG_MAJOR_VERSION processing */
