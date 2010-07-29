/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OpenGroupware.org.

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

#include "ODResourceManager.h"
#include "common.h"

@interface WOResourceManager(Privates)

- (id)definitionForComponent:(NSString *)_name
  languages:(NSArray *)_languages;
- (NSString *)pathToComponentNamed:(NSString *)_name
  inFramework:(NSString *)_fw;

@end

@implementation ODResourceManager

+ (int)version {
  return [super version] + 0 /* v3 */;
}
+ (void)initialize {
  static BOOL isInitialized = NO;
  NSDictionary *defs;
  
  NSAssert2([super version] == 3,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  
  if (isInitialized) return;
  isInitialized = YES;

  defs = [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSArray arrayWithObjects:
                                      @"xml", @"wml", @"xhtml", nil],
                           @"ODXMLComponentExtensions",
                           nil];
  // .svg, ... can be added using the default
    
  [[NSUserDefaults standardUserDefaults] registerDefaults:defs];
}

+ (NSArray *)xmlComponentExtensions {
  static NSArray *exts = nil;

  if (exts == nil) {
    exts = [[[NSUserDefaults standardUserDefaults]
                             arrayForKey:@"ODXMLComponentExtensions"]
                             copy];
  }
  
  return exts;
}

- (void)dealloc {
  RELEASE(self->nameToCDef);
  [super dealloc];
}

/* lookup */

- (NSString *)pathToComponentNamed:(NSString *)_name
  inFramework:(NSString *)_framework
  languages:(NSArray *)_langs
{
  /* search for component template .. */
  
  if (_name == nil) {
#ifdef DEBUG
    NSLog(@"WARNING(%s): tried to get path to component with <nil> name !",
          __PRETTY_FUNCTION__);
#endif
    return nil;
  }
  
  /* scan for name.$ext resource ... */
  {
    NSEnumerator *e;
    NSString *ext;
    
    e = [[[self class] xmlComponentExtensions] objectEnumerator];
    
    while ((ext = [e nextObject])) {
      NSString *templateName;
      NSString *path;
      
      templateName = [_name stringByAppendingPathExtension:ext];
      
      path = [self pathForResourceNamed:templateName
                   inFramework:_framework
                   languages:_langs];
      if (path) return path;
    }
  }
  
  /* this resource manager does not search in WOProjectSearchPath ... */
  
  return [super pathToComponentNamed:_name inFramework:_framework];
}

- (id)definitionForComponent:(NSString *)_name
  languages:(NSArray *)_languages
{
  id cdef;
  id cacheKey = nil;
  
  if (_name == nil)
    return nil;
  
  if (_languages == nil)
    _languages = [NSArray array];
  
  /* look into cache */
  
  if ([[WOApplication application] isCachingEnabled]) {
    cacheKey = [NSArray arrayWithObjects:_name, _languages, nil];
    
    if ((cdef = [self->nameToCDef objectForKey:cacheKey]))
      return cdef;
  }
  else {
    cdef     = nil;
    cacheKey = nil;
  }
  
  /* look for .wo component if no XML component could be found ... */
  
  if (cdef == nil)
    cdef = [super definitionForComponent:_name languages:_languages];
  
  /* return result */
  
  return cdef;
}

@end /* ODResourceManager */
