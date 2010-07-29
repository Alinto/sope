/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#ifndef __OFS_OFSFactoryRegistry_H__
#define __OFS_OFSFactoryRegistry_H__

#import <Foundation/NSObject.h>

/*
  OFSFactoryRegistry
  
  The registry is responsible to select factories for producing objects
  for either new objects or for unarchiving stored objects.
  It's not the task of the registry to perform the creation itself.
  
  Note that the registry is usually not accessed directly, but rather
  through OFSFolder.
*/

@class NSString, NSMutableDictionary;
@class SoClass;
@class OFSFactoryContext;

@interface OFSFactoryRegistry : NSObject
{
  NSMutableDictionary *classToFileFactory;
  NSMutableDictionary *extToFileFactory;
  NSMutableDictionary *nameToFileFactory;
  id defaultFolderFactory;
  id defaultFileFactory;
}

+ (id)sharedFactoryRegistry;

/* lookup */

- (id)restorationFactoryForContext:(OFSFactoryContext *)_ctx;
- (id)creationFactoryForContext:(OFSFactoryContext *)_ctx;

/* registration */

- (void)registerFileFactory:(id)_factory forSoClass:(SoClass *)_clazz;
- (void)registerFileFactory:(id)_factory forClass:(Class)_clazz;

- (void)registerFileFactory:(id)_factory forExtension:(NSString *)_ext;
- (void)registerFileFactory:(id)_factory forExactName:(NSString *)_name;

@end

#endif /* __OFS_OFSFactoryRegistry_H__ */
