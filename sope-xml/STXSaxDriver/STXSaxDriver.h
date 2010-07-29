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

#ifndef __ExtraSTX_STXSaxDriver_H__
#define __ExtraSTX_STXSaxDriver_H__

#import <Foundation/NSObject.h>
#include <SaxObjC/SaxObjC.h>

@class NSArray, NSDictionary;
@class SaxAttributes;
@class StructuredTextParagraph, StructuredTextList, StructuredTextListItem;
@class StructuredTextLiteralBlock, StructuredTextHeader;

@interface STXSaxDriver : NSObject < SaxXMLReader >
{
  id<NSObject,SaxContentHandler> contentHandler;
  id<NSObject,SaxErrorHandler>   errorHandler;
  id<NSObject,SaxLexicalHandler> lexicalHandler;
  id<NSObject,SaxEntityResolver> entityResolver;

  NSDictionary  *context;
  SaxAttributes *attrs;
}

/* handlers */

- (void)setContentHandler:(id<NSObject,SaxContentHandler>)_handler;
- (void)setDTDHandler:(id<NSObject,SaxDTDHandler>)_handler;
- (void)setErrorHandler:(id<NSObject,SaxErrorHandler>)_handler;
- (void)setEntityResolver:(id<NSObject,SaxEntityResolver>)_handler;
- (id<NSObject,SaxContentHandler>)contentHandler;
- (id<NSObject,SaxDTDHandler>)dtdHandler;
- (id<NSObject,SaxErrorHandler>)errorHandler;
- (id<NSObject,SaxEntityResolver>)entityResolver;

/* parsing */

- (void)parseFromSource:(id)_source systemId:(NSString *)_sysId;

/* generating events */

- (void)produceSaxEventsForParagraph:(StructuredTextParagraph *)_p;
- (void)produceSaxEventsForList:(StructuredTextList *)_list;
- (void)produceSaxEventsForListItem:(StructuredTextListItem *)_item;
- (void)produceSaxEventsForLiteralBlock:(StructuredTextLiteralBlock *)_block;
- (void)produceSaxEventsForHeader:(StructuredTextHeader *)_header;

- (void)produceSaxEventsForElement:(id)_element;
- (void)produceSaxEventsForElements:(NSArray *)_elems;

@end

#endif /* __ExtraSTX_STXSaxDriver_H__ */
