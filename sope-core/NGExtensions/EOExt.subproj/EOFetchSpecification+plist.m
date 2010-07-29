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

#include <NGExtensions/EOFetchSpecification+plist.h>
#import <EOControl/EOControl.h>
#include "common.h"

@implementation EOFetchSpecification(plist)

- (id)initWithDictionary:(NSDictionary *)_dictionary {
  if ((self = [self init]) != nil) {
    id tmp;

    // TODO: add groupings
    
    if ((tmp = [_dictionary objectForKey:@"qualifier"]) != nil) {
      if ([tmp isKindOfClass:[NSDictionary class]])
        tmp = [EOQualifier qualifierToMatchAllValues:tmp];
      else
        tmp = [EOQualifier qualifierWithQualifierFormat:tmp];
      
      [self setQualifier:tmp];
    }
    
    if ((tmp = [_dictionary objectForKey:@"sortOrderings"]) != nil) {
      NSArray        *sos = nil;
      EOSortOrdering *so;
      
      if ([tmp isKindOfClass:[NSArray class]]) {
        NSMutableArray *result  = nil;
        NSEnumerator   *objEnum;
        id             obj;
        
        objEnum = [tmp objectEnumerator];
        result = [NSMutableArray arrayWithCapacity:8];
        while ((obj = [objEnum nextObject])) {
          so = [[EOSortOrdering alloc] initWithPropertyList:obj owner:nil];
          [so autorelease];
          if (so)
            [result addObject:so];
        }
        sos = [[NSArray alloc] initWithArray:result];
      }
      else {
        so = [[[EOSortOrdering alloc] initWithPropertyList:tmp owner:nil] 
                               autorelease];
          
        if (so != nil) sos = [[NSArray alloc] initWithObjects:&so count:1];
      }
      if (sos != nil) [self setSortOrderings:sos];
      [sos release];
    }
    
    if ((tmp = [_dictionary objectForKey:@"fetchLimit"]) != nil) {
      if ([tmp respondsToSelector:@selector(intValue)])
        [self setFetchLimit:[tmp intValue]];
      else
        NSLog(@"%s: invalid fetchLimit key !", __PRETTY_FUNCTION__);
    }
    
    if ((tmp = [_dictionary objectForKey:@"hints"])) {
      if ([tmp isKindOfClass:[NSDictionary class]])
        [self setHints:tmp];
      else
        NSLog(@"%s: invalid hints key !", __PRETTY_FUNCTION__);
    }
    
    if ([[self hints] objectForKey:@"addDocumentsAsObserver"] == nil) {
      NSMutableDictionary *hnts;

      hnts = [[NSMutableDictionary alloc] initWithDictionary:[self hints]];
      [hnts setObject:[NSNumber numberWithBool:NO]
            forKey:@"addDocumentsAsObserver"];
      [self setHints:hnts];
      [hnts release];
    }
  }
  return self;
}
- (id)initWithString:(NSString *)_string {
  EOQualifier *q;
  
  q = [EOQualifier qualifierWithQualifierFormat:_string];
  
  return [self initWithEntityName:nil
               qualifier:q
               sortOrderings:nil
               usesDistinct:NO isDeep:NO hints:nil];
}

- (id)initWithPropertyList:(id)_plist owner:(id)_owner {
  if ([_plist isKindOfClass:[NSDictionary class]])
    return [self initWithDictionary:_plist];
  
  if ([_plist isKindOfClass:[NSString class]])
    return [self initWithString:_plist];
  
  if ([_plist isKindOfClass:[self class]]) {
    [self release];
    return [_plist copy];
  }

  [self release];
  return nil;
}
- (id)initWithPropertyList:(id)_plist {
  return [self initWithPropertyList:_plist owner:nil];
}

@end /* EOFetchSpecification(plist) */
