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

#ifndef __NGNet_H__
#define __NGNet_H__

#include <NGStreams/NGActiveSocket.h>
#include <NGStreams/NGInternetSocketAddress.h>
#include <NGStreams/NGInternetSocketDomain.h>
#include <NGStreams/NGPassiveSocket.h>
#include <NGStreams/NGSocket.h>
#include <NGStreams/NGSocketExceptions.h>
#include <NGStreams/NGSocketProtocols.h>
#include <NGStreams/NGDatagramPacket.h>
#include <NGStreams/NGDatagramSocket.h>
#include <NGStreams/NGNetUtilities.h>

#if !defined(WIN32)
#  include <NGStreams/NGLocalSocketAddress.h>
#  include <NGStreams/NGLocalSocketDomain.h>
#endif

// kit class

@interface NGNet : NSObject
@end

#define LINK_NGNet void __link_NGNet() { [NGNet class]; }

#endif /* __NGNet_H__ */
