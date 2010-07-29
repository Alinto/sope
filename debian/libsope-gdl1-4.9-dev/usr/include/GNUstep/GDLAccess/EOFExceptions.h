/* 
   EOFExceptions.h

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

#ifndef __EOFExceptions_h__
#define __EOFExceptions_h__

#import <Foundation/NSException.h>

@class NSString;
@class EOEntity;
@class EORelationship;
@class EOAdaptorChannel;

@interface EOFException : NSException
@end

@interface ObjectNotAvailableException : EOFException
- initWithEntity:entity andPrimaryKey:key;
@end

@interface PropertyDefinitionException : EOFException
@end

@interface DestinationEntityDoesntMatchDefinitionException
		: PropertyDefinitionException
- initForDestination:(EOEntity*)destinationEntity
	andDefinition:(NSString*)definition
	relationship:(EORelationship*)relationship;
@end

@interface InvalidNameException : PropertyDefinitionException
- initWithName:(NSString*)name;
@end

@interface InvalidPropertyException : PropertyDefinitionException
- initWithName:propertyNamed entity:currentEntity;
@end

@interface RelationshipMustBeToOneException : PropertyDefinitionException
- initWithName:propertyNamed entity:currentEntity;
@end

@interface InvalidValueTypeException : PropertyDefinitionException
- initWithType:type;
@end

@interface InvalidAttributeException : EOFException
@end

@interface InvalidQualifierException : EOFException
@end

@interface EOAdaptorException : EOFException
@end

@interface CannotFindAdaptorBundleException : EOAdaptorException
@end

@interface InvalidAdaptorBundleException : EOAdaptorException
@end

@interface InvalidAdaptorStateException : EOAdaptorException
{
    id adaptor;
}
+ exceptionWithAdaptor:(id)adaptor;
@end

@interface DataTypeMappingNotSupportedException : EOAdaptorException
@end

@interface ChannelIsNotOpenedException : InvalidAdaptorStateException
@end

@interface AdaptorIsFetchingException : InvalidAdaptorStateException
@end

@interface AdaptorIsNotFetchingException : InvalidAdaptorStateException
@end

@interface NoTransactionInProgressException : InvalidAdaptorStateException
@end

@interface TooManyOpenedChannelsException : EOAdaptorException
@end

#endif /* __EOFExceptions_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
