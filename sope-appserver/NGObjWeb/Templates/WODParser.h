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

#ifndef __WODParser_H__
#define __WODParser_H__

#import <Foundation/NSObject.h>

@class NSString, NSDictionary, NSException, NSData;

@protocol WODParserHandler

- (BOOL)parser:(id)_parser willParseDeclarationData:(NSData *)_data;
- (void)parser:(id)_parser finishedParsingDeclarationData:(NSData *)_data
  declarations:(NSDictionary *)_decls;
- (void)parser:(id)_parser failedParsingDeclarationData:(NSData *)_data
  exception:(NSException *)_exception;

- (id)parser:(id)_parser makeAssociationWithValue:(id)_value;
- (id)parser:(id)_parser makeAssociationWithKeyPath:(NSString *)_keyPath;
- (id)parser:(id)_parser makeDefinitionForComponentNamed:(NSString *)_cname
  associations:(id)_entry
  elementName:(NSString *)_elemName;

@end

@interface WODParser : NSObject
{
  id<WODParserHandler,NSObject> callback;
}

- (id)initWithHandler:(id<WODParserHandler,NSObject>)_handler;

/* parsing */

- (NSDictionary *)parseDeclarationData:(NSData *)_decl;

@end

#endif /* __WODParser_H__ */
