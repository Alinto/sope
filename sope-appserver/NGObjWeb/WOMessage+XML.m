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

#include <NGObjWeb/WOMessage.h>
#include "common.h"

@interface NSObject(DOMXML)
- (void)outputDocument:(id)_document to:(id)_target;
- (id)buildFromData:(NSData *)_data;
- (id)documentElement;
- (void)appendChild:(id)_child;
@end

@implementation WOMessage(XMLSupport)

- (void)_rebuildDOMDataContent {
  NSMutableString *ms;
  id     outputter;
  NSData *data;
  id     dom;
  
  if ((dom = self->domCache) == nil) {
    [self setContent:nil];
    return;
  }
  
  outputter =
    [[[NSClassFromString(@"DOMXMLOutputter") alloc] init] autorelease];
  
  ms = [NSMutableString stringWithCapacity:2048];
  [outputter outputDocument:dom to:ms];
  
  data = [ms dataUsingEncoding:NSUTF8StringEncoding];

  [self setContent:data];
}

- (void)setContentDOMDocument:(id)_dom {
  ASSIGN(self->domCache, _dom);
  [self _rebuildDOMDataContent];
}

- (void)appendContentDOMDocumentFragment:(id)_domfrag {
  id dom;
  
  if (_domfrag == nil)
    return;
  
  if ((dom = [self contentAsDOMDocument])) {
    [[dom documentElement] appendChild:_domfrag];
    [self setContentDOMDocument:dom];
  }
  else {
    [self setContentDOMDocument:_domfrag];
  }
}

- (id)contentAsDOMDocument {
  NSData *data;
  id dom;
  
  if ((dom = self->domCache) != nil)
    return dom;
  
  if ((data = [self content]) != nil) {
    id builder;
    
    builder = [[[NSClassFromString(@"DOMSaxBuilder") alloc] init] autorelease];
    dom = [builder buildFromData:data];
  }
  
  /* cache DOM structure */
  if (dom != nil) {
    ASSIGN(self->domCache, dom);
  }
  return dom;
}

@end /* WOMessage */
