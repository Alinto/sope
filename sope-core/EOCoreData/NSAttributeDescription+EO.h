/*
  Copyright (C) 2005-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess
  
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

#ifndef __NSAttributeDescription_EO_H__
#define __NSAttributeDescription_EO_H__

// the next two are here to please the Leopard
#import <Foundation/NSEnumerator.h>
@class NSData;

#import <CoreData/NSAttributeDescription.h>

/*
  NSAttributeDescription(EO)
  
  Make an NSAttributeDescription behave like an EOAttribute. This is mostly to
  make the CoreData model objects work with DirectToWeb and EO at the same 
  time.
*/

@interface NSAttributeDescription(EO)

- (unsigned)width;
- (BOOL)allowsNull;

@end

#endif /* __NSAttributeDescription_EO_H__ */
