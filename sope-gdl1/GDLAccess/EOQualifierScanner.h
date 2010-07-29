/* 
   EOQualifierScanner.h

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
           Helge Hess <helge.hess@mdlink.de>
   Date:   September 1996
           November  1999

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
// $Id: EOQualifierScanner.h 1 2004-08-20 10:38:46Z znek $

#ifndef __EOAccess_EOQualifierScanner_H__
#define __EOAccess_EOQualifierScanner_H__

#if !LIB_FOUNDATION_LIBRARY
#  import "DefaultScannerHandler.h"
#else
#  import <extensions/DefaultScannerHandler.h>
#endif

@class EOEntity;

@interface EOQualifierScannerHandler : DefaultScannerHandler
{
  EOEntity *entity;
}

- (void)setEntity:(EOEntity *)entity;

@end

@interface EOQualifierEnumScannerHandler : DefaultEnumScannerHandler
{
  EOEntity *entity;
}

- (void)setEntity:(EOEntity *)entity;

@end

#endif /* __EOAccess_EOQualifierScanner_H__ */
