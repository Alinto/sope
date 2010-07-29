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

#include "OFSFactoryRegistry.h"
#include "OFSFolder.h"
#include "OFSFile.h"
#include "OFSFactoryContext.h"
#include <SoObjects/SoClassRegistry.h>
#include <SoObjects/SoObjCClass.h>
#include "common.h"

@interface SoClass(Factory)
- (id)ofsObjectFactory;
@end

@implementation OFSFactoryRegistry

static int factoryDebugOn    = 0;
static int factoryRegDebugOn = 0;

+ (id)sharedFactoryRegistry {
  static id reg = nil;
  if (reg == nil) reg = [[OFSFactoryRegistry alloc] init];
  return reg;
}

- (id)init {
  if ((self = [super init])) {
    self->classToFileFactory = 
      [[NSMutableDictionary alloc] initWithCapacity:32];
    self->extToFileFactory = 
      [[NSMutableDictionary alloc] initWithCapacity:64];
    self->nameToFileFactory = 
      [[NSMutableDictionary alloc] initWithCapacity:64];
    
    self->defaultFolderFactory = [OFSFolder class];
    self->defaultFileFactory   = [OFSFile   class];
  }
  return self;
}
- (void)dealloc {
  [self->defaultFileFactory   release];
  [self->defaultFolderFactory release];
  [self->classToFileFactory   release];
  [self->extToFileFactory     release];
  [self->nameToFileFactory    release];
  [super dealloc];
}

/* lookup factory */

- (id)factoryForChildKey:(NSString *)_key 
  ofFolder:(OFSFolder *)_folder
  fileType:(NSString *)_ftype
  mimeType:(NSString *)_mimeType
{
  SoClassRegistry *classRegistry;
  NSString *pe;
  SoClass  *soClass;
  BOOL     isDir;
  id       factory = nil;
  
  isDir = [_ftype isEqualToString:NSFileTypeDirectory] ? YES : NO;
  
  if (factoryDebugOn) {
    [self debugWithFormat:@"lookup factory for key %@ type=%@ mime=%@",
	    _key, _ftype, _mimeType];
  }
  
  /* first check fixed child classes */
  
  if (_folder && !isDir) {
    factory = [self->classToFileFactory objectForKey:[_folder soClass]];
    if (factory) {
      if (factoryDebugOn) {
	[self debugWithFormat:
		@"selected a file factory fixed to folderclass: %@", factory];
      }
      return factory;
    }
  }
  
  /* then, check exact names (eg 'htpasswd') */

  if ((factory = [self->nameToFileFactory objectForKey:_key])) {
    if (factoryDebugOn) {
      [self debugWithFormat:@"selected file factory by exact name '%@': %@",
              _key, factory];
    }
    return factory;
  }
  
  /* now check extension */
  
  pe = [_key pathExtension];
  if (pe == nil) pe = @"";
  
  if ((factory = [self->extToFileFactory objectForKey:pe])) {
    if (factoryDebugOn) {
      [self debugWithFormat:@"selected file factory by extension '%@': %@",
              pe, factory];
    }
    return factory;
  }
  
  /* check for SoClass factories */

  classRegistry = [SoClassRegistry sharedClassRegistry];
  
  if ((soClass = [classRegistry soClassForExactName:_key])) {
    if (factoryDebugOn) {
      [self debugWithFormat:@"selected SoClass factory by exact name '%@': %@",
              _key, factory];
    }
  }
  else if ((soClass = [classRegistry soClassForExtension:pe])) {
    if (factoryDebugOn) {
      [self debugWithFormat:@"selected SoClass factory by extension '%@': %@",
              pe, factory];
    }
  }
  
  if (soClass) {
    if ((factory = [soClass ofsObjectFactory]))
      return factory;
    else {
      if (factoryDebugOn) {
	[self debugWithFormat:
                @"did not use SoClass for name/extension %@/'%@': %@",
	        _key, pe, soClass];
      }
    }
  }
  
  /* apply defaults */
  
  return isDir ? self->defaultFolderFactory : self->defaultFileFactory;
}

- (id)restorationFactoryForContext:(OFSFactoryContext *)_ctx {
  return [self factoryForChildKey:[_ctx nameInContainer]
	       ofFolder:[_ctx container]
	       fileType:_ctx->fileType
	       mimeType:_ctx->mimeType];
}
- (id)creationFactoryForContext:(OFSFactoryContext *)_ctx {
  return [self factoryForChildKey:[_ctx nameInContainer]
	       ofFolder:[_ctx container]
	       fileType:_ctx->fileType
	       mimeType:_ctx->mimeType];
}

/* registration */

- (void)registerFileFactory:(id)_factory forSoClass:(SoClass *)_clazz {
  if (_factory == nil) return;
  if (_clazz   == nil) return;
  if (factoryRegDebugOn) {
    [self debugWithFormat:@"registering file factory '%@' for class %@",
	    _factory, _clazz];
  }
  [self->classToFileFactory setObject:_factory forKey:_clazz];
}

- (void)registerFileFactory:(id)_factory forClass:(Class)_clazz {
  [self registerFileFactory:_factory forSoClass:[_clazz soClass]];
}

- (void)registerFileFactory:(id)_factory forExtension:(NSString *)_ext {
  if (_factory == nil) return;
  if (_ext     == nil) return;
  
  if (factoryRegDebugOn) {
    [self debugWithFormat:@"registering file factory '%@' for extension %@",
	    _factory, _ext];
  }
  [self->extToFileFactory setObject:_factory forKey:_ext];
}

- (void)registerFileFactory:(id)_factory forExactName:(NSString *)_name {
  if (_factory == nil) return;
  if (_name    == nil) return;
  
  if (factoryRegDebugOn) {
    [self debugWithFormat:@"registering file factory '%@' for exact name '%@'",
	    _factory, _name];
  }
  [self->nameToFileFactory setObject:_factory forKey:_name];
}

@end /* OFSFactoryRegistry */

@implementation SoClass(Factory)

- (id)ofsObjectFactory {
  return nil;
}

@end /* SoClass(Factory) */

@implementation SoObjCClass(Factory)

- (id)ofsObjectFactory {
  Class bClazz;
  
  if ((bClazz = [self objcClass]) == Nil)
    return nil;
  
  if (![bClazz respondsToSelector:@selector(instantiateInFactoryContext:)])
    return nil;
  
  return bClazz;
}

@end /* SoObjCClass(Factory) */
