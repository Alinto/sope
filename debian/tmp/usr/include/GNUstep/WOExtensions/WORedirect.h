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

#ifndef __WOExtensions_WORedirect_H__
#define __WOExtensions_WORedirect_H__

#include <NGObjWeb/WOComponent.h>

/*
  WORedirect

   Q: Whats the difference to WERedirect?
   A: It is a component while WERedirect is a dynamic element.
   
   Note: you can also use the WOComponent -redirectToLocation: method (SOPE
         specific extension).
*/

@interface WORedirect : WOComponent
{
  id url;
}

/* accessors */

- (void)setURL:(id)_url;
- (void)setUrl:(id)_url; // for KVC
- (id)url;

@end

#endif /* __WOExtensions_WORedirect_H__ */
