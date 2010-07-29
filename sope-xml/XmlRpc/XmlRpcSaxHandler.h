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

#ifndef __XmlRpcSaxHandler_H__
#define __XmlRpcSaxHandler_H__

#include <SaxObjC/SaxDefaultHandler.h>

/*
  Mappings:
  
    <i4> or <int>      -> NSNumber
    <boolean>          -> NSNumber
    <double>           -> NSNumber
    <base64>           -> NSData
    <string>           -> NSString
    <dateTime.iso8601> -> NSCalendarDate
    <struct>           -> NSDictionary
    <array>            -> NSArray
*/

@class NSMutableArray, NSTimeZone, NSCalendarDate;
@class XmlRpcMethodCall, XmlRpcMethodResponse;

@interface XmlRpcSaxHandler : SaxDefaultHandler
{
  XmlRpcMethodCall     *call;
  XmlRpcMethodResponse *response;
  
  NSMutableArray *params;
  NSString       *methodName;
  
  BOOL           invalidCall;
  NSMutableArray *tagStack;
  
  NSMutableArray *valueStack;
  NSString       *className;
  
  NSMutableArray *memberNameStack;
  NSMutableArray *memberValueStack;

  NSTimeZone     *timeZone;
  NSCalendarDate *dateTime;
  NSMutableString *characters;
  
  unsigned valueNestingLevel;
  SEL      nextCharactersProcessor;
}

/* reusing sax handler */

- (void)reset;

/* result accessors */

- (XmlRpcMethodCall *)methodCall;
- (XmlRpcMethodResponse *)methodResponse;

@end

#endif /* __XmlRpcSaxHandler_H__ */
