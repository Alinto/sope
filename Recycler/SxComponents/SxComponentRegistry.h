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

#ifndef __SxComponentRegistry_H__
#define __SxComponentRegistry_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSMapTable.h>
#include <SxComponents/SxComponent.h>

/*
  This object is the client of the SandStorm/SKYRiX registry service.

  Query any component you like by using
    - (SxComponent *)getComponent:(NSString *)_namespace;
  
  eg:
    SxComponent *c;
    c = [[SxComponentRegistry defaultComponentRegistry]
                              getComponent:@"com.skyrix.accounts"];
    NSLog(@"Methods: ", [c call:@"system.listMethods", nil]);

  A registry can have multiple registry backends, probably most
  important/useful is the XML-RPC one implementing the SandStorm
  registry interface.
*/

@class NSArray, NSMutableArray, NSMutableDictionary;

@interface SxComponentRegistry : NSObject < NSCoding >
{
  NSArray             *backends;
  NSMapTable          *lookupCache;
  NSMutableArray      *credentials;
  NSMutableDictionary *listMethodsCache;
  NSMutableDictionary *methodSignatureCache;
}

+ (id)defaultComponentRegistry;

/* getting components */

- (id<NSObject,SxComponent>)getComponent:(NSString *)_namespace;

/* returns the names of the available components */

- (NSArray *)listComponents:(NSString *)_prefix;
- (NSArray *)listComponents;

/* component registration */

- (BOOL)registerComponent:(SxComponent *)_component;
- (BOOL)unregisterComponent:(SxComponent *)_component;

/* introspection methods */
- (NSArray *)listMethods:(NSString *)_component;
- (NSArray *)methodSignature:(NSString *)_component method:(NSString *)_name;
- (NSString *)methodHelp:(NSString *)_component method:(NSString *)_name;

/* component retries on error (failover) */

- (int)componentRetryCountOnError;
- (int)componentRetryTime;

/* caching */

- (SxComponent *)getCachedComponent:(NSString *)_namespace;
- (void)flush;

/* credentials */

- (NSArray *)credentials;
- (void)addCredentials:(id)_creds;

@end

@protocol SxComponentRegistryBackend

- (BOOL)registry:(id)_registry canHandleNamespace:(NSString *)_prefix;
- (NSArray *)registry:(id)_registry listComponents:(NSString *)_prefix;
- (SxComponent *)registry:(id)_registry getComponent:(NSString *)_cname;

- (NSArray *)registry:(id)_registry listMethods:(NSString *)_cname;
- (NSArray *)registry:(id)_registry methodSignature:(NSString *)_component
               method:(NSString *)_name;
- (NSString *)registry:(id)_registry methodHelp:(NSString *)_component
               method:(NSString *)_name;

- (BOOL)canHandleComponent:(SxComponent *)_component;
- (BOOL)registerComponent:(SxComponent *)_component;
- (BOOL)unregisterComponent:(SxComponent *)_component;

@end

#endif /* __SxComponentRegistry_H__ */
