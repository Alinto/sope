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

#include "SoSecurityManager.h"
#include "SoObject.h"
#include "SoClass.h"
#include "SoClassSecurityInfo.h"
#include "SoPermissions.h"
#include "SoUser.h"
#include "SoSecurityException.h"
#include "WOContext+SoObjects.h"
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOApplication.h>
#include "common.h"

@interface NSObject(WOAppAuth)
- (BOOL)isPublicInContext:(id)_ctx;
@end

@interface NSObject(UserDB)
- (id)userInContext:(WOContext *)_ctx;
@end

@interface NSString(SpecialPermissionChecks)
- (BOOL)isSoPublicPermission;
- (BOOL)isSoAnonymousUserLogin;
@end

#if USE_PERM_CACHE
static NSString *SoPermCache      = @"__validatedperms";
#endif

@implementation SoSecurityManager

static int debugOn = -1;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  debugOn = [ud boolForKey:@"SoSecurityManagerDebugEnabled"] ? 1 : 0;
}

+ (id)sharedSecurityManager {
  static SoSecurityManager *sharedManager = nil; // THREAD
  
  if (sharedManager == nil)
    sharedManager = [[SoSecurityManager alloc] init];
  return sharedManager;
}

- (void)dealloc {
  [super dealloc];
}

/* exceptions */

- (NSException *)makeExceptionForObject:(id)_obj reason:(NSString *)_r {
  NSException *e;
  if (_obj == nil) return nil;
  e = [SoAccessDeniedException securityExceptionOnObject:_obj
			       withAuthenticator:nil
			       andManager:self];
  if ([_r length] > 0) [e setReason:_r];
  return e;
}

- (NSException *)isPrivateExceptionForObject:(id)_object {
  NSString *r;
  
  r = [NSString stringWithFormat:@"tried to access private object "
                @"(0x%p, SoClass=%@)",
                _object, [[_object soClass] className]];
  return [self makeExceptionForObject:_object reason:r];
}
- (NSException *)missingPermissionException:(NSString *)_perm 
  forObject:(id)_object
{
  NSString *r;
  
  r = [NSString stringWithFormat:@"missing permission '%@' on object "
                @"(0x%p, SoClass=%@)",
                _perm, _object, [[_object soClass] className]];
  return [self makeExceptionForObject:_object  reason:r];
}

- (NSException *)isPrivateKeyException:(NSString *)_key ofObject:(id)_object {
  NSException *e;
  NSString    *s;
  
  s = [[NSString alloc] initWithFormat:
			  @"tried to access private key '%@' of object: %@",
			  _key, _object];
  e = [self makeExceptionForObject:_object reason:s];
  [s release];
  return e;
}

/* secinfo lookup */

- (SoClassSecurityInfo *)lookupInfoOfClass:(SoClass *)_soClass
  condition:(SEL)_sel
  object:(id)_object
{
  SoClass *soClass;
  
  for (soClass = _soClass; soClass; soClass = [soClass soSuperClass]) {
    SoClassSecurityInfo *sinfo;
    IMP m;

    // [self logWithFormat:@"CHECK CLASS: %@", soClass];
    
    if ((sinfo = [soClass soClassSecurityInfo]) == nil) continue;
    if ((m = [sinfo methodForSelector:_sel])) {
      BOOL ok;
      
      ok = (_object)
	? ((BOOL (*)(id, SEL, id))m)(sinfo, _sel, _object)
	: ((BOOL (*)(id, SEL))m)(sinfo, _sel);
      if (ok) return sinfo;
    }
  }
  return nil;
}

/* validation */

- (id)authenticatorInContext:(id)_ctx object:(id)_object {
  id authenticator;

  if ((authenticator = [_object authenticatorInContext:_ctx]) == nil)
    authenticator = [[WOApplication application] authenticatorInContext:_ctx];
  return authenticator;
}
- (id<SoUser>)userInContext:(id)_ctx object:(id)_object {
  id user, authenticator;
  
  if ((user = [(WOContext *)_ctx activeUser]) != nil)
    return [user isNotNull] ? user : nil;
  
  authenticator = [self authenticatorInContext:_ctx object:_object];
    
  if ((user = [authenticator userInContext:_ctx]) != nil)
    [(WOContext *)_ctx setActiveUser:user];
  
  return [user isNotNull] ? user : nil;
}

- (BOOL)isUser:(id<SoUser>)_user ownerOfObject:(id)_obj inContext:(id)_ctx {
  NSString *objectOwner;
  
  if ((objectOwner = [_obj ownerInContext:_ctx]) == nil)
    return NO;
  
  if ([[_user login] isEqualToString:objectOwner])
    return YES;
  
  return NO;
}

- (NSException *)validatePermission:(NSString *)_perm
  onObject:(id)_object 
  inContext:(id)_ctx
{
  NSMutableDictionary *validatedPerms;
  NSArray             *rolesHavingPermission;
  SoClassSecurityInfo *sinfo;
  id<SoUser> user;
  NSArray      *userRoles;
  NSEnumerator *e;
  NSString     *role;
  
  if (_perm == nil)
    return [self missingPermissionException:_perm forObject:_object];
  
#if !USE_PERM_CACHE
  validatedPerms = nil;
#else
  // TODO: Bug !! The cache must go on Permission+ObjectID since the
  //              permission can be set without the ID !
  
  /* check the cache */
  if ((validatedPerms = [_ctx objectForKey:SoPermCache])) {
    NSException *o;
  
    if ((o = [validatedPerms objectForKey:_perm])) {
      if (debugOn)
	[self debugWithFormat:@"permission '%@' cached as valid ...", _perm];
      
      if ([o isNotNull])
	/* an exception */
	return o;
      return nil;
    }
  }
  else {
    /* setup cache */
    validatedPerms = [[NSMutableDictionary alloc] init];
    [_ctx setObject:validatedPerms forKey:SoPermCache];
    [validatedPerms autorelease];
  }
#endif
  
  if (debugOn) {
    [self debugWithFormat:@"validate permission '%@' on object: %@",
	    _perm, _object];
  }
  
  if ([_perm isSoPublicPermission])
    /* the object is public */
    goto found;
  
  /* determine the possible roles for the permission */
  
  // TODO: check object for policy (currently only default roles are checked)
  
  sinfo = [self lookupInfoOfClass:[_object soClass] 
		condition:@selector(hasDefaultRoleForPermission:)
		object:_perm];
  
  if (sinfo == nil)
    sinfo = [[_object soClass] soClassSecurityInfo];
  
  rolesHavingPermission = [sinfo defaultRolesForPermission:_perm];
  if (debugOn) {
    [self debugWithFormat:@"  possible roles for permission '%@': %@",
	    _perm, [rolesHavingPermission componentsJoinedByString:@", "]];
  }
  
  if ([rolesHavingPermission containsObject:SoRole_Anonymous]) {
    /* is public */
    [self debugWithFormat:@"  allowed because of anonymous roles."];
    goto found;
  }
  if ([rolesHavingPermission count] == 0) {
    /* is public */
    [self debugWithFormat:@"  allowed because no roles are required."];
    goto found;
  }
  
  /* now retrieve the user that is logged in */
  
  if ((user = [self userInContext:_ctx object:_object]) == nil) {
    /* no user, anonymous */
    [self debugWithFormat:@"  got no user (=> auth required)."];
    return [SoAuthRequiredException securityExceptionOnObject:_object
				    withAuthenticator:
				      [self authenticatorInContext:_ctx 
					    object:_object]
				    andManager:self];
  }
  
  [self debugWithFormat:@"  got user: %@)", user];
  
  /* process user */
  
  userRoles = [user rolesForObject:_object inContext:_ctx];
  [self debugWithFormat:@"    user roles: %@", 
        [userRoles componentsJoinedByString:@","]];
  if ([userRoles count] == 0)
    return [self isPrivateExceptionForObject:_object];
    
  /* now check whether the roles subset */
      
  e = [userRoles objectEnumerator];
  while ((role = [e nextObject])) {
    if ([rolesHavingPermission containsObject:role]) {
      /* found role ! */
      break;
    }
  }
    
  /* if no role was found, check whether the user is the owner */
    
  if (role == nil) {
    if ([rolesHavingPermission containsObject:SoRole_Owner]) {
      if ([self isUser:user ownerOfObject:_object inContext:_ctx]) {
        role = SoRole_Owner;
        [self debugWithFormat:@"    user is owner of object."];
      }
      else if ([_object ownerInContext:_ctx] == nil) {
        role = SoRole_Owner;
        [self debugWithFormat:@"    object is not owned, grant access."];
      }
      else {
        role = nil;
        [self debugWithFormat:
                @"    user is not the owner of object (owner=%@).",
              [_object ownerInContext:_ctx]];
      }
    }
  }
    
  /* check whether a role was finally found */
    
  if (role == nil) {
    [self debugWithFormat:@"    found no matching role."];
    
    if ([[user login] isSoAnonymousUserLogin]) {
      [self debugWithFormat:@"still anonymous, requesting login ..."];
      return [SoAuthRequiredException securityExceptionOnObject:_object
                                      withAuthenticator:
                                        [self authenticatorInContext:_ctx
                                              object:_object]
                                      andManager:self];
    }
    else {
      /* 
         Note: AFAIK Zope will present the user a login panel in any
         case. IMHO this is not good in practice (you don't change
         identities very often ;-), and the 403 code has it's value too.
      */
      [self debugWithFormat:@"valid user, denying access ..."];
      return [self isPrivateExceptionForObject:_object];
    }
  }
    
  [self debugWithFormat:@"    found a valid role: '%@'.", role];
  
 found:
  [self debugWithFormat:@"  successfully validated permission '%@'.", _perm];
  [validatedPerms setObject:[NSNull null] forKey:_perm];
  return nil;
}

- (NSException *)validateObject:(id)_object inContext:(id)_ctx {
  /* This methods check how the object itself is protected. */
  NSMutableArray      *validatedObjects;
  SoClassSecurityInfo *sinfo;
  NSString            *perm;
  NSException *e;
  
  if (_object == nil) return nil;
  
  /* some objects are always public */
  if ([_object isPublicInContext:_ctx])
    return nil;
  
  /* check the cache */
  if ((validatedObjects = [(WOContext *)_ctx objectPermissionCache])) {
    if ([validatedObjects indexOfObjectIdenticalTo:_object] != NSNotFound)
      return nil;
  }
  else {
    /* setup cache */
    validatedObjects = [[NSMutableArray alloc] init];
    [(WOContext *)_ctx setObjectPermissionCache:validatedObjects];
    [validatedObjects autorelease];
  }
  
  [self debugWithFormat:@"validate object: %@", _object];
  
  /* find the security info which has object protections */
  sinfo = [self lookupInfoOfClass:[_object soClass] 
		condition:@selector(hasObjectProtections)
		object:nil];
  if (sinfo == nil) {
    [self debugWithFormat:
	    @"found no security info with object protection for object "
	    @"(rejecting access):\n  object: %@\n  class: %@\n  soclass: %@)", 
	    _object, NSStringFromClass([_object class]), [_object soClass]];
    return [self isPrivateExceptionForObject:_object];
  }
  
  if ([sinfo isObjectPublic]) {
    /* object is public ... */
    [self debugWithFormat:@"  object is public."];
    [validatedObjects addObject:_object];
    return nil;
  }
  
  if ([sinfo isObjectPrivate]) {
    /* object is private ... */
    [self debugWithFormat:@"  object is private."];
    return [self isPrivateExceptionForObject:_object];
  }
  
  perm = [sinfo permissionRequiredForObject];
  if ((e = [self validatePermission:perm onObject:_object inContext:_ctx]))
    return e;
  
  [self debugWithFormat:@"  successfully validated object (perm=%@).", perm];
  [validatedObjects addObject:_object];
  return nil;
}

- (NSException *)validateName:(NSString *)_key 
  ofObject:(id)_object
  inContext:(id)_ctx
{
  /* note: this does not check object-value restrictions */
  SoClassSecurityInfo *sinfo;
  NSException *e;
  NSString    *perm;
  
  /* step a: find out permission required for object */
  
  if ((e = [self validateObject:_object inContext:_ctx])) {
    [self debugWithFormat:@"  object did not validate (tried lookup on %@).",
	    _key];
    return e;
  }
  
  /* step b: find out permission required for key */
  
  [self debugWithFormat:@"validate key %@ of object: %@", _key, _object];
  
  /* find the security info which has protections for the key */
  sinfo = [self lookupInfoOfClass:[_object soClass]
		condition:@selector(hasProtectionsForKey:)
		object:_key];
  
  if (sinfo == nil) {
    /* found no security for key, so we take the defaults */
    [self debugWithFormat:@"  found no security info for key (class %@): %@",
	    NSStringFromClass([_object class]), _key];
    
    sinfo = [self lookupInfoOfClass:[_object soClass]
		  condition:@selector(hasDefaultAccessDeclaration)
		  object:nil];
    
    // TODO: search superclasses for one with declared default-access
    if ([[sinfo defaultAccess] isEqualToString:@"allow"]) {
      [self debugWithFormat:@"  default is allow ..."];
      return nil;
    }
    return [self isPrivateKeyException:_key ofObject:_object];
  }
  
  if ([sinfo isKeyPublic:_key])
    return nil;
  
  if ([sinfo isKeyPrivate:_key])
    /* key is private ... */
    return [self isPrivateKeyException:_key ofObject:_object];
  
  perm = [sinfo permissionRequiredForKey:_key];
  if ((e = [self validatePermission:perm onObject:_object inContext:_ctx]))
    return e;
  
  [self debugWithFormat:@"  successfully validated key (%@).", _key];
  return nil;
}

- (NSException *)validateValue:(id)_value
  forName:(NSString *)_key 
  ofObject:(id)_object
  inContext:(id)_ctx
{
  /* this additionally checks object restrictions of the value */
  if (_value) {
    NSException *e;
    
    if ((e = [self validateObject:_value inContext:_ctx])) {
      [self debugWithFormat:@"value (0x%p,%@) of key %@ didn't validate",
	      _value, NSStringFromClass([_value class]), _key];
      return e;
    }
  }
  return [self validateName:_key ofObject:_object inContext:_ctx];
}

@end /* SoSecurityManager */

@implementation SoSecurityManager(Logging)
// Note: this is a category, so that its more difficult to override (of course
//       still not impossible ...

- (NSString *)loggingPrefix {
  return @"[so-security]";
}
- (BOOL)isDebuggingEnabled {
  return debugOn ? YES : NO;
}

@end /* SoSecurityManager(Logging) */


/* public objects */

@implementation NSObject(Pub)
- (BOOL)isPublicInContext:(id)_ctx { return NO; }
@end

@implementation NSArray(Pub)
- (BOOL)isPublicInContext:(id)_ctx { return YES; }
@end

@implementation NSString(Pub)
- (BOOL)isPublicInContext:(id)_ctx { return YES; }
@end

@implementation NSDictionary(Pub)
- (BOOL)isPublicInContext:(id)_ctx { return YES; }
@end

@implementation NSException(Pub)
- (BOOL)isPublicInContext:(id)_ctx { return YES; }
@end

@implementation NSString(SpecialPermissionChecks)

- (BOOL)isSoPublicPermission {
  return [@"<public>" isEqualToString:self];
}
- (BOOL)isSoAnonymousUserLogin {
  return [@"anonymous" isEqualToString:self];
}

@end /* NSString(SpecialPermissionChecks) */
