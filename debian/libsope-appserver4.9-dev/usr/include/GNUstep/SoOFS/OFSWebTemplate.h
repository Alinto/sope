/*
  Copyright (C) 2000-2005 SKYRIX Software AG

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

#ifndef __SoOFS_OFSWebTemplate_H__
#define __SoOFS_OFSWebTemplate_H__

#include <SoOFS/OFSWebMethod.h>

/*
  OFSWebTemplate

  A specialized SoClass for handling SOPE templates. The major difference
  is, that templates cannot be access through the web !
  
  [TODO: implement the web-limit, templates should not be callable !]
*/

@interface OFSWebTemplate : OFSWebMethod
{
}

@end

#endif /* __SoOFS_OFSWebTemplate_H__ */
