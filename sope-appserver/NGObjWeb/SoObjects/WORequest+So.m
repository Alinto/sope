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

#include "WORequest+So.h"
#include <NGObjWeb/WEClientCapabilities.h>
#include "common.h"

@implementation WORequest(SoRequestClassification)

static BOOL _debugClassify(void) {
  static int debugOn = -1;
  if (debugOn == -1) {
    debugOn = [[NSUserDefaults standardUserDefaults] 
                boolForKey:@"SoDebugRequestClassification"] ? 1 : 0;
    if (debugOn)
      NSLog(@"SoDebugRequestClassification: enabled");
  }
  return debugOn ? YES : NO;
}

- (BOOL)isSoWebDAVRequest {
  WEClientCapabilities *cc;
  id tmp;
  
  /* check handler key */
  if ([[self requestHandlerKey] isEqualToString:@"dav"]) {
    /* this can be used to force WebDAV */
    if (_debugClassify())
      [self logWithFormat:@"classified as WebDAV by request-handler-key"];
    return YES;
  }
  
  /* check client type */
  cc = [self clientCapabilities];
  if ([cc isDAVClient]) {
    if (_debugClassify()) {
      [self logWithFormat: 
              @"classified as WebDAV by user-agent (it's a DAV client)"];
    }
    return YES;
  }
  
  /* check translate header */
  if ((tmp = [self headerForKey:@"translate"])) {
    NSString *h = tmp;
    if ([h hasPrefix:@"t"] || [h hasPrefix:@"T"]) {
      if (_debugClassify()) {
        [self logWithFormat:
                @"classified as WebDAV by a 'true' translation header"];
      }
      return YES;
    }
  }
  
  /* check HTTP methods */
  {
    static NSMutableSet *davMethods = nil;
    if (davMethods == nil) {
      NSArray *m;
      m = [[NSUserDefaults standardUserDefaults] 
                           arrayForKey:@"SoWebDAVDetectionMethods"];
      davMethods = [[NSMutableSet alloc] initWithArray:m];
    }
    if ([davMethods containsObject:[self method]]) {
      if (_debugClassify()) {
        [self logWithFormat:
                @"classified as WebDAV because of the method name"];
      }
      return YES;
    }
  }
  
  /* found no WebDAV indicator */
  return NO;
}

- (BOOL)isSoXmlRpcRequest {
  NSString *t;
  
  if (![[self method] isEqualToString:@"POST"])
    /* XML-RPC requests must be POST ... */
    return NO;
  
  /* check handler key */
  if ([[self requestHandlerKey] isEqualToString:@"RPC2"]) {
    /* this can be used to force XML-RPC */
    if (_debugClassify()) {
      [self logWithFormat:
              @"classified as XML-RPC because of request-handler-key"];
    }
    return YES;
  }
  
  /* look at content type */
  t = [self headerForKey:@"content-type"];
  if (![t hasPrefix:@"text/xml"])
    /* XML-RPC requests must be text/xml ... */
    return NO;
  if ([t hasPrefix:@"text/xml+"])
    /* XML-RPC requests must be text/xml ... */
    return NO;

  /* look at content length */
  t = [self headerForKey:@"content-length"];
  if ([t intValue] < 51)
    /* an XML-RPC request has some minimum length ... */
    return NO;
  
  /* now it becomes difficult, how do we distinguish plain XML and RPC ? */
  {
    /*
      We check for some contents, see below. Not exactly the most
      efficient thing on earth, but ...
      
      must be longer than 50 chars:
      <methodCall><methodName>x</methodName></methodCall>
    */
    NSString *s;
    NSRange crng, nrng;

    s = [self contentAsString];
    if ([s length] < 51)
      return NO;

    crng = [s rangeOfString:@"<methodCall>"];
    nrng = [s rangeOfString:@"<methodName>"];
    if (crng.length <= 0) return NO;
    if (nrng.length <= 0) return NO;
    if (nrng.location < crng.location) return NO;

    crng = [s rangeOfString:@"</methodCall>"];
    nrng = [s rangeOfString:@"</methodName>"];
    if (crng.length <= 0) return NO;
    if (nrng.length <= 0) return NO;
    if (nrng.location > crng.location) return NO;

    if (_debugClassify()) {
      [self logWithFormat:
	      @"classified as XML-RPC because of POST and the contents "
	      @"looks like XML-RPC "];
    }
    return YES;
  }
  
  /* found no XML-RPC indicator */
  return NO;
}

- (BOOL)isSoSOAPRequest {
  NSString *soapAction;
  
  if ((soapAction = [self headerForKey:@"soapaction"]) == nil)
    return NO;
  
  if (_debugClassify()) {
    [self logWithFormat:
	    @"classified as SOAP because the SOAPAction header is set."];
  }
  
  return YES;
}

- (BOOL)isSoWCAPRequest {
  NSString *s;
  NSRange  r;
  
  s = [self uri];
  r = [s rangeOfString:@"?"];
  if (r.length > 0) s = [s substringToIndex:r.location];
  r = [s rangeOfString:@"#"];
  if (r.length > 0) s = [s substringToIndex:r.location];
  
  return [s hasSuffix:@".wcap"];
}

- (BOOL)isSoBrkDAVRequest {
  /* a broken WebDAV request */
  return [[self uri] hasPrefix:@"/servlet/webdav."];
}

@end /* WORequest(SoRequestClassification) */
