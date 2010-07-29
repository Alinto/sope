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

#include "SoObjectRequestHandler.h"
#include "SoObject.h"
#include "SoSecurityManager.h"
#include "WOContext+SoObjects.h"
#include <NGObjWeb/WORequest.h>
#include "common.h"

/*
  The implementation for HTTP path traversion, just uses lookupKey
  of SoObject.

  The traverseKey:inContext: basically reflects Zope's __bobo_traverse__()
  method. But __bobo_traverse__ can return a tuple with a set of objects
  to be inserted in the traversion path (what is that good for ?).
  
  Zope has an additional __before_publishing_traverse__() which is called
  before traversion. This is used to change requests and supposed to be
  useful for virtual hosting and special authentication controls. (need a
  specific example why a special method is required for that)
*/

@implementation NSObject(SoObjectLookup)

static int debugTraversal = -1;
static BOOL _isDebugOn(void) {
  if (debugTraversal == -1) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    debugTraversal = [ud boolForKey:@"SoDebugObjectTraversal"] ? 1 : 0;
  }
  return debugTraversal;
}

- (id)traverseKey:(NSString *)_key inContext:(id)_ctx {
  /* this corresponds to Zope's __bobo_traverse__() */
  return [self lookupName:_key inContext:_ctx acquire:NO];
}

/* path traversion */

- (id)handleValidationError:(NSException *)_error 
  duringTraveralOfKey:(NSString *)_key
  inContext:(id)_ctx 
{
  if (_isDebugOn()) {
    [self debugWithFormat:@"traversal validation error for key '%@':", _key];
    [self debugWithFormat:@"  error:  %@", [_error name]];
    [self debugWithFormat:@"  reason: %@", [_error reason]];
  }
  return nil;
}

- (id)traverseKey:(NSString *)_name
  inContext:(id)_ctx
  error:(NSException **)_error
  acquire:(BOOL)_acquire
{
  SoSecurityManager *sm;
  id obj;
  
  if (_isDebugOn()) {
    [self debugWithFormat:@"traverse key '%@' (acquire=%s) ..",
	    _name, _acquire ? "yes" : "no"];
  }
  
  /* check access right */
  
  if ((*_error = [self validateName:_name inContext:_ctx])) {
    /* not allowed ! */
    if (debugTraversal)
      [self debugWithFormat:@"  key '%@' did not validate !", _name];
    return nil;
  }
  
  /* lookup in object (and acquire from strict parents) */
  
  sm = [_ctx soSecurityManager];
  if ((obj = [self traverseKey:_name inContext:_ctx]) != nil) {
    *_error = [sm validateValue:obj
                  forName:_name
                  ofObject:self 
		              inContext:_ctx];
    if (*_error != nil) {
      /* not allowed ! */
      if (debugTraversal)
        [self debugWithFormat:@"  value of key '%@' did not validate !",_name];
      return nil;
    }
    
    if (debugTraversal)
      [self debugWithFormat:@"  key '%@' resolved: %@", _name, obj];
    return obj;
  }
  
  if (_acquire) {
    /* now try to acquire from parents in URL path */
    NSEnumerator *e;
    
    if (debugTraversal) {
      [self debugWithFormat:@"  try to acquire key '%@' from traversal stack",
	      _name];
    }
    
    e = [[_ctx objectTraversalStack] reverseObjectEnumerator];
    while ((obj = [e nextObject])) {
      NSException *e;
      
      if ((e = [obj validateName:_name inContext:_ctx])) {
        /* access restriction */
        *_error = e;
        return nil;
      }
      
      if ((obj = [obj traverseKey:_name inContext:_ctx])) {
        /* found .. */
        e = [sm validateValue:obj forName:_name 
                ofObject:self inContext:_ctx];
        if (e) {
          *_error = e;
          return nil;
        }
        return obj;
      }
    }
  }
  else {
    if (debugTraversal)
      [self debugWithFormat:@"  acquisition disabled."];
  }
  
  /* did not find object ... */
  if (_isDebugOn())
    [self debugWithFormat:@"  lookup of key '%@' failed.", _name];
  return nil;
}

- (id)traversePathArray:(NSArray *)traversalPath
  inContext:(id)_ctx
  error:(NSException **)_error
  acquire:(BOOL)_acquire
{
  // TODO: We might want to have an addition method to traverse a path without
  //       modifying the context (for internal lookups).
  //       Currently most code uses -lookupName:inContext:acquire: directly,
  //       which doesn't check permissions.
  // Note: You can also use SoSubContext to accomplish that, but this is not
  //       very convenient.
  register BOOL  doDebug          = _isDebugOn();
  static   Class NSExceptionClass = Nil;
  WORequest *rq;
  BOOL      isCreateIfMissingMethod = NO;
  BOOL      isCreateMethod = NO;
  unsigned  i, count;
  id        root, currentObject, clientObject;

  if (NSExceptionClass == Nil) {
    NSExceptionClass = [NSException class];
  }

  if (doDebug) {
    [self logWithFormat:@"traverse%s: %@",
                        _acquire ? "(acquire)" : "",
                        [traversalPath componentsJoinedByString:@" => "]];
  }
  
  /* reset error */
  if (_error != NULL) *_error = nil;
  
  if ((rq = [(id <WOPageGenerationContext>)_ctx request]) != nil) {
    /* isn't that somewhat hackish, directly accessing the HTTP method? */
    NSString *m;
    
    if ((m = [rq method]) != nil) {
      if ([m isEqualToString:@"PUT"])
        isCreateIfMissingMethod = YES;
      else if ([m isEqualToString:@"PROPPATCH"])
        isCreateIfMissingMethod = YES;
      else if ([m isEqualToString:@"MKCOL"]
	       || [m isEqualToString:@"MKCALENDAR"])
        /* this one is strictly creating */
        isCreateMethod = YES;
        // TODO: the following are only create-if-missing on the target!
        else if ([m isEqualToString:@"MOVE"] ||
	               [m isEqualToString:@"COPY"])
        {
          isCreateIfMissingMethod = 
            [[(WOContext *)_ctx objectForKey:@"isDestinationPathLookup"] 
                                boolValue];
      }
    }
  }
  
  root          = self;
  currentObject = self;
  clientObject  = nil;
  [_ctx addObjectToTraversalStack:currentObject];
  
  /* do traversion */
  
  for (i = 0, count = [traversalPath count]; i < count; i++) {
    NSException *error = nil;
    NSString    *name;
    id          nextObject = nil;
    
    /* get next name */
    name = [traversalPath objectAtIndex:i];
    if (doDebug) [self logWithFormat:@"  do traverse name: '%@'", name];
    if ([name length] == 0)
      /* empty name ?, ignore */
      continue;
    
    if ([name isEqualToString:@"/"])
      /* ignore root */
      continue;
    
    if (i == (count - 1)) {
      /* 
        is last object, special handling for MKCOL, with MKCOL queries
        the last part of the URI is a collection to be created and not
        yet in the object tree ...
      */
      // TODO: should check whether the resource exists, but access is denied
      if (isCreateMethod) {
        [_ctx setPathInfo:name];
        if (doDebug)
          [self logWithFormat:@"create-method: PATH_INFO: %@", name];
        break;
      }
    }
    
    /* lookup next object */
    
    nextObject = [currentObject traverseKey:name inContext:_ctx error:&error
				acquire:_acquire];
    if (nextObject == nil) {
      if (doDebug) {
        [self logWithFormat:@"  traverse miss: name=%@%s: i=%i,count=%i", 
	                          name, _acquire ? ", acquire" : "", i, count];
      }
      if (i == (count - 1)) {
        /* 
           Is last object, special handling for PUT, with PUT queries
           the last part of the URI is allowed to be missing. If this
           is the case, the PUT is actually a "creation" operation.
           The same goes for PROPPATCH.
        */
        // should check whether the resource exists, but access is denied
        if (isCreateIfMissingMethod) {
          [_ctx setPathInfo:name];
          if (doDebug)
            [self logWithFormat:@"create-if-missing: PATH_INFO: %@", name];
          break;
        }
        if (doDebug) [self logWithFormat:@"    miss is last object."];
      }
      
      if (error != nil) {
        if (doDebug) [self logWithFormat:@"    handle miss error: %@", error];
        currentObject = [currentObject handleValidationError:error 
				                               duringTraveralOfKey:name
				                               inContext:_ctx];
        if (currentObject == nil) {
          if (_error) 
            *_error = error;
          else
            currentObject = error;
          break;
        }
        if (doDebug) [self logWithFormat:@"    miss error continues ..."];
      }
      if (doDebug) [self logWithFormat:@"    got no error for miss."];
    }
    
    /* check whether the current object is executable */
    /*
      TODO: why did I add this check?, we cannot break on the first 
            executable, otherwise we cannot use methods on methods!
      So:   but we can break if the nextObject could not be found, so
            that we can generate a proper pathinfo!
    */
    
    if (nextObject == nil && [currentObject isCallable]) {
      NSArray *piArray;
      NSRange r;
      
      r.location = i;
      r.length   = (count - i);
      piArray = [traversalPath subarrayWithRange:r];
      if (doDebug) [self logWithFormat:@"PATH_INFO: %@", piArray];
      // TODO: what about escaping?
      [_ctx setPathInfo:[piArray componentsJoinedByString:@"/"]];
      break;
    }
    else if (nextObject == nil && doDebug) {
      [self logWithFormat:
	      @"Note: next object is nil, but currentObject "
	      @"is not callable: %@",
	      currentObject];
    }

    /* abort traversal if an exception was returned */
    if ([currentObject isKindOfClass:NSExceptionClass])
      break;

    /* found an object */
    currentObject = nextObject;
    [_ctx addObjectToTraversalStack:currentObject];
  }
  
  /* fill clientObject */
  
  if ([currentObject isCallable]) {
    unsigned count;
    NSArray  *tstack;
    
    tstack = [_ctx objectTraversalStack];
    count  = [tstack count];
    if (count > 2)
      clientObject = [tstack objectAtIndex:(count - 2)];
  }
  else
    clientObject = currentObject;
  
  if (clientObject != nil) {
    if (doDebug)
      [self logWithFormat:@"set clientObject: %@", clientObject];
    [_ctx setClientObject:clientObject];
  }
  
  /* return result */
  return currentObject;
}

- (id)traversePathArray:(NSArray *)_tp acquire:(BOOL)_acquire {
  NSAutoreleasePool *pool;
  NSException *error = nil;
  WOContext   *context;
  id          result;
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    // TODO: shouldn't we use a "subcontext"?
    context = [WOContext context];
  
    result = [self traversePathArray:_tp
                   inContext:context
                   error:&error
		               acquire:_acquire];
    result = error ? [error retain] : [result retain];
  }
  [pool release];

  return [result autorelease];
}

- (id)traversePath:(id)_tp acquire:(BOOL)_acquire {
  if (![_tp isNotNull]) return nil;
  
  if ([_tp isKindOfClass:[NSArray class]])
    return [self traversePathArray:_tp acquire:_acquire];
  
  if ([_tp isKindOfClass:[NSString class]])
    return [self traversePathArray:[_tp pathComponents] acquire:_acquire];
  
  if ([_tp respondsToSelector:@selector(objectEnumerator)]) {
    _tp = [[[NSArray alloc] initWithObjectsFromEnumerator:_tp] autorelease];
    return [self traversePathArray:_tp acquire:_acquire];
  }
  
  [self errorWithFormat:
          @"(%s): don't know how to turn path object %@ into an array",
          __PRETTY_FUNCTION__, _tp];
  return nil;
}

@end /* NSObject(SoObjectLookup) */
