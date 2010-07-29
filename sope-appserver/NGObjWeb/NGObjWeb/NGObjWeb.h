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

#ifndef __NGObjWeb_H__
#define __NGObjWeb_H__

#if NeXT_Foundation_LIBRARY || APPLE_Foundation_LIBRARY
#  include <NGExtensions/NGObjectMacros.h>
#  include <NGExtensions/NGExtensions.h>
#endif

#include <NGObjWeb/OWResponder.h>
#include <NGObjWeb/WOAdaptor.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOAssociation.h>
#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOCookie.h>
#include <NGObjWeb/WODirectAction.h>
#include <NGObjWeb/WODynamicElement.h>
#include <NGObjWeb/WOElement.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResourceManager.h>
#include <NGObjWeb/WORequestHandler.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOSession.h>
#include <NGObjWeb/WOSessionStore.h>
#include <NGObjWeb/WODisplayGroup.h>
#include <NGObjWeb/WOHTTPConnection.h>
#include <NGObjWeb/WOMailDelivery.h>
#include <NGObjWeb/WOStatisticsStore.h>

#include <NGObjWeb/WOxElemBuilder.h>
#include <NGObjWeb/NSString+JavaScriptEscaping.h>

// kit class

@interface NGObjWeb : NSObject
@end

#define LINK_NGObjWeb \
  static void __link_NGObjWeb(void) { \
    [NGObjWeb self];  \
    __link_NGObjWeb(); \
  }

#endif /* __NGObjWeb_H__ */
