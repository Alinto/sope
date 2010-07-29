/* 
   NSString+MySQL4.h

   Copyright (C) 1999-2005 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge@mdlink.de)

   This file is part of the MySQL4 Adaptor Library

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

#ifndef ___MySQL4_NSString_H___
#define ___MySQL4_NSString_H___

#import <Foundation/NSString.h>

@interface NSString(MySQL4MiscStrings)

- (NSString *)_mySQL4ModelMakeInstanceVarName;
- (NSString *)_mySQL4ModelMakeClassName;
- (NSString *)_mySQL4StringWithCapitalizedFirstChar;
- (NSString *)_mySQL4StripEndSpaces;

@end

#endif /* ___MySQL4_NSString_H___ */
