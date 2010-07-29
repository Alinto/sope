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

#include "WOImage.h"

@interface _WOResourceImage : WOImage
{
  WOAssociation *filename;  // path relative to WebServerResources
  WOAssociation *framework;
}
@end

#include "WOElement+private.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOResourceManager.h>
#include "decommon.h"

@implementation _WOResourceImage

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->filename  = OWGetProperty(_config, @"filename");
    self->framework = OWGetProperty(_config, @"framework");
    
    if (self->filename == nil) {
      NSLog(@"missing filename association for WOImage ..");
      [self release];
      return nil;
    }

#if DEBUG
    if ([_config objectForKey:@"value"]    ||
        [_config objectForKey:@"data"]     ||
        [_config objectForKey:@"mimeType"] ||
        [_config objectForKey:@"key"]      ||
        [_config objectForKey:@"src"]) {
      NSLog(@"WARNING: inconsistent association settings in WOImage !"
            @" (assign only one of value, src, data or filename)");
    }
#endif
  }
  return self;
}

- (void)dealloc {
  [self->framework release];
  [self->filename  release];
  [super dealloc];
}

/* HTML generation */

- (void)_appendSrcToResponse:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  NSString    *uFi;
  NSArray     *languages;
  WOResourceManager *rm;
  NSString    *frameworkName;
  
  sComponent = [_ctx component];

  if (self->filename == nil) {
    [_resp appendContentHTMLAttributeValue:
             @"/missingImage?reason=nofilenamebinding"];
    return;
  }
  
  if ((uFi = [self->filename stringValueInComponent:sComponent]) == nil) {
    [_resp appendContentHTMLAttributeValue:
             @"/missingImage?reason=nilfilenamebinding"];
    return;
  }
  
  if ((rm = [[_ctx component] resourceManager]) == nil)
    rm = [[_ctx application] resourceManager];
  
  languages = [_ctx hasSession] ? [[_ctx session] languages] : (NSArray *)nil;
  
  /* If 'framework' binding is not set, use parent component's framework */
  if (self->framework){
    frameworkName = [self->framework stringValueInComponent:sComponent];
    if (frameworkName != nil && [frameworkName isEqualToString:@"app"])
      frameworkName = nil;
  }
  else
    frameworkName = [sComponent frameworkName];

  uFi = [rm urlForResourceNamed:uFi
            inFramework:frameworkName
            languages:languages
            request:[_ctx request]];
  if (uFi == nil) {
    uFi = [self->filename stringValueInComponent:sComponent];
    NSLog(@"%@: did not find resource '%@'", sComponent, uFi);
    uFi = [@"/missingImage?" stringByAppendingString:uFi];
  }
  
#if HEAVY_DEBUG
  [self logWithFormat:@"RESOURCE IMAGE: %@", uFi];
#endif
  [_resp appendContentHTMLAttributeValue:uFi];
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = [NSMutableString stringWithCapacity:64];

  [str appendFormat:@" filename=%@", self->filename];
  if (self->framework) [str appendFormat:@" framework=%@", self->framework];
  [str appendString:[super associationDescription]];
  return str;
}

@end /* _WOResourceImage */
