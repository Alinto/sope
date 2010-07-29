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
#include "WOHyperlinkInfo.h"
#include "WOCompoundElement.h"
#include <NGObjWeb/WOAssociation.h>
#include "decommon.h"

@implementation _WOTemporaryHyperlink

static Class _WOSimpleActionHyperlinkClass       = Nil;
static Class _WOSimpleStringActionHyperlinkClass = Nil;
static Class _WOActionHyperlinkClass             = Nil;
static Class _WOPageHyperlinkClass               = Nil;
static Class _WOHrefHyperlinkClass               = Nil;
static Class _WOCommonStaticDAHyperlinkClass     = Nil;
static Class _WODirectActionHyperlinkClass       = Nil;

+ (void)initialize {
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;

  _WOSimpleActionHyperlinkClass = 
    NSClassFromString(@"_WOSimpleActionHyperlink");
  _WOSimpleStringActionHyperlinkClass = 
    NSClassFromString(@"_WOSimpleStringActionHyperlink");

  _WOActionHyperlinkClass = NSClassFromString(@"_WOActionHyperlink");
  _WOPageHyperlinkClass   = NSClassFromString(@"_WOPageHyperlink");
  _WOHrefHyperlinkClass   = NSClassFromString(@"_WOHrefHyperlink");

  _WOCommonStaticDAHyperlinkClass = 
    NSClassFromString(@"_WOCommonStaticDAHyperlink");
  _WODirectActionHyperlinkClass = 
    NSClassFromString(@"_WODirectActionHyperlink");
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  WOHyperlinkInfo *info;
  Class linkClass = Nil;
  
  if ((info = [(WOHyperlinkInfo *)[WOHyperlinkInfo alloc]
                initWithConfig:(id)_config]) == nil) {
    return nil;
  }
  
  if (info->action) {
    if (info->assocCount == 0)
      linkClass = [_WOSimpleActionHyperlinkClass class];
    else if ((info->assocCount == 1) && (info->string != nil))
      linkClass = [_WOSimpleStringActionHyperlinkClass class];
    else
      linkClass = [_WOActionHyperlinkClass class];
  }
  else if (info->pageName) {
    linkClass = [_WOPageHyperlinkClass class];
  }
  else if (info->href) {
    linkClass = [_WOHrefHyperlinkClass class];
  }
  else if (info->directActionName) {
    linkClass = Nil;
    
    if (info->assocCount < 3) {
      if ([info->directActionName isValueConstant]) {
        if (info->actionClass == nil ||
            ([info->actionClass isValueConstant])) {
          if (info->assocCount == 1) {
            if (info->queryParameters != nil || info->string != nil)
              linkClass = [_WOCommonStaticDAHyperlinkClass class];
          }
          else if (info->assocCount == 2 &&
                   (info->queryParameters != nil) &&
                   (info->string != nil)) {
            linkClass = [_WOCommonStaticDAHyperlinkClass class];
          }
        }
      }
    }

    if (linkClass == Nil)
      linkClass = [_WODirectActionHyperlinkClass class];
  }
  else {
    NSLog(@"%s: found no setting for link named '%@', assocs %@",
          __PRETTY_FUNCTION__, _name, _config);
    return nil;
  }
  
  self =
    [[linkClass alloc] initWithName:_name hyperlinkInfo:info template:_t];
  [info release]; info = nil;
  return self;
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_associations
  contentElements:(NSArray *)_contents
{
  WOCompoundElement *template;
  int count;
  
  count = [_contents count];
  
  if (count == 0) {
    template = nil;
  }
  else if (count == 1) {
    template = [_contents objectAtIndex:0];
  }
  else {
    template = [[WOCompoundElement allocForCount:[_contents count]
                                   zone:[self zone]]
                                   initWithContentElements:_contents];
    [template autorelease];
  }
  
  return [self initWithName:_name
               associations:_associations
               template:template];
}

- (void)dealloc {
  [self errorWithFormat:@"called dealloc on %@", self];
#if DEBUG
  abort();
#endif
  return;

  // make Tiger GCC / gcc 4.1 happy
  if (0) [super dealloc];
}

@end /* _WOTemporaryHyperlink */
