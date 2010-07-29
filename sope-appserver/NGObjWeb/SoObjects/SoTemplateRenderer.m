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

#include "SoTemplateRenderer.h"
#include "SoSecurityManager.h"
#include "WOContext+SoObjects.h"
#include "WOContext+private.h" // required for page rendering
#include "NSException+HTTP.h"
#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOApplication.h>
#include "common.h"

@interface NSObject(UsedPrivates)
- (id)resourceManagerInContext:(WOContext *)_ctx;
- (id)container;
- (id)nameInContainer;
- (void)setResourceManager:(WOResourceManager *)_rm;
- (void)setName:(NSString *)_name;
@end

@interface SoTemplateCustomObjectComponent : WOComponent
{
@public
  id customObject;
}

/* accessors */

- (NSString *)customObject;

@end

@implementation SoTemplateRenderer

static BOOL debugOn = NO;

+ (void)initialize {
  static BOOL didInit = NO;
  if (!didInit) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    didInit = YES;
    
    debugOn = [ud boolForKey:@"SoTemplateRendererDebugEnabled"];
  }
}

+ (id)sharedRenderer {
  static SoTemplateRenderer *singleton = nil;
  if (singleton == nil)
    singleton = [[SoTemplateRenderer alloc] init];
  return singleton;
}

/* master dispatcher */

- (NSException *)renderComponentWithoutTemplate:(WOComponent *)_component 
  inContext:(WOContext *)_ctx 
{
  WOResponse *r;
  
  [self debugWithFormat:@"render component without template: %@", _component];
  
  r = [_ctx response];
  [r setHeader:@"text/html" forKey:@"content-type"];
  
  [_ctx setPage:_component];
  
  [_ctx enterComponent:_component content:nil];
  [_component appendToResponse:r inContext:_ctx];
  [_ctx leaveComponent:_component];
  return nil;
}

- (NSException *)renderComponent:(WOComponent *)_c inContext:(WOContext *)_ctx{
  WOResponse *r;
  WOComponent *template;
  NSString    *templateName;
  
  [self debugWithFormat:@"template renderer render component: %@", _c]; 

  /* determine name of template */
  
  templateName = [[_ctx request] formValueForKey:@"template"];
  if ([templateName length] == 0) templateName = @"Main";
  
  /* lookup template */
  
  if ((template = [_c pageWithName:templateName])==nil){
    [self debugWithFormat:@"did not find a template named '%@'", templateName];
    return [self renderComponentWithoutTemplate:_c inContext:_ctx];
  }
  
  [self debugWithFormat:@"  render with template: %@", template];
  
  /* render template */
  
  r = [_ctx response];
  [r setHeader:@"text/html" forKey:@"content-type"];
  
  // TODO: use template as page? may be required for component actions,
  //       but mixes up the system?
  [_ctx setPage:_c];
  
  [_ctx enterComponent:template content:nil];
  [template appendToResponse:r inContext:_ctx];
  [_ctx leaveComponent:template];
  
  return nil;
}

- (NSException *)renderCustomObject:(id)_obj inContext:(WOContext *)_ctx {
  SoTemplateCustomObjectComponent *component;
  WOResourceManager *rm;
  NSException       *e;
  NSString          *componentName;
  
  [self debugWithFormat:@"template renderer render custom object: %@", _obj]; 
  
  /* create resource manager for object */
  
  if ([_obj respondsToSelector:@selector(resourceManagerInContext:)])
    rm = [_obj resourceManagerInContext:_ctx];
  else {
    id container;
    
    if ([_obj respondsToSelector:@selector(container)])
      container = [_obj container];
    else
      container = nil;
    
    if ([container respondsToSelector:@selector(resourceManagerInContext:)])
      rm = [container resourceManagerInContext:_ctx];
    else {
      /* TODO: maybe not the best solution? ;-) */
      rm = [[WOApplication application] resourceManager];
    }
  }
  [self debugWithFormat:@"  using resource manager: %@", rm];
  
  /* create a component wrapper for the custom object */
  
  component = [[SoTemplateCustomObjectComponent alloc] initWithContext:_ctx];
  component->customObject = [_obj retain];

  if ((componentName = [_obj nameInContainer])) {
    componentName = [componentName stringByDeletingPathExtension];
    [component setName:componentName];
  }
  [component ensureAwakeInContext:_ctx];
  [component setResourceManager:rm];
  [self debugWithFormat:@"  custom object component: %@", component];
  
  /* render custom component like a usual one ... */
  
  e = [self renderComponent:component inContext:_ctx];
  [component release];
  return e;
}

- (NSException *)renderObject:(id)_object inContext:(WOContext *)_ctx {
  SoSecurityManager *sm;
  NSException *e;
  
  [self debugWithFormat:@"template renderer render: %@ in ctx 0x%p", 
          _object, _ctx];
  
  sm = [_ctx soSecurityManager];
  if ((e = [sm validateObject:_object inContext:_ctx]) != nil)
    return e;
  
  if ([_object isKindOfClass:[WOComponent class]])
    return [self renderComponent:_object inContext:_ctx];
  
  return [self renderCustomObject:_object inContext:_ctx];
}

- (BOOL)canRenderObject:(id)_object inContext:(WOContext *)_ctx {
  // TODO: we could add specialized templates for exceptions !
  
  [self debugWithFormat:@"template renderer shall render: %@", _object];
  
#if 0 
  /* 
     TODO: does that harm anyone?, in theory templates can render without
           embedding "page". Though if they do, all this breaks ... (since
	   the page is probably the template?)
  */
  if (![_object isKindOfClass:[WOComponent class]])
    return NO;
#endif
  
  return YES;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}
- (NSString *)loggingPrefix {
  return @"[so-tmpl-renderer]";
}

@end /* SoTemplateRenderer */

@implementation SoTemplateCustomObjectComponent

- (void)dealloc {
  [self->customObject release];
  [super dealloc];
}

/* accessors */

- (NSString *)customObject {
  return self->customObject;
}

/* key/value coding */

- (id)objectForKey:(NSString *)_key {
  return [self->customObject valueForKey:_key];
}

/* response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  [_response appendContentString:@"<!-- custom object -->"];
  [super appendToResponse:_response inContext:_ctx];
}

@end /* SoTemplateCustomObjectComponent */
