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

#include "NGLdapDataSource.h"
#include "NGLdapEntry.h"
#include "NGLdapAttribute.h"
#include "NGLdapConnection.h"
#import <NGExtensions/NGFileFolderInfoDataSource.h>
#import <EOControl/EOControl.h>
#include "common.h"

@implementation NGLdapDataSource

- (id)initWithLdapConnection:(NGLdapConnection *)_con searchBase:(NSString *)_dn{
  if (_con == nil) {
    [self release];
    return nil;
  }
  if ((self = [super init])) {
    self->ldap       = [_con retain];
    self->searchBase = [_dn copy];
  }
  return self;
}

- (void)dealloc {
  [self->searchBase release];
  [self->fspec      release];
  [self->ldap       release];
  [super dealloc];
}

- (void)setFetchSpecification:(EOFetchSpecification *)_fspec {
  /* should invalidate ds chain */
  ASSIGN(self->fspec, _fspec);
}
- (EOFetchSpecification *)fetchSpecification {
  return self->fspec;
}

/* transformation */

- (NSDictionary *)_recordFromEntry:(NGLdapEntry *)_entry {
  NSMutableDictionary *md;
  NSEnumerator        *keys;
  NSString            *key;
  id tmp;
  
  if (_entry == nil)
    return nil;
  
  md = [NSMutableDictionary dictionaryWithCapacity:[_entry count]];
  
  if ((tmp = [_entry dn])) {
    [md setObject:tmp forKey:@"NSFileIdentifier"];
    [md setObject:tmp forKey:NSFilePath];
  }
  if ((tmp = [_entry rdn]))
    [md setObject:tmp forKey:NSFileName];
  
  keys = [[_entry attributeNames] objectEnumerator];
  
  while ((key = [keys nextObject])) {
    NGLdapAttribute *attribute;
    unsigned count;
    id value;
    
    attribute = [_entry attributeWithName:key];
    count     = [attribute count];
    
    if (count == 0)
      value = [EONull null];
    else if (count == 1)
      value = [attribute stringValueAtIndex:0];
    else
      value = [attribute allStringValues];

    [md setObject:value forKey:key];
  }

  return [[md copy] autorelease];
}

/* operations */

- (NSArray *)fetchObjects { // TODO: use the new fetch-enumerator
  NSAutoreleasePool *pool;
  NSString       *scope;
  EOQualifier    *qualifier;
  NSArray        *sortOrderings;
  NSEnumerator   *e;
  NSString       *baseDN;
  NSMutableArray *results;
  NGLdapEntry    *entry;
  NSArray        *array;
  NSArray        *attrs;

  pool = [NSAutoreleasePool new];
  
  scope         = nil;
  qualifier     = nil;
  sortOrderings = nil;
  baseDN        = nil;
  attrs         = nil;
  
  if (self->fspec) {
    NSString *entityName;
    
    qualifier     = [self->fspec qualifier];
    sortOrderings = [self->fspec sortOrderings];
    scope         = [[self->fspec hints] objectForKey:@"NSFetchScope"];
    attrs         = [[self->fspec hints] objectForKey:@"NSFetchKeys"];

    if ((entityName = [self->fspec entityName])) {
      EOQualifier *oq;

      oq = [[EOKeyValueQualifier alloc]
                                 initWithKey:@"objectclass"
                                 operatorSelector:EOQualifierOperatorEqual
                                 value:entityName];
      if (qualifier) {
        NSArray *qa;
        
        qa = [NSArray arrayWithObjects:oq, qualifier, nil];
        qualifier = [[EOAndQualifier alloc] initWithQualifierArray:qa];
        qualifier = [qualifier autorelease];
        [oq release]; oq = nil;
      }
      else {
        qualifier = [oq autorelease];
        oq = nil;
      }
    }
  }
  else {
    static NSArray *so = nil;
    if (so == nil) {
      EOSortOrdering *o;
      o = [EOSortOrdering sortOrderingWithKey:@"NSFileIdentifier"
			  selector:EOCompareAscending];
      so = [[NSArray alloc] initWithObjects:&o count:1];
    }
    sortOrderings = so;
  }
  
  if (scope == nil)
    scope = @"NSFetchScopeOneLevel";
  if (baseDN == nil)
    baseDN = self->searchBase;

  if ([scope isEqualToString:@"NSFetchScopeOneLevel"]) {
    e = [self->ldap flatSearchAtBaseDN:baseDN
                    qualifier:qualifier
                    attributes:attrs];
  }
  else if ([scope isEqualToString:@"NSFetchScopeSubTree"]) {
    e = [self->ldap deepSearchAtBaseDN:baseDN
                    qualifier:qualifier
                    attributes:attrs];
  }
  else {
    [NSException raise:@"NGLdapDataSourceException"
                 format:@"unsupported fetch-scope: '%@' !", scope];
    e = nil;
  }
  
  if (e == nil) {
    /* no results */
    [pool release];
    return nil;
  }

  /* transform results into records */
  
  results = [NSMutableArray arrayWithCapacity:64];
  while ((entry = [e nextObject])) {
    NSDictionary *record;

    if ((record = [self _recordFromEntry:entry]) == nil) {
      NSLog(@"WARNING: couldn't transform entry %@ into record !", entry);
      continue;
    }
    
    [results addObject:record];
  }
  array = [[results copy] autorelease];
  
  /* apply sort-orderings in-memory */
  if (sortOrderings)
    array = [array sortedArrayUsingKeyOrderArray:sortOrderings];

  array = [array retain];
  [pool release];
  
  return [array autorelease];
}

- (NSString *)searchBase {
  return self->searchBase;
}


@end /* NGLdapDataSource */
