/*
  Copyright (C) 2004 eXtrapola Srl

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

#ifndef __StructuredTextRenderingDelegate_H__
#define __StructuredTextRenderingDelegate_H__

#import <Foundation/NSObject.h>

@class NSString, NSDictionary;

@protocol StructuredTextRenderingDelegate

- (void)appendText:(NSString *)_txt inContext:(NSDictionary *)_ctx;
- (void)beginItalicsInContext:(NSDictionary *)_ctx;
- (void)endItalicsInContext:(NSDictionary *)_ctx;
- (void)beginUnderlineInContext:(NSDictionary *)_ctx;
- (void)endUnderlineInContext:(NSDictionary *)_ctx;
- (void)beginBoldInContext:(NSDictionary *)_ctx;
- (void)endBoldInContext:(NSDictionary *)_ctx;
- (void)beginPreformattedInContext:(NSDictionary *)_ctx;
- (void)endPreformattedInContext:(NSDictionary *)_ctx;
- (void)beginParagraphInContext:(NSDictionary *)_ctx;
- (void)endParagraphInContext:(NSDictionary *)_ctx;
  
- (NSString *)insertLink:(NSString *)_txt 
  withUrl:(NSString *)anUrl target:(NSString *)aTarget 
  inContext:(NSDictionary *)_ctx;

- (NSString *)insertEmail:(NSString *)_txt 
  withAddress:(NSString *)anAddress 
  inContext:(NSDictionary *)_ctx;
- (NSString *)insertImage:(NSString *)_txt 
  withUrl:(NSString *)anUrl 
  inContext:(NSDictionary *)_ctx;

- (NSString *)insertExtrapolaLink:(NSString *)_txt
  parameters:(NSDictionary *)someParameters
  withTarget:(NSString *)aTarget
  inContext:(NSDictionary *)_ctx;

- (NSString *)insertDynamicKey:(NSString *)_txt 
  inContext:(NSDictionary *)_ctx;
- (NSString *)insertPreprocessedTextForKey:(NSString *)aKey 
  inContext:(NSDictionary *)_ctx;

@end

#endif /* __StructuredTextRenderingDelegate_H__ */
