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

#ifndef __SoObjects_SoDefaultRenderer_H__
#define __SoObjects_SoDefaultRenderer_H__

#import <Foundation/NSObject.h>

/*
  SoDefaultRenderer
  
  This renderer can render any object, at least as it's description.

  It renders the following things (in order):
  - NSExceptions (acks the http-status userInfo field)
  - NSData       (as an application/octet-stream)
  - tuples if turned on like described for Zope
  - WOComponents
  - WOElements   (anything that has appendToResponse:inContext:)
  - *            by retrieving the stringValue
*/

@class NSException;
@class WOContext;

@interface SoDefaultRenderer : NSObject
{
}

+ (id)sharedRenderer;

- (NSException *)renderObject:(id)_object inContext:(WOContext *)_ctx;
- (BOOL)canRenderObject:(id)_object inContext:(WOContext *)_ctx;

@end

#endif /* __SoObjects_SoDefaultRenderer_H__ */
