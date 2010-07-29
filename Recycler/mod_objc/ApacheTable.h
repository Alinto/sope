// $Id: ApacheTable.h,v 1.1 2004/06/08 11:15:59 helge Exp $

#ifndef __ApacheTable_H__
#define __ApacheTable_H__

#include "ApacheObject.h"

@interface ApacheTable : ApacheObject
{
}

/* query */

- (id)objectForKey:(NSString *)_key;

/* modification */

- (void)setObject:(id)_obj forKey:(NSString *)_key;

- (void)mergeObject:(id)_obj forKey:(NSString *)_key;
- (void)addObject:(id)_obj forKey:(NSString *)_key;

- (void)removeAllObjects;
- (void)removeObjectForKey:(NSString *)_key;

@end

#endif /* __ApacheTable_H__ */
