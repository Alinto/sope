/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#ifndef __NGObjWeb_SaxDAVHandler_H__
#define __NGObjWeb_SaxDAVHandler_H__

#include <SaxObjC/SaxDefaultHandler.h>

/*
  A SAX handler to parse WebDAV requests ...
  
  The delegate is used to parse (potentially long) responses.
*/

@class NSMutableString, NSMutableArray, NSArray, NSString, NSMutableDictionary;
@class EOFetchSpecification;

@interface SaxDAVHandler : SaxDefaultHandler
{
  id<NSObject,SaxLocator> locator;
  id delegate; /* non-retained */
  
  /* results */
  NSMutableArray *propNames;
  BOOL           findAllProps;
  BOOL           findPropNames;
  NSMutableArray *responses;
  NSString       *searchSQL;
  NSMutableDictionary *propSet;
  EOFetchSpecification *fspec;
  
  /* state */
  id              response;
  NSMutableString *cdata;
  BOOL            ascending;
  NSString        *lastLiteral;
  NSString        *lastWherePropName;
  NSString        *lastScopeHref;
  NSString        *lastScopeDepth;
  NSString        *lastHref;
  NSMutableArray  *targets;
  int             propValueNesting;
  NSMutableArray  *qualifiers;
  NSMutableArray  *compoundQualStack;
  
  /* active tags */
  struct {
    BOOL PropFind:1;
    BOOL Response:1;
    BOOL MultiStatus:1;
    BOOL Href:1;
    BOOL Status:1;
    BOOL Prop:1;
    BOOL PropStat:1;
    BOOL PropertyUpdate:1;
    BOOL Set:1;
    BOOL Remove:1;
    /* bulk */
    BOOL target:1;
    /* DASL */
    BOOL SearchRequest:1;
    BOOL SQL:1;
    BOOL basicsearch:1;
    BOOL select:1;
    BOOL from:1;
    BOOL scope:1;
    BOOL depth:1;
    BOOL where:1;
    BOOL gt:1;
    BOOL lt:1;
    BOOL gte:1;
    BOOL lte:1;
    BOOL eq:1;
    BOOL literal:1;
    BOOL orderby:1;
    BOOL order:1;
    BOOL ascending:1;
    BOOL like:1;
  } in;
}

/* accessors */

- (void)setDelegate:(id)_delegate;
- (id)delegate;

/* cleanup */

- (void)reset;

/* propfind results */

- (BOOL)propFindAllProperties;
- (BOOL)propFindPropertyNames;
- (NSArray *)propFindQueriedNames;
- (NSArray *)bpropFindTargets;

/* proppatch results */

- (NSArray *)propPatchPropertyNamesToRemove;
- (NSDictionary *)propPatchValues;

/* search query results */

- (EOFetchSpecification *)searchFetchSpecification;

@end

@interface NSObject(SaxDAVHandlerDelegate)

- (void)davHandler:(SaxDAVHandler *)_handler
  receivedProperties:(NSDictionary *)_record
  forURI:(NSString *)_uri;

@end

#endif /* __NGObjWeb_SaxDAVHandler_H__ */
