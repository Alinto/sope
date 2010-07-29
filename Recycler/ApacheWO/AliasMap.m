// $Id: AliasMap.m,v 1.1 2004/06/08 11:06:00 helge Exp $

#include "AliasMap.h"
#include "common.h"

@implementation AliasMap

- (id)initWithCapacity:(unsigned)_capacity {
  self->uri2key  = [[NSMutableDictionary alloc] initWithCapacity:_capacity];
  self->key2uris = [[NSMutableDictionary alloc] initWithCapacity:_capacity];
  self->uris     = [[NSMutableArray alloc] initWithCapacity:_capacity];
  return self;
}
- (id)initWithAliasMap:(AliasMap *)_map {
  self->uri2key  = [_map->uri2key  mutableCopy];
  self->key2uris = [_map->key2uris mutableCopy];
  self->uris     = [_map->uris     mutableCopy];
  return self;
}

- (id)init {
  return [self initWithCapacity:16];
}

- (void)dealloc {
  RELEASE(self->key2uris);
  RELEASE(self->uri2key);
  RELEASE(self->uris);
  [super dealloc];
}

/* modification */

- (BOOL)mapKey:(id)_key toURI:(NSString *)_uri {
  id tmp;
  NSMutableArray *kuris;
  
  if (_uri == nil) return NO;
  if (_key == nil) return NO;
  
  if ((tmp = [self->uri2key objectForKey:_uri]))
    /* already mapped !!! */
    return NO;
  
  [self->uri2key setObject:_key forKey:_uri];
  [self->uris    addObject:_uri];
  
  if ((kuris = [self->key2uris objectForKey:_key]) == nil)
    kuris = [[NSMutableArray alloc] initWithCapacity:4];
  else
    kuris = [kuris mutableCopy];
  
  [kuris addObject:_uri];
  
  [self->key2uris setObject:kuris forKey:_key];
  RELEASE(kuris);
  
  return YES;
}

- (BOOL)addEntriesFromAliasMap:(AliasMap *)_map {
  [self->uri2key  addEntriesFromDictionary:_map->uri2key];
  [self->key2uris addEntriesFromDictionary:_map->key2uris];
  [self->uris     addObjectsFromArray:_map->uris];
  return YES;
}

/* query */

- (NSString *)longestMatchingURIForURI:(NSString *)_uri
  fromArray:(NSArray *)_baseSet  
{
  NSEnumerator *e;
  NSString     *auri, *longest = nil;
  unsigned     max = 0, len;
  
  if ((len = [_uri length]) == 0)
    return nil;
  
  /* foreach registered URI */
  e = [_baseSet objectEnumerator];
  
  while ((auri = [e nextObject])) {
    unsigned l = [auri length];
    
    /* quick precondition: prefix can't be longer than the string .. */
    if (l > len) 
      continue; 
    
    if ([_uri hasPrefix:auri]) {
      if (len == l) /* found an exact match */
	return auri;
      
      if (l > max) { /* found a new longer uri ... */
	longest = auri;
	max = len;
      }
    }
  }
  
  return longest;
}

- (id)keyForURI:(NSString *)_uri {
  NSString *aliasURI;
  
  aliasURI = [self longestMatchingURIForURI:_uri fromArray:self->uris];
  if ([aliasURI length] == 0)
    return nil;
  
  return [self->uri2key objectForKey:aliasURI];
}

- (NSString *)uriForKey:(id)_key baseURI:(NSString *)_uri {
  NSArray  *kuris;
  NSString *aliasURI;
  unsigned kcount;
  
  kuris = [self->key2uris objectForKey:_key];
  if ((kcount = [kuris count] == 0))
    return nil;
  
  if (kcount == 1) /* only one possibility */
    aliasURI = [kuris objectAtIndex:0];
  else {
    aliasURI = [self longestMatchingURIForURI:_uri fromArray:kuris];
    NSAssert(aliasURI != nil, @"no matching URI in structure ???");
  }
  
  return aliasURI;
}

/* copying */

- (id)copyWithZone:(NSZone *)_zone {
  return [[AliasMap alloc] initWithAliasMap:self];
}

@end /* AliasMap */
