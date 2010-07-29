/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#include "SoObjectSOAPDispatcher.h"
#include "SoObject.h"
#include "NSException+HTTP.h"
#include "WOContext+SoObjects.h"
#include "SoDefaultRenderer.h"
#include <NGObjWeb/WOActionResults.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WORequest.h>
#include "common.h"
#include <DOM/DOM.h>
#include <SaxObjC/XMLNamespaces.h>

/*
  TODO: is it required by SOAP that the HTTP method is POST?

  Note:
  Servers also set a SOAPAction HTTP header.

  SOAP sample:
    <?xml version="1.0" encoding="UTF-8" standalone="no"?>
    <SOAP-ENV:Envelope 
      xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" 
      xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" 
      xmlns:xsd="http://www.w3.org/1999/XMLSchema" 
      xmlns:xsi="http://www.w3.org/1999/XMLSchema-instance"
    >
      <SOAP-ENV:Body 
        xmlns:types="http://schemas.novell.com/2003/10/NCSP/types.xsd" 
        SOAP-ENV:encodingStyle=""
      >
        <loginRequest>
          <types:auth xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
                      xsi:type="types:PlainText"
          >
            <types:username>dummy</types:username>
            <types:password>user</types:password>
          </types:auth>
        </loginRequest>
      </SOAP-ENV:Body>
    </SOAP-ENV:Envelope>
  
  Another (http://novell.com/simias/domain/GetDomainID):
    <?xml version="1.0" encoding="utf-8"?>
    <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" 
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
	           xmlns:xsd="http://www.w3.org/2001/XMLSchema">
      <soap:Body>
        <GetDomainID xmlns="http://novell.com/simias/domain" />
      </soap:Body>
    </soap:Envelope>
*/

@interface SoSOAPRenderer : SoDefaultRenderer
@end

@implementation SoObjectSOAPDispatcher

static BOOL debugOn      = NO;
static BOOL debugParsing = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  debugOn = [ud boolForKey:@"SoObjectSOAPDispatcherDebugEnabled"];
  if (debugOn) NSLog(@"Note: SOPE SOAP dispatcher debugging turned on.");
  
  debugParsing = [ud boolForKey:@"SoObjectSOAPDispatcherParserDebugEnabled"];
  if (debugParsing) NSLog(@"Note: SOPE SOAP parsing debugging turned on.");
}

/* XML actions */

- (id)performSOAPAction:(NSString *)_actionName
  header:(id<DOMElement>)_header body:(id<DOMElement>)_body
  inContext:(WOContext *)_ctx
{
  id clientObject;
  id methodObject;
  id resultObject;

  if (debugOn) 
    [self debugWithFormat:@"calling SOAP method: '%@'", _actionName];
  
  /* find client object */
  
  if ((clientObject = [_ctx clientObject]) != nil) {
    if (debugOn)
      [self debugWithFormat:@"  client object from ctx: %@", clientObject];
  }
  else if ((clientObject = [self->object clientObject])) {
    if (debugOn)
      [self debugWithFormat:@"  setting client object: %@", clientObject];
    [_ctx setClientObject:clientObject];
  }
  
  /* find callable (method) object */
  
  // TODO: should we allow acquisition?
  methodObject = [clientObject lookupName:_actionName inContext:_ctx
			       acquire:NO];
  if (methodObject == nil) {
    /* check for common names like "GetFolderRequest" => "GetFolder" */
    if ([_actionName hasSuffix:@"Request"]) {
      NSString *an;
      
      an = [_actionName substringToIndex:([_actionName length] - 7)];
      if (debugOn) [self debugWithFormat:@"  try special name: %@", an];
      methodObject = [clientObject lookupName:an inContext:_ctx acquire:NO];
      if (methodObject != nil) _actionName = an;
    }
  }
  if (methodObject == nil) {
    /* check for names like "http://novell.com/domain/GetID" => "GetID" */
    NSRange  r;
    
    r = [_actionName rangeOfString:@"/" options:NSBackwardsSearch];
    if (r.length > 0) {
      NSString *an;
      
      an = [_actionName substringFromIndex:(r.location + r.length)];
      if (debugOn) [self debugWithFormat:@"  try special name: %@", an];
      
      methodObject = [clientObject lookupName:an inContext:_ctx acquire:NO];
      if (methodObject != nil) _actionName = an;
    }
  }
  
  if (methodObject == nil) {
    [self warnWithFormat:@"could not locate SOAP method: %@", 
            _actionName];
    return [NSException exceptionWithHTTPStatus:501 /* not implemented */
			reason:@"did not find the specified SOAP method"];
  }
  else if (![methodObject isCallable]) {
    [self warnWithFormat:
            @"object found for SOAP method '%@' is not callable: "
            @"%@", _actionName, methodObject];
    return [NSException exceptionWithHTTPStatus:501 /* not implemented */
			reason:@"did not find the specified SOAP method"];
  }
  if (debugOn) [self debugWithFormat:@"  method: %@", methodObject];
  
  /* apply arguments */
  
  // TODO: use some query syntax in product.plist to retrieve parameters
  //       from SOAP
  
  // TODO: somehow apply SOPE header/body?
  if (_header) [_ctx setObject:_header forKey:@"SOAPHeader"];
  if (_body)   [_ctx setObject:_body   forKey:@"SOAPBody"];
  
  if ([methodObject respondsToSelector:
  		      @selector(takeValuesFromRequest:inContext:)]) {
    if (debugOn)
      [self debugWithFormat:@"  applying values from request ..."];
    [methodObject takeValuesFromRequest:[_ctx request] inContext:_ctx];
  }
  
  /* perform call */
  
  resultObject = [methodObject callOnObject:[_ctx clientObject] 
			       inContext:_ctx];
  if (debugOn) [self debugWithFormat:@"got SOAP result: %@", resultObject];
  return resultObject;
}

- (id)performSOAPAction:(NSString *)_actionName document:(id)_dom
  inContext:(WOContext *)_ctx
{
  id<DOMElement>  envelope;
  id<DOMElement>  header;
  id<DOMElement>  body;
  id<DOMNodeList> list;

  /* envelope */

  envelope = [_dom documentElement];
  if (![[envelope tagName] isEqualToString:@"Envelope"] ||
      ![[envelope namespaceURI] isEqualToString:XMLNS_SOAP_ENVELOPE]) {
    [self debugWithFormat:@"Note: missing SOAP envelope at document root."];
    return [NSException exceptionWithHTTPStatus:400 /* bad request */
			reason:@"could not parse SOAP content of request"];
  }
  if (debugParsing) [self debugWithFormat:@"envelope: %@", envelope];
  
  [_ctx setObject:envelope forKey:@"SOAPEnvelope"];
  
  /* header */

  list = [envelope getElementsByTagName:@"Header"];
  // TODO: not yet supported by DOMElement: namespaceURI:XMLNS_SOAP_ENVELOPE];
  if ([list length] > 1) {
    [self warnWithFormat:@"multiple SOAP headers in request?! (using first)"];
  }
  header = [list length] > 0 ? [list objectAtIndex:0] : nil;
  if (debugParsing) [self debugWithFormat:@"header: %@", header];

  /* body */
  
  list = [envelope getElementsByTagName:@"Body"];
  // TODO: not yet supported by DOMElement: namespaceURI:XMLNS_SOAP_ENVELOPE];
  if ([list length] == 0) {
    [self debugWithFormat:@"Note: missing SOAP body."];
    return [NSException exceptionWithHTTPStatus:400 /* bad request */
			reason:@"could not parse SOAP body of request"];
  }
  else if ([list length] > 1) {
    [self warnWithFormat:@"multiple SOAP bodies in request?! (using first)"];
  }
  body = [list objectAtIndex:0];
  if (debugParsing) [self debugWithFormat:@"body: %@", body];
  
  /* process */
  
  return [self performSOAPAction:_actionName 
	       header:header body:body inContext:_ctx];
}

/* main dispatcher */

- (id)dispatchInContext:(WOContext *)_ctx {
  NSAutoreleasePool *pool;
  WORequest         *rq;
  NSString          *SOAPAction;
  id<DOMDocument>   dom;
  id resultObject;
  
  pool = [[NSAutoreleasePool alloc] init];
  
  if ((rq = [_ctx request]) == nil) {
    [self errorWithFormat:@"missing request in context!"];
    return nil;
  }
  
  /* 
     Note: the SOAPAction is also contained in the body which is probably
           considered the authority? We currently prefer the header when
	   available.
  */
  SOAPAction = [rq headerForKey:@"soapaction"];
  if ([SOAPAction length] > 1) {
    
    if ([SOAPAction characterAtIndex:0] == '"' &&
	[SOAPAction characterAtIndex:([SOAPAction length] - 1)] == '"') {
      /* a quoted header, like "http://novell.com/simias/domain/GetDomainID" */
      NSRange r;
      
      r.location = 1;
      r.length   = [SOAPAction length] - 2;
      SOAPAction = [SOAPAction substringWithRange:r];
    }
  }
  if (![SOAPAction isNotEmpty]) {
    [self errorWithFormat:@"missing SOAPAction HTTP header!"];
    return nil;
  }
  
  /* parse XML */
  
  if ((dom = [rq contentAsDOMDocument]) == nil) {
    [self debugWithFormat:@"Note: could not parse XML content of request"];
    return [NSException exceptionWithHTTPStatus:400 /* bad request */
			reason:@"could not parse XML content of request"];
  }
  
  resultObject = 
    [[self performSOAPAction:SOAPAction document:dom inContext:_ctx]retain];
  [pool release];
  
  return [resultObject autorelease];
}

/* debugging */

- (NSString *)loggingPrefix {
  return @"[obj-soap-dispatch]";
}
- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* SoObjectSOAPDispatcher */

@implementation SoSOAPRenderer

// TODO: render exceptions as SOAP faults
// TODO: maybe support rendering of DOM trees? (should be supported by default)
// TODO: maybe some "schema" driven rendering

@end /* SoSOAPRenderer */
