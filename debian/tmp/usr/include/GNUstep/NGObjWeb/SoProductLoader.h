/*
  Copyright (C) 2006 Helge Hess

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

#ifndef __SoProductLoader_H__
#define __SoProductLoader_H__

#import <Foundation/NSObject.h>

/*
  SoProductLoader

  This class is for loading SOPE products for a given application.
  
  TODO: document
*/

@class NSString, NSArray;

@interface SoProductLoader : NSObject
{
  NSString *productDirectoryName;
  NSString *fhsDirectoryName;
  NSArray  *searchPathes;
}

- (id)initWithAppName:(NSString *)_appName fhsName:(NSString *)_fhs
  majorVersion:(unsigned int)_mav minorVersion:(unsigned int)_miv;

/* operations */

- (void)loadProducts;

@end

#endif /* __SoProductLoader_H__ */
