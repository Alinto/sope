/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef	__NGExtensions_NGLogLevel_H_
#define	__NGExtensions_NGLogLevel_H_

/*
  Currently defined log levels.
*/

typedef enum {
  NGLogLevelOff   = 0,
  NGLogLevelFatal = 1,
  NGLogLevelError = 2,
  NGLogLevelWarn  = 3,
  NGLogLevelInfo  = 4,
  NGLogLevelDebug = 5,
  NGLogLevelAll   = 6
} NGLogLevel;

#endif	/* __NGExtensions_NGLogLevel_H_ */
