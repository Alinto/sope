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

#include "WOComponentContent.h"
#include "WOContext+private.h"
#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WOResponse.h>
#include "decommon.h"

@interface WOContext(ComponentStackCount)
- (unsigned)componentStackCount;
@end

@implementation WOComponentContent

static int profileComponents = -1;
static Class NSDateClass = Nil;

+ (void)initialize {
  if (profileComponents == -1) {
    profileComponents = [[[NSUserDefaults standardUserDefaults]
                                          objectForKey:@"WOProfileComponents"]
                                          boolValue] ? 1 : 0;
  }
  if (NSDateClass == Nil)
    NSDateClass = [NSDate class];
}

// responder

- (void)takeValuesFromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  WOElement *content;
  
  content = [_ctx componentContent]; // content (valid in parent)
  
  if (content) {
    NSTimeInterval st = 0.0;
    WOComponent *component = [_ctx component]; // reusable component
    
    component = RETAIN(component);
    content   = RETAIN(content);
    
    if (profileComponents)
      st = [[NSDateClass date] timeIntervalSince1970];
    
    [_ctx leaveComponent:component];
    [content takeValuesFromRequest:_request inContext:_ctx];
    [_ctx enterComponent:component content:content];
    
    if (profileComponents) {
      NSTimeInterval diff;
      int i;
      diff = [[NSDateClass date] timeIntervalSince1970] - st;
      for (i = [_ctx componentStackCount]; i >= 0; i--)
        printf("  ");
      printf("content: [%s %s]: %0.3fs\n",
             [[component name] cString], 
#if (defined(__GNU_LIBOBJC__) && (__GNU_LIBOBJC__ == 20100911)) || defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
	     sel_getName(_cmd), 
#else
	     sel_get_name(_cmd), 
#endif
	     diff);
    }
    
    [content   release];
    [component release];
  }
}

- (id)invokeActionForRequest:(WORequest *)_request inContext:(WOContext *)_ctx {
  WOElement *content = [_ctx componentContent]; // content (valid in parent)

  if (content) {
    NSTimeInterval st = 0.0;
    WOComponent *component = [_ctx component]; // reusable component
    id result;
    
    component = [component retain];
    content   = [content   retain];

    if (profileComponents)
      st = [[NSDateClass date] timeIntervalSince1970];
    
    [_ctx leaveComponent:component];
    result = [content invokeActionForRequest:_request inContext:_ctx];
    result = [result retain];
    [_ctx enterComponent:component content:content];
    
    if (profileComponents) {
      NSTimeInterval diff;
      int i;
      diff = [[NSDateClass date] timeIntervalSince1970] - st;
      for (i = [_ctx componentStackCount]; i >= 0; i--)
        printf("  ");
      printf("content: [%s %s]: %0.3fs\n",
             [[component name] cString], 
#if (defined(__GNU_LIBOBJC__) && (__GNU_LIBOBJC__ == 20100911)) || defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
	     sel_getName(_cmd), 
#else
	     sel_get_name(_cmd), 
#endif
	     diff);
    }
    
    [content   release];
    [component release];
    return [result autorelease];
  }
  return nil;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOElement *content;
  
  content = [_ctx componentContent]; // content (valid in parent)
  
  if (content) {
    NSTimeInterval st = 0.0;
    WOComponent *component;
    
    component = [_ctx component]; // reusable component
    component = [component retain];
    content   = [content   retain];

#if DEBUG && 0
    [_response appendContentHTMLString:@" Component:"];
    [_response appendContentHTMLString:[component description]];
    [_response appendContentHTMLString:@" Content:"];
    [_response appendContentHTMLString:[content description]];
#endif
    
    if (profileComponents)
      st = [[NSDateClass date] timeIntervalSince1970];
    
    [_ctx leaveComponent:component];
    [content appendToResponse:_response inContext:_ctx];
    [_ctx enterComponent:component content:content];
    
    if (profileComponents) {
      NSTimeInterval diff;
      int i;
      diff = [[NSDateClass date] timeIntervalSince1970] - st;
      for (i = [_ctx componentStackCount]; i >= 0; i--)
        printf("  ");
      printf("content: [%s %s]: %0.3fs\n",
             [[component name] cString], 
#if (defined(__GNU_LIBOBJC__) && (__GNU_LIBOBJC__ == 20100911)) || defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
	     sel_getName(_cmd), 
#else
	     sel_get_name(_cmd), 
#endif
	     diff);
    }
    
    [content   release];
    [component release];
  }
  else {
#if DEBUG && 0
    [_response appendContentHTMLString:@" Missing content in component: "];
    [_response appendContentHTMLString:[[_ctx component] description]];
#endif
  }
}

@end /* WOComponentContent */
