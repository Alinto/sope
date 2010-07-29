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

#ifndef __SoOFS_OFSWebDocument_H__
#define __SoOFS_OFSWebDocument_H__

#include <SoOFS/OFSWebMethod.h>

/*
  OFSWebDocument

  A web-document is basically the same thing like a web method - the only 
  difference is the assignment of the "clientObject" in the context. A method
  always applies on the object prior in it's traversal path while a document
  applies to itself.
*/

@interface OFSWebDocument : OFSWebMethod
{
}

@end

#endif /* __SoOFS_OFSWebDocument_H__ */
