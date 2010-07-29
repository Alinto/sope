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

#ifndef __NGObjWeb_WORequestHandler_private_H__
#define __NGObjWeb_WORequestHandler_private_H__

#include <NGObjWeb/WORequestHandler.h>
#include <NGObjWeb/WORequest.h>

@class WOSession, WOResponse, WOContext, WOComponent;

@interface WORequestHandler(Cookies)

- (void)addCookiesForSession:(WOSession *)_sn
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx;

@end

@interface WORequest(DblClickBrowser)

/* returns whether the user agent is one, which does two clicks per request */
- (BOOL)isDoubleClickBrowser;

@end

@interface WORequestHandler(SemiPrivate)

- (WOResponse *)doubleClickResponseForContext:(WOContext *)_ctx;

- (void)saveSession:(WOSession *)_session
  inContext:(WOContext *)_ctx
  withResponse:(WOResponse *)_response
  application:(WOApplication *)_app;

- (WOResponse *)generateResponseForComponent:(WOComponent *)_component
  inContext:(WOContext *)_ctx
  application:(WOApplication *)_app;

@end

#endif /* __NGObjWeb_WORequestHandler_private_H__ */
