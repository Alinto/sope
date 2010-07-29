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

#include <XmlRpc/XmlRpcCoder.h>
#include <XmlRpc/XmlRpcSaxHandler.h>
#include <XmlRpc/XmlRpcMethodCall.h>
#include <XmlRpc/XmlRpcValue.h>
#include <SaxObjC/SaxXMLReaderFactory.h>
#include "common.h"

@implementation XmlRpcRequestDecoder

static id   saxRequestHandler = nil;
static id   requestParser     = nil;
static BOOL doDebug           = NO;

- (void)_ensureSaxAndParser {
  if (saxRequestHandler == nil) {
    static Class clazz = Nil;
    
    if (clazz == Nil)
      clazz = NSClassFromString(@"XmlRpcSaxRequestHandler");
    
    if ((saxRequestHandler = [[clazz alloc] init]) == nil) {
      NSLog(@"%s: did not find sax handler ...", __PRETTY_FUNCTION__);
      return;
    }
  }
  
  if (requestParser != nil) return;
  
  requestParser =
    [[SaxXMLReaderFactory standardXMLReaderFactory] createXMLReader];
  
  if (requestParser == nil) {
    NSLog(@"%s: did not find an XML parser ...", __PRETTY_FUNCTION__);
    return;
  }
  
  [requestParser setContentHandler:saxRequestHandler];
  [requestParser setDTDHandler:saxRequestHandler];
  [requestParser setErrorHandler:saxRequestHandler];

  [requestParser retain];
}

- (XmlRpcMethodCall *)decodeRootObject {
  XmlRpcMethodCall *methodCall;
  NSEnumerator     *paramEnum;
  NSMutableArray   *params;
  XmlRpcValue      *param;
  
  if (doDebug) NSLog(@"%s: begin", __PRETTY_FUNCTION__);
  [self _ensureSaxAndParser];
  
  [saxRequestHandler reset];
  
  [requestParser parseFromSource:self->string systemId:nil];
  
  methodCall = [saxRequestHandler methodCall];
  
  // the methodCall's parameters is an array of XmlRpcValues!!!
  
  paramEnum = [[methodCall parameters] objectEnumerator];
  params    = [[NSMutableArray alloc] initWithCapacity:
                                      [[methodCall parameters] count]];

  while ((param = [paramEnum nextObject])) {
    Class objClass = Nil;
    id    obj;
    
    [self->value autorelease];
    self->value = [param retain];
    
    if ((objClass = NSClassFromString([param className])) != Nil) {
      if ((obj = [objClass decodeObjectWithXmlRpcCoder:self])) {
        [params addObject:obj];
      }
      else {
        NSLog(@"%s: Warning: try to add 'nil' object to params (class='%@')",
              __PRETTY_FUNCTION__,
              [param className]);
      }
    }
  }
  [methodCall setParameters:params];
  
  [params release];

  if (doDebug) NSLog(@"%s: done: %@", __PRETTY_FUNCTION__, methodCall);
  return methodCall;
}

@end /* XmlRpcRequestDecoder */
