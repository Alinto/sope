/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#include "OFSFileRenderer.h"
#include "OFSFile.h"
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOContext.h>
#include "common.h"

@interface OFSFile(Render)

- (id)davContentLength;
- (NSDate *)davLastModified;

@end

@implementation OFSFileRenderer

static NSTimeZone *gmt = nil;

+ (void)initialize {
  gmt = [[NSTimeZone timeZoneWithAbbreviation:@"GMT"] retain];
}

+ (id)sharedRenderer {
  static OFSFileRenderer *singleton = nil;
  if (singleton == nil)
    singleton = [[OFSFileRenderer alloc] init];
  return singleton;
}

/* rendering */

- (NSException *)renderHeadOfObject:(id)_object inContext:(WOContext *)_ctx {
  WOResponse *r;
  id tmp;
  
  r = [_ctx response];
  
  /* render headers */
  
  if ((tmp = [_object contentTypeInContext:_ctx]))
    [r setHeader:tmp forKey:@"content-type"];
  if ((tmp = [_object davContentLength]))
    [r setHeader:tmp forKey:@"content-length"];
  
  if ((tmp = [_object davLastModified])) {
    NSCalendarDate *date;

#if COCOA_Foundation_LIBRARY
    date = [[NSCalendarDate alloc] initWithTimeIntervalSinceReferenceDate:
				     [tmp timeIntervalSinceReferenceDate]];
#else
    date = [[NSCalendarDate alloc] initWithTimeIntervalSince1970:
				     [tmp timeIntervalSince1970]];
#endif
    [date setTimeZone:gmt];
    
    // "Tue, 10 Jul 2001 14:09:06 GMT"
    tmp = [date descriptionWithCalendarFormat:@"%a, %d %b %Y %H:%M:%S GMT"];
    [date release];
    [r setHeader:tmp forKey:@"last-modified"];
  }
  
  return nil;
}

- (NSException *)renderBodyOfObject:(id)_object inContext:(WOContext *)_ctx {
  WOResponse *r;
  NSData     *content;
  NSString   *storePath;
  id fm;
  
  fm        = [_object fileManager];
  storePath = [_object storagePath];
  content   = [fm contentsAtPath:storePath];
  
  /* some error handling */
  
  if (content == nil) {
    // TODO: should render exception ?
    if ([fm respondsToSelector:@selector(lastException)])
      return (id)[fm lastException];
    return [NSException exceptionWithHTTPStatus:404 /* not found */];
  }
  
  /* render body */
  r = [_ctx response];
  [r setContent:content];
  return nil;
}

- (NSException *)renderObject:(id)_object inContext:(WOContext *)_ctx {
  NSException *e;
  
  if ((e = [self renderHeadOfObject:_object inContext:_ctx]))
    return e;
  
  if (![[[_ctx request] method] isEqualToString:@"HEAD"]) {
    if ((e = [self renderBodyOfObject:_object inContext:_ctx]))
      return e;
  }
  return nil;
}

- (BOOL)canRenderObject:(id)_object inContext:(WOContext *)_ctx {
  return [_object isKindOfClass:[OFSFile class]];
}

@end /* OFSFileRenderer */
