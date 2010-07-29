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

#include "WOResourceURLAssociation.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResourceManager.h>
#include <NGObjWeb/WOSession.h>
#include "common.h"

@implementation WOResourceURLAssociation

static BOOL doDebug = NO;

+ (int)version {
  return [super version] + 0 /* v2 */;
}
+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  
  doDebug = [ud boolForKey:@"WOResourceURLAssociationDebugEnabled"];
}

- (id)initWithString:(NSString *)_name {
  if ([_name length] == 0) {
    if (doDebug) {
      [self warnWithFormat:@"(%s): got passed no resource name!", 
              __PRETTY_FUNCTION__];
    }
    [self release];
    return nil;
  }
  if ((self = [super init])) {
    NSRange r;
    
    r = [_name rangeOfString:@"/"];
    if (r.length == 0)
      self->resourceName = [_name copy];
    else {
      self->frameworkName = [[_name substringToIndex:r.location] copy];
      self->resourceName  = 
	[[_name substringFromIndex:(r.location + r.length)] copy];
    }
  }
  return self;
}
- (id)init {
  return [self initWithString:nil];
}

- (void)dealloc {
  [self->resourceName  release];
  [self->frameworkName release];
  [super dealloc];
}

/* accessors */

- (NSString *)resourceName {
  return self->resourceName;
}
- (NSString *)frameworkName {
  return self->frameworkName;
}

/* value */

- (void)setValue:(id)_value inComponent:(WOComponent *)_component {
  /* resource-url association values cannot be set */
  [NSException raise:@"AssociationException"
               format:@"association value is not settable !"];
}
- (id)valueInComponent:(WOComponent *)_component {
  WOResourceManager *rm;
  WOContext *ctx;
  NSArray   *langs;
  WORequest *rq;
  id url;
  
  if (doDebug) {
    [self debugWithFormat:@"lookup resource: %@ in component %@",
	  [self resourceName], _component];
  }
  
  if ((ctx = [_component context]) == nil)
    ctx = [[WOApplication application] context];
  rq    = [ctx request];
  langs = [ctx resourceLookupLanguages];
  
  if (doDebug) {
    [self debugWithFormat:@"  languages: %@", 
            [langs componentsJoinedByString:@","]];
  }
  
  if ((rm = [_component resourceManager]) == nil) {
    WOApplication *app;

    if (doDebug)
      [self logWithFormat:@"component has no own resource manager!"];
    
    if ((app = [ctx application]) == nil)
      app = [WOApplication application];
    
    rm = [app resourceManager];
  }
  if (rm == nil) {
    [self warnWithFormat:@"found no resource manager!"];
    return nil;
  }
  if (doDebug) [self debugWithFormat:@"  resource-manager: %@", rm];
  
  url = [rm urlForResourceNamed:[self resourceName]
            inFramework:[self frameworkName]
            languages:langs
            request:rq];
  if (doDebug) {
    if (url != nil)
      [self debugWithFormat:@"  => URL: %@", url];
    else
      [self debugWithFormat:@"  => resource not found!"];
  }
  return url;
}

- (BOOL)isValueConstant {
  return NO;
}
- (BOOL)isValueSettable {
  return NO;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  /* rsrc-url associations are immutable and don't need to be copied */
  return [self retain];
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return doDebug;
}
- (NSString *)loggingPrefix {
  return [NSString stringWithFormat:@"[rsrc:url assoc:0x%p]", self];
}

/* description */

- (NSString *)description {
  NSMutableString *str;

  str = [NSMutableString stringWithCapacity:64];
  [str appendFormat:@"<%@[0x%p]:", NSStringFromClass([self class]), self];
  [str appendFormat:@" rsrc='%@'", [self resourceName]];
  [str appendString:@">"];
  return str;
}

@end /* WOResourceURLAssociation */
