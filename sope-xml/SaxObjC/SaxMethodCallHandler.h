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

#ifndef __SaxMethodCallHandler_H__
#define __SaxMethodCallHandler_H__

#include <SaxObjC/SaxDefaultHandler.h>
#import <Foundation/NSMapTable.h>

@class NSString, NSMutableArray, NSMutableDictionary;

/*
  [also take a look at SaxObjectDecoder]
  
  This handler calls a method on a delegate for each tag. The selector is
  constructed this way:
  
    [start|end] + nskey + tagname + ':'

  If no method could be found for the tag, it is first checked whether the
  delegate responds to

    [start|end] + nskey + 'unknownTag:attributes:'

  and it this couldn't be found, it is checked for

    [start|end] + 'tag:_tagName namespace:_ns attributes:'

  If no key could be found for a namespace, it is first checked whether the
  delegate responds to

    [start|end] + 'any_' + tagname + ':'

  if this fails it is checked for this selector

    [start|end] + 'tag:_tagName namespace:_ns attributes:'

  if neither exists, the tag is ignored.
  
  Eg:

    nskey='xhtml' startKey='start_' endKey='end_'
    - (void)start_xhtml_br:(id<SaxAttributes>)_attrs;
    - (void)end_xhtml_br;
*/

@interface SaxMethodCallHandler : SaxDefaultHandler
{
  id                  delegate; // non-retained: default=self (for subclasses)
  NSMutableDictionary *namespaceToKey;
  NSMutableArray      *tagStack;
  NSString            *startKey;            // default: 'start_'
  NSString            *endKey;              // default: 'end_'
  NSString            *unknownNamespaceKey; // default: 'any_'
  int                 ignoreLevel;
  
  /* processing */
  NSMapTable      *fqNameToStartSel;
  NSMutableString *selName; /* reused for each construction */
}

/* namespaces */

- (void)registerNamespace:(NSString *)_namespace withKey:(NSString *)_key;

/* keys */

- (void)setStartKey:(NSString *)_s;
- (NSString *)startKey;
- (void)setEndKey:(NSString *)_s;
- (NSString *)endKey;
- (void)setUnknownNamespaceKey:(NSString *)_s;
- (NSString *)unknownNamespaceKey;

/* tag stack */

- (NSArray *)tagStack;
- (unsigned)depth;

- (void)ignoreChildren;
- (BOOL)doesIgnoreChildren;

/* delegate */

- (void)setDelegate:(id)_delegate;
- (id)delegate;

@end

#endif /* __SaxMethodCallHandler_H__ */
