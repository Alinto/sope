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

#include "NGExtensions.h"
#include "NGBase64Coding.h"
#include "NGBaseTypes.h"
#include "NGBitSet.h"
#include "NGHashMap.h"
#include "NGMemoryAllocation.h"
#include "NGStack.h"
#include "NGBundleManager.h"
#include "NGQuotedPrintableCoding.h"
#include "NSArray+enumerator.h"
#include "NSData+misc.h"
#include "NSException+misc.h"
#include "NSObject+Values.h"
#include "NSSet+enumerator.h"
#include "NSString+Formatting.h"
#include "NSString+misc.h"
#include "NSDictionary+misc.h"
#include "NSCalendarDate+misc.h"

@implementation NGExtensions

/* statically link Objective-C categories */

extern void __link_NSProcessInfo_misc(void);
extern void __link_NSCalendarDate_misc(void);
extern void __link_EODataSource_NGExtensions(void);
extern void __link_NSString_Formatting(void);
extern void __link_NGBase64Coding(void);
extern void __link_NGExtensions_NSObjectValues(void);

- (void)_staticLinkClasses {
   __link_NSProcessInfo_misc();
   __link_NSCalendarDate_misc();
   __link_EODataSource_NGExtensions();
   __link_NSString_Formatting();
   __link_NGBase64Coding();
   __link_NGExtensions_NSObjectValues();
}

@end /* NGExtensions */
