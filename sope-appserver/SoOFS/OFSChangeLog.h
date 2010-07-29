/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#ifndef __SoOFS_OFSChangeLog_H__
#define __SoOFS_OFSChangeLog_H__

#include <SoOFS/OFSFile.h>

/*
  OFSChangeLog

  This class is intended to wrap a ChangeLog text file. It should provide
  web methods to view and edit ChangeLog information in a convenient way.
*/

@interface OFSChangeLog : OFSFile
{
}

@end

#endif /* __SoOFS_OFSChangeLog_H__ */
