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

#ifndef __StructuredText_H__
#define __StructuredText_H__

#import <Foundation/NSObject.h>
#include "StructuredTextDocument.h"

@class NSString, NSMutableString;
@class StructuredLine, StructuredStack;
@class StructuredTextHeader, StructuredTextParagraph, StructuredTextList;
@class StructuredTextListItem, StructuredTextLiteralBlock;

#define StructuredTextParserLine_Header       0
#define StructuredTextParserLine_Paragraph    1
#define StructuredTextParserLine_List         2
#define StructuredTextParserLine_LiteralBlock 3

@interface StructuredText : NSObject
{
  NSString		 *_text;
  StructuredTextDocument *_document;
  StructuredStack	 *_stack;

  StructuredStack	 *_paragraphs;

#if DISABLE_BUG_FIX
  int			 currentHeaderLevel;
#endif
}

+ (StructuredTextDocument *)parseText:(NSString *)_txt;
- (id)initWithString:(NSString *)_str;

/* accessors */

- (NSString *)text;
- (StructuredTextDocument *)document;
- (StructuredStack *)stack;
- (StructuredStack *)paragraphs;

/* parsing */

- (void)parse;

- (int)lineType:(StructuredLine *)_line;

- (void)separateIntoBlocks;
- (void)adjustLineLevels;
- (void)buildDocument;

- (BOOL)checkForHeader:(StructuredLine *)_line;
- (BOOL)checkForListItem:(StructuredLine *)_line;
- (BOOL)checkForPreformattedStatement:(StructuredLine *)_line;
- (BOOL)checkForPreformattedBlock:(StructuredLine *)_line;

- (StructuredTextHeader *)buildHeader;
- (StructuredTextParagraph *)buildParagraph;
- (StructuredTextLiteralBlock *)buildLiteralBlock;
- (StructuredTextList *)buildList;

- (int)listItemTypology:(StructuredLine *)_line;

@end

#endif /* __StructuredText_H__ */
