/*
  Copyright (C) 2005 SKYRIX Software AG

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
  This builder processes elements in a way inspired by the Zope TAL. It is
  incomplete / work in progress.
  
  Since this builds scans the attributes of _all_ tags, it might lead to some
  slow-down when parsing templates. But this should be negligible in the real
  world (with WO template caching)

  Note: for processing 'TAL associations', we also need a (TALES?)
        WOAssociation subclass.
  
  Supported attributes:

  Processing order as per Zope doc:
  1. define
  2. condition
  3. repeat
  4. content OR replace
  5. attributes
  6. omit-tag
*/

@interface WOxTalElemBuilder : WOxElemBuilder
{
}

@end

#include <SaxObjC/XMLNamespaces.h>
#include "decommon.h"

@implementation WOxTalElemBuilder

- (WOElement *)buildElement:(id<DOMElement>)_element templateBuilder:(id)_b {
  // TODO: scan attributes for TAL/VAR attributes
  id<NSObject,DOMNamedNodeMap> attrs;
  unsigned len;
  
  attrs = [_element attributes];
  if ((len = [attrs length]) > 0) {
    id<NSObject,DOMAttr> talDefine     = nil; // len=6,  d, define
    id<NSObject,DOMAttr> talCondition  = nil; // len=9,  c, condition
    id<NSObject,DOMAttr> talRepeat     = nil; // len=6,  r, repeat
    id<NSObject,DOMAttr> talContent    = nil; // len=7,  c, content
    id<NSObject,DOMAttr> talReplace    = nil; // len=7,  r, replace
    id<NSObject,DOMAttr> talAttributes = nil; // len=10, a, attributes
    id<NSObject,DOMAttr> talOmitTag    = nil; // len=8,  o, omit-tag
    unsigned i;
    
    /* collect TAL attributes */
    
    for (i = 0; i < len; i++) {
      id<NSObject,DOMAttr> attr;
      NSString *ns, *aname;
      unsigned alen;
      unichar  c0;
      BOOL     isBindNS = NO;
      
      attr  = [attrs objectAtIndex:i];
      aname = [attr name];
      alen  = [aname length];

      /* some pre-filtering based on name */
      
      if (alen < 6 || alen > 10)
        continue;
      c0 = [aname characterAtIndex:0];
      if (!(c0 == 'd' && alen == 6  /* define */) && 
          !(c0 == 'c' && (alen == 9 || alen == 7)) && 
          !(c0 == 'r' && (alen == 6 || alen == 7)) && 
          !(c0 == 'a' && alen == 10 /* attributes */) &&
          !(c0 == 'o' && alen == 8  /* omit-tag */))
        continue;
      
      /* check namespace */
      
      ns = [attr namespaceURI];
      // TODO: cache isEqualToString method?
      if (![XMLNS_Zope_TAL isEqualToString:ns] &&
          !(isBindNS = [XMLNS_OD_BIND  isEqualToString:ns]))
        continue;
      
      /* check names and derive attributes */
      
      // TODO: use var:if      instead of tal:condition
      //       and var:foreach instead of tal:repeat
      //       ?
      // TODO: the biggest issue to be solved is how to know when
      //       the element itself would be dynamic and resolve the binding
      //       => eg: <var:if> aka WOConditional and 'tal:condition'
      
      switch (c0) {
      case 'd':
        if (alen == 6 && [aname isEqualToString:@"define"])
          talDefine = attr;
        break;
      case 'c':
        if (alen == 7 && [aname isEqualToString:@"content"])
          talContent = attr;
        else if (alen == 9 && [aname isEqualToString:@"condition"])
          talCondition = attr;
        break;
      case 'r':
        if (alen == 6 && [aname isEqualToString:@"repeat"])
          talRepeat = attr;
        else if (alen == 7 && [aname isEqualToString:@"replace"])
          talReplace = attr;
        break;
      case 'a':
        if (alen == 10 && [aname isEqualToString:@"attributes"])
          talAttributes = attr;
        break;
      case 'o':
        if (alen == 8 && [aname isEqualToString:@"omit-tag"])
          talOmitTag = attr;
        break;
      }
    }
    
    /* process TAL attributes */
  }
  
  return [self->nextBuilder buildElement:_element templateBuilder:_b];
}

@end /* WOxTalElemBuilder */
