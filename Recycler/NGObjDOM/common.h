/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#ifndef __NGObjDOM_common_H__
#define __NGObjDOM_common_H__

#import <Foundation/Foundation.h>

#if NeXT_Foundation_LIBRARY || APPLE_FOUNDATION_LIBRARY
#  include <NGExtensions/NGObjectMacros.h>
#endif

#include <NGExtensions/NGExtensions.h>
#include <NGObjWeb/NGObjWeb.h>
#include <DOM/DOM.h>

@class ODNodeRenderer;

@interface WOContext(ODNodeRenderPrivate)
- (void)addActiveFormElement:(ODNodeRenderer *)_element;
@end

@interface DOMElement(ODNodeRenderPrivate)
- (id)lookupQueryPath:(NSString *)_queryPath;
@end


static inline void ODRAppendFont(WOResponse *_resp,
                                 NSString   *_color,
                                 NSString   *_face,
                                 NSString   *_size)
{
  [_resp appendContentString:@"<font"];
  if (_color) {
    [_resp appendContentString:@" color=\""];
    [_resp appendContentHTMLAttributeValue:_color];
    [_resp appendContentCharacter:'"'];
  }
  if (_face) {
    [_resp appendContentString:@" face=\""];
    [_resp appendContentHTMLAttributeValue:_face];
    [_resp appendContentCharacter:'"'];
  }
  if (_size) {
    [_resp appendContentString:@" size=\""];
    [_resp appendContentHTMLAttributeValue:_size];
    [_resp appendContentCharacter:'"'];
  }
  [_resp appendContentCharacter:'>'];
}

static inline void ODRAppendTD(WOResponse *_resp,
                               NSString   *_align,
                               NSString   *_valign,
                               NSString   *_bgColor,
                               NSString   *_colspan)
{
  [_resp appendContentString:@"<td"];
  if (_bgColor) {
    [_resp appendContentString:@" bgcolor=\""];
    [_resp appendContentHTMLAttributeValue:_bgColor];
    [_resp appendContentCharacter:'"'];
  }
  if (_align) {
    [_resp appendContentString:@" align=\""];
    [_resp appendContentHTMLAttributeValue:_align];
    [_resp appendContentCharacter:'"'];
  }
  if (_valign) {
    [_resp appendContentString:@" valign=\""];
    [_resp appendContentHTMLAttributeValue:_valign];
    [_resp appendContentCharacter:'"'];
  }
  if (_colspan) {
    [_resp appendContentString:@" colspan=\""];
    [_resp appendContentHTMLAttributeValue:_colspan];
    [_resp appendContentCharacter:'"'];
  }
  [_resp appendContentCharacter:'>'];
}

static inline void ODRAppendButton(WOResponse *_response,
                                   NSString   *_name,
                                   NSString   *_src,
                                   NSString   *_alt)
{
  
  if (_name == nil) {
    [_response appendContentHTMLString:(_alt) ? _alt : @"[button]"];
    return;
  }
  [_response appendContentString:@"<input border=\"0\" type=\""];
  [_response appendContentString:(_src) ? @"image" : @"submit"];
  [_response appendContentString:@"\" name=\""];
  [_response appendContentString:_name];
  [_response appendContentCharacter:'"'];
  if (_src) {
    [_response appendContentString:@" src=\""];
    [_response appendContentString:_src];
    [_response appendContentCharacter:'"'];
    // append alt-text
    if (_alt) {
      [_response appendContentString:@" alt=\""];
      [_response appendContentString:_alt];
      [_response appendContentCharacter:'"'];
    }
  }
  else {
    [_response appendContentString:@" value=\""];
    [_response appendContentString:(_alt) ? _alt : @"submit"];
    [_response appendContentCharacter:'"'];
  }
  [_response appendContentString:@" />"];
}

static inline void ODRAppendImage(WOResponse *_response,
                                   NSString   *_name,
                                   NSString   *_src,
                                   NSString   *_alt)
{
  if (_src == nil) {
    [_response appendContentHTMLString:(_alt) ? _alt : @"[img]"];
    return;
  }

  [_response appendContentString:@"<img border=\"0\" src=\""];
  [_response appendContentString:_src];
  if (_name) {
    [_response appendContentString:@"\" name=\""];
    [_response appendContentString:_name];
  }
  [_response appendContentString:@"\" alt=\""];
  [_response appendContentString:_alt];
  [_response appendContentString:@"\" />"];
}


static inline NSArray *ODRLookupQueryPath(id _node, NSString *_path) {
  static Class arrayClass = Nil;
  id     tmp;

  if (arrayClass == Nil)
    arrayClass = [NSArray class];

  if (!(tmp = [_node lookupQueryPath:_path]))
    return nil;
  
  return ([tmp isKindOfClass:arrayClass])
    ? tmp
    : [arrayClass arrayWithObject:tmp];
}

static inline NSString *ODRUriOfResource(NSString *_name, WOContext *_ctx) {
  NSArray           *languages;
  WOResourceManager *resourceManager;
  NSString          *uri;

  if (_name == nil)
    return nil;

  languages = [_ctx hasSession]
    ? [[_ctx session] languages]
    : [[_ctx request] browserLanguages];

  if ((resourceManager = [[_ctx component] resourceManager]) == nil)
    resourceManager = [[_ctx application] resourceManager];
  
  uri = [resourceManager urlForResourceNamed:_name
                         inFramework:nil
                         languages:languages
                         request:[_ctx request]];
  if ([uri rangeOfString:@"/missingresource?"].length > 0)
    uri = nil;
  
  return uri;
}

#if PROFILE
#  define BEGIN_PROFILE \
     { NSTimeInterval __ti = [[NSDate date] timeIntervalSince1970];

#  define END_PROFILE \
     __ti = [[NSDate date] timeIntervalSince1970] - __ti;\
     if (__ti > 0.05) \
       printf("***PROF[%s]: %0.3fs\n", __PRETTY_FUNCTION__, __ti);\
     else if (__ti > 0.005) \
       printf("PROF[%s]: %0.3fs\n", __PRETTY_FUNCTION__, __ti);\
     }

#  define PROFILE_CHECKPOINT(__key__) \
       printf("---PROF[%s] CP %s: %0.3fs\n", __PRETTY_FUNCTION__, __key__,\
              [[NSDate date] timeIntervalSince1970] - __ti)

#else
#  define BEGIN_PROFILE {
#  define END_PROFILE   }
#  define PROFILE_CHECKPOINT(__key__)
#endif

@interface NSObject(AttrNodeNSURI)
- (id)attributeNode:(NSString *)_name namespaceURI:(NSString *)_nsuri;
@end

#endif /* __NGObjDOM_common_H__ */
