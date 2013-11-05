/* 
   EOFExceptions.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: August 1996

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

#import "common.h"
#import "EOFExceptions.h"
#import "EOEntity.h"
#import "EORelationship.h"

@implementation EOFException
@end /* EOFException */


@implementation ObjectNotAvailableException

- initWithEntity:entity andPrimaryKey:key {
    id _reason = [NSString stringWithFormat:@"A to-one relation could not be "
                            @"resolved for entity %@ and primary key %@",
                            [(EOEntity*)entity name], [key description]];

    [self initWithName:@"NSObjectNotAvailableException"
                    reason:_reason userInfo:nil];
    return self;
}

@end /* ObjectNotAvailableException */


@implementation PropertyDefinitionException
@end /* PropertyDefinitionException */


@implementation DestinationEntityDoesntMatchDefinitionException

- initForDestination:(EOEntity*)destinationEntity
  andDefinition:(NSString*)definition
  relationship:(EORelationship*)relationship
{
    id _reason = [NSString stringWithFormat:@"destination entity '%@' does not"
                            @" match definition '%@' in relationship '%@'",
                            [destinationEntity name],
                            definition,
                            [relationship name]];
    [self initWithName:NSStringFromClass(isa)
            reason:_reason userInfo:nil];
    return self;
}
@end /* DestinationEntityDoesntMatchDefinitionException */


@implementation InvalidNameException
- initWithName:(NSString*)_name
{
    id _reason = [NSString stringWithFormat:@"invalid name: '%@'", _name];
    [self initWithName:NSStringFromClass(isa) reason:_reason userInfo:nil];
    return self;
}
@end /* InvalidNameException */


@implementation InvalidPropertyException
- initWithName:propertyName entity:currentEntity
{
    id _reason = [NSString stringWithFormat:@"property '%@' does not exist in "
                            @"entity '%@'", propertyName,
                            [(EOEntity*)currentEntity name]];
    [self initWithName:NSStringFromClass(isa)
            reason:_reason userInfo:nil];
    return self;
}
@end /* InvalidPropertyException */


@implementation RelationshipMustBeToOneException
- initWithName:propertyName entity:currentEntity
{
    id _reason = [NSString stringWithFormat:@"property '%@' must be to one in "
                    @"entity '%@' to allow flattened attribute",
                    propertyName, [(EOEntity*)currentEntity name]];
    [self initWithName:NSStringFromClass(isa)
            reason:_reason userInfo:nil];
    return self;
}
@end /* RelationshipMustBeToOneException */


@implementation InvalidValueTypeException
- initWithType:type
{
    id _reason = [NSString stringWithFormat:@"unknow value type '%@'", type];
    [self initWithName:@"InvalidValueTypeException"
            reason:_reason userInfo:nil];
    return self;
}
@end


@implementation InvalidAttributeException
@end /* InvalidAttributeException */


@implementation InvalidQualifierException
@end /* InvalidQualifierException */


@implementation EOAdaptorException
@end /* EOAdaptorException */


@implementation CannotFindAdaptorBundleException
@end /* CannotFindAdaptorBundleException */


@implementation InvalidAdaptorBundleException
@end /* InvalidAdaptorBundleException */


@implementation InvalidAdaptorStateException
+ exceptionWithAdaptor:(id)_adaptor
{
    InvalidAdaptorStateException* exception = [self alloc];
    exception->adaptor = _adaptor;
    return exception;
}
@end /* InvalidAdaptorStateException */


@implementation DataTypeMappingNotSupportedException
@end /* DataTypeMappingNotSupportedException */


@implementation ChannelIsNotOpenedException
@end /* ChannelIsNotOpenedException */


@implementation AdaptorIsFetchingException
@end /* AdaptorIsFetchingException */


@implementation AdaptorIsNotFetchingException
@end /* AdaptorIsNotFetchingException */


@implementation NoTransactionInProgressException
@end /* NoTransactionInProgressException */


@implementation TooManyOpenedChannelsException
@end /* TooManyOpenedChannelsException */
