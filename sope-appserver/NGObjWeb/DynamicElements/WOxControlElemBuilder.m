/*
  Copyright (C) 2000-2005 SKYRIX Software AG
  Copyright (C) 2007 OpenGroupware.org.

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

#include <NGObjWeb/WOxElemBuilder.h>

/*
  This builder builds control flow elements, eg conditionals and
  repetitions.

  Supported tags:
    <var:if .../>        maps to WOConditional
    <var:if-not .../>    maps to WOConditional
    <var:foreach .../>   maps to WORepetition
    <var:with .../>      maps to WOSetCursor
    <var:copy-value ../> maps to WOCopyValue
    <var:fragment ../>   maps to WOFragment
*/

@interface WOxControlElemBuilder : WOxTagClassElemBuilder
{
}

@end

#include <SaxObjC/XMLNamespaces.h>
#include "decommon.h"

@implementation WOxControlElemBuilder

- (Class)classForElement:(id<DOMElement>)_element {
  NSString *nsuri;
  NSString *tag;
  unsigned len;
  unichar  c0;
  
  if (_element == nil) return nil;
  
  nsuri = [_element namespaceURI];
  if (![nsuri isEqualToString:XMLNS_OD_BIND])
    return Nil;
  
  tag = [_element tagName];
  len = [tag length];
  c0  = len > 0 ? [tag characterAtIndex:0] : 0;

  if (c0 == 'i' && len > 1 &&
      ((len == 2 && [tag isEqualToString:@"if"])     ||
       (len == 6 && [tag isEqualToString:@"if-not"]) || 
       (len == 5 && [tag isEqualToString:@"ifnot"]))) {
    static Class clazz = Nil;
    if (clazz == Nil)
      clazz = NSClassFromString(@"WOConditional");
    
    if (len > 2)
      [self logWithFormat:@"WARNING: if-not/ifnot not supported!"];
    
    return clazz;
  }
  
  if (c0 == 'f' && len > 6 &&
      ([tag isEqualToString:@"foreach"] || [tag isEqualToString:@"for-each"])){
    static Class clazz = Nil;
    if (clazz == Nil)
      clazz = NSClassFromString(@"WORepetition");
    return clazz;
  }

  if (c0 == 'f' && len == 8 && [tag isEqualToString:@"fragment"]) {
    static Class clazz = Nil;
    if (clazz == Nil)
      clazz = NSClassFromString(@"WOFragment");
    return clazz;
  }

  if (c0 == 'w' && len == 4 && [tag isEqualToString:@"with"]) {
    static Class clazz = Nil;
    if (clazz == Nil)
      clazz = NSClassFromString(@"WOSetCursor");
    return clazz;
  }
  
  if (c0 == 'c' && len == 10 && [tag isEqualToString:@"copy-value"]) {
    static Class clazz = Nil;
    if (clazz == Nil)
      clazz = NSClassFromString(@"WOCopyValue");
    return clazz;
  }
  
  return Nil;
}

@end /* WOxControlElemBuilder */
