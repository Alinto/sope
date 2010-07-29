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

#ifndef __NGObjDOM_ODNodeRendererFactorySet_H__
#define __NGObjDOM_ODNodeRendererFactorySet_H__

#include <NGObjDOM/ODNodeRendererFactory.h>

@class NSMutableDictionary, NSMutableArray;
@class EOQualifier;

/*
  Attention:

    The set caches renderers based on the tag/namespace of an element only !!

    That is: you can't have two different renderers for eg "input type='text'"
    and "input type='submit'" !
*/

@interface ODNodeRendererFactorySet : NSObject < ODNodeRendererFactory >
{
  NSMutableDictionary *cache;
  NSMutableArray      *subfactories;
}

- (void)flushCache;

- (void)registerFactory:(id<NSObject,ODNodeRendererFactory>)_factory
  forNodeQualifier:(EOQualifier *)_qualifier;

- (void)registerFactory:(id<NSObject,ODNodeRendererFactory>)_factory
  forNamespaceURI:(NSString *)_namespaceURI;

- (void)registerFactory:(id<NSObject,ODNodeRendererFactory>)_factory
  forNamespaceURI:(NSString *)_namespaceURI
  tagName:(NSString *)_tagName;

@end

#endif /* __NGObjDOM_ODNodeRendererFactorySet_H__ */
