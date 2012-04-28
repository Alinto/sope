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

#include "SoObjectDataSource.h"
#include "SoObjectResultEntry.h"
#include "SoObject+SoDAV.h"
#include "SoObject.h"
#include "EOFetchSpecification+SoDAV.h"
#include <NGObjWeb/WEClientCapabilities.h>
#include <NGObjWeb/WOContext.h>
#import <EOControl/EOQualifier.h>
#import <EOControl/EOSortOrdering.h>
#include "common.h"

@implementation SoObjectDataSource

static BOOL debugOn = NO;

+ (void)initialize {
  NSUserDefaults *ud;
  
  ud = [NSUserDefaults standardUserDefaults];
  debugOn = [ud boolForKey:@"SoObjectDataSourceDebugEnabled"];
}

- (id)initWithObject:(id)_object inContext:(id)_ctx {
  if ((self = [super init])) {
    self->object  = [_object retain];
    self->context = _ctx;
  }
  return self;
}
- (id)init {
  return [self initWithObject:nil inContext:nil];
}

- (void)dealloc {
  [self->object release];
  [self->fspec  release];
  [super dealloc];
}


/* accessors */

- (void)setFetchSpecification:(EOFetchSpecification *)_fetchSpec {
  if ([_fetchSpec isEqual:self->fspec]) return;
  
  ASSIGN(self->fspec, _fetchSpec);
  [self postDataSourceChangedNotification];
}
- (EOFetchSpecification *)fetchSpecification {
  return self->fspec;
}

- (id)context {
  return self->context;
}
- (id)object {
  return self->object;
}

- (EOClassDescription *)classDescriptionForObjects {
  if ([self->object respondsToSelector:_cmd])
    /* forward to datasource owner if possible */
    return [self->object performSelector:_cmd];
  
  return nil;
}

/* implementation */

- (NSArray *)davFlatQuery:(EOFetchSpecification *)_fs inContext:(id)_ctx {
  /*
    If you have a datasource for your children, consider to override this
    method and use the DS to perform the query.
  */
  id<EOQualifierEvaluation> q;
  NSMutableArray *ma;
  NSArray      *result;
  NSEnumerator *childKeys;
  NSArray      *queriedAttrNames;
  NSArray      *orderings;
  NSString     *childKey;
  BOOL         doEscape;
  NSString     *entityURL;
  BOOL         isBrief = YES; // do not encode "sub-errors", just omit the item
  
  [self debugWithFormat:@"performing flat query: %@", _fs];

  /* base URL */

  entityURL = [_fs entityName];
  if (![entityURL hasSuffix:@"/"]) 
    entityURL = [entityURL stringByAppendingString:@"/"];
  if (debugOn)
    [self logWithFormat:@"using base-url: %@", entityURL];
  
  /* wsourdeau, 20120206: if we enable escaping here, the resulting URL in
     PROPFIND responses will be escaped twice, so I disabled it. Maybe it will
     break something else? */
  doEscape = NO;
  
  /* retrieve child names (calls -toOneRelationshipKeys and -toManyRel...) */
  
  childKeys = [self->object davChildKeysInContext:_ctx];
  
  /* process */
  
  [self debugWithFormat:@"query keys: %@", childKeys];
    
  q  = (void *)[_fs qualifier];
  ma = [NSMutableArray arrayWithCapacity:16];
    
  queriedAttrNames = [_fs selectedWebDAVPropertyNames];
  
  while ((childKey = [[childKeys nextObject] stringValue]) != nil) {
    NSDictionary *rec;
    NSException  *e;
    NSString     *childHref;
    id child = nil;
      
    /* 
       TODO: question of the week, is it faster to filter on the record
       dictionary or to filter on the object itself? Do WebDAV clients
       always select all items they sort or filter? Hm.
    */
    rec = nil;
    
    if ((e = [self->object validateName:childKey inContext:_ctx])) {
      /* security problem */
      [self debugWithFormat:@"  child key '%@' did not validate:\n  %@", 
	      childKey, e];
	
      if (isBrief) // when the brief header is set, forget errors
	e = nil;
    }
    else if ((child = [self->object lookupName:childKey inContext:_ctx 
			            acquire:NO]) == nil) {
      /* not found */
      [self debugWithFormat:@"  did not find key '%@'", childKey];
	
      if (!isBrief) { // when the brief header is not set, encode status
	NSDictionary *ui;
	
	ui = [NSDictionary dictionaryWithObject:@"404" /* not found */
			   forKey:@"http-status"];
	e = [NSException exceptionWithName:@"KeyError"
			 reason:@"failed to lookup a WebDAV child resource"
			 userInfo:ui];
      }
    }
    else if ([child isKindOfClass:[NSException class]]) {
      e = child;
      child = nil;
    }
    else {
      /* found a valid child */
      //[self debugWithFormat:@"  found child for key '%@'", childKey];
      
      if (q != nil) {
	if (![q evaluateWithObject:child]) {
	  /* object does not match the filter */
          if (debugOn) {
            [self debugWithFormat:@"  object did not match qualifier: %@", 
		    child];
          }
	  continue;
	}
      }
      
      /* passed */
      // TODO: child can be SoHTTPException ?
      rec = (queriedAttrNames == nil)
	? child
	: (id)[child valuesForKeys:queriedAttrNames];
#if 0
      [self logWithFormat:@"got values: %@ for keys: %@ from object: %@",
	    rec, queriedAttrNames, child];
#endif
    }
      
    /* calc URI */
    
    /* 
       Note: we cannot use NSPathUtilities, those will reformat the string on
             Cocoa Foundation! (eg http://a => http:/a, remove double slashes)
    */
    childHref = doEscape ? [childKey stringByEscapingURL] : childKey;
    childHref = [entityURL stringByAppendingString:childHref];
    
    if (debugOn) {
      // TODO: this happens if we access using Goliath
      if ([childHref hasPrefix:@"http:/"] && 
	  ![childHref hasPrefix:@"http://"]) {
	[self logWithFormat:@"BROKEN CHILD URL: %@ (entity=%@,key=%@)", 
	      childHref, [_fs entityName], childKey];
	//abort();
      }
    }
    
    /* add errors if required */
    
    if ((rec == nil) && (e != nil) && !isBrief) {
      rec = [[SoObjectErrorEntry alloc] 
	      initWithURI:childHref object:child error:e];
    }
    else if (rec == nil) {
      /* either brief or no error found */
      continue;
    }
    else if (queriedAttrNames) {
      rec = [[SoObjectResultEntry alloc] 
	      initWithURI:childHref object:child values:rec];
    }
    else
      /* the child */
      rec = [rec retain];
    
    /* add record to result */
    [ma addObject:rec];
    [rec release];
  }
  
  /* sort result (note: you must select anything you want to sort ...) */
  if ((orderings = [_fs sortOrderings]))
    [ma sortUsingKeyOrderArray:orderings];
  
  result = ma;
  
  [self debugWithFormat:@"  got %i results\n%@", [result count], result];
  return result;
}

/* operations */

- (NSArray *)fetchObjects {
  NSAutoreleasePool *pool;
  id result;

  if ([[self fetchSpecification] davBulkTargetKeys] != nil) {
    [self logWithFormat:@"SoObjectDataSource cannot handle bulk queries !"];
    return nil;
  }
  
  pool = [[NSAutoreleasePool alloc] init];
  result = [self davFlatQuery:[self fetchSpecification]
		 inContext:[self context]];
  result = [result retain];
  [pool release];
  return [result autorelease];;
}

/* logging */

- (NSString *)loggingPrefix {
  return @"[object-datasource]";
}
- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* SoObjectDataSource */
