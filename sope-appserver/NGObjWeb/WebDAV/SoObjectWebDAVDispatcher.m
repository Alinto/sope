/*
  Copyright (C) 2002-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#include "SoObjectWebDAVDispatcher.h"
#include "SoObject.h"
#include "SoObject+SoDAV.h"
#include "SoSecurityManager.h"
#include "SoPermissions.h"
#include "SoObjectRequestHandler.h"
#include "SoSubscriptionManager.h"
#include "SaxDAVHandler.h"
#include "SoDAVLockManager.h"
#include "EOFetchSpecification+SoDAV.h"
#include "WOContext+SoObjects.h"
#include "NSException+HTTP.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WEClientCapabilities.h>
#include <SaxObjC/SaxObjC.h>
#include <SaxObjC/XMLNamespaces.h>
#include <DOM/DOMDocument.h>
#include <NGExtensions/NSString+Ext.h>
#include "common.h"

@interface WORequest(HackURI)
- (void)_hackSetURI:(NSString *)_vuri;
@end

@implementation SoObjectWebDAVDispatcher

static int      debugOn = -1;
static BOOL     debugBulkTarget = NO;
static BOOL     disableCrossHostMoveCheck = NO;
static NSNumber *yesNum = nil;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;
  
  debugOn = [ud boolForKey:@"SoObjectDAVDispatcherDebugEnabled"] ? 1 : 0;
  if (debugOn) NSLog(@"Note: WebDAV dispatcher debugging is enabled.");
  if (yesNum == nil) yesNum = [[NSNumber numberWithBool:YES] retain];
  
  disableCrossHostMoveCheck =
    [ud boolForKey:@"SoWebDAVDisableCrossHostMoveCheck"];
}

// THREAD
static id<NSObject,SaxXMLReader> xmlParser = nil;
static SaxDAVHandler             *davsax   = nil;
static NSTimeZone                *gmt      = nil;

- (id)initWithObject:(id)_object {
  if ((self = [super init])) {
    self->object = [_object retain];
  }
  return self;
}
- (void)dealloc {
  [self->object release];
  [super dealloc];
}

/* parser */

- (void)lockParser:(id)_sax {
  [_sax reset];
  [xmlParser setContentHandler:_sax];
  [xmlParser setErrorHandler:_sax];
}
- (void)unlockParser:(id)_sax {
  [xmlParser setContentHandler:nil];
  [xmlParser setErrorHandler:nil];
  [_sax reset];
}

/* common stuff */

- (NSException *)httpException:(int)_status reason:(NSString *)_reason {
  NSDictionary *ui;

  ui = [NSDictionary dictionaryWithObjectsAndKeys:
		       self, @"dispatcher",
		       [NSNumber numberWithInt:_status], @"http-status",
		     nil];
  return [NSException exceptionWithName:
			[NSString stringWithFormat:@"HTTP%i", _status]
		      reason:_reason
		      userInfo:ui];
}

- (NSString *)baseURLForContext:(WOContext *)_ctx {
  extern NSString *SoObjectRootURLInContext
    (WOContext *_ctx, id logobj, BOOL withAppPart);
  NSString *rootURL;
  
  rootURL = SoObjectRootURLInContext(_ctx, self, NO);
  return [rootURL stringByAppendingString:[[_ctx request] uri]];
}

- (id)primaryCallWebDAVMethod:(NSString *)_name inContext:(WOContext *)_ctx {
  id method;
  
  method = [self->object lookupName:_name inContext:_ctx acquire:NO];
  if (method == nil) {
    return [self httpException:501 /* Not Implemented */
		 reason:@"target object does not support requested operation"];
  }
  if ([method isKindOfClass:[NSException class]]) {
    [self logWithFormat:@"could not lookup method, got exception: %@", method];
    return method;
  }
  
  [self debugWithFormat:@"  %@ method: %@", _name, method];
  return [method callOnObject:self->object inContext:_ctx];
}

/* core HTTP methods */

- (id)_callObjectMethod:(NSString *)_method inContext:(WOContext *)_ctx {
  /* returns 'nil' if the object had no such method */
  NSException *e;
  id methodObject;
  id result;
  
  methodObject =
    [self->object lookupName:_method inContext:_ctx acquire:NO];
  if (![methodObject isNotNull])
    return nil;
  if ([methodObject isKindOfClass:[NSException class]]) {
    if ([(NSException *)methodObject httpStatus] == 404 /* Not Found */) {
      /* not found */
      return nil;
    }
    return methodObject; /* the exception */
  }
  if ((e = [self->object validateName:_method inContext:_ctx]) != nil)
    return e;
  
  if ([methodObject respondsToSelector:
  		      @selector(takeValuesFromRequest:inContext:)])
    [methodObject takeValuesFromRequest:[_ctx request] inContext:_ctx];
  
  result = [methodObject callOnObject:self->object inContext:_ctx];
  return (result != nil) ? result : (id)[NSNull null];
}

- (id)doGET:(WOContext *)_ctx {
  NSException *e;
  id methodObject;
  
  methodObject = [self->object lookupName:@"GET" inContext:_ctx acquire:NO];
  if (methodObject == nil)
    methodObject = [self->object lookupDefaultMethod];
  else {
    if ((e = [self->object validateName:@"GET" inContext:_ctx]) != nil)
      return e;
  }
  
  if (methodObject == nil)
    return self->object;
  if ([methodObject isKindOfClass:[NSException class]])
    return methodObject;
  
  if ([methodObject respondsToSelector:
  		      @selector(takeValuesFromRequest:inContext:)])
    [methodObject takeValuesFromRequest:[_ctx request] inContext:_ctx];
  
  return [methodObject callOnObject:self->object inContext:_ctx];
}

- (id)doPUT:(WOContext *)_ctx {
  SoSecurityManager *sm;
  NSException       *e;
  NSString          *pathInfo;
  
  pathInfo = [_ctx pathInfo];
  [self debugWithFormat:@"doPUT (pathinfo='%@')", pathInfo];
  
  /* check permissions */
  
  sm = [_ctx soSecurityManager];
  e  = [sm validatePermission:
	     [pathInfo isNotEmpty]
	     ? SoPerm_AddDocumentsImagesAndFiles
	     : SoPerm_ChangeImagesAndFiles
	   onObject:self->object
	   inContext:_ctx];
  if (e != nil) return e;
  
  if ((e = [self->object validateName:@"PUT" inContext:_ctx]))
    return e;
  
  /* perform */
  
  if ([pathInfo isNotEmpty]) {
    /* check whether all the parent collections are available */
    // TODO: we might also want to check for a 'create' permission
    if ([pathInfo rangeOfString:@"/"].length > 0) {
      return [self httpException:409 /* Conflict */
		   reason:
		     @"invalid WebDAV PUT request, first create all "
		     @"parent collections !"];
    }
  }

  return [self primaryCallWebDAVMethod:@"PUT" inContext:_ctx];
}

- (id)doPOST:(WOContext *)_ctx {
  NSException *e;
  
  if ((e = [self->object validateName:@"POST" inContext:_ctx]))
    return e;
  
  return [self primaryCallWebDAVMethod:@"POST" inContext:_ctx];
}

- (id)doDELETE:(WOContext *)_ctx {
  SoSecurityManager *sm;
  NSException       *e;
  
  /* check permissions */
  
  sm = [_ctx soSecurityManager];
  e  = [sm validatePermission:SoPerm_DeleteObjects
	   onObject:self->object
	   inContext:_ctx];
  if (e != nil) 
    return e;
  if ((e = [self->object validateName:@"DELETE" inContext:_ctx]) != nil)
    return e;
  
  // TODO: IE WebFolders sent a "Destroy" header together with the
  //       DELETE request, eg:
  //       "Destroy: NoUndelete"
  
  return [self primaryCallWebDAVMethod:@"DELETE" inContext:_ctx];
}

- (id)doOPTIONS:(WOContext *)_ctx {
  WOResponse *response;
  NSArray    *tmp;
  id         result;
  
  /* this checks whether the object provides a specific OPTIONS method */
  if ((result = [self _callObjectMethod:@"OPTIONS" inContext:_ctx]) != nil)
    return result;
  
  response = [_ctx response];
  [response setStatus:200 /* OK */];
  
  if ((tmp = [self->object davAllowedMethodsInContext:_ctx]) != nil) 
    [response setHeader:[tmp componentsJoinedByString:@", "] forKey:@"allow"];
  
  if ([[[_ctx request] clientCapabilities] isWebFolder]) {
    /*
       As described over here:
         http://teyc.editthispage.com/2005/06/02
       
       This page also says that: "MS-Auth-Via header is not required to work
       with Web Folders".
    */
    [response setHeader:[tmp componentsJoinedByString:@", "] forKey:@"public"];
  }
  
  if ((tmp = [self->object davComplianceClassesInContext:_ctx]) != nil) 
    [response setHeader:[tmp componentsJoinedByString:@", "] forKey:@"dav"];
  
  return response;
}

- (id)doHEAD:(WOContext *)_ctx {
  return [self doGET:_ctx];
}

/* core WebDAV methods */

- (id)doMKCOL:(WOContext *)_ctx {
  SoSecurityManager *sm;
  NSException       *e;
  NSString          *pathInfo;
  
  pathInfo = [_ctx pathInfo];
  if (![pathInfo isNotEmpty]) {
    /* MKCOL target already exists ... */
    WOResponse *r;

    [self logWithFormat:@"MKCOL target exists !"];
    
    r = [_ctx response];
    [r setStatus:405 /* method not allowed */];
    [r appendContentString:@"collection already exists !"];
    return r;
  }
  
  /* check permissions */
  
  sm = [_ctx soSecurityManager];
  e  = [sm validatePermission:SoPerm_AddFolders 
	   onObject:self->object
	   inContext:_ctx];
  if (e != nil) return e;

  /* check whether all the parent collections are available */
  if ([pathInfo rangeOfString:@"/"].length > 0) {
    return [self httpException:409 /* Conflict */
                 reason:
                   @"invalid WebDAV MKCOL request, first create all "
		   @"parent collections !"];
  }
  
  /* check whether the object supports creating collections */

  if (![self->object respondsToSelector:
              @selector(davCreateCollection:inContext:)]) {
    /* Note: this should never happen, as this is implemented on NSObject */
    
    [self logWithFormat:@"MKCOL: object '%@' path-info '%@'", 
            self->object, pathInfo];
    return [self httpException:405 /* not allowed */
                 reason:
                   @"this object cannot create a new collection with MKCOL"];
  }
  
  if ((e = [self->object davCreateCollection:pathInfo inContext:_ctx])) {
    [self debugWithFormat:@"creation of collection '%@' failed: %@",
            pathInfo, e];
    return e;
  }
  
  [self debugWithFormat:@"created collection."];
  return [NSNumber numberWithBool:YES];
}

- (NSString *)scopeForDepth:(NSString *)_depth inContext:(WOContext *)_ctx {
  NSString *scope;
  
  if ([_depth hasPrefix:@"0"])
    scope = @"self";
  else if ([_depth hasPrefix:@"1,noroot"])
    scope = @"flat";
  else if ([_depth hasPrefix:@"1"]) {
    NSString *ua;
    
    scope = @"flat+self";
    
    /* some special handling for IE ... */
    if ((ua = [[[_ctx request] clientCapabilities] userAgentType])) {
      if ([ua isEqualToString:@"Evolution"])
	scope = @"flat";
      else if ( [ua isEqualToString:@"WebFolder"])
	scope = @"flat";
    }
  }
  else if ([_depth hasPrefix:@"infinity"])
    scope = @"deep";
  else
    scope = @"deep";

  return scope;
}

- (NSMutableDictionary *)hintsWithScope:(NSString *)_scope
  propNames:(NSArray *)_propNames
  findAll:(BOOL)_findAll
  namesOnly:(BOOL)_namesOnly
{
  NSMutableDictionary *hints;
  
  hints = [NSMutableDictionary dictionaryWithCapacity:4];

  if (_scope)
    [hints setObject:_scope forKey:@"scope"];
  if (_propNames)
    [hints setObject:_propNames forKey:@"attributes"];
  // else if (_findAll) ; /* empty attributes */
  
  if (_namesOnly)
    [hints setObject:[NSNumber numberWithBool:YES] forKey:@"namesOnly"];
  return hints;
}

- (id)doPROPFIND:(WOContext *)_ctx {
  SoSecurityManager    *sm;
  NSException          *e;
  EOFetchSpecification *fs;
  WORequest *rq;
  NSString  *uri;
  NSString  *depth; /* 0, 1, 1,noroot or infinity */
  NSArray   *propNames, *rtargets;
  BOOL      findAll;
  BOOL      findNames;
  id        result;
  NSRange   r;
  
  /* check permissions */
  
  sm = [_ctx soSecurityManager];
  e  = [sm validatePermission:SoPerm_AccessContentsInformation 
	   onObject:self->object
	   inContext:_ctx];
  if (e != nil) return e;
  
  /* perform search */
  
  if (![self->object respondsToSelector:
              @selector(performWebDAVQuery:inContext:)]) {
    return [self httpException:405 /* not allowed */
		 reason:@"this object cannot not execute a PROPFIND query"];
  }
  
  rq    = [_ctx request];
  depth = [rq headerForKey:@"depth"];
  uri   = [rq uri];
  
  if (![depth isNotEmpty]) depth = @"infinity";
  
  if ([[rq content] isNotEmpty]) {
    [self lockParser:davsax];
    {
      [xmlParser parseFromSource:[rq content]];
      propNames = [[davsax propFindQueriedNames] copy];
      findAll   = [davsax  propFindAllProperties];
      findNames = [davsax  propFindPropertyNames];
    }
    [self unlockParser:davsax];
    propNames = [propNames autorelease];
  }
  else {
    /*
      8.1 PROPFIND
      "A client may choose not to submit a request body.  An empty PROPFIND 
       request body MUST be treated as a request for the names and values of
       all properties."
      TODO: means, an empty request is to be handled as <allprop/>?
    */
    propNames = nil;
    findAll   = YES;
    findNames = NO;
  }
  
  if (findAll) {
    /* 
       Hack up request to include 'brief'. This elimates the reporting of 404
       properties in the renderer. Its necessary because some objects may not
       properly report their default properties (they sometimes report missing
       properties).
    */
    [[_ctx request] setHeader:@"true" forKey:@"brief"];
  }
  
  /* check query all properties */
  
  if (propNames == nil)
    propNames = [self->object defaultWebDAVPropertyNamesInContext:_ctx];
  
  /* check for a ZideStore ranges query (a BPROPFIND "emulation") */
  
  if (debugOn) [self logWithFormat:@"request uri: %@", uri];
  r = [uri rangeOfString:@"_range"];
  if (r.length > 0) { /* ZideStore range query */
    NSString *s;
    NSArray  *ids;
    
    if (debugOn)
      [self logWithFormat:@"  detected a ZideStore range query: '%@'", uri];
    
    s = [uri substringFromIndex:(r.location + r.length)];
    if ([s hasSuffix:@"/"]) s = [s substringToIndex:([s length] - 1)];
    if ([s hasPrefix:@"_"]) s = [s substringFromIndex:1];
    
    ids = [s isNotEmpty]
      ? [s componentsSeparatedByString:@"_"]
      : (NSArray *)[NSArray array];
    
    // TODO: should use -stringByUnescapingURL on IDs (not required for ints)
    
    rtargets = ids;
    if (debugOn) 
      [self logWithFormat:@"  IDs: %@", [ids componentsJoinedByString:@","]];
    
    /* patch URI, could have side-effects ? */
    [self logWithFormat:
            @"NOTE: hacked URI, _range_ part won't be visible in the HTTP "
            @"access log:\n%@", uri];
    [rq _hackSetURI:[uri substringToIndex:r.location]];
  }
  else
    rtargets = nil;
  
  /* build the fetch-spec */
  {
    NSMutableDictionary *hints;
    
    hints = [self hintsWithScope:[self scopeForDepth:depth inContext:_ctx]
		  propNames:propNames findAll:findAll namesOnly:findNames];
    if (rtargets != nil) /* range-query keys */
      [hints setObject:rtargets forKey:@"bulkTargetKeys"];
    
    fs = [EOFetchSpecification alloc];
    fs = [fs initWithEntityName:[self baseURLForContext:_ctx]
	     qualifier:nil
	     sortOrderings:nil
	     usesDistinct:NO isDeep:NO hints:hints];
    fs = [fs autorelease];

    if (debugOn) [self logWithFormat:@"  propfind fetchspec: %@", fs];
  }
  
  [_ctx setObject:fs forKey:@"DAVFetchSpecification"];
  
  /* translate fetchspec if necessary */
  {
    NSDictionary *map;
    
    if ((map = [self->object davAttributeMapInContext:_ctx]) != nil) {
      [_ctx setObject:map forKey:@"DAVPropertyMap"];
      fs = [fs fetchSpecificationByApplyingKeyMap:map];
      [_ctx setObject:fs  forKey:@"DAVMappedFetchSpecification"];
      if (debugOn) [self logWithFormat:@"    remapped fetchspec: %@", fs];
    }
  }
  
  /* perform */
  
  if ((result = [self->object performWebDAVQuery:fs inContext:_ctx]) == nil) {
    return [self httpException:500 /* Server Error */
		 reason:@"could not perform query (object returned nil)"];
  }
  
  if (debugOn) [self logWithFormat:@"  propfind result: %@", result];
  
  return result;
}

- (BOOL)allowDeletePropertiesOnNewObjectInContext:(WOContext *)_ctx {
  NSString *ua;
  
  ua = [[_ctx request] headerForKey:@"user-agent"];
  if ([ua hasPrefix:@"Evolution"]) {
    /* if Evo creates tasks, it tries to delete some props at the same time */
    return YES;
  }
  if ([ua hasPrefix:@"CFNetwork"]) {
    /* iSync trying to create a record ... */
    return YES;
  }
  
  [self logWithFormat:@"do not allow delete properties on new object for: %@",
	  ua];
  return NO;
}

- (id)doPROPPATCH:(WOContext *)_ctx {
  SoSecurityManager *sm;
  NSException       *e;
  NSMutableArray    *resProps;
  NSArray           *delProps;
  NSDictionary      *setProps;
  NSString          *pathInfo;
  
  pathInfo = [_ctx pathInfo];
  
  /* check permissions */
  
  sm = [_ctx soSecurityManager];
  e  = [sm validatePermission:[pathInfo isNotEmpty]
	     ? SoPerm_AddDocumentsImagesAndFiles
	     : SoPerm_ChangeImagesAndFiles
	   onObject:self->object
	   inContext:_ctx];
  if (e != nil) return e;
  
  /* check for conflicts */

  if ([pathInfo isNotEmpty]) {
    /* check whether all the parent collections are available */
    if ([pathInfo rangeOfString:@"/"].length > 0) {
      return [self httpException:409 /* Conflict */
		   reason:
		     @"invalid WebDAV PROPPATCH request, first create all "
		     @"parent collections !"];
    }
  }
  
  /* check whether the object supports patching */

  if ([pathInfo isNotEmpty]) {
    if (![self->object respondsToSelector:
		@selector(davCreateObject:properties:inContext:)]) {
      [self debugWithFormat:@"cannot create new object via DAV on %@",
	      self->object];
      return [self httpException:405 /* not allowed */
		   reason:
		     @"this object cannot create a new object with PROPPATCH"];
    }
  }
  else {
    if (![self->object respondsToSelector:
	    @selector(davSetProperties:removePropertiesNamed:inContext:)]) {
      [self debugWithFormat:@"cannot change object props via DAV on %@",
	      self->object];
      return [self httpException:405 /* not allowed */
		   reason:@"this object cannot PROPPATCH the attributes"];
    }
  }
  
  /* parse request */
  
  [self lockParser:davsax];
  {
    [xmlParser parseFromSource:[[_ctx request] content]];
    delProps = [[davsax propPatchPropertyNamesToRemove] copy];
    setProps = [[davsax propPatchValues] copy];
  }
  [self unlockParser:davsax];
  delProps = [delProps autorelease];
  setProps = [setProps autorelease];
  
  if (delProps == nil && setProps == nil) {
    [self warnWithFormat:@"got no properties in PROPPATCH !"];
    return [self httpException:400 /* bad request */
		 reason:@"got no properties in PROPPATCH !"];
  }
  
  if ([pathInfo isNotEmpty]) {
    /* a create object cannot delete props ... */
    if ([delProps isNotEmpty]) {
      if (![self allowDeletePropertiesOnNewObjectInContext:_ctx]) {
        [self logWithFormat:@"shall delete props in new object '%@': %@",
	        pathInfo, delProps];
        return [self httpException:400 /* bad request */
		     reason:@"cannot delete properties of a new object"];
      }
      [self debugWithFormat:@"deleting properties on a new object: %@ ...",
	      delProps];
    }
  }
  
  resProps = [NSMutableArray arrayWithCapacity:16];
  if (delProps) [resProps addObjectsFromArray:delProps];
  if (setProps) [resProps addObjectsFromArray:[setProps allKeys]];
  
  /* map attributes */
  {
    NSDictionary *map;
    
    if ((map = [self->object davAttributeMapInContext:_ctx])) {
      unsigned count;
      
      [_ctx setObject:map forKey:@"DAVPropertyMap"];
      
      if ((count = [delProps count]) > 0) {
	NSMutableArray *mappedDelProps;
	unsigned i;
	
	mappedDelProps = [NSMutableArray arrayWithCapacity:(count + 1)];
	for (i = 0; i < count; i++) {
	  NSString *k, *tk;
	  
	  k  = [delProps objectAtIndex:i];
	  tk = [map valueForKey:k];
	  
	  [mappedDelProps addObject:(tk ? tk : k)];
	}
	delProps = mappedDelProps;
      }
      if ((count = [setProps count]) > 0) {
	NSMutableDictionary *mappedSetProps;
	NSEnumerator *keys;
	NSString *k;
	
	mappedSetProps = [NSMutableDictionary dictionaryWithCapacity:count];
	keys = [setProps keyEnumerator];
	while ((k = [keys nextObject])) {
	  NSString *tk;
	  
	  tk = [map valueForKey:k];
	  [mappedSetProps setObject:[setProps objectForKey:k]
			  forKey:(tk ? tk : k)];
	}
	setProps = mappedSetProps;
      }
    }
  }
  
  if (debugOn) {
    [self debugWithFormat:@"PROPPATCH '%@': delete=%@, set=%@",
	    pathInfo, delProps, setProps];
  }
  
  if (![pathInfo isNotEmpty]) {
    /* edit an object */
    NSException *e;
    
    e = [self->object 
	     davSetProperties:setProps
	     removePropertiesNamed:delProps
	     inContext:_ctx];
    if (e != nil) return e;
  }
  else {
    /* create an object */
    id newChild;
    
    newChild = [self->object 
		    davCreateObject:pathInfo
		    properties:setProps
		    inContext:_ctx];
    if ([newChild isKindOfClass:[NSException class]]) 
      return newChild;
    
    [self debugWithFormat:@"created: %@", newChild];
  }
  
  /* generate response */
  return resProps;
}

- (id)doLOCK:(WOContext *)_ctx {
  SoSecurityManager *sm;
  NSException       *e;
  SoDAVLockManager *lockManager;
  WORequest  *rq;
  WOResponse *r;
  NSString   *ifValue, *lockDepth;
  id token;
  
  /* check permissions */
  
  sm = [_ctx soSecurityManager];
  e  = [sm validatePermission:SoPerm_WebDAVLockItems
	   onObject:self->object
	   inContext:_ctx];
  if (e != nil) return e;
  
  /* check lock manager */
  
  if ((lockManager = [self->object davLockManagerInContext:_ctx]) == nil) {
    return [self httpException:405 /* method not allowed */
		 reason:@"target object does not support locking !"];
  }
  
  rq = [_ctx request];
  r  = [_ctx response];
  
  lockDepth = [rq headerForKey:@"depth"];
  ifValue   = [rq headerForKey:@"if"];
  
  if (lockDepth != nil && ![lockDepth isEqualToString:@"0"]) {
    [self warnWithFormat:@"'depth' locking not supported yet (depth=%@)!", 
            lockDepth];
  }
  if (ifValue != nil) {
    [self warnWithFormat:@"'if' locking not supported yet, if: '%@'", ifValue];
  }
  
  /*
    TODO: parse lockinfo:
      <?xml version="1.0" encoding="UTF-8" ?>
      <lockinfo xmlns="DAV:">
        <locktype><write/></locktype>
        <lockscope><exclusive/></lockscope>
        <owner>helge</owner>
      </lockinfo>
    
    Currently we assume exclusive/write ... (also see SoWebDAVRenderer)
  */
  
  /* Sample timeout: Second-180 */
  
  token = [lockManager lockURI:[rq uri]
		       timeout:[rq headerForKey:@"timeout"]
		       scope:@"exclusive" // TODO
		       type:@"write"      // TODO
		       owner:nil];        // TODO
  if (token == nil) {
    /* already locked */
    return [self httpException:423 /* locked */
		 reason:@"object locked, lock manager did not provide token."];
  }
  
  [self debugWithFormat:@"locked: %@ (token %@)", [[_ctx request] uri], token];
  return token;
}

- (id)doUNLOCK:(WOContext *)_ctx {
  SoSecurityManager *sm;
  NSException       *e;
  SoDAVLockManager  *lockManager;
  NSString *token;
  
  /* check permissions */
  
  sm = [_ctx soSecurityManager];
  e  = [sm validatePermission:SoPerm_WebDAVUnlockItems
	   onObject:self->object
	   inContext:_ctx];
  if (e != nil) return e;
  
  /* check lock manager */
  
  if ((lockManager = [self->object davLockManagerInContext:_ctx]) == nil) {
    return [self httpException:405 /* method not allowed */
		 reason:@"target object does not support locking."];
  }
  
  token = [[_ctx request] headerForKey:@"lock-token"];
  
  [lockManager unlockURI:[[_ctx request] uri] token:token];
  
  [self debugWithFormat:
	  @"unlocked: %@ (token %@)", [[_ctx request] uri], token];
  
  [[_ctx response] setStatus:204 /* fake ok */];
  return [_ctx response];
}

- (NSException *)extractDestinationPath:(NSArray **)path_
  fromContext:(WOContext *)_ctx
{
  NSString *absDestURL;
  NSURL    *destURL, *srvURL;

  if (path_) *path_ = nil;
  
  /* TODO: check proper permission prior attempting a move */
  
  absDestURL = [[_ctx request] headerForKey:@"destination"];
  if (![absDestURL isNotEmpty]) {
    return [self httpException:400 /* Bad Request */
		 reason:
		   @"the destination WebDAV header was missing "
		   @"for the MOVE/COPY operation"];
  }
  if ((destURL = [NSURL URLWithString:absDestURL]) == nil) {
    [self logWithFormat:@"MOVE: got invalid destination URL: '%@'", 
	    absDestURL];
    return [self httpException:400 /* Bad Request */
		 reason:@"the MOVE/COPY destination is not a valid URL!"];
  }
  
  srvURL = [_ctx serverURL];
  
  [self debugWithFormat:@"move/copy:\n  to:    %@ (%@)\n  server: %@)", 
	  [destURL absoluteString], absDestURL,
	  [srvURL absoluteString]];
  
  /* check whether URL is on the same server ... */
  if (![[srvURL host] isEqualToString:[destURL host]]) {
    //  || !(([srvURL port] == [destURL port])
    //       || [[srvURL port] isEqual:[destURL port]])) {
    /* 
       The WebDAV spec is not really clear on what we should return in this
       case? Let me know if anybody has a suggestion ...

       Note: This is easy to confuse if you don't use the Apache server name
             to access Apache (eg just the IP). Which is why we allow to
	     disable this check.
    */
    [self logWithFormat:@"tried to do a cross server move (%@ vs %@)",
	    [srvURL absoluteString], [destURL absoluteString]];
    if (!disableCrossHostMoveCheck) {
      return [self httpException:403 /* Forbidden */
		   reason:@"MOVE destination is on a different host."];
    }
  }
  
  if (path_ != NULL) {
    NSMutableArray *ma;
    unsigned i;
    
    /* TODO: hack hack hack */
    ma = [[[destURL path] componentsSeparatedByString:@"/"] mutableCopy];
    if ([ma isNotEmpty]) // leading slash ("")
      [ma removeObjectAtIndex:0];
    if ([ma isNotEmpty]) // the appname (eg zidestore)
      [ma removeObjectAtIndex:0];
    if ([ma isNotEmpty]) // the request handler key (eg so)
      [ma removeObjectAtIndex:0];
    
    /* unescape path components */
    for (i = 0; i < [ma count]; i++) {
      NSString *s, *ns;
      
      s = [ma objectAtIndex:i];
      ns = [s stringByUnescapingURL];
      if (ns != s)
        [ma replaceObjectAtIndex:i withObject:ns];
    }
    
    *path_ = [ma copy];
    [ma release];
  }
  return nil;
}
- (NSException *)lookupDestinationObject:(id *)target_ 
  andNewName:(NSString **)name_
  inContext:(WOContext *)_ctx
{
  NSException *error;
  NSArray     *targetPath;
  id          root;
  
  if ((error = [self extractDestinationPath:&targetPath fromContext:_ctx]))
    return error;

  if ((root = [_ctx application]) == nil)
    root = [WOApplication application];
  if (root == nil) {
    return [self httpException:500 /* internal server error */
		 reason:@"did not find SOPE root object"];
  }
  
  /* TODO: we should probably use a subcontext?! */
  [_ctx setObject:yesNum forKey:@"isDestinationPathLookup"];

  /* We check if the destination collection exist */
  *target_ = [root traversePathArray: [targetPath subarrayWithRange: NSMakeRange(0, [targetPath count]-1)]
		   inContext:_ctx
		   error:&error
		   acquire:NO];
  if ([*target_ isKindOfClass:[NSException class]])
    error = *target_;
  if (error != nil) {
    [self logWithFormat:@"could not resolve destination object (%@): %@",
	    [targetPath componentsJoinedByString:@" => "],
	    error];
    return error;
  }
  
  if (name_ != NULL) *name_ = [[[_ctx pathInfo] copy] autorelease];
  
  if (*target_ == nil) {
    [self debugWithFormat:@"MOVE/COPY destination could not be found."];
    return [self httpException:404 /* Not Found */
		 reason:@"did not find target object"];
  }
  
  [self debugWithFormat:@"SOURCE: %@", self->object];
  [self debugWithFormat:@"TARGET: %@ (pathinfo %@)", 
	*target_, [_ctx pathInfo]];
  return nil;
}

- (id)doCOPY:(WOContext *)_ctx {
  NSException *error;
  NSString    *newName;
  id          targetObject;
  
  /* TODO: check proper permission prior attempting a copy */
  
  error = [self lookupDestinationObject:&targetObject andNewName:&newName
		inContext:_ctx];
  if (error) return error;
  
  error = [self->object 
	       davCopyToTargetObject:targetObject newName:newName
	       inContext:_ctx];
  if (error) {
    [self debugWithFormat:@"WebDAV COPY operation failed: %@", error];
    return error;
  }
  
  return [newName isNotEmpty]
    ? [NSNumber numberWithBool:201 /* Created */]
    : [NSNumber numberWithBool:204 /* No Content */];
}

- (id)doMOVE:(WOContext *)_ctx {
  NSException *error;
  NSString    *newName;
  id          targetObject;
  
  /* TODO: check proper permission prior attempting a move */
  
  error = [self lookupDestinationObject:&targetObject andNewName:&newName
		inContext:_ctx];
  if (error) return error;
  
  /*
    Note: more relevant headers:
      overwrite: T|F      (overwrite target) [rc: 201 vs 204!]
      depth:     infinity
      and locking tokens of course ...
  */
  
  // TODO: should we check in this place for some constraints,
  //       eg moving a collection to a non-collection or something
  //       like that?
  
  error = [self->object 
	       davMoveToTargetObject:targetObject newName:newName
	       inContext:_ctx];
  if (error) {
    [self debugWithFormat:@"WebDAV MOVE operation failed: %@", error];
    return error;
  }
  
  return [newName isNotEmpty]
    ? [NSNumber numberWithBool:201 /* Created */]
    : [NSNumber numberWithBool:204 /* No Content */];
}

/* WebDAV search methods */

- (id)doSEARCH:(WOContext *)_ctx {
  SoSecurityManager    *sm;
  NSException          *e;
  EOFetchSpecification *fs;
  NSString *baseURL;
  id       result;
  NSString *range;
  
  /* check permissions */
  
  sm = [_ctx soSecurityManager];
  e  = [sm validatePermission:SoPerm_AccessContentsInformation 
	   onObject:self->object
	   inContext:_ctx];
  if (e != nil) return e;

  /* perform search */
  
  if (![self->object 
            respondsToSelector:@selector(performWebDAVQuery:inContext:)]) {
    [[_ctx response] setStatus:405 /* not allowed */];
    [[_ctx response] appendContentString:
		       @"this object cannot not execute a SEARCH query"];
    return [_ctx response];
  }
  
  // TODO: whats that? VERY bad, maybe use -baseURLForContext:?
  baseURL = [NSString stringWithFormat:@"http://%@%@",
		        [[_ctx request] headerForKey:@"host"],
		        [[_ctx request] uri]];
  
  [self lockParser:davsax];
  {
    [xmlParser parseFromSource:[[_ctx request] content]];
    fs = [[davsax searchFetchSpecification] retain];
  }
  [self unlockParser:davsax];
  
  fs = [fs autorelease];
  if (fs == nil) {
    [[_ctx response] setStatus:400 /* Bad Request */];
    [[_ctx response] appendContentString:
		       @"could not process SEARCH query specification"];
    return [_ctx response];
  }

  /* range */
  if ((range = [[[_ctx request] headerForKey:@"range"] stringValue])) {
    /* TODO: parse range header and add to fetch-specification */
    NSRange r;
    
    r = [range rangeOfString:@"rows="];
    if (r.length > 0) {
      range = [range substringFromIndex:(r.location + r.length)];
      [self debugWithFormat:
              @"Note: got a row range header (ignored): '%@'", range];
    }
    else
      [self logWithFormat:@"Note: got a range header (ignored): '%@'", range];
  }
  
  /* override entity name ... (FROM xxx isn't yet parsed correctly) */
  [fs setEntityName:baseURL];
  
  [self debugWithFormat:@"SEARCH: %@", fs];
  
  [_ctx setObject:fs forKey:@"DAVFetchSpecification"];

  /* translate fetchspec if necessary */
  {
    NSDictionary *map;
    
    if ((map = [self->object davAttributeMapInContext:_ctx])) {
      [_ctx setObject:map forKey:@"DAVPropertyMap"];
      fs = [fs fetchSpecificationByApplyingKeyMap:map];
      [_ctx setObject:fs forKey:@"DAVMappedFetchSpecification"];
    }
  }
  
  /* perform call */
  
  if ((result = [self->object performWebDAVQuery:fs inContext:_ctx]) == nil) {
    return [self httpException:500 /* Server Error */
		 reason:@"could not execute SEARCH query (returned nil)"];
  }
  
  return result;
}

/* Exchange WebDAV methods */

- (id)doNOTIFY:(WOContext *)_ctx {
  return [self httpException:403 reason:@"NOTIFY not yet implemented"];
}

- (id)doPOLL:(WOContext *)_ctx {
  SoSubscriptionManager *sm;
  WORequest  *rq;
  NSString   *subscriptionID;
  NSArray    *ids;
  NSURL      *url;
  
  rq  = [_ctx request];
  sm  = [SoSubscriptionManager sharedSubscriptionManager];
  url = [NSURL URLWithString:[self->object baseURLInContext:_ctx]];
  
  if (url == nil) {
    return [self httpException:500
                 reason:@"could not calculate URL of WebDAV object !"];
  }
  
  subscriptionID = [rq headerForKey:@"subscription-id"];
  if (![subscriptionID isNotEmpty]) {
    return [self httpException:400 /* Bad Request */
                 reason:@"did not find subscription-id header in POLL"];
  }
  
  ids = [subscriptionID componentsSeparatedByString:@","];
  
  return [sm pollSubscriptions:ids onURL:url];
}

- (id)doSUBSCRIBE:(WOContext *)_ctx {
  SoSubscriptionManager *sm;
  WORequest  *rq;
  WOResponse *r;
  NSURL    *url;
  id       callback;
  NSString *notificationType;
  NSString *notificationDelay;
  NSString *lifetime;
  NSString *subscriptionID;
  
  rq  = [_ctx request];
  r   = [_ctx response];
  sm  = [SoSubscriptionManager sharedSubscriptionManager];
  url = [NSURL URLWithString:[self->object baseURLInContext:_ctx]];
  
  if (url == nil) {
    return [self httpException:500
                 reason:@"could not calculate URL of WebDAV object !"];
  }
  
  subscriptionID = [rq headerForKey:@"subscription-id"];
  
  /* first check, whether it's an existing subscription to be renewed */
  
  if ([subscriptionID isNotEmpty]) {
    NSString *newId;
    
    if ((newId = [sm renewSubscription:subscriptionID onURL:url]) == nil) {
      return [self httpException:412 /* precondition failed */
                   reason:@"did not find provided subscription ID !"];
    }
    return newId;
  }
  
  if ((callback = [rq headerForKey:@"call-back"])) {
    NSURL *url;
    
    if ((url = [NSURL URLWithString:[callback stringValue]]) == nil) {
      [self errorWithFormat:@"could not parse callback URL '%@'", 
              callback];
      return [self httpException:400 /* Bad Request */
                   reason:@"missing valid callback URL !"];
    }
    else
      callback = url;
  }
  
  /* TODO: add sanity checking of notification-type as described in docs */
  /* TODO: check depth */
  
  notificationDelay = [rq headerForKey:@"notification-delay"];
  notificationType  = [rq headerForKey:@"notification-type"];
  lifetime          = [rq headerForKey:@"subscription-lifetime"];
  
  subscriptionID = [sm subscribeURL:url forObserver:callback
                       type:notificationType 
                       delay:notificationDelay
                         ? [notificationDelay doubleValue] : 0.0
                       lifetime:lifetime ? [lifetime doubleValue] : 0.0];
  return subscriptionID;
}
- (id)doUNSUBSCRIBE:(WOContext *)_ctx {
  SoSubscriptionManager *sm;
  WORequest  *rq;
  WOResponse *r;
  NSString *subscriptionID;
  NSURL    *url;
  
  rq  = [_ctx request];
  r   = [_ctx response];
  sm  = [SoSubscriptionManager sharedSubscriptionManager];
  url = [NSURL URLWithString:[self->object baseURLInContext:_ctx]];
  
  if (url == nil) {
    return [self httpException:500
                 reason:@"could not calculate URL of WebDAV object !"];
  }
  
  subscriptionID = [rq headerForKey:@"subscription-id"];
  if (![subscriptionID isNotEmpty]) {
    return [self httpException:400 /* Bad Request */
		 reason:@"missing subscription id !"];
  }
  
  if ([sm unsubscribeID:subscriptionID onURL:url]) {
    [r setStatus:200];
    return r;
  }

  return [self httpException:400 /* Bad Request */
	       reason:@"unsubscribe failed (invalid or old id ?)"];
}

/* Exchange bulk methods */

- (NSArray *)urlPartsForTargets:(NSArray *)_targets basePath:(NSString *)_base{
  /*
    Transform the target URLs given to the BPROPFIND operation. This is a
    simplified implementation, for example we expect that the URLs are all
    located in the same URL space (on same host and port).
  */
  NSMutableArray *ma;
  unsigned i, count;
  
  if ((count = [_targets count]) == 0)
    return [NSArray array];
  
  ma = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    NSString *target;
    
    target = [_targets objectAtIndex:i];
    if (debugBulkTarget)
      [self logWithFormat:@"  MORPH target '%@'", target];
    
    /* extract the path from full URLs */
    if ([target isAbsoluteURL]) {
      NSURL *url;
      
      /* fix an Evolution bug, uses the 'unsafe' "@" in the URL ! */
      if ([target rangeOfString:@"@"].length > 0) {
	target = [target stringByReplacingString:@"@"
			 withString:@"%40"];
      }
      
      if ((url = [NSURL URLWithString:target])) {
	if (debugBulkTarget) [self logWithFormat:@"got URL: %@", url];
	target = [url path];
	if (debugBulkTarget) [self logWithFormat:@"path: %@", target];
      }
      else {
        [self errorWithFormat:@"could not parse BPROPFIND target '%@' !",
                target];
      }
    }
    
    /* make the target name relative to the request URI */
    if ([target hasPrefix:_base]) {
      target = [target substringFromIndex:[_base length]];
      if ([target hasPrefix:@"/"])
	target = [target substringFromIndex:1];
    }
    
    /* add the target */
    target = [target stringByUnescapingURL];
    if (debugBulkTarget) [self logWithFormat:@"  ADD target '%@'", target];
    [ma addObject:target];
  }
  return ma;
}

- (id)doBPROPFIND:(WOContext *)_ctx {
  /*
    TODO: could optimize a BPROPFIND on a single target to use PROPFIND
    
    How are BPROPFINDs mapped ? BPROPFIND corresponds to SKYRiX 4.1
    "fetch-by-globalids" commands, that is, a search gets passed a list
    of primary keys to fetch.
    BPROPFIND is implemented in a similiar way, the target URLs are converted
    to be relative to the URI object and are passed to the query datasource
    using the "bulkTargetKeys" fetch hint.
    
    Important: the URI object *must* support the "bulkTargetKeys" fetch hint,
    otherwise the operation will run on the object itself.
    
    Note: Previously BPROPFIND was mapped to a set of individual requests,
    but obviously this doesn't match SQL very well (resulting in an individual
    SQL query for each entity ...)
  */
  SoSecurityManager    *sm;
  NSException          *e;
  EOFetchSpecification *fs;
  WORequest *rq;
  NSString  *depth; /* 0, 1, 1,noroot or infinity */
  NSArray   *propNames;
  NSArray   *targets, *rtargets;
  BOOL      findAll;
  BOOL      findNames;
  id        result;
  NSDictionary *map;
  
  /* check permissions */
  
  sm = [_ctx soSecurityManager];
  e  = [sm validatePermission:SoPerm_AccessContentsInformation 
	   onObject:self->object
	   inContext:_ctx];
  if (e != nil) return e;

  /* perform search */
  
  if (![self->object respondsToSelector:@selector(performWebDAVQuery:inContext:)]) {
    return [self httpException:405 /* not allowed */
		 reason:@"this object cannot not execute a PROPFIND query"];
  }
  
  rq = [_ctx request];
  depth = [rq headerForKey:@"depth"];
  if (![depth isNotEmpty]) depth = @"infinity";
  
  [self lockParser:davsax];
  {
    [xmlParser parseFromSource:[rq content]];
    propNames = [[davsax propFindQueriedNames] copy];
    findAll   = [davsax  propFindAllProperties];
    findNames = [davsax  propFindPropertyNames];
    targets   = [[davsax  bpropFindTargets] copy];
  }
  [self unlockParser:davsax];
  propNames = [propNames autorelease];
  targets   = [targets   autorelease];
  
  if (![targets isNotEmpty])
    return [NSArray array];
  
  /* check query all properties */
  
  if (propNames == nil)
    propNames = [self->object defaultWebDAVPropertyNamesInContext:_ctx];
  
  /* morph targets */
  
  rtargets = [self urlPartsForTargets:targets
                   basePath:[[rq uri] stringByUnescapingURL]];
  
  [self debugWithFormat:@"BPROPFIND targets: %@", rtargets];
  
  /* build the fetch-spec */
  {
    NSMutableDictionary *hints;
    
    hints = [self hintsWithScope:[self scopeForDepth:depth inContext:_ctx]
		  propNames:propNames findAll:findAll namesOnly:findNames];
    [hints setObject:rtargets forKey:@"bulkTargetKeys"];
    
    fs = [EOFetchSpecification alloc];
    fs = [fs initWithEntityName:[self baseURLForContext:_ctx]
	     qualifier:nil
	     sortOrderings:nil
	     usesDistinct:NO isDeep:NO hints:hints];
    fs = [fs autorelease];
  }
  
  [_ctx setObject:fs forKey:@"DAVFetchSpecification"];
  
  /* 
     translate fetchspec if necessary - we currently cannot allow a map
     for each target, so we use the map of the queried target.
  */
  if ((map = [self->object davAttributeMapInContext:_ctx])) {
    [_ctx setObject:map forKey:@"DAVPropertyMap"];
    fs = [fs fetchSpecificationByApplyingKeyMap:map];
    [_ctx setObject:fs  forKey:@"DAVMappedFetchSpecification"];
  }

  /* perform */
  
  if ((result = [self->object performWebDAVQuery:fs inContext:_ctx]) == nil) {
    return [self httpException:500 /* Server Error */
		 reason:@"could not perform query (object returned nil)"];
  }
  
  return result;
#if 0  
  /* now, for each BPROPFIND target ... */
  {
    NSEnumerator *e;
    NSString *targetURL;
    
    result = [NSMutableArray arrayWithCapacity:32];
    
    e = [targets objectEnumerator];
    while ((targetURL = [e nextObject])) {
      NSAutoreleasePool *pool;
      WOContext   *localContext;
      WORequest   *localRequest;
      NSException *e;
      id targetObject;
      id targetResult;
      
      pool = [[NSAutoreleasePool alloc] init];
      
      /* setup the "subrequest" */
      
      if ([targetURL isAbsoluteURL]) {
        NSURL *url;
        
        if ((url = [NSURL URLWithString:targetURL]))
          targetURL = [url path];
        else {
          [self errorWithFormat:@"could not parse target-url '%@'", targetURL];
        }
      }
      
      localRequest = [[WORequest alloc] initWithMethod:@"PROPFIND"
					uri:targetURL
					httpVersion:[rq httpVersion]
					headers:[rq headers]
					content:nil
					userInfo:nil];
      localContext = 
        [[[WOContext alloc] initWithRequest:localRequest] autorelease];
      [localRequest autorelease];
      
      /* resetup fetchspec */
      [fs setEntityName:targetURL];
      
      /* traverse URL */
      
      targetObject = [_ctx traversalRoot];
      targetObject = [targetObject traversePathArray:
				     [localRequest requestHandlerPathArray]
				   inContext:localContext
				   error:&e
				   acquire:NO];
      if (targetObject == nil) {
        [self logWithFormat:@"did not find BPROPFIND target: %@", targetURL];
        [self logWithFormat:@"  root:   %@", [_ctx traversalRoot]];
        [self logWithFormat:@"  path:   %@", 
	        [[localRequest requestHandlerPathArray] 
		               componentsJoinedByString:@"/"]];
        [self logWithFormat:@"  error:  %@", e];
        targetResult = e;
      }
      else {
        /* perform query */
	
        targetResult = [targetObject performWebDAVQuery:fs 
                                              inContext:localContext];
        if (targetResult == nil) {
          targetResult = 
          [self httpException:500 /* Server Error */
                reason:@"could not perform query (object returned nil)"];
        }
      }
      
      // do we need to distinguish the queries somehow ? (href generation)
      if ([targetResult isKindOfClass:[NSArray class]])
        [result addObjectsFromArray:targetResult];
      else if (targetResult)
        [result addObject:targetResult];

      [pool release];
    }
  }
  
  /* perform */
  
  if (result) return result;
#endif
}

- (id)doBCOPY:(WOContext *)_ctx {
  return [self httpException:403 /* forbidden */
	       reason:@"BCOPY not yet implemented."];
}
- (id)doBDELETE:(WOContext *)_ctx {
  return [self httpException:403 /* forbidden */
	       reason:@"BDELETE not yet implemented."];
}
- (id)doBMOVE:(WOContext *)_ctx {
  return [self httpException:403 /* forbidden */
	       reason:@"WebDAV operation not yet implemented."];
}

- (id)doBPROPPATCH:(WOContext *)_ctx {
  return [self httpException:403 /* forbidden */
	       reason:@"WebDAV operation not yet implemented."];
}

/* DAV reports */

- (id)doREPORT:(WOContext *)_ctx {
  id<DOMDocument> domDocument;
  WORequest *rq;
  NSString  *mname, *ctype;
  id method, resultObject;
  
  rq = [_ctx request];
  
  /* ensure XML */

  ctype = [rq headerForKey:@"content-type"];
  if (!([ctype hasPrefix:@"text/xml"]
	|| [ctype hasPrefix:@"application/xml"])) {
    return [self httpException:400 /* invalid request */
		 reason:@"XML entity expected for WebDAV REPORT."];
  }
  
  /* retrieve XML */

  if ((domDocument = [rq contentAsDOMDocument]) == nil) {
    return [self httpException:400 /* invalid request */
		 reason:@"Could not parse XML of WebDAV REPORT."];
  }
  
  /* first try to lookup method with fully qualified name */
  
  mname  = [NSString stringWithFormat:@"{%@}%@",
		       [[domDocument documentElement] namespaceURI],
		       [[domDocument documentElement] localName]];
  method = [self->object lookupName:mname inContext:_ctx acquire:NO];
  
  if (method == nil || [method isKindOfClass:[NSException class]]) {
    /* then try to lookup by simplified name */
    id m2;
    
    m2 = [self->object lookupName:[[domDocument documentElement] localName]
	               inContext:_ctx acquire:NO];
    if (m2 == nil)
      ; /* failed */
    else if ([m2 isKindOfClass:[NSException class]]) {
      if (method == nil)
	method = m2; /* use the second exceptions */
    }
    else {
      method = m2;
      mname  = [[domDocument documentElement] localName];
    }
  }
  
  // TODO: what I would really like to have here is a pluggable dispatcher
  //       mechanism which translates the report payload into a customized
  //       method call.
  
  /* check for lookup errors */
  
  if (method == nil || [method isKindOfClass:[NSException class]]) {
    [self logWithFormat:@"did not find a method to server the REPORT"];
    return [NSException exceptionWithHTTPStatus:501 /* not implemented */
			reason:@"did not find the specified REPORT"];
  }
  else if ([method isKindOfClass:[NSException class]]) {
    [self logWithFormat:@"failed to lookup the REPORT: %@", method];
    return method;
  }
  else if (![method isCallable]) {
    [self warnWithFormat:
            @"object found for REPORT '%@' is not callable: %@",
            mname, method];
  }
  [self debugWithFormat:@"REPORT method: %@", method];

  /* perform call */
  
  resultObject = [method callOnObject:[_ctx clientObject] inContext:_ctx];
  if (debugOn) [self debugWithFormat:@"got REPORT result: %@", resultObject];
  return resultObject;
}

/* CalDAV */

- (id)doMKCALENDAR:(WOContext *)_ctx {
  SoSecurityManager *sm;
  NSException       *e;
  NSString          *pathInfo;
  
  pathInfo = [_ctx pathInfo];
  if (![pathInfo isNotEmpty]) {
    /* MKCALENDAR target already exists ... */
    WOResponse *r;

    [self logWithFormat:@"MKCALENDAR target exists !"];
    
    r = [_ctx response];
    [r setStatus:405 /* method not allowed */];
    [r appendContentString:@"calendar collection already exists !"];
    return r;
  }
  
  /* check permissions */
  
  sm = [_ctx soSecurityManager];
  e  = [sm validatePermission:SoPerm_AddFolders 
	   onObject:self->object
	   inContext:_ctx];
  if (e != nil) return e;

  /* check whether all the parent collections are available */
  if ([pathInfo rangeOfString:@"/"].length > 0) {
    return [self httpException:409 /* Conflict */
                 reason:
                   @"invalid WebDAV MKCALENDAR request, first create all "
		   @"parent collections !"];
  }
  
  /* check whether the object supports creating collections */

  if (![self->object respondsToSelector:
              @selector(davCreateCalendarCollection:inContext:)]) {
    /* Note: this should never happen, as this is implemented on NSObject */
    
    [self logWithFormat:@"MKCALENDAR: object '%@' path-info '%@'", 
            self->object, pathInfo];
    return [self httpException:405 /* not allowed */
                 reason:
                   @"this object cannot create a new calendar collection with MKCALENDAR"];
  }
  
  if ((e = [self->object davCreateCalendarCollection:pathInfo inContext:_ctx])) {
    [self debugWithFormat:@"creation of calendar collection '%@' failed: %@",
            pathInfo, e];
    return e;
  }
  
  [self debugWithFormat:@"created calendar collection."];
  return [NSNumber numberWithBool:YES];
}

/* DAV access control lists */

- (id)doACL:(WOContext *)_ctx {
  return [self httpException:405 /* method not allowed */
	       reason:@"WebDAV operation not yet implemented."];
}

/* DAV binding */

- (id)doBIND:(WOContext *)_ctx {
  return [self httpException:405 /* method not allowed */
	       reason:@"WebDAV operation not yet implemented."];
}

/* DAV ordering */

- (id)doORDERPATCH:(WOContext *)_ctx {
  return [self httpException:405 /* method not allowed */
	       reason:@"WebDAV operation not yet implemented."];
}

/* DAV deltav */

- (id)doCHECKOUT:(WOContext *)_ctx {
  return [self httpException:405 /* method not allowed */
	       reason:@"WebDAV operation not yet implemented."];
}
- (id)doUNCHECKOUT:(WOContext *)_ctx {
  return [self httpException:405 /* method not allowed */
	       reason:@"WebDAV operation not yet implemented."];
}
- (id)doCHECKIN:(WOContext *)_ctx {
  return [self httpException:405 /* method not allowed */
	       reason:@"WebDAV operation not yet implemented."];
}
- (id)doMKWORKSPACE:(WOContext *)_ctx {
  return [self httpException:405 /* method not allowed */
	       reason:@"WebDAV operation not yet implemented."];
}
- (id)doUPDATE:(WOContext *)_ctx {
  return [self httpException:405 /* method not allowed */
	       reason:@"WebDAV operation not yet implemented."];
}
- (id)doMERGE:(WOContext *)_ctx {
  return [self httpException:405 /* method not allowed */
	       reason:@"WebDAV operation not yet implemented."];
}
- (id)doVERSIONCONTROL:(WOContext *)_ctx {
  return [self httpException:405 /* method not allowed */
	       reason:@"WebDAV operation not yet implemented."];
}

/* perform dispatch */

- (id)performMethod:(NSString *)_method inContext:(WOContext *)_ctx {
  SoSecurityManager *sm;
  NSException       *e;
  NSString *s;
  SEL      sel;
  
  /* check basic WebDAV permission */
  
  sm = [_ctx soSecurityManager];
  e  = [sm validatePermission:SoPerm_WebDAVAccess
	   onObject:self->object
	   inContext:_ctx];
  if (e != nil) return e;
  
  /* perform search */
  
  _method = [_method uppercaseString];
  _method = [_method stringByReplacingString:@"-" withString:@""];
  s = [NSString stringWithFormat:@"do%@:", _method];
  sel = NSSelectorFromString(s);
  
  if (![self respondsToSelector:sel]) {
    [self logWithFormat:@"unknown WebDAV method: '%@'", _method];
    [[_ctx response] setStatus:405 /* invalid method */];
    return [_ctx response];
  }
  
  return [self performSelector:sel withObject:_ctx];
}

- (BOOL)setupXmlParser {
  if (xmlParser == nil) {
    xmlParser =
      [[[SaxXMLReaderFactory standardXMLReaderFactory] 
                             createXMLReaderForMimeType:@"text/xml"]
                             retain];
    if (xmlParser == nil)
      return NO;
  }
  if (davsax == nil) {
    if ((davsax = [[SaxDAVHandler alloc] init]) == nil)
      return NO;
  }
  return YES;
}

- (id)dispatchInContext:(WOContext *)_ctx {
  NSAutoreleasePool *pool;
  WOResponse *r;
  id result;
  
  if (gmt == nil) gmt = [[NSTimeZone timeZoneWithAbbreviation:@"GMT"] retain];
  
  /* setup XML parser */
  if (![self setupXmlParser]) {
    r = [_ctx response];
    [r setStatus:500 /* internal server error */];
    [r appendContentString:@"did not find an XML parser, cannot process DAV."];
    return r;
  }
  
  pool = [[NSAutoreleasePool alloc] init];
  result = [[self performMethod:[[_ctx request] method] inContext:_ctx] retain];
  [pool release];
  return [result autorelease];
}

/* logging */

- (NSString *)loggingPrefix {
  return @"[obj-dav-dispatch]";
}
- (BOOL)isDebuggingEnabled {
  return debugOn ? YES : NO;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self,
        NSStringFromClass((Class)*(void**)self)];
  
  if (self->object)
    [ms appendFormat:@" object=%@", self->object];
  else
    [ms appendString:@" <no object>"];
  
  [ms appendString:@">"];
  return ms;
}

@end /* SoObjectWebDAVDispatcher */
