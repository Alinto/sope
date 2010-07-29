/* 
   FBChannel.h

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge.hess@mdlink.de)

   This file is part of the FB Adaptor Library

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
// $Id: FBChannel.h 1 2004-08-20 10:38:46Z znek $

#ifndef ___FB_Channel_H___
#define ___FB_Channel_H___

#import <GDLAccess/EOAdaptorChannel.h>
#import "FBHeaders.h"

@class NSArray, NSString, NSMutableDictionary;

struct _FBColumnData;

@interface FrontBaseChannel : EOAdaptorChannel
{
@public
  /* connection is valid after an openChannel call */
  FBCDatabaseConnection *fbdc;
  void                  **rawRows;
  FBCRowHandler         *rowHandler;
  FBCMetaData           *cmdMetaData;
  char                  *fetchHandle;
  BOOL                  isFirstInBatch;

  /* these variables are valid only during an evaluation */
  int                currentRow;
  int                numberOfColumns; // number of columns in result set
  int                *datatypeCodes;
  int                rowsAffected;
  unsigned           txVersion;
  NSArray            *selectedAttributes; // contains the real select order

  /* turns on/off channel debugging */
  BOOL isDebuggingEnabled;
  NSString *sqlLogFile;

  /* caching */
  NSMutableDictionary *_primaryKeysNamesForTableName;
  NSMutableDictionary *_attributesForTableName;
}

- (void)setDebugEnabled:(BOOL)_flag;
- (BOOL)isDebugEnabled;

- (BOOL)isOpen;
- (BOOL)openChannel;
- (void)closeChannel;
- (void)primaryCloseChannel; // private

- (NSMutableDictionary *)primaryFetchAttributes:(NSArray *)_attributes
  withZone:(NSZone *)_zone;

- (BOOL)evaluateExpression:(NSString *)_expression;

// cancelFetch is always called to terminate a fetch
// (even by primaryFetchAttributes)
// it frees all fetch-local variables
- (void)cancelFetch;

// uses type information to create EOAttribute objects
- (NSArray *)describeResults;

@end

#endif
