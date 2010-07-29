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

#include "SoDefaultRenderer.h"
#include "SoObjectRequestHandler.h"
#include "SoSecurityManager.h"
#include "WOContext+private.h" // required for page rendering
#include "WOContext+SoObjects.h"
#include "SoSecurityManager.h"
#include "SoSecurityException.h"
#include "SoObject.h"
#include "NSException+HTTP.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOElement.h>
#include <NGObjWeb/WOComponent.h>
#include "common.h"

@implementation SoDefaultRenderer

static int debugOn = 0;

+ (void)initialize {
  static BOOL didInit = NO;
  if (!didInit) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    didInit = YES;
    
    debugOn = [ud boolForKey:@"SoRendererDebugEnabled"];
  }
}

+ (id)sharedRenderer {
  static SoDefaultRenderer *singleton = nil;
  if (singleton == nil)
    singleton = [[SoDefaultRenderer alloc] init];
  return singleton;
}

/* rendering */

- (NSException *)renderException:(NSException *)_ex 
  inContext:(WOContext *)_ctx 
{
  WOResponse *r = [_ctx response];
  int stat;
  
  /* check whether it's a security framework exception */
  
  if ([_ex isKindOfClass:[SoSecurityException class]]) {
    id authenticator;
    
    if (debugOn)
      [self debugWithFormat:@"    render as security exception: %@", _ex];
    
    authenticator = [(SoSecurityException *)_ex authenticator];
    if (authenticator == nil)
      authenticator = [[_ctx application] authenticatorInContext:_ctx];
    
    if (authenticator) {
      if (debugOn)
	[self debugWithFormat:@"    authenticator: %@", authenticator];
      
      if (([authenticator renderException:_ex inContext:_ctx])) {
	if (debugOn)
	  [self debugWithFormat:@"    authenticator did render exception."];
	return nil;
      }
    }
    else {
      if (debugOn)
	[self debugWithFormat:@"    missing authenticator."];
    }
  }
  
  if (debugOn)
    [self debugWithFormat:@"    as exception"];
  
  // TODO: add ability to specify HTTP headers in the user info?
  
  if ((stat = [_ex httpStatus]) > 0) {
    [r setStatus:stat];
    if (stat >= 200 && stat < 300) {
      [r appendContentString:[_ex reason]];
      return nil;
    }
  }
  else
    [r setStatus:500];
  
  [r setHeader:@"text/html; charset=\"iso-8859-1\"" forKey:@"content-type"];
  [r appendContentString:
       @"<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n"
       @"<html xmlns=\"http://www.w3.org/1999/xhtml\">\n"
       @"<body>"
       @"<h3>An error occurred during object publishing</h3>"];
  [r appendContentString:@"<p>"];
  [r appendContentString:[_ex reason]];
  [r appendContentString:@"</p>"];
  [r appendContentString:@"</body>\n"];
  [r appendContentString:@"</html>\n"];
  return nil;
}

- (NSException *)renderComponent:(WOComponent *)_c inContext:(WOContext *)_ctx{
  WOResponse *r = [_ctx response];
  
  if (debugOn) {
    [self debugWithFormat:
	    @"    as component (use appendToResponse:inContext:)"];
  }
  [r setHeader:@"text/html" forKey:@"content-type"];
  [_ctx setPage:_c];
  [_ctx enterComponent:_c content:nil];
  [_c appendToResponse:r inContext:_ctx];
  [_ctx leaveComponent:_c];
  return nil;
}

- (NSException *)renderElement:(WOElement *)_e inContext:(WOContext *)_ctx {
  if (debugOn)
    [self debugWithFormat:@"    as element (use appendToResponse:inContext:"];
  [_e appendToResponse:[_ctx response] inContext:_ctx];
  return nil;
}

- (NSException *)renderData:(NSData *)_data inContext:(WOContext *)_ctx {
  /* this could be extended to do some MIME magic */
  WOResponse *r = [_ctx response];
  
  [r setStatus:200];
  [r setHeader:@"application/octet-stream" forKey:@"content-type"];
  [r setHeader:[NSString stringWithFormat:@"%i", [_data length]] 
     forKey:@"content-length"];
  [r setContent:_data];
  return nil;
}

- (NSException *)renderTuple:(NSArray *)_tuple inContext:(WOContext *)_ctx {
  WOResponse *r = [_ctx response];
  NSString   *title = nil, *body = nil;
  
  if (debugOn)
    [self debugWithFormat:@"    as tuple"];
  [r setStatus:200];
  [r appendContentString:@"<html>"];
  
  switch ([_tuple count]) {
  case 0: break;
  case 1: 
    body = [_tuple objectAtIndex:0]; 
    break;
  case 2: 
    title = [_tuple objectAtIndex:0];
    body  = [_tuple objectAtIndex:1];
    break;
  case 3: 
    title = [_tuple objectAtIndex:0];
    body  = [[_tuple subarrayWithRange:NSMakeRange(1, [_tuple count] - 1)]
	      componentsJoinedByString:@"<br />"];
    break;
  }
  
  if ([title length] > 0) {
    [r appendContentString:@"<head><title>"];
    [r appendContentHTMLString:title];
    [r appendContentString:@"</title></head>"];
  }
  if ([body length] > 0) {
    [r appendContentString:@"<body>"];
    [r appendContentHTMLString:body];
    [r appendContentString:@"</body>"];
  }
  [r appendContentString:@"</html>"];
  return nil;
}

- (NSException *)renderObjectAsString:(id)_object inContext:(WOContext *)_ctx {
  /* fall back, use stringValue */
  WOResponse *r;
  
  if (debugOn)
    [self debugWithFormat:@"    render as string (last fallback)"];
  
  r = [_ctx response];
  [r setStatus:200];
  [r setHeader:@"text/html" forKey:@"content-type"];
  [r appendContentString:
       @"<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n"
       @"<html xmlns=\"http://www.w3.org/1999/xhtml\">\n"
       @"<body>"];
  [r appendContentHTMLString:[_object stringValue]];
  [r appendContentString:@"</body>\n"];
  [r appendContentString:@"</html>\n"];
  return nil;
}

/* master dispatcher */

- (BOOL)processTupleResults {
  return NO;
}

- (NSException *)renderObject:(id)_object inContext:(WOContext *)_ctx {
  SoSecurityManager *sm;
  NSException *e;
  
  if ([_object isKindOfClass:[WOResponse class]]) {
    if (_object != [_ctx response]) {
      [self logWithFormat:@"response mismatch !"];
      return [NSException exceptionWithHTTPStatus:500 /* internal error */];
    }
    return nil; /* already rendered */
  }
  
  /* base types, no useful security validation possible */
  
  if ([_object isKindOfClass:[NSException class]])
    return [self renderException:_object inContext:_ctx];
  
  if ([_object isKindOfClass:[NSData class]])
    return [self renderData:_object inContext:_ctx];
  
  if ([_object isKindOfClass:[NSArray class]] && [self processTupleResults])
    return [self renderTuple:_object inContext:_ctx];
  
  /* objects that require validation */
  
  sm = [_ctx soSecurityManager];
  if ((e = [sm validateObject:_object inContext:_ctx]) != nil)
    return [self renderException:e inContext:_ctx];
  
  if ([_object isKindOfClass:[WOComponent class]])
    return [self renderComponent:_object inContext:_ctx];
  
  if ([_object respondsToSelector:@selector(appendToResponse:inContext:)])
    return [self renderElement:_object inContext:_ctx];
  
  return [self renderObjectAsString:_object inContext:_ctx];
}

- (BOOL)canRenderObject:(id)_object inContext:(WOContext *)_ctx {
  return YES;
}

/* debugging */

- (NSString *)loggingPrefix {
  return @"[so-dflt-renderer]";
}

@end /* SoDefaultRenderer */
