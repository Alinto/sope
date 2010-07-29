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

#include "SoObject+SoDAV.h"
#include "SoObject.h"
#include "SoObjectDataSource.h"
#include "EOFetchSpecification+SoDAV.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WEClientCapabilities.h>
#import <EOControl/EOQualifier.h>
#import <EOControl/EOSortOrdering.h>
#include "common.h"

@implementation NSObject(SoObjectDAVQueries)

static int debugBulk = NO; // TODO: set to -1 and use defaults

- (NSEnumerator *)davChildKeysInContext:(id)_ctx {
  /*
    This returns the names of the children of a collection.
    Could return toOneRelationshipKeys+toManyRelationshipKeys ? 
  */
  NSClassDescription *cd;
  NSArray *t1, *tn;
  
  /* 
     Note: this is done explicitly because the WebDAV class description
           can be different to the 'EOF' class description.
  */
  if ((cd = [self soClassDescription]) != nil) {
    t1 = [cd toOneRelationshipKeys];
    tn = [cd toManyRelationshipKeys];
  }
  else {
    t1 = [self toOneRelationshipKeys];
    tn = [self toManyRelationshipKeys];
  }
  
  if ([tn count] == 0)
    return [t1 objectEnumerator];
  if ([t1 count] == 0)
    return [tn objectEnumerator];
  
  return [[t1 arrayByAddingObjectsFromArray:tn] objectEnumerator];
}

- (EODataSource *)contentDataSourceInContext:(id)_ctx {
  return [[[SoObjectDataSource alloc] initWithObject:self
				      inContext:_ctx] autorelease];
}

- (EODataSource *)davFlatDataSourceInContext:(id)_ctx {
  [self logWithFormat:
	  @"%s: this method is deprecated,use -contentDataSourceInContext: !"];
  return [self contentDataSourceInContext:_ctx];
}

- (NSArray *)davQueryOnSelf:(EOFetchSpecification *)_fs inContext:(id)_ctx {
  id<EOQualifierEvaluation> q;
  NSDictionary *values;
  NSArray *keys;
  
  if ((q = (void *)[_fs qualifier])) {
    if (![q evaluateWithObject:self]) {
      [self debugWithFormat:@"  self does not match qualifier."];
      return [NSArray array];
    }
  }
  
  if ((keys = [_fs selectedWebDAVPropertyNames]) == nil) {
    /*
      Note: this should not happen anymore, a default-set will be used by
      the dispatcher.
    */
    keys = [[self soClassDescription] attributeKeys];
    [self debugWithFormat:@"using keys from description: %@", keys];
  }
  
  /* ensure that the URL is added */
  keys = [keys arrayByAddingObject:@"davURL"];
  
  if ([_fs queryWebDAVPropertyNamesOnly]) {
    /* how does the renderer know, that these are the keys ? */
    [self debugWithFormat:@"deliver keys only: %@", keys];
    return keys != nil ? [NSArray arrayWithObject:keys] : nil;
  }
  
  // TODO: we should map out certain keys, like 'retain', 'release' etc!
  if ((values = [self valuesForKeys:keys]) == nil)
    return nil;
  
  return [NSArray arrayWithObject:values];
}

- (id)performWebDAVDeepQuery:(EOFetchSpecification *)_fs inContext:(id)_ctx {
  /* this just does a flat search :-(, maybe we should return 403 ? */
  WEClientCapabilities *cc;
  EODataSource *ds;
  NSArray      *result;
  NSString *scope;
  BOOL     includeSelf, doDeep;
  unsigned count;
  
  /* setup scope info */
  
  scope = [_fs scopeOfWebDAVQuery];
  includeSelf = [scope rangeOfString:@"-self"].length == 0 ? NO : YES;
  doDeep      = YES;
  
  /* do some user-agent specific tolerance */
  
  cc = [[(id <WOPageGenerationContext>)_ctx request] clientCapabilities];
  if (includeSelf) {
    NSString *ua;
    
    ua = [cc userAgentType];
    if ([ua isEqualToString:@"Evolution"] || [ua isEqualToString:@"WebFolder"])
      includeSelf = NO;
    else {
      [self logWithFormat:@"return self on UA: %@", ua];
      includeSelf = YES;
    }
  }
  doDeep = NO;
  
  /* perform deep query */
  
  ds = [self contentDataSourceInContext:_ctx];
  [ds setFetchSpecification:_fs];
  
  if ((result = [ds fetchObjects]) == nil)
    /* nil is error */
    return nil;
  
  if ((count = [result count]) == 0) {
    if (includeSelf)
      return [self davQueryOnSelf:_fs inContext:_ctx];
  }
  else {
    NSMutableArray *ma;
    
    ma = [NSMutableArray arrayWithCapacity:(count + 2)];
    
    if (includeSelf)
      [ma addObjectsFromArray:[self davQueryOnSelf:_fs inContext:_ctx]];
    
    /* add flat results */
    [ma addObjectsFromArray:result];
    
    if (doDeep) {
      /* 
	 Should walk over each result and reperform the query with deep-self.
	 If the results came from SoObjectDataSource this is possible because
	 the "full" object is none in the SoObjectResultEntry.
      */
      [self warnWithFormat:@"attempted deep-search, not supported yet."];
    }    
    result = ma;
  }
  return result;
}

- (id)performWebDAVBulkQuery:(EOFetchSpecification *)_fs inContext:(id)_ctx {
  NSAutoreleasePool    *pool;
  EOFetchSpecification *subSpec;
  NSMutableArray *results;
  NSEnumerator *keys;
  NSString     *key;

  pool = [[NSAutoreleasePool alloc] init];
  //[self debugWithFormat:@"perform bulk query ..."];
  
  /* create a sub-fetch-spec */
  {
    NSMutableDictionary *hints;
    
    hints = [[_fs hints] mutableCopy];
    [hints removeObjectForKey:@"bulkTargetKeys"];
    
    subSpec = [[_fs copy] autorelease];
    [subSpec setHints:hints];
    [hints release];
  }
  
  results = [NSMutableArray arrayWithCapacity:256];
  keys = [[_fs davBulkTargetKeys] objectEnumerator];
  while ((key = [keys nextObject])) {
    id child;
    id childResults;
    
    if (debugBulk)
      [self debugWithFormat:@"  check bulk key: '%@'", key];
    
    /* lookup target */
    
    if ([key rangeOfString:@"/"].length == 0) {
      /* simple key, just use -lookupName */
      child = [self lookupName:key inContext:_ctx acquire:NO];
      if (child == nil) {
        [self errorWithFormat:@"did not find the BPROPFIND target '%@'", key];
        continue;
      }
    }
    else {
      /* complex key, try to traverse */
      // TODO: pass auth parameters to traversal context !!
      child = [self traversePath:key acquire:NO];
      if (child == nil) {
        [self errorWithFormat:
                @"did not find the BPROPFIND target '%@' by traversing.",
                key];
        continue;
      }
      if ([child isKindOfClass:[NSException class]]) {
        [self logWithFormat:@"traversing bulk path '%@', failed: %@", 
                key, child];
        continue;
      }
      [self logWithFormat:@"traversed bulk path '%@', got: %@", key, child];
    }
    
    /* set entity name */
    [subSpec setEntityName:
	       [[_fs entityName] stringByAppendingPathComponent:key]];
    
    /* perform subquery */
    childResults = [child performWebDAVQuery:subSpec inContext:_ctx];
    if (childResults) {
      if ([childResults isKindOfClass:[NSArray class]])
	[results addObjectsFromArray:childResults];
      else
	[results addObject:childResults];
    }
  }
  
  results = [results retain];
  [pool release];
  return [results autorelease];
}

- (id)performWebDAVQuery:(EOFetchSpecification *)_fs inContext:(id)_ctx {
  NSString *scope;
  NSArray  *bulkQueryKeys;
  
  if (_fs == nil) return nil;

  if ((bulkQueryKeys = [_fs davBulkTargetKeys]))
    return [self performWebDAVBulkQuery:_fs inContext:_ctx];
  
  scope = [_fs scopeOfWebDAVQuery];
  if ([scope hasPrefix:@"flat"]) {
    EODataSource *ds;
    NSArray *result;
    
    ds = [self contentDataSourceInContext:_ctx];
    [ds setFetchSpecification:_fs];
    if ((result = [ds fetchObjects]) == nil)
      /* error */
      return nil;
    
    if ([scope rangeOfString:@"+self"].length > 0) {
      /* should include self */
      unsigned len;
      
      // TODO: don't add self if we work on ZideLook or WebFolders !
      
      if ((len = [result count]) == 0)
	result = [self davQueryOnSelf:_fs inContext:_ctx];
      else {
	NSMutableArray *ma;
	
	ma = [NSMutableArray arrayWithCapacity:(len + 2)];
	[ma addObjectsFromArray:[self davQueryOnSelf:_fs inContext:_ctx]];
	[ma addObjectsFromArray:result];
	result = ma;
      }
    }
    return result;
  }

  if ([scope hasPrefix:@"self"])
    return [self davQueryOnSelf:_fs inContext:_ctx];
  
  if ([scope hasPrefix:@"deep"])
    return [self performWebDAVDeepQuery:_fs inContext:_ctx];
  
  [self errorWithFormat:@"called with invalid scope '%@'", scope];
  return nil;
}

@end /* NSObject(SoObjectDAVQueries) */
