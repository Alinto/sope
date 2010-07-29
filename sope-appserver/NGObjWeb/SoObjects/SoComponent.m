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

#include "SoComponent.h"
#include "SoProductResourceManager.h"
#include "SoProductRegistry.h"
#include "SoProduct.h"
#include <NGObjWeb/WOApplication.h>
#include "common.h"

@implementation SoComponent

+ (int)version {
  return [super version] + 0 /* v2 */;
}
+ (void)initialize {
  static BOOL didInit = NO;
  
  if (didInit) return;
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  didInit = YES;
}

- (void)dealloc {
  [self->soResourceManager release];
  [self->soTemplate        release];
  [self->soBaseURL         release];
  [super dealloc];
}

/* resource manager */

- (NSBundle *)componentBundle {
  return [NSBundle bundleForClass:[self class]];
}
- (SoProduct *)componentProduct {
  static SoProductRegistry *reg = nil;
  SoProduct *product;
  NSBundle  *bundle;
  
  if (reg == nil)
    reg = [[SoProductRegistry sharedProductRegistry] retain];
  if (reg == nil)
    [self errorWithFormat:@"missing product registry!"];
  
  if ((bundle = [self componentBundle]) == nil)
    [self warnWithFormat:@"did not find bundle of component !"];
  
  if ((product = [reg productForBundle:bundle]) == nil)
    [self warnWithFormat:@"did not find product of component (bundle=%@)",
            bundle];
  return product;
}

- (void)setResourceManager:(WOResourceManager *)_rm {
  ASSIGN(self->soResourceManager, _rm);
}
- (WOResourceManager *)resourceManager {
  if (self->soResourceManager != nil)
    return self->soResourceManager;
  
  self->soResourceManager = [[[self componentProduct] resourceManager] retain];
  if (self->soResourceManager)
    return self->soResourceManager;
  
  return [super resourceManager];
}

/* move some extra vars into ivars */

- (void)setBaseURL:(NSURL *)_url {
  ASSIGN(self->soBaseURL, _url);
}
- (NSURL *)baseURL {
  NSURL *url;
  
  if (self->soBaseURL)
    return self->soBaseURL;
  
  url = [(WOApplication *)[self application] baseURL];
  url = [NSURL URLWithString:@"WebServerResources" relativeToURL:url];
  self->soBaseURL = [url copy];
  return self->soBaseURL;
}

- (void)setTemplate:(id)_template {
  /*
    WO has private API for this:
      - (void)setTemplate:(WOElement *)template;
    As mentioned in the OmniGroup WO mailing list ...
  */
  ASSIGN(self->soTemplate, _template);
}
- (WOElement *)_woComponentTemplate {
  WOElement *tmpl;
  
  if (self->soTemplate)
    return self->soTemplate;
  
  tmpl = [self templateWithName:[self name]];
  if (tmpl == nil) {
    [self warnWithFormat:
	    @"found no template named '%@' for component (fw=%@)",
	    [self name], [self frameworkName]];
  }
  return tmpl;
}

@end /* SoComponent */
