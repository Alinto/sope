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

#include "WOHyperlink.h"
#include "WOElement+private.h"
#include "WOHyperlinkInfo.h"
#include "WOCompoundElement.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOResourceManager.h>
#include <NGExtensions/NSString+Ext.h>
#include "decommon.h"

#define PROFILE_CLUSTERS 0

#if PROFILE_CLUSTERS
#  warning HYPERLINK CLUSTER PROFILING IS TURNED ON !!!
#endif

// TODO(perf): all adding of links to an anker can probably be added using
//             appendContentCString because they are already escaped
//             => check that for umlauts in downloads !

/*
  WOHyperlink associations:

    href | pageName | action | (directActionName & actionClass)
    fragmentIdentifier
    string
    target
    disabled
    queryDictionary

  Concrete Class Hierachy

    _WOTemporaryHyperlink
    WOHTMLDynamicElement
      WOHyperlink
        _WOComplexHyperlink
          _WOHrefHyperlink
          _WOActionHyperlink
          _WOPageHyperlink
          _WODirectActionHyperlink
        _WOSimpleActionHyperlink
          _WOSimpleStringActionHyperlink
        _WOCommonStaticDAHyperlink
*/

@implementation WOHyperlink

+ (int)version {
  return [super version] + 2 /* v4 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

+ (id)allocWithZone:(NSZone *)zone {
  static Class WOHyperlinkClass = Nil;
  static _WOTemporaryHyperlink *temporaryHyperlink = nil;
  
  if (WOHyperlinkClass == Nil)
    WOHyperlinkClass = [WOHyperlink class];
  if (temporaryHyperlink == nil)
    temporaryHyperlink = [_WOTemporaryHyperlink allocWithZone:zone];
  
  if (self == WOHyperlinkClass)
    return temporaryHyperlink;
  else {
#if PROFILE_CLUSTERS
    static unsigned totalCount        = 0;
    static unsigned countSimpleAction = 0;
    static unsigned countAction       = 0;
    static unsigned countHref         = 0;
    static unsigned countDirectAction = 0;
    static unsigned countCommonDA     = 0;
    static unsigned countOther        = 0;
    totalCount++;
    if (self == [_WOSimpleActionHyperlink class])
      countSimpleAction++;
    else if (self == [_WOActionHyperlink class])
      countAction++;
    else if (self == [_WODirectActionHyperlink class])
      countDirectAction++;
    else if (self == [_WOHrefHyperlink class])
      countHref++;
    else if (self == NSClassFromString(@"_WOCommonStaticDAHyperlink"))
      countCommonDA++;
    else
      countOther++;

    if (totalCount % 30 == 0) {
      NSLog(@"WOHyperlink statistics:\n"
            @" total: %d,"
            @" simple action: %d,"
            @" action: %d,"
            @" direct action: %d,"
            @" common DA:     %d,"
            @" href: %d,"
            @" other: %d",
            totalCount, countSimpleAction, countAction,
            countDirectAction, countCommonDA, countHref, countOther);
    }
#endif
    return NSAllocateObject(self, 0, zone);
  }
}

- (id)initWithName:(NSString *)_name
  hyperlinkInfo:(WOHyperlinkInfo *)_info
  template:(WOElement *)_t
{
  return [super initWithName:_name associations:nil template:_t];
}

@end /* WOHyperlink */
