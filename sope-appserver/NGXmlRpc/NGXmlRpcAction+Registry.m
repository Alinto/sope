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

#include <NGXmlRpc/NGXmlRpcAction.h>
#include "common.h"

@interface NGXmlRpcActionSelMapping : NSObject
{
  NSMutableArray *signatures;
  NSMutableArray *selectors;
  unsigned count;
}

- (void)registerSelector:(SEL)_sel forSignature:(NSArray *)_signature;
- (SEL)selectorForSignature:(NSArray *)_signature;
- (NSArray *)signatures;

@end

@implementation NGXmlRpcActionSelMapping

static int logSelMapping = -1;

- (id)init {
  if (logSelMapping == -1) {
    logSelMapping = [[NSUserDefaults standardUserDefaults]
		      boolForKey:@"WOLogXmlRpcSelectorMapping"]
      ? 1 : 0;
  }

  self->signatures = [[NSMutableArray alloc] initWithCapacity:2];
  self->selectors  = [[NSMutableArray alloc] initWithCapacity:2];
  return self;
}
- (void)dealloc {
  RELEASE(self->selectors);
  RELEASE(self->signatures);
  [super dealloc];
}

- (void)registerSelector:(SEL)_sel forSignature:(NSArray *)_signature {
  [self->signatures addObject:_signature];
  [self->selectors  addObject:NSStringFromSelector(_sel)];
  self->count++;
}

- (BOOL)signature:(NSArray *)_base matches:(NSArray *)_query {
  unsigned bc, qc;
  
  bc = [_base  count];
  qc = [_query count];
  if (bc != qc) return NO;
  /* should check further */
  return YES;
}
- (SEL)selectorForSignature:(NSArray *)_signature {
  unsigned i;
  
  for (i = 0; i < self->count; i++) {
    NSArray *sig;
    
    sig = [self->signatures objectAtIndex:i];
    if ([self signature:sig matches:_signature])
      return NSSelectorFromString([self->selectors objectAtIndex:i]);
  }
#if DEBUG
  if (self->count > 0) {
    [self debugWithFormat:
            @"found no signature matching argcount %i, signatures: %@, got: %@",
            ([_signature count] - 1),
            self->signatures, _signature];
  }
#endif
  return NULL;
}
- (NSArray *)signatures {
  return self->signatures;
}

@end /* NGXmlRpcActionSelMapping */

@implementation NGXmlRpcAction(Registry)

/* class registry */

static NSMutableDictionary *uriToClass = nil;
static NSMutableDictionary *classToMethodDict = nil;

+ (void)registerActionClass:(Class)_class forURI:(NSString *)_uri {
  [(id<NSObject>)_class self]; /* ensure initialize */
  if (uriToClass == nil)
    uriToClass = [[NSMutableDictionary alloc] initWithCapacity:4];
  [uriToClass setObject:_class forKey:_uri];
  
  NSLog(@"%s: mapped uri '%@' to class %@", __PRETTY_FUNCTION__,
        _uri, NSStringFromClass(_class));
}
+ (Class)actionClassForURI:(NSString *)_uri {
  return [uriToClass objectForKey:_uri];
}

+ (void)registerSelector:(SEL)_selector
  forMethodNamed:(NSString *)_method
  signature:(id)_signature
{
  NSMutableDictionary      *md;
  NGXmlRpcActionSelMapping *methodInfo;

  if (![_signature isKindOfClass:[NSArray class]])
    _signature = [[_signature stringValue] componentsSeparatedByString:@","];
  
  if (classToMethodDict == nil)
    classToMethodDict = [[NSMutableDictionary alloc] initWithCapacity:4];
  
  if ((md = [classToMethodDict objectForKey:self]) == nil) {
    md = [[NSMutableDictionary alloc] initWithCapacity:16];
    [classToMethodDict setObject:md forKey:self];
    RELEASE(md);
  }

  if ((methodInfo = [md objectForKey:_method]) == nil) {
    methodInfo = [[NGXmlRpcActionSelMapping alloc] init];
    [md setObject:methodInfo forKey:_method];
    RELEASE(methodInfo);
  }
  
  [methodInfo registerSelector:_selector forSignature:_signature];
  
  if (logSelMapping) {
    NSLog(@"%@: registered selector %@ for method %@ %@",
	  NSStringFromClass(self),
	  NSStringFromSelector(_selector),
	  _method,
	  [_signature componentsJoinedByString:@","]);
  }
}
+ (SEL)selectorForActionNamed:(NSString *)_name
  signature:(NSArray *)_signature
{
  NSMutableDictionary      *methodDict;
  NGXmlRpcActionSelMapping *methodInfo;
  
  if ((methodDict = [classToMethodDict objectForKey:self]) == nil)
    /* nothing registered */
    return NULL;
  
  if ((methodInfo = [methodDict objectForKey:_name]) == nil)
    /* no action with that name is registered */
    return NULL;
  
  return [methodInfo selectorForSignature:_signature];
}

+ (NSArray *)registeredMethodNames {
  NSMutableDictionary *methodDict;
  
  if ((methodDict = [classToMethodDict objectForKey:self]) == nil)
    /* nothing registered */
    return nil;
  return [methodDict allKeys];
}
+ (NSArray *)signaturesForMethodNamed:(NSString *)_name {
  NSMutableDictionary      *methodDict;
  NGXmlRpcActionSelMapping *methodInfo;
  
  if ((methodDict = [classToMethodDict objectForKey:self]) == nil)
    /* nothing registered */
    return NULL;
  
  if ((methodInfo = [methodDict objectForKey:_name]) == nil)
    /* no action with that name is registered */
    return NULL;
  
  return [methodInfo signatures];
}

/* mapping files */

+ (BOOL)registerSystemMethods {
  if ([self instancesRespondToSelector:@selector(system_listMethodsAction)]) {
    [self registerSelector:@selector(system_listMethodsAction)
          forMethodNamed:@"system.listMethods"
          signature:[NSArray arrayWithObject:@"array"]];
  }
  else {
    NSLog(@"WARNING(%s): class does not have a listMethods action !",
          __PRETTY_FUNCTION__);
  }
  if ([self instancesRespondToSelector:
              @selector(system_methodSignatureAction:)]) {
    [self registerSelector:@selector(system_methodSignatureAction:)
          forMethodNamed:@"system.methodSignature"
          signature:[NSArray arrayWithObjects:@"array", @"string", nil]];
  }
  if ([self instancesRespondToSelector:
              @selector(system_methodHelpAction:)]) {
    [self registerSelector:@selector(system_methodHelpAction:)
          forMethodNamed:@"system.methodHelp"
          signature:[NSArray arrayWithObjects:@"string", @"string", nil]];
  }
  return YES;
}

+ (BOOL)registerMappingsInFile:(NSString *)_path {
  NSString     *path;
  NSDictionary *cfg;
  NSEnumerator *keys;
  NSString     *methodName;
  
  if (![_path isAbsolutePath]) {
    NSBundle *b;
    
    b = [NSBundle bundleForClass:self];
    if ((path = [b pathForResource:_path ofType:@"plist"]) == nil)
      path = _path;
  }
  else
    path = _path;
  
  NSLog(@"%s: register mappings in file %@", __PRETTY_FUNCTION__, path);
  
  if ((cfg = [NSDictionary dictionaryWithContentsOfFile:path]) == nil) {
    NSLog(@"%s:   could not load file %@", __PRETTY_FUNCTION__, path);
    return NO;
  }
  
  if (![self registerSystemMethods])
    return NO;
  
  keys = [cfg keyEnumerator];
  while ((methodName = [keys nextObject])) {
    NSDictionary *mi;
    NSEnumerator *sigs;
    NSArray      *sig;
    
    if ([methodName hasPrefix:@"__"])
      continue;
    
    mi = [cfg objectForKey:methodName];
    if (![mi respondsToSelector:@selector(keyEnumerator)]) {
      [self logWithFormat:@"entry '%@' in mapping file is no dictionary, skipping: %@", methodName, mi];
      continue;
    }
    
    sigs = [mi keyEnumerator];
    while ((sig = [sigs nextObject])) {
      NSString *selName;
      SEL sel;
      
      selName = [mi objectForKey:sig];
      
      if ((sel = NSSelectorFromString(selName)) == NULL) {
        NSLog(@"%s:  did not find selector '%@'", __PRETTY_FUNCTION__,
              selName);
        continue;
      }
      
      if (![self instancesRespondToSelector:sel]) {
        NSLog(@"WARNING(%s):  instances of %@ do not respond to selector '%@'",
              __PRETTY_FUNCTION__, NSStringFromClass(self),
              selName);
      }
      
      [self registerSelector:sel
            forMethodNamed:methodName
            signature:sig];
    }
  }
  return YES;
}

@end /* NGXmlRpcAction(Registry) */
