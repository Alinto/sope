/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __NGObjWeb_EOFetchSpecification_SoDAV_H__
#define __NGObjWeb_EOFetchSpecification_SoDAV_H__

#import <EOControl/EOFetchSpecification.h>

@class NSString, NSArray;

/*
  Additional WebDAV related methods for EOFetchSpecification. 
  EOFetchSpecification is used to represent PROPFIND and SEARCH queries.
  
  If the selectedWebDAVPropertyNames (= the 'attributes' hint) is empty,
  this designates that a "propall" query is to be done (a SELECT *).
  
  Note: the propertynames are given back as fully qualified XML names, eg
    
    {DAV:}getlastmodified
    
  The namespace is enclosed in the braces.
  
  Mapping of scope:
                depth      from
    flat      - 1,noroot - 'shallow traversal of'
    flat+self - 1        - 
    self      - 0        - 
    deep      - infinity - 'hierarchical traversal of'

  Used hints:
    hint         method
    scope          - scopeOfWebDAVQuery
    attributes     - selectedWebDAVPropertyNames
    namesOnly      - queryWebDAVPropertyNamesOnly
    bulkTargetKeys - davBulkTargetKeys
*/

@interface EOFetchSpecification(SoDAV)

+ (EOFetchSpecification *)parseWebDAVSQLString:(NSString *)_s;

- (NSArray *)selectedWebDAVPropertyNames;
- (NSString *)scopeOfWebDAVQuery; /* flat, deep, self, flat+self */
- (BOOL)queryWebDAVPropertyNamesOnly;
- (NSArray *)davBulkTargetKeys;

@end

#endif /* __NGObjWeb_EOFetchSpecification_SoDAV_H__ */
