//$Id: EOAdaptorChannel+Attributes.h 1 2004-08-20 10:38:46Z znek $

#ifndef __EOAdaptorChannel_Attributes_h__
#define __EOAdaptorChannel_Attributes_h__

@class NSString, NSArray;

#import <GDLAccess/EOAdaptorChannel.h>

@interface EOAdaptorChannel(Attributes)

- (NSArray *)attributesForTableName:(NSString *)_tableName;
- (NSArray *)primaryKeyAttributesForTableName:(NSString *)_tableName;

@end

#endif /* __EOAdaptorChannel_Attributes_h__ */
