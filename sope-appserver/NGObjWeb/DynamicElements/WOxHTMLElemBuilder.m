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

#import <NGObjWeb/WOxElemBuilder.h>

/*
  This builder builds all standard elements which are defined in the XHTML
  or HTML 4 namespace.

  Supported tags:
    - all other tags are represented using either WOGenericElement or
      WOGenericContainer, so this builder is "final destination" for
      all HTML related tags.
  
    <input> - the "type" attribute of the input must be static and further
              specifies the generated element
      type="submit"   maps to WOSubmitButton
      type="reset"    maps to WOResetButton
      type="image"    maps to WOImageButton
      type="radio"    maps to WORadioButton
      type="checkbox" maps to WOCheckBox
      type="file"     maps to WOFileUpload
      type="hidden"   maps to WOHiddenField
      type="password" maps to WOPasswordField
      TODO: button!
      all other       map  to WOTextField
    <a>..</a>         maps to WOHyperlink
    <img .../>        maps to WOImage
    <form .../>	      maps to WOForm
    <textarea .../>   maps to WOText
    <embed .../>      maps to WOEmbeddedObject
    <frame .../>      maps to WOFrame
    <iframe .../>     maps to WOIFrame
    <body .../>       maps to WOBody
    <entity .../>     maps to WOEntity
    <container .../>  removes the tag and embeds the content
*/

@interface WOxHTMLElemBuilder : WOxTagClassElemBuilder
{
}

@end

#include "WOCompoundElement.h"
#include "decommon.h"
#include <SaxObjC/XMLNamespaces.h>

@implementation WOxHTMLElemBuilder

static Class WOGenericContainerClass = Nil;
static Class WOGenericElementClass   = Nil;

+ (void)initialize {
  WOGenericContainerClass = NSClassFromString(@"WOGenericContainer");
  WOGenericElementClass   = NSClassFromString(@"WOGenericElement");
}

- (Class)classForInputElement:(id<DOMElement>)_element {
  NSString *type;
  unsigned tl;
  unichar c1;
  
  type = [_element attribute:@"type" namespaceURI:XMLNS_XHTML];
  tl = [type length];

  if (tl == 0)
    return NSClassFromString(@"WOTextField");
  else if (tl > 0)
    c1 = [type characterAtIndex:0];
  
  switch (tl) {
    case 0:

    case 4:
      if (c1 == 't') {
        if ([type isEqualToString:@"text"])
          return NSClassFromString(@"WOTextField");
      }
      else if (c1 == 'f') {
        if ([type isEqualToString:@"file"])
          return NSClassFromString(@"WOFileUpload");
      }
      break;
      
    case 5:
      if (c1 == 'i' && [type isEqualToString:@"image"])
        return NSClassFromString(@"WOImageButton");
      else if (c1 == 'r') {
        if ([type isEqualToString:@"radio"])
          return NSClassFromString(@"WORadioButton");
        if ([type isEqualToString:@"reset"])
          return NSClassFromString(@"WOResetButton");
      }
      break;
      
    case 6:
      if (c1 == 's' && [type isEqualToString:@"submit"])
        return NSClassFromString(@"WOSubmitButton");
      else if (c1 == 'h' && [type isEqualToString:@"hidden"])
        return NSClassFromString(@"WOHiddenField");
      else if (c1 == 'b' && [type isEqualToString:@"button"])
        return NSClassFromString(@"WOGenericElement");
      break;

    case 8:
      if (c1 == 'c' && [type isEqualToString:@"checkbox"])
        return NSClassFromString(@"WOCheckBox");
      else if (c1 == 'p' && [type isEqualToString:@"password"])
        return NSClassFromString(@"WOPasswordField");
      
    default:
      break;
  }
  
  [self warnWithFormat:@"unknown input type '%@' !", type];
  return NSClassFromString(@"WOTextField");
}

- (Class)classForElement:(id<DOMElement>)_element {
  /* Note: namespace is checked in build-element */
  NSString *tag;
  unsigned tl;
  unichar  c0;

  tag = [_element tagName];
  
  if ((tl = [tag length]) == 0)
    return Nil;
  c0 = [tag characterAtIndex:0];
  
  switch (tl) {
    case 1:
      if (c0 == 'a') {
	// TODO: improve this section
	if ([_element hasAttribute:@"name" namespaceURI:@"*"])
	  return NSClassFromString(@"WOGenericContainer");
	
	return NSClassFromString(@"WOHyperlink");
      }
      break;

    case 3:
      if (c0 == 'i' && [tag isEqualToString:@"img"])
        return NSClassFromString(@"WOImage");
      break;

    case 4:
      if (c0 == 'b' && [tag isEqualToString:@"body"])
        return NSClassFromString(@"WOBody");
#if WRAP_HTML_ROOT_TAG
      if (c0 == 'h' && [tag isEqualToString:@"html"])
        return NSClassFromString(@"WOHtml");
#endif
      if (c0 == 'f' && [tag isEqualToString:@"form"])
        return NSClassFromString(@"WOForm");

      if (c0 == 'm' && [tag isEqualToString:@"meta"]) {
	NSString *val;
	
        val = [_element attribute:@"http-equiv" namespaceURI:XMLNS_XHTML];
	if (val) {
	  val = [[val stringValue] lowercaseString];
	  if ([val hasPrefix:@"refresh"])
	    return NSClassFromString(@"WOMetaRefresh");
	}
      }
      break;
      
    case 5:
      if (c0 == 'i' && [tag isEqualToString:@"input"])
        return [self classForInputElement:_element];
      if (c0 == 'f' && [tag isEqualToString:@"frame"])
        return NSClassFromString(@"WOFrame");
      if (c0 == 'e' && [tag isEqualToString:@"embed"])
        return NSClassFromString(@"WOEmbeddedObject");
      break;

    case 6:
      if (c0 == 'i' && [tag isEqualToString:@"iframe"])
        return NSClassFromString(@"WOIFrame");
      if (c0 == 'e' && [tag isEqualToString:@"entity"])
        return NSClassFromString(@"WOEntity");
      break;

    case 8:
      if (c0 == 't' && [tag isEqualToString:@"textarea"])
        return NSClassFromString(@"WOText");
      break;
  }
  
  return [_element hasChildNodes] 
    ? WOGenericContainerClass
    : WOGenericElementClass;
}

- (WOElement *)buildContainer:(id<DOMElement>)_element templateBuilder:(id)_b {
  /*
    this is a 'noop' tag, which only generates its children, useful
    as a root tag for templates
  */
  NSArray *children;
  unsigned count;
  
  children = [_element hasChildNodes]
    ? [_b buildNodes:[_element childNodes] templateBuilder:_b]
    : (NSArray *)nil;
  [children autorelease];

  if ((count = [children count]) == 0)
    return nil;
  
  if (count == 1)
    return [[children objectAtIndex:0] retain];
  
  return [[WOCompoundElement allocForCount:count 
                                       zone:NULL] initWithContentElements:children];
}

- (WOElement *)buildElement:(id<DOMElement>)_element templateBuilder:(id)_b {
  NSString *nsuri;

  /* only build HTML namespace tags */
  
  if ((nsuri = [_element namespaceURI]) == nil)
    return [self buildNextElement:_element templateBuilder:_b];
  
  if (![nsuri isEqualToString:XMLNS_XHTML]) {
    /* check HTML 4 namespace */
    if (![nsuri isEqualToString:XMLNS_HTML40])
      return [self buildNextElement:_element templateBuilder:_b];
  }
  
  /* check for container tag (has not class ...) */

  if ([[_element tagName] isEqualToString:@"container"])
    return [self buildContainer:_element templateBuilder:_b];
  
  /* call class based builder in superclass */
  
  return [super buildElement:_element templateBuilder:_b];
}

@end /* WOxHTMLElemBuilder */
