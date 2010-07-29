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

#ifndef __SoObjects_SoObjectWebDAVDispatcher_H__
#define __SoObjects_SoObjectWebDAVDispatcher_H__

#import <Foundation/NSObject.h>

/*
  SoObjectWebDAVDispatcher
  
  This request dispatcher is used to dispatch WebDAV calls to SoObjects. Eg
  it translates WebDAV PROPFIND and SEARCH requests in a fetch specifications
  that is passed to the SoObject.
  For more information on the available callbacks, take a look at the 
  SoObject+SoDAV protocols.

  Methods:
    PROPPATCH - performWebDAVQuery:
    SEARCH    - performWebDAVQuery:
    POST      - calls POST SoObject-method
    PUT       - calls PUT SoObject-method
    DELETE    - calls DELETE SoObject-method
    GET       - calls -appendToResponse:inContext: [subject to change]
*/

@class WOContext;

@interface SoObjectWebDAVDispatcher : NSObject
{
  id object;
}

- (id)initWithObject:(id)_object;

/* perform dispatch */

- (id)dispatchInContext:(WOContext *)_ctx;

@end

#endif /* __SoObjects_SoObjectWebDAVDispatcher_H__ */
