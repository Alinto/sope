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

#ifndef __WOHTMLParser_H__
#define __WOHTMLParser_H__

#import <Foundation/NSObject.h>

/*
  WOHTMLParser
  
  This parser parses "old-style" .wo templates. It does *not* process the
  whole HTML of the file, it only searches for text sections which start
  with "<#". That way you can process "illegal" HTML code, eg:

    <a href="<#MyLink" />"> ...

  So the syntax is:
    <#wod-name>...</#wod-name>
*/

@class NSString, NSDictionary, NSArray, NSException, NSData;
@class WOElement;

@protocol WOHTMLParserHandler

- (BOOL)parser:(id)_parser willParseHTMLData:(NSData *)_data;
- (void)parser:(id)_parser finishedParsingHTMLData:(NSData *)_data
  elements:(NSArray *)_elements;
- (void)parser:(id)_parser failedParsingHTMLData:(NSData *)_data
  exception:(NSException *)_exception;

- (WOElement *)dynamicElementWithName:(NSString *)_element
  attributes:(NSDictionary *)_attributes // not the associations !
  contentElements:(NSArray *)_subElements;

@end

@interface WOHTMLParser : NSObject
{
  id<NSObject,WOHTMLParserHandler> callback;
  NSException *parsingException;
}

- (id)initWithHandler:(id<NSObject,WOHTMLParserHandler>)_handler;

/* accessors */

- (NSException *)parsingException;

/* parsing */

- (NSArray *)parseHTMLData:(NSData *)_html;

@end

#endif /* __WOHTMLParser_H__ */
