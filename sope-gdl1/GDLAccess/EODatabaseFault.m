/* 
   EODatabaseFault.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
   Date: 1996

   Author: Helge Hess <helge.hess@mdlink.de>
   Date: 1999

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#import "EODatabaseFault.h"
#import "EODatabase.h"
#import "EODatabaseChannel.h"
#import "EOEntity.h"
#import "EOFExceptions.h"
#import "EODatabaseFaultResolver.h"
#import "EOArrayProxy.h"
#import "common.h"

#if NeXT_RUNTIME || APPLE_RUNTIME
#  include <objc/objc-class.h>
#endif

typedef struct {
    Class isa;
} *my_objc_object;

#define object_is_instance(object) \
    ((object!=nil)&&CLS_ISCLASS(((my_objc_object)object)->isa))

/*
 * EODatabaseFault class
 */

@implementation EODatabaseFault

// Fault class methods

+ (id)objectFaultWithPrimaryKey:(NSDictionary *)key
  entity:(EOEntity *)entity 
  databaseChannel:(EODatabaseChannel *)channel
  zone:(NSZone *)zone
{
    EODatabaseFault *fault = nil;
    
    fault = [channel allocateObjectForRow:key entity:entity zone:zone];
    
    if (fault == nil)
        return nil;
#if defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__) 
    if (class_getInstanceSize([fault class]) < class_getInstanceSize([self class])) {
#else
	if ([fault class]->instance_size < ((Class)self)->instance_size) {
#endif
        [fault autorelease];
	[NSException raise:NSInvalidArgumentException
		     format:
		       @"Instances from class %@ must be at least %d in size "
		       @"to fault",
		       NSStringFromClass([fault class]),
#if defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
		       class_getInstanceSize([self class])];
#else
			   ((Class)self)->instance_size];
#endif
    }
    fault->faultResolver = [[EOObjectFault alloc] initWithPrimaryKey:key
        entity:entity databaseChannel:channel zone:zone 
        targetClass:fault->isa];
    fault->isa = self;
    
    return (EODatabaseFault *)AUTORELEASE(fault);
}

+ (NSArray*)arrayFaultWithQualifier:(EOSQLQualifier*)qualifier 
  fetchOrder:(NSArray*)fetchOrder 
  databaseChannel:(EODatabaseChannel*)channel
  zone:(NSZone*)zone
{
  return [EOArrayProxy arrayProxyWithQualifier:qualifier
                       fetchOrder:fetchOrder
                       channel:channel];
#if 0
    EODatabaseFault* fault;
    
    fault = [NSMutableArray allocWithZone:zone];

    if ([fault class]->instance_size < ((Class)(self))->instance_size) {
        (void)AUTORELEASE(fault);
        THROW([[InvalidArgumentException alloc]
                initWithFormat:
                    @"Instances from class %s must be at least %d "
                    @"in size to fault",
                    NSStringFromClass([fault class]),
                    ((Class)self)->instance_size]);
    }
    fault->faultResolver = [[EOArrayFault alloc] initWithQualifier:qualifier
        fetchOrder:fetchOrder databaseChannel:channel zone:zone 
        targetClass:fault->isa fault:fault];
    fault->isa = self;

    return (NSArray*)AUTORELEASE(fault);
#endif
}

// no more garbage collecting
+ (NSArray *)gcArrayFaultWithQualifier:(EOSQLQualifier *)qualifier 
  fetchOrder:(NSArray *)fetchOrder 
  databaseChannel:(EODatabaseChannel *)channel
  zone:(NSZone *)zone
{
  EODatabaseFault *fault;
    
  fault = [NSMutableArray allocWithZone:zone];

#if defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__) 
  if (class_getInstanceSize([fault class]) < class_getInstanceSize([self class])) {
#else
  if ([fault class]->instance_size < ((Class)(self))->instance_size) {
#endif
        (void)[fault autorelease];
	[NSException raise:NSInvalidArgumentException
		     format:
                    @"Instances from class %s must be at least %d "
                    @"in size to fault",
                    NSStringFromClass([fault class]),
#if defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__) 
                    class_getInstanceSize([self class])];
#else
					((Class)self)->instance_size];
#endif
  }
  fault->faultResolver = [[EOArrayFault alloc] initWithQualifier:qualifier
        fetchOrder:fetchOrder databaseChannel:channel zone:zone 
        targetClass:fault->isa];
  fault->isa = self;

  return (NSArray *)AUTORELEASE(fault);
}

+ (NSDictionary *)primaryKeyForFault:(id)fault {
  EODatabaseFault *aFault = (EODatabaseFault *)fault;

  // Check that argument is fault
  if (aFault->isa != self)
    return nil;
    
  return [(EODatabaseFaultResolver *)aFault->faultResolver primaryKey];
}

+ (EOEntity *)entityForFault:(id)fault {
  EODatabaseFault *aFault = (EODatabaseFault *)fault;

  // Check that argument is fault
  if (aFault->isa != self)
    return nil;

  return [(EODatabaseFaultResolver *)aFault->faultResolver entity];
}

+ (EOSQLQualifier *)qualifierForFault:(id)fault {
  EODatabaseFault *aFault = (EODatabaseFault *)fault;

  // Check that argument is fault
  if (aFault->isa != self)
    return nil;
    
  return [(EODatabaseFaultResolver *)aFault->faultResolver qualifier];
}

+ (NSArray *)fetchOrderForFault:(id)fault {
  EODatabaseFault *aFault = (EODatabaseFault *)fault;

  // Check that argument is fault
  if (aFault->isa != self)
    return nil;
    
  return [(EODatabaseFaultResolver *)aFault->faultResolver fetchOrder];
}

+ (EODatabaseChannel *)databaseChannelForFault:fault {
  EODatabaseFault *aFault = (EODatabaseFault *)fault;

  // Check that argument is fault
  if (aFault->isa != self)
    return nil;
    
  return [(EODatabaseFaultResolver *)aFault->faultResolver databaseChannel];
}

- (void)dealloc {
  [EODatabase forgetObject:self];
  [super dealloc];
}

// Forwarding stuff

+ (void)initialize {
  // Must be here as initialize is called for each root class
  // without asking if it responds to it !
}

- (EOEntity *)entity {
  return [EODatabaseFault entityForFault:self];
}

@end /* EODatabaseFault */

/*
 * Informal protocol that informs an instance that a to-one
 * relationship could not be resoved to get data for self.
 * Its implementation in NSObject raises NSObjectNotAvailableException. 
 */

@implementation NSObject(EOUnableToFaultToOne)

- (void)unableToFaultWithPrimaryKey:(NSDictionary*)key 
  entity:(EOEntity*)entity 
  databaseChannel:(EODatabaseChannel*)channel
{
    // TODO - throw exception form derived class
    [[[ObjectNotAvailableException alloc]
            initWithFormat:@"cannot fault to-one for primary key %@ entity %@",
                            [key description], [entity name]] raise];
}

@end /* NSObject(EOUnableToFaultToOne) */

@implementation EOFault(EOUnableToFaultToOne)

- (void)unableToFaultWithPrimaryKey:(NSDictionary*)key 
  entity:(EOEntity *)entity 
  databaseChannel:(EODatabaseChannel*)channel
{
  // TODO - throw exception from derived class
  [[[ObjectNotAvailableException alloc]
     initWithFormat:@"cannot fault to-one for primary key %@ entity %@",
       [key description], [entity name]] 
     raise];
}

@end /* EOFault(EOUnableToFaultToOne) */
