// $Id: NSObject+EONullInit.h 1 2004-08-20 10:38:46Z znek $

#ifndef __GDLAccess_NSObject_EONull_H__
#define __GDLAccess_NSObject_EONull_H__

#import <Foundation/NSObject.h>
#import <GDLAccess/EONull.h>

@class EOEntity;

@interface NSObject(EONullInit)

- (void)setAllAttributesToEONull:(EOEntity *)_entity;
- (void)setAllAttributesToEONull; // assume the object respondsTo: entity

@end

#endif /* __GDLAccess_NSObject_EONull_H__ */
