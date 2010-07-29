// $Id: AliasMap.h,v 1.1 2004/06/08 11:06:00 helge Exp $

#ifndef __AliasMap_H__
#define __AliasMap_H__

#import <Foundation/NSObject.h>

/*
  An alias-map maps some kind of key to a URI. During lookups the
  URI is processed to find the longest matching prefix.
  
  Note: a URI may be mapped to only one key, but a key can be mapped
  to multiple URIs ! (key<->URI is 1:n)
*/

@class NSMutableDictionary, NSMutableArray;

@interface AliasMap : NSObject < NSCopying >
{
  NSMutableArray      *uris;
  NSMutableDictionary *uri2key;
  NSMutableDictionary *key2uris;
}

- (id)initWithCapacity:(unsigned)_capacity;
- (id)initWithAliasMap:(AliasMap *)_map;

/* modification */

- (BOOL)mapKey:(id)_key toURI:(NSString *)_uri;
- (BOOL)addEntriesFromAliasMap:(AliasMap *)_map;

/* query */

- (id)keyForURI:(NSString *)_uri;
- (NSString *)uriForKey:(id)_key baseURI:(NSString *)_uri;

@end

#endif /* __AliasMap_H__ */
