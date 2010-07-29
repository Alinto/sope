/* 
   EOAdaptorDataSource.h
   
   Copyright (C) SKYRIX Software AG and Helge Hess

   Author: Helge Hess (helge.hess@opengroupware.org)
   Date:   1999-2004

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
// $Id: EOAdaptorDataSource.h 1 2004-08-20 10:38:46Z znek $

#ifndef __EOAdaptorDataSource_h__
#define __EOAdaptorDataSource_h__

#import <EOControl/EODataSource.h>

@class NSArray, NSDictionary;
@class EOFetchSpecification, EOAdaptorChannel, EOQualifier;

/*
  Fetch dictionaries from database tables.
  The tablename has to be set in [FetchSpecification entityName].
  Qualifier, sortOrdering, distinct will be evaluated.
  It handles now tables with more than one primary key.
  Its possible to set the primary key in the fetchspecification hints
  (EOPrimaryKeyAttributeNamesHint -> array with strings as columnnames
  for the PKeys; EOPrimaryKeyAttributesHint -> array with EOAttributes for
  the PKeys).
  If no primary key is set, and now primary key could find in the table
  schema, all keys will be taken as primary keys.
  If only one primary key exsist, in insert object a new key will be generatet,
  else all keys has to be set.
  If fetch hint EOFetchResultTimeZone is set (NSTimeZone), this timezone will
  be set in date objectes.
*/

extern NSString *EOPrimaryKeyAttributeNamesHint;
extern NSString *EOPrimaryKeyAttributesHint;
extern NSString *EOFetchResultTimeZone;

@interface EOAdaptorDataSource : EODataSource
{
@private
  EOFetchSpecification *fetchSpecification;
@protected
  EOAdaptorChannel     *adChannel;
  EOQualifier          *__qualifier;
  NSArray              *__attributes;
  BOOL                 commitTransaction;
  NSDictionary         *connectionDictionary;
}

- (id)initWithAdaptorChannel:(EOAdaptorChannel *)_channel;

- (id)initWithAdaptorChannel:(EOAdaptorChannel *)_channel
  connectionDictionary:(NSDictionary *)_connDict;

- (id)initWithAdaptorName:(NSString *)_adName
  connectionDictionary:(NSDictionary *)_dict
  primaryKeyGenerationDictionary:(NSDictionary *)_pkGen;  


/*
  Returns an array with dictionaries, who contains key/values from the
  entity (use entityName/qualifier/sortOrdering). 
  Also it contains an key named 'globalID'. If EOAdaptorDataSource is
  initialized with initWithAdaptorChannel the globaID is an EOKeyGlobalID
  else if it is initialized with initWithAdaptorName the globalID is and
  EOAdaptorGlobalID.
*/
- (NSArray *)fetchObjects;

/*
  returns an mutable dictionary 
*/
- (id)createObject;

- (void)insertObject:(id)_obj;
- (void)deleteObject:(id)_obj;
- (void)updateObject:(id)_obj;
 
- (void)setFetchSpecification:(EOFetchSpecification *)_fs;
- (EOFetchSpecification *)fetchSpecification;

/* for subclasses */
- (EOAdaptorChannel *)beginTransaction;
- (void)commitTransaction;
- (void)rollbackTransaction;

- (void)openChannel;
- (void)closeChannel;
@end

#endif /* __EOAdaptorDataSource_h__ */
