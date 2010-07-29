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

#include "XmlRpcCoder.h"
#include "XmlRpcSaxHandler.h"
#include <SaxObjC/SaxXMLReaderFactory.h>
#include "common.h"

@implementation XmlRpcResponseDecoder

static id saxResponseHandler = nil;
static id responseParser     = nil;

- (void)_ensureSaxAndParser {
  if (saxResponseHandler == nil) {
    if ((saxResponseHandler = [[XmlRpcSaxResponseHandler alloc] init])==nil) {
      NSLog(@"%s: did not find sax handler ...", __PRETTY_FUNCTION__);
      return;
    }
  }

  if (responseParser != nil) return;
  
  responseParser =
    [[SaxXMLReaderFactory standardXMLReaderFactory]
                          createXMLReaderForMimeType:@"text/xml"];
  
  if (responseParser == nil) {
    NSLog(@"%s: did not find an XML parser ...", __PRETTY_FUNCTION__);
    return;
  }
  
  responseParser = [responseParser retain];
  [responseParser setContentHandler:saxResponseHandler];
  [responseParser setDTDHandler:saxResponseHandler];
  [responseParser setErrorHandler:saxResponseHandler];
}

- (id)decodeRootObject {
  static Class ExceptionClass = Nil;
  id     result;
  
  [self _ensureSaxAndParser];

  if (ExceptionClass == Nil)
    ExceptionClass = [NSException class];
  
  [saxResponseHandler reset];

  [responseParser parseFromSource:self->string systemId:nil];
  
  result = [saxResponseHandler result];

  if ([result isKindOfClass:ExceptionClass]) {
    return result;
  }
  else { // => XmlRpcValue
    XmlRpcValue *val     = result;
    Class       objClass = Nil;
    id          obj;

    [self->value autorelease];
    self->value = [val retain];

    if ((objClass = NSClassFromString([val className])) != Nil) {
      obj = [objClass decodeObjectWithXmlRpcCoder:self];
      return obj;
    }
  }
  
  return nil;
}

@end /* XmlRpcResponseDecoder */
