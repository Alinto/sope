// $Id: EOGenericRecord.h 1 2004-08-20 10:38:46Z znek $

#ifndef __eoaccess_EOGenericRecord_H__
#define __eoaccess_EOGenericRecord_H__

#import <EOControl/EOGenericRecord.h>

@class NSDictionary;
@class EOEntity;

@interface EOGenericRecord(EOAccess)

// Initializing new instances

- (id)initWithPrimaryKey:(NSDictionary *)aKey entity:(EOEntity *)anEntity;

// Getting the associated entity

- (EOEntity *)entity;

@end

/*
 * Informal protocol. NOT implemented by NSObject.
 * Before sending one of this messages the caller must
 * check if the object responds to them.
 */

@interface NSObject(EOGenericRecord)

/*
 * Initialize an new instance of an object. 
 * If an enterprise object does not respond
 * to this method it will receive -init.
 */
- (id)initWithPrimaryKey:(NSDictionary *)key entity:(EOEntity *)entity;

/*
 * Determines the entity of user defined objects, 
 * when more than one entity uses the same class for its objects.
 */
- (EOEntity *)entity;

/*
 * Determine the class for object based on its fetched row. 
 * The returned class *must* be a subclass of the class that 
 * receives this method.
 */
+ (Class)classForEntity:(EOEntity *)entity values:(NSDictionary *)values;

@end

#endif /* __eoaccess_EOGenericRecord_H__ */

