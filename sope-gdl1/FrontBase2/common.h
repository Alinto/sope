/* 
   common.h

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge.hess@mdlink.de)

   This file is part of the FB Adaptor Library

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
// $Id: common.h 1 2004-08-20 10:38:46Z znek $

#ifndef ___FB_common_H___
#define ___FB_common_H___

#import <objc/objc-api.h>

#if LIB_FOUNDATION_BOEHM_GC
#  include <objc/gc.h>
#  include <objc/gc_typed.h>
#  include <extensions/GarbageCollector.h>
#endif

#import <Foundation/Foundation.h>


#if !LIB_FOUNDATION_LIBRARY
#  import <FoundationExt/NSObjectMacros.h>
#  import <FoundationExt/FoundationException.h>
#  import <FoundationExt/NSCoderExceptions.h>
#  import <FoundationExt/NSException.h>
#  import <FoundationExt/GeneralExceptions.h>
#  import <FoundationExt/objc-api.h>
#  import <FoundationExt/objc-runtime.h>
#else
#  import <Foundation/exceptions/GeneralExceptions.h>
#endif

#import <GDLAccess/EOAccess.h>

#import "FBException.h"
#import "FBSQLExpression.h"

#import "FBChannel.h"
#import "FBContext.h"
#import "FrontBase2Adaptor.h"

#import "FBChannel+Model.h"
#import "FBValues.h"
#import "EOAttribute+FB.h"
#import "NSString+FB.h"

#endif
