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

#include "SoProductClassInfo.h"
#include "SoActionInvocation.h"
#include "SoPageInvocation.h"
#include "SoSelectorInvocation.h"
#include "SoClassSecurityInfo.h"
#include "SoClass.h"
#include "SoClassRegistry.h"
#include "SoProduct.h"
#include "common.h"

static int debugOn     = 1;
static int loadDebugOn = 0;

@interface SoProductSlotSetInfo(ManifestLoading)
- (BOOL)_loadManifest:(NSDictionary *)_m;
@end

@interface SoProductSlotSetInfo(Privates)
- (void)reset;
@end

@interface NSObject(PListInit)
- (id)initWithPropertyList:(id)_plist;
- (id)initWithPropertyList:(id)_plist owner:(id)_owner;
@end

@implementation SoProductSlotSetInfo

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;
  
  loadDebugOn = [ud boolForKey:@"SoDebugProductLoading"] ? 1 : 0;
}

- (void)reset {
  [self->protectedBy   release]; self->protectedBy   = nil;
  [self->defaultAccess release]; self->defaultAccess = nil;
  [self->roleInfo      release]; self->roleInfo      = nil;
  [self->slotValues      removeAllObjects];
  [self->slotProtections removeAllObjects];
}

- (id)initWithName:(NSString *)_name manifest:(NSDictionary *)_dict
  product:(SoProduct *)_product
{
  if ((self = [super init])) {
    self->product   = _product; // non-retained
    self->className = [_name copy];
    [self _loadManifest:_dict];
  }
  return self;
}

- (void)dealloc {
  [[self->slotValues allValues]
    makeObjectsPerformSelector:@selector(detachFromContainer)];
  
  [self->roleInfo        release];
  [self->protectedBy     release];
  [self->extensions      release];
  [self->exactFilenames  release];
  [self->className       release];
  [self->slotValues      release];
  [self->slotProtections release];
  [super dealloc];
}

/* accessors */

- (NSString *)className {
  return self->className;
}
- (Class)objcClass {
  return NSClassFromString([self className]);
}

/* apply */

- (void)applyClassSecurity:(SoClassSecurityInfo *)_security {
  if (self->protectedBy) {
    if ([self->protectedBy isEqualToString:@"<public>"])
      [_security declareObjectPublic];
    else if ([self->protectedBy isEqualToString:@"<private>"])
      [_security declareObjectPrivate];
    else
      [_security declareObjectProtected:self->protectedBy];
  }
  
  if (self->defaultAccess != nil)
    [_security setDefaultAccess:self->defaultAccess];
  
  if (self->roleInfo != nil) {
    NSEnumerator *perms;
    NSString *perm;
    
    perms = [self->roleInfo keyEnumerator];
    while ((perm = [perms nextObject]) != nil) {
      id role = [self->roleInfo objectForKey:perm];
      
      if ([role isKindOfClass:[NSArray class]])
	[_security declareRoles:role asDefaultForPermission:perm];
      else if ([role isKindOfClass:[NSString class]])
	[_security declareRole:role asDefaultForPermission:perm];
      else {
	[self warnWithFormat:
		@"unexpected 'role' value (expect string or array): %@", role];
      }
    }
  }
}

- (void)applySlotSecurity:(SoClassSecurityInfo *)_security {
  NSEnumerator *names;
  NSString *slotName;
  
  names = [self->slotProtections keyEnumerator];
  while ((slotName = [names nextObject])) {
    NSString *perm;
    
    if ((perm = [self->slotProtections objectForKey:slotName]))
      [_security declareProtected:perm:slotName,nil];
  }
}

- (void)applySlotValues:(SoClass *)_soClass {
  NSEnumerator *names;
  NSString *slotName;

  if (loadDebugOn) {
    [self debugWithFormat:@"  applying %i slots on class %@ ...", 
            [self->slotValues count], [self className]];
  }
  
  names = [self->slotValues keyEnumerator];
  while ((slotName = [names nextObject])) {
    id slot;
    
    slot = [self->slotValues objectForKey:slotName];
    if (slot == nil)
      continue;
    
    if (loadDebugOn) {
      [self debugWithFormat:@"  register slot named %@ on class %@", 
	      slotName, [_soClass className]];
    }
    
    /* if an implementation was provided, register it with the class */
      
    if ([_soClass valueForSlot:slotName]) {
	[self warnWithFormat:@"redefining slot '%@' of class '%@'",
	      slotName, _soClass];
    }
	
    [_soClass setValue:slot forSlot:slotName];
    [slot release];
  }
}

- (void)applyExtensionsForSoClass:(SoClass *)_soClass
  onRegistry:(SoClassRegistry *)_registry
{
  NSEnumerator *e;
  NSString     *ext;
  NSException *error;
  
  if (_soClass == nil) {
    [self errorWithFormat:@"(%s): missing soClass parameter?!",
            __PRETTY_FUNCTION__];
    return;
  }
  if (_registry == nil) {
    [self errorWithFormat:@"missing registry ?!"];
    return;
  }
  
  e = [self->extensions objectEnumerator];
  while ((ext = [e nextObject])) {
    if ((error = [_registry registerSoClass:_soClass forExtension:ext])) {
      [self errorWithFormat:
              @"failed to register class %@ for extension %@: %@", 
              [_soClass className], ext, error];
    }
    else if (loadDebugOn) {
      [self debugWithFormat:@"  registered class %@ for extension %@", 
              [_soClass className], ext];
    }
  }
  
  e = [self->exactFilenames objectEnumerator];
  while ((ext = [e nextObject])) {
    if ((error = [_registry registerSoClass:_soClass forExactName:ext])) {
      [self errorWithFormat:
              @"failed to register class %@ for name %@: %@", 
              [_soClass className], ext, error];
    }
    else if (loadDebugOn) {
      [self debugWithFormat:@"  registered class %@ for name %@", 
              [_soClass className], ext];
    }
  }
}

- (void)applyOnRegistry:(SoClassRegistry *)_registry {
  SoClass *soClass;
  id security;

  if (_registry == nil) {
    [self warnWithFormat:@"(%s): did not pass a registry?!",
            __PRETTY_FUNCTION__];
    return;
  }
  
  if ((soClass = [_registry soClassWithName:[self className]]) == nil) {
    [self errorWithFormat:
            @"did not find exported SoClass '%@' in product %@!", 
            [self className], self->product];
    return;
  }
  
  security = [soClass soClassSecurityInfo];
  if (loadDebugOn) {
    [self debugWithFormat:@"loading info for class %@: %@", 
            [self className], soClass];
  }
  
  [self applyClassSecurity:security];
  [self applySlotSecurity:security];
  [self applySlotValues:soClass];

  /* filename extensions for OFS */
  [self applyExtensionsForSoClass:soClass onRegistry:_registry];
  
  if (loadDebugOn)
    [self debugWithFormat:@"info for class %@ loaded.", [soClass className]];
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn ? YES : NO;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  unsigned cnt;

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  [ms appendFormat:@" name=%@", self->className];
  
  if ((cnt = [self->extensions count]) > 0)
    [ms appendFormat:@" #extensions=%d", cnt];
  if ((cnt = [self->slotValues count]) > 0)
    [ms appendFormat:@" #slotvals=%d", cnt];
  if ((cnt = [self->slotProtections count]) > 0)
    [ms appendFormat:@" #slotperms=%d", cnt];
  
  [ms appendString:@">"];
  return ms;
}

@end /* SoProductSlotSetInfo */

@implementation SoProductClassInfo

/* debugging */

- (NSString *)loggingPrefix {
  return @"[so-class-info]";
}

@end /* SoProductClassInfo */

@implementation SoProductCategoryInfo

/* debugging */

- (NSString *)loggingPrefix {
  return @"[so-category-info]";
}

@end /* SoProductCategoryInfo */

@implementation SoProductSlotSetInfo(ManifestLoading)

- (BOOL)isPageInvocationManifest:(NSDictionary *)_m {
  return [_m objectForKey:@"pageName"] != nil ? YES : NO;
}
- (BOOL)isActionInvocationManifest:(NSDictionary *)_m {
  if ([_m objectForKey:@"actionClass"]      != nil) return YES;
  if ([_m objectForKey:@"directActionName"] != nil) return YES;
  return NO;
}

- (id)makeActionInvocationForMethodNamed:(NSString *)_name 
  manifest:(NSDictionary *)_m 
{
  /*
    Page invocation:
      {
        actionClass      = "DirectAction";
	directActionName = "doIt";
        arguments = {
          SOAP = {
           login    = "loginRequest/auth/username/!textValue";
           password = "loginRequest/auth/password/!textValue";
          };
        }
      }
  */
  SoActionInvocation *method;
  NSString     *actionClass, *actionName;
  NSDictionary *argspecs;
  
  actionClass = [_m objectForKey:@"actionClass"];
  argspecs    = [_m objectForKey:@"arguments"];
  
  if ((actionName = [_m objectForKey:@"directActionName"]) == nil)
    actionName = [_m objectForKey:@"actionName"];
  
  method = [[SoActionInvocation alloc]
	     initWithActionClassName:actionClass actionName:actionName];
  [method setArgumentSpecifications:argspecs];
  return method;
}

- (id)makePageInvocationForMethodNamed:(NSString *)_name 
  manifest:(NSDictionary *)_m 
{
  /*
    Page invocation:
      {
        pageName   = "Main";
	actionName = "doIt";
        arguments = {
          SOAP = {
           login    = "loginRequest/auth/username/!textValue";
           password = "loginRequest/auth/password/!textValue";
          };
        }
      }
  */
  SoPageInvocation *method;
  NSString     *pageName;
  NSDictionary *argspecs;
  
  pageName = [_m objectForKey:@"pageName"];
  argspecs = [_m objectForKey:@"arguments"];
  
  method = [[SoPageInvocation alloc]
	     initWithPageName:pageName
	     actionName:[_m objectForKey:@"actionName"]
	     product:self->product];
  [method setArgumentSpecifications:argspecs];
  return method;
}

- (id)makeInvocationForMethodNamed:(NSString *)_name selector:(id)_config {
  SoSelectorInvocation *method;
  
  if (_config == nil) {
    [self errorWithFormat:
            @"missing config for selector invocation method: '%@'",
            _name];
    return nil;
  }
  
  if ([_config isKindOfClass:[NSString class]]) {
    /* form: selector = "doItInContext:" */
    method = [[SoSelectorInvocation alloc] initWithSelectorNamed:_config 
					   addContextParameter:YES];
  }
  else if ([_config isKindOfClass:[NSDictionary class]]) {
    /*
      Selector Invocation:
        selector = {
	  name                = "doItInContext:";
	  addContextParameter = YES;
	  // TODO: positionalArgumentBindings = ( );
	  // TODO: names (for mapping different argcounts)
          arguments = {
            SOAP = (
              "loginRequest/auth/username/!textValue",
              "loginRequest/auth/password/!textValue"
            );
          }
        };
    */
    NSDictionary *config;
    NSDictionary *argspecs;
    NSString     *selector;
    BOOL         ctxParameter;

    config = (NSDictionary *)_config;
    
    selector = [config objectForKey:@"name"];
    if ([selector length] == 0) {
      [self errorWithFormat:
              @"missing 'name' in selector config of method '%@': %@",
              _name, _config];
      return nil;
    }
    
    argspecs = [config objectForKey:@"arguments"];
    
    ctxParameter = [[config objectForKey:@"addContextParameter"]boolValue];
    
    method = [[SoSelectorInvocation alloc] init];
    [method addSelectorNamed:selector];
    [method setDoesAddContextParameter:ctxParameter];
    [method setArgumentSpecifications:argspecs];
  }
  else {
    [self errorWithFormat:@"cannot handle selector configuration: %@",
            _config];
    return nil;
  }
  return method;
}

- (id)cannotHandleManifest:(NSDictionary *)_m ofMethodNamed:(NSString *)_name {
  /* no implementation provided */
  if (loadDebugOn) {
    /* 
       note, a manifest does not need to contain the actual implementation
       info, eg it can be used to just define the protections
    */
    [self logWithFormat:
	    @"Note: missing implemention info for method '%@' !", _name];
  }
  return nil;
}

- (BOOL)_loadManifest:(NSDictionary *)_m ofMethodNamed:(NSString *)_name {
  NSString *mp;
  NSString *selector;
  id       method;
  
  /* security */
  
  if ((mp = [_m objectForKey:@"protectedBy"]))
    [self->slotProtections setObject:mp forKey:_name];
  
  /* implementation */
  
  if ([self isPageInvocationManifest:_m])
    method = [self makePageInvocationForMethodNamed:_name manifest:_m];
  else if ([self isActionInvocationManifest:_m])
    method = [self makeActionInvocationForMethodNamed:_name manifest:_m];
  else if ((selector = [_m objectForKey:@"selector"]))
    method = [self makeInvocationForMethodNamed:_name selector:selector];
  else
    method = [self cannotHandleManifest:_m ofMethodNamed:_name];
  
  if (method) {
    [self->slotValues setObject:method forKey:_name];
    [method release];
  }
  
  return YES;
}

- (id)instantiateObjectOfClass:(Class)clazz withPlist:(id)value {
  /* returns a retained instance */
  
  if ([value isKindOfClass:[NSDictionary class]]) {
    if ([clazz instancesRespondToSelector:@selector(initWithDictionary:)])
      return [[clazz alloc] initWithDictionary:value];
  }
  else if ([value isKindOfClass:[NSArray class]]) {
    if ([clazz instancesRespondToSelector:@selector(initWithArray:)])
      return [[clazz alloc] initWithArray:value];
  }
  else if ([value isKindOfClass:[NSData class]]) {
    if ([clazz instancesRespondToSelector:@selector(initWithData:)])
      return [[clazz alloc] initWithData:value];
  }
  else {
    if ([clazz instancesRespondToSelector:@selector(initWithString:)])
      return [[clazz alloc] initWithString:[value stringValue]];
  }
  
  if ([clazz instancesRespondToSelector:
               @selector(initWithPropertyList:owner:)])
    return [[clazz alloc] initWithPropertyList:value owner:nil];
  if ([clazz instancesRespondToSelector:@selector(initWithPropertyList:)])
    return [[clazz alloc] initWithPropertyList:value];
  
  return nil;
}

- (BOOL)_loadManifest:(NSDictionary *)_m ofSlotNamed:(NSString *)_name {
  NSString *mp;
  NSString *valueClassName;
  Class    valueClass;
  id value;

  if ([_m isKindOfClass:[NSString class]]) {
    /* user used: slots = { abc = 15; } */
    _m = [NSDictionary dictionaryWithObject:_m forKey:@"value"];
  }
  
  /* security */
  
  if ((mp = [_m objectForKey:@"protectedBy"]))
    [self->slotProtections setObject:mp forKey:_name];
  
  if ((valueClassName = [[_m objectForKey:@"valueClass"] stringValue])) {
    // TODO: hack, we need to load the bundle of the product to have the
    //       contained classes available as valueClasses (But: shouldn't
    //       that be already done by NGBundleManager?)
    [[self->product bundle] load];
    
    // TODO: should we allow/use SoClasses here?
    if ((valueClass = NSClassFromString(valueClassName)) == Nil) {
      [self errorWithFormat:
              @"did not find value class '%@' for slot: '%@'",
              valueClassName, _name];
      return NO;
    }
  }
  else
    valueClass = Nil;
  
  if ((value = [_m objectForKey:@"value"]) != nil) {
    if (valueClass) {
      value = [self instantiateObjectOfClass:valueClass withPlist:value];
      
      if (value == nil) {
	[self errorWithFormat:
          @"could not initialize value of slot %@ with class %@",
	        _name, valueClassName];
	return NO;
      }
      value = [value autorelease];
    }
    else
      /* pass through property list */;
  }
  else if (valueClass) {
    /* 
       Note: a manifest does not need to contain the actual value, eg it can be
       used to just define the protections
    */
    if (loadDebugOn) 
      [self logWithFormat:@"Note: slot no value: '%@'", _name];
    
    value = [[[valueClass alloc] init] autorelease];
    if (value == nil) {
      [self errorWithFormat:
              @"could not initialize value of slot '%@' with class: %@",
              _name, valueClassName];
      return NO;
    }
  }
  
  if (value)
    [self->slotValues setObject:value forKey:_name];
  
  return YES;
}

- (BOOL)_loadManifest:(NSDictionary *)_m {
  NSDictionary *slots;
  id tmp;
  
  [self reset];
  self->protectedBy   = [[_m objectForKey:@"protectedBy"] copy];
  self->defaultAccess = [[_m objectForKey:@"defaultAccess"] copy];
  self->roleInfo      = [[_m objectForKey:@"defaultRoles"] copy];
  
  self->exactFilenames = [[_m objectForKey:@"exactFilenames"] copy];
  
  self->extensions = [[_m objectForKey:@"extensions"] copy];
  if ((tmp = [_m objectForKey:@"extension"])) {
    if (self->extensions == nil) {
      self->extensions = [tmp isKindOfClass:[NSArray class]]
	? [tmp copy]
	: [[NSArray alloc] initWithObjects:&tmp count:1];
    }
    else {
      tmp = [tmp isKindOfClass:[NSArray class]]
	? [[self->extensions arrayByAddingObjectsFromArray:tmp] retain]
	: [[self->extensions arrayByAddingObject:tmp] retain];
      [self->extensions autorelease];
      self->extensions = tmp;
    }
  }
  
  if (self->slotValues == nil)
    self->slotValues = [[NSMutableDictionary alloc] init];
  if (self->slotProtections == nil)
    self->slotProtections = [[NSMutableDictionary alloc] init];
  
  if ((slots = [_m objectForKey:@"methods"])) {
    NSEnumerator *names;
    NSString *methodName;
    
    names = [slots keyEnumerator];
    while ((methodName = [names nextObject])) {
      NSDictionary *info;
      
      info = [slots objectForKey:methodName];
      
      if (![self _loadManifest:info ofMethodNamed:methodName])
	[self logWithFormat:@"manifest of method %@ is broken.", methodName];
    }
  }
  if ((slots = [_m objectForKey:@"slots"])) {
    NSEnumerator *names;
    NSString *slotName;
    
    names = [slots keyEnumerator];
    while ((slotName = [names nextObject])) {
      NSDictionary *info;
      
      info = [slots objectForKey:slotName];
      
      if (![self _loadManifest:info ofSlotNamed:slotName])
	[self logWithFormat:@"manifest of slot %@ is broken.", slotName];
    }
  }
  return YES;
}

@end /* SoProductSlotSetInfo(ManifestLoading) */
