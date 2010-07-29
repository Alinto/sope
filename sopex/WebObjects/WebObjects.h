/*
 Copyright (C) 2004 Marcus Mueller <znek@mulle-kybernetik.com>

 This file is part of OGo

 OGo is free software; you can redistribute it and/or modify it under
 the terms of the GNU Lesser General Public License as published by the
 Free Software Foundation; either version 2, or (at your option) any
 later version.

 OGo is distributed in the hope that it will be useful, but WITHOUT ANY
 WARRANTY; without even the implied warranty of MERCHANTABILITY or
 FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 License for more details.

 You should have received a copy of the GNU Lesser General Public
 License along with OGo; see the file COPYING.  If not, write to the
 Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
 02111-1307, USA.
 */
// $Id: WebObjects.h 1 2004-08-20 11:17:52Z znek $
//  Created by znek on Thu Mar 18 2004.

#ifndef	__WebObjects_H_
#define	__WebObjects_H_

/*
 WHAT IS THIS?
 
 The sole purpose of this framework is to solve as a compatibility
 entry for legacy WebObjects projects build with Apple's discontinued
 Objective-C version of WebObjects.
 
 As far as we can tell this framework is a superset of WebObjects 4.5
 and thus compatible with WebObjects 4.5.
 
 New projects are discouraged from using this umbrella framework,
 but instead should link to SxCore, SxXML and SOPE directly.
 */

#import <Foundation/Foundation.h>
#import <NGObjWeb/NGObjWeb.h>


#endif	/* __WebObjects_H_ */
