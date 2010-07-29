// $Id: EOEntity+Factory.h 1 2004-08-20 10:38:46Z znek $

#ifndef __GDLAccess_EOEntity_Factory_H__
#define __GDLAccess_EOEntity_Factory_H__

#import <GDLAccess/EOEntity.h>

@class NSDictionary;
@class EOAttribute;

@interface EOEntity(AttributeNames)

- (NSArray *)attributeNames;

@end

@interface EOEntity(PrimaryKeys)

- (BOOL)isPrimaryKeyAttribute:(EOAttribute *)_attribute;
- (unsigned)primaryKeyCount;

@end

@interface EOEntity(ObjectFactory)

- (id)produceNewObjectWithPrimaryKey:(NSDictionary *)_key;
- (void)setAttributesOfObjectToEONull:(id)_object;

@end

#endif /* __GDLAccess_EOEntity_Factory_H__ */
