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

#ifndef __NGObjWeb_SoObjectRequestHandler_H__
#define __NGObjWeb_SoObjectRequestHandler_H__

#include <NGObjWeb/WORequestHandler.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOCoreApplication.h>
#import <Foundation/NSObject.h>

/*
  SoObjectRequestHandler
  
  This request handler is used to handle requests by traversing objects.
  
  It also defines a new KVC interface on NSObject. The major difference
  to KVC is, that KVC calls method keys while SoObjectLookup returns an
  invocation object.

  How objects are "published"

  First how the object is located. The handler starts at it's root instance
  variable which usually is the global NGObjWeb application object. Then
  it walks over each path component of the requestHandlerPathArray as
  returned by WORequest. For each pathcomponent the dispatcher first calls
  the SoObject validation primitive then the SoObject lookup primitive to
  find the next object. If an object couldn't be found (the lookup returned
  nil), an HTTP 404 (Not Found) is returned.
  Note that the two HTTP methods MKCOL and PUT leave out the last path
  component during dispatch and insert it as the PATH_INFO in the context.

  Next, the dispatch. Once the object is found a dispatcher is selected. There
  are basically three dispatchers: method, WebDAV and XML-RPC. Which one is
  used is determined either using the object if it supports a 
  -dispatcherForContext: method or selected on request based information
  otherwise.
  To trigger WebDAV: use 'dav' as the request handler key. Otherwise heuristics
  are used to select the DAV dispatcher (most problematic are DAV GET requests)
  
  And finally, the rendering. Often a method will return a WOResponse. If this
  is the case the response is simply delivered. If a method returns an 
  NSException object, an HTTP error response is generated. Otherwise the
  renderer looks for -generateResponse and -appendToResponse:inContext: 
  methods, if this still doesn't work out, -stringValue is used ;-)
  
  If all the processing is done, all objects in the traversal stack are sent
  _sleepWithContext:, -sleep or nothing, depending on what they implement ...
  
  Some special form keys:
    ":method" - like in Zope
    "Cmd"     - like in ASP
*/

@class NSString, NSException;
@class NGRuleContext;

@interface SoObjectRequestHandler : WORequestHandler
{
  BOOL          doesNoRequestPathAcquisition;
  id            rootObject;
  NGRuleContext *dispatcherRules;
}

@end

@interface WOCoreApplication(RendererSelection)

- (id)rendererForObject:(id)_object inContext:(WOContext *)_ctx;

@end

#endif /* __NGObjWeb_SoObjectRequestHandler_H__ */
