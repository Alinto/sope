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

#include "OFSWebMethod.h"
#include <NGObjWeb/WEClientCapabilities.h>
#include <NGObjWeb/WOResourceManager.h>
#include <NGObjWeb/WOSession.h>
#include <NGObjWeb/WOResponse.h>
#include "common.h"

@interface WOComponent(RM)
- (void)setResourceManager:(WOResourceManager *)_rm;
@end

@implementation OFSWebMethod

static BOOL debugOn = NO;

+ (int)version {
  return [super version] + 0 /* v1 */;
}
+ (void)initialize {
  static BOOL didInit = NO;
  if (!didInit) {
    didInit = YES;
    NSAssert2([super version] == 1,
	      @"invalid superclass (%@) version %i !",
	      NSStringFromClass([self superclass]), [super version]);
    
    debugOn = [[NSUserDefaults standardUserDefaults] 
	                       boolForKey:@"SoOFSWebMethodDebugEnabled"];
  }
}

- (void)dealloc {
  [self->component release];
  [super dealloc];
}

/* page */

- (WOResourceManager *)resourceManagerInContext:(id)_ctx {
  return [[self container] resourceManagerInContext:_ctx];
}

- (WOComponent *)componentInContext:(WOContext *)_ctx {
  WOResourceManager *rm;
  WOComponent *lPage;
  NSArray     *languages;
  
  if (self->component)
    return self->component;
  
  [self debugWithFormat:@"should load component: %@", [self storagePath]];
  if ((rm = [self resourceManagerInContext:_ctx]) == nil) {
    [self logWithFormat:@"got no resource manager ..."];
    return nil;
  }
    
  /* determine language */
    
  languages = [_ctx hasSession]
    ? [(WOSession *)[_ctx session] languages]
    : [[_ctx request] browserLanguages];
    
  /* instantiate */
    
  lPage = [rm pageWithName:[self nameInContainer] languages:languages];
  [lPage ensureAwakeInContext:_ctx];
  [lPage setResourceManager:rm];
  
  [self debugWithFormat:@"   page: %@", lPage];
  
  self->component = [lPage retain];
  return self->component;
}
- (WOComponent *)component {
  return [self componentInContext:[[WOApplication application] context]];
}

/* actions */

- (id)rendererForObject:(id)_object inContext:(WOContext *)_ctx {
  // TODO: should return the component ?
  // TODO: add OFSWebMethodRenderer which selects on DAV ?
  return nil;
}

- (id)getUnparsedContentInContext:(WOContext *)_ctx {
  /* this method should not be publically available ! */
  // TODO: check permission for source-view !
  return [super GETAction:_ctx];
}

- (BOOL)useRendererForComponentCreation {
  /* will GET/view return the component as a result or self ? */
  return NO;
}

- (id)viewAction:(WOContext *)_ctx {
  /* 
     The difference to get is, that view always renders the content, so
     you can get a rendered representation even with a WebDAV client.
  */
  
  /* the default renderer will recognize that as a component ... */
  return [self useRendererForComponentCreation]
    ? (id)self 
    : (id)[self componentInContext:_ctx];
}

- (id)GETAction:(WOContext *)_ctx {
  WORequest *rq;
  NSString  *translate;
  
  rq = [_ctx request];
  translate = [[rq headerForKey:@"translate"] lowercaseString];
  
  if ([translate hasPrefix:@"f"]) {
    /* return the unparsed body */
    if (debugOn)
      [self debugWithFormat:@"returning unparsed content (translate f)"];
    return [self getUnparsedContentInContext:_ctx];
  }
  
  if ([[rq clientCapabilities] isDAVClient]) {
    /* return the unparsed body */
    if (debugOn)
      [self debugWithFormat:@"returning unparsed content (DAV-client)"];
    return [self getUnparsedContentInContext:_ctx];
  }
  
  /* the default renderer will recognize that as a component ... */
  if (debugOn) [self debugWithFormat:@"return component object for GET ..."];
  return [self viewAction:_ctx];
}
- (id)POSTAction:(WOContext *)_ctx {
  WOComponent *comp;
  
  if (debugOn) [self debugWithFormat:@"process POST using component ..."];
  
  if ((comp = [self componentInContext:_ctx]) == nil)
    return nil;
  
  // TODO: should we invoke some action ?
  // TODO: maybe the renderer should do the takeValues/invoke/... ??
  [comp takeValuesFromRequest:[_ctx request] inContext:_ctx];
  return comp;
}

- (BOOL)isOFSWebMethod {
  return YES;
}

/* calling (being a method ...) */

- (BOOL)isCallable {
  return YES;
}

- (id)callOnObject:(id)_client inContext:(id)_ctx {
  WOComponent *c;
  
  if ((c = [self componentInContext:_ctx]) == nil)
    return nil;
  
  [c setClientObject:_client];
  return c;
}

- (id)clientObject {
  return [[[WOApplication application] context] clientObject];
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* OFSWebMethod */

@implementation NSObject(OFSWebMethodClassify)

- (BOOL)isOFSWebMethod {
  return NO;
}

@end /* NSObject(OFSWebMethodClassify) */
