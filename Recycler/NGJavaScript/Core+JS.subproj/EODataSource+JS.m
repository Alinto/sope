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

#include <EOControl/EOControl.h>
#include <NGExtensions/EODataSource+NGExtensions.h>
#include <NGExtensions/NSNull+misc.h>
#include "../common.h"

/*
  EODataSource JavaScript object
  
  Methods
    bool     setQualifier(string [,args...]) // Format: EOQualifier Format !
    String   getQualifier()
    bool     setEntity(string)
    String   getEntity()
    bool     setSortOrdering(string)  // Format: 'name' oder '-name'
    String   getSortOrdering()
    bool     setHint(string, value)
    Object   getHint(string)
    
    Array    fetchObjects([qual][,orderings][,grouping])
    
    Document createObject()
    bool     updateObject(document)
    bool     insertObject(document)
    bool     deleteObject(document)
*/

@implementation EODataSource(SkyJSDataSourceBehaviour)

static id null = nil;

static inline void _ensureNull(void) {
  if (null == nil)
    null = [[NSNull null] retain];
}

/* methods */

- (void)_updateFetchSpecWithEntityName:(NSString *)_ename
  qualifier:(EOQualifier *)_qual
  sortOrderings:(NSArray *)_so
{
  EOFetchSpecification *fspec;

  if (_ename == nil && _qual == nil && _so == nil)
    /* nothing to update .. */
    return;
  
  _ensureNull();
  
  if ((fspec = [self fetchSpecification]) == nil) {
    if (_qual  == null) _qual  = nil;
    if (_so    == null) _so    = nil;
    if (_ename == null) _ename = nil;
    
    fspec = [[EOFetchSpecification alloc]
                                   initWithEntityName:_ename
                                   qualifier:_qual
                                   sortOrderings:_so
                                   usesDistinct:YES isDeep:NO hints:nil];
    fspec = [fspec autorelease];
    
    [self setFetchSpecification:fspec];
  }
  else {
    fspec = [[fspec copy] autorelease];
    
    if (_qual) {
      if (_qual == null) _qual = nil;
      [fspec setQualifier:_qual];
    }
    if (_ename) {
      if (_ename == null) _ename = nil;
      [fspec setEntityName:_ename];
    }
    if (_so) {
      if (_so == null) _so = nil;
      [fspec setSortOrderings:_so];
    }
    
    [self setFetchSpecification:fspec];
  }
}

- (id)_jsfunc_setEntity:(NSArray *)_args {
  unsigned count;
  NSString *entityName;

  if ((count = [_args count]) == 0) {
#if DEBUG && 0
    NSLog(@"%s: missing qualifier argument ..", __PRETTY_FUNCTION__);
#endif
    entityName = nil;
  }
  else {
    entityName = [[_args objectAtIndex:0] stringValue];
  }

  if (entityName == nil) entityName = null;
  
  [self _updateFetchSpecWithEntityName:entityName
        qualifier:nil
        sortOrderings:nil];
  
  return [NSNumber numberWithBool:YES];
}
- (id)_jsfunc_getEntity:(NSArray *)_args {
  return [[self fetchSpecification] entityName];
}

- (id)_jsfunc_setSortOrdering:(NSArray *)_args {
  unsigned count;
  
  if ((count = [_args count]) == 0) {
    [self _updateFetchSpecWithEntityName:nil
          qualifier:nil
          sortOrderings:[NSArray array]];
    
    return [NSNumber numberWithBool:YES];
  }
  else if (count == 1) {
    NSString       *key;
    SEL            selector;
    EOSortOrdering *ordering;

    selector = EOCompareAscending;
    
    key = [[_args objectAtIndex:0] stringValue];
    if ([key hasPrefix:@"-"]) {
      selector = EOCompareDescending;
      key = [key substringFromIndex:1];
    }
    
    ordering = [EOSortOrdering sortOrderingWithKey:key selector:selector];
    
    [self _updateFetchSpecWithEntityName:nil
          qualifier:nil
          sortOrderings:[NSArray arrayWithObject:ordering]];
    
    return [NSNumber numberWithBool:YES];
  }
  
  return [NSNumber numberWithBool:NO];
}
- (id)_jsfunc_getSortOrdering:(NSArray *)_args {
  NSArray        *orderings;
  unsigned       count;
  EOSortOrdering *ordering;
  
  orderings = [[self fetchSpecification] sortOrderings];
  if ((count = [orderings count]) == 0)
    return nil;
  
  ordering = [orderings objectAtIndex:0];
  
#if APPLE_RUNTIME || NeXT_RUNTIME
  if ([ordering selector] == EOCompareDescending)
    return [@"-" stringByAppendingString:[ordering key]];
  if ([ordering selector] == EOCompareDescending)
    return [ordering key];
#else
  if (sel_eq([ordering selector], EOCompareDescending))
    return [@"-" stringByAppendingString:[ordering key]];
  if (sel_eq([ordering selector], EOCompareDescending))
    return [ordering key];
#endif
  return @"<unknown>";
}

- (id)_jsfunc_setQualifier:(NSArray *)_args {
  EOFetchSpecification *fspec;
  unsigned    count;
  EOQualifier *q;
  NSArray     *args;

  _ensureNull();
  
  fspec = [self fetchSpecification];
  
  if ((count = [_args count]) == 0) {
#if DEBUG && 0
    NSLog(@"%s: missing qualifier argument ..", __PRETTY_FUNCTION__);
#endif
    q = nil;
  }
  else {
    id qq;
    
    qq = [_args objectAtIndex:0];
    
    args = (count > 1)
      ? [_args subarrayWithRange:NSMakeRange(1, count - 1)]
      : [NSArray array];
    
    if ([qq isKindOfClass:[EOQualifier class]]) {
      q = qq;
    }
    else if ([[qq stringValue] length] == 0) {
      q = nil;
    }
    else {
      q = [EOQualifier qualifierWithQualifierFormat:[qq stringValue]
                       arguments:args];
      
#if DEBUG
      if (q == nil) {
        NSLog(@"%s: couldn't parse qualifier '%@' ..",
              __PRETTY_FUNCTION__, qq);
        return [NSNumber numberWithBool:NO];
      }
#endif
    }
  }
  
  if (q == nil) q = null;
  
  [self _updateFetchSpecWithEntityName:nil qualifier:q sortOrderings:nil];
  
  return [NSNumber numberWithBool:YES];
}
- (id)_jsfunc_getQualifier:(NSArray *)_args {
  return [(id)[[self fetchSpecification] qualifier] stringValue];
}

- (id)_jsfunc_setHint:(NSArray *)_args {
  unsigned count;
  NSString *key;
  id       value;
  EOFetchSpecification *fspec;
  NSMutableDictionary  *hints;
  
  if ((count = [_args count]) == 0)
    return [NSNumber numberWithBool:NO];
  if (count == 1)
    return [NSNumber numberWithBool:NO];

  key   = [[_args objectAtIndex:0] stringValue];
  value = [_args objectAtIndex:1];

  if (key == nil)
    return [NSNumber numberWithBool:NO];
  
  if ((fspec = [[self fetchSpecification] copy]) == nil) {
    fspec = [[EOFetchSpecification alloc]
                                   initWithEntityName:nil
                                   qualifier:nil
                                   sortOrderings:nil
                                   usesDistinct:YES isDeep:NO hints:nil];
  }
  fspec = [fspec autorelease];
  
  hints = [[fspec hints] mutableCopy];
  if (hints == nil)
    hints = [[NSMutableDictionary alloc] initWithCapacity:4];
  
  if (![value isNotNull]) {
    /* delete hint */
    [hints removeObjectForKey:key];
  }
  else {
    [hints setObject:value forKey:key];
  }
  
  [fspec setHints:hints];
  [hints release]; hints = nil;
  
  [self setFetchSpecification:fspec];
  
  return [NSNumber numberWithBool:YES];
}
- (id)_jsfunc_getHint:(NSArray *)_args {
  unsigned     count;
  NSDictionary *hints;
  
  if ((count = [_args count]) == 0)
    return nil;
  
  hints = [[self fetchSpecification] hints];
  return [hints objectForKey:[[_args objectAtIndex:0] stringValue]];
}

/* query operation */

- (void)logException:(NSException *)_exception {
  NSLog(@"%s: exception: %@", __PRETTY_FUNCTION__, _exception);
}

- (id)_jsfunc_fetchObjects:(NSArray *)_args {
  EOFetchSpecification *fspec;
  unsigned count;
  id qualifier     = nil;
  id sortOrderings = nil;
  id groupings     = nil;
  id results;
  
  count = [_args count];
  fspec = nil;

  NS_DURING {
    if (count > 0) {
      if ((fspec = [self fetchSpecification]) == nil) {
        fspec = [EOFetchSpecification fetchSpecificationWithEntityName:nil
                                      qualifier:nil
                                      sortOrderings:nil];
      }
      else
        fspec = [[fspec copy] autorelease];
    }
    
    if (count > 0) {
      NSString *qs;
      
      qualifier = [_args objectAtIndex:0];
      if (![qualifier isKindOfClass:[EOQualifier class]]) {
        qs = [qualifier stringValue];
        qualifier = [EOQualifier qualifierWithQualifierFormat:qs];
  #if DEBUG && 0
        NSLog(@"%s: made q %@ for string '%@'",
              __PRETTY_FUNCTION__, qualifier, qs);
  #endif
      }
      
      [fspec setQualifier:qualifier];
    }
    
    if (count > 1) {
      sortOrderings = [_args objectAtIndex:1];
      [fspec setSortOrderings:sortOrderings];
    }
    
    if (count > 2) {
      groupings = [_args objectAtIndex:2];
      // [fspec setGroupings:..];
    }
    
    if (fspec)
      [self setFetchSpecification:fspec];
    
    results = [self fetchObjects];
  }
  NS_HANDLER {
    *(&results) = nil;
    [self logException:localException];
  }
  NS_ENDHANDLER;
  
  return results;
}

/* modification operations */

- (id)_jsfunc_createObject:(NSArray *)_args {
  id obj;

  NS_DURING
    obj = [self createObject];
  NS_HANDLER {
    *(&obj) = nil;
    [self logException:localException];
  }
  NS_ENDHANDLER;
  
  return obj;
}

- (id)_jsfunc_insertObject:(NSArray *)_args {
  unsigned     count;
  NSEnumerator *e;
  id   obj;
  BOOL ok;
  
  if ((count = [_args count]) == 0)
    return [NSNumber numberWithBool:YES];

  e = [_args objectEnumerator];
  ok = YES;
  while ((obj = [e nextObject]) && ok) {
    NS_DURING
      [self insertObject:obj];
    NS_HANDLER {
      ok = NO;
      [self logException:localException];
    }
    NS_ENDHANDLER;
  }
  
  return [NSNumber numberWithBool:ok];
}

- (id)_jsfunc_updateObject:(NSArray *)_args {
  unsigned     count;
  NSEnumerator *e;
  id   obj;
  BOOL ok;
  
  if ((count = [_args count]) == 0)
    return [NSNumber numberWithBool:YES];

  e = [_args objectEnumerator];
  ok = YES;
  while ((obj = [e nextObject]) && ok) {
    NS_DURING
      [self updateObject:obj];
    NS_HANDLER
      ok = NO;
    NS_ENDHANDLER;
  }
  return [NSNumber numberWithBool:ok];
}

- (id)_jsfunc_deleteObject:(NSArray *)_args {
  unsigned     count;
  NSEnumerator *e;
  id   obj;
  BOOL ok;
  
  if ((count = [_args count]) == 0)
    return [NSNumber numberWithBool:YES];

  e = [_args objectEnumerator];
  ok = YES;
  while ((obj = [e nextObject]) && ok) {
    NS_DURING
      [self deleteObject:obj];
    NS_HANDLER {
      ok = NO;
      [self logException:localException];
    }
    NS_ENDHANDLER;
  }
  return [NSNumber numberWithBool:ok];
}

@end /* EOControl(SkyJSDataSourceBehaviour) */
