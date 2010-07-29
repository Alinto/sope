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

#ifndef __NGObjWeb_WOComponentDefinition_H__
#define __NGObjWeb_WOComponentDefinition_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>

@class NSString, NSMutableDictionary, NSArray, NSMutableArray, NSMutableSet;
@class NSDictionary, NSURL;
@class WOElement, WOComponent, WOResourceManager, WOTemplate;

/*
  WOComponentDefinition
  
  Instances of this class are to WOComponents what Classes are to Objective-C
  objects. They are the description and factory of components.
*/
@interface WOComponentDefinition : NSObject
{
@private
  NSString       *name;
  NSString       *path; /* can also contain a URL! */
  NSURL          *baseUrl;
  NSString       *frameworkName;
  Class          componentClass;
  NSTimeInterval lastTouch;
  WOTemplate     *template;
}

- (id)initWithName:(NSString *)_name
  path:(NSString *)_path
  baseURL:(NSURL *)_baseUrl
  frameworkName:(NSString *)_frameworkName;

/* accessors */

- (Class)componentClass;
- (NSString *)componentName;

/* templates */

- (WOTemplate *)template;

/* instantiation */

- (WOComponent *)instantiateWithResourceManager:(WOResourceManager *)_rm
  languages:(NSArray *)_languages;

/* caching */

- (void)touch; /* mark as used .. */
- (NSTimeInterval)lastTouch;

/* privates */

- (void)_finishInitializingComponent:(WOComponent *)_component;

@end

@interface NSObject(WOComponentInfo)

- (NSString *)componentName;
- (Class)componentClass;
- (NSDictionary *)bindings;

@end

#endif /* __NGObjWeb_WOComponentDefinition_H__ */
