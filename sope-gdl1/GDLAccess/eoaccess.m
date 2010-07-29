/* 
   EOAdaptorChannel.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: October 1996

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
// $Id: eoaccess.m 1 2004-08-20 10:38:46Z znek $

#include "GDLAccess.h"
#include "EOArrayProxy.h"

@implementation GDLAccess

- (void)_staticLinkClasses {
  [EOAdaptor                        class];
  [EOAdaptorChannel                 class];
  [EOAdaptorContext                 class];
  [EOArrayProxy                     class];
  [EOAttribute                      class];
  [EOAttributeOrdering              class];
  [EODatabase                       class];
  [EODatabaseChannel                class];
  [EODatabaseContext                class];
  [EOEntity                         class];
  [EOFException                     class];
  [ObjectNotAvailableException      class];
  [PropertyDefinitionException      class];
  [DestinationEntityDoesntMatchDefinitionException class];
  [InvalidNameException             class];
  [InvalidPropertyException         class];
  [RelationshipMustBeToOneException class];
  [InvalidValueTypeException        class];
  [InvalidAttributeException        class];
  [InvalidQualifierException        class];
  [EOAdaptorException               class];
  [CannotFindAdaptorBundleException class];
  [InvalidAdaptorBundleException    class];
  [InvalidAdaptorStateException     class];
  [DataTypeMappingNotSupportedException class];
  [ChannelIsNotOpenedException      class];
  [AdaptorIsFetchingException       class];
  [AdaptorIsNotFetchingException    class];
  [NoTransactionInProgressException class];
  [TooManyOpenedChannelsException   class];
  [EOModel                          class];
  [EOObjectUniquer                  class];
  [EOPrimaryKeyDictionary           class];
  [EOSQLQualifier                   class];
  [EOQuotedExpression               class];
  [EORelationship                   class];
  [EOSQLExpression                  class];
#if 0
  [EOSelectSQLExpression            class];
  [EOInsertSQLExpression            class];
  [EOUpdateSQLExpression            class];
  [EODeleteSQLExpression            class];
#endif
}

- (void)_staticLinkCategories {
}

- (void)_staticLinkModules {
}

@end /* GDLAccess */
