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

#include "StructuredText.h"
#include "StructuredLine.h"
#include "StructuredStack.h"

#include "StructuredTextHeader.h"
#include "StructuredTextParagraph.h"
#include "StructuredTextList.h"
#include "StructuredTextListItem.h"
#include "StructuredTextLiteralBlock.h"

#include "common.h"
#include <ctype.h>

@implementation StructuredText

- (id)initWithString:(NSString *)_str {
  if ((self = [super init])) {
    self->_text = [_str copy];
  }
  return self;
}

- (void)dealloc {
  [self->_text       release];
  [self->_document   release];
  [self->_stack      release];
  [self->_paragraphs release];
  [super dealloc];
}

/* factory */

+ (StructuredTextDocument *)parseText:(NSString *)aText {
  StructuredText *text;
  
  // TODO: shouldn't we release the object?
  text = [[StructuredText alloc] initWithString:aText];
  
  return [text document];
}

/* accessors */

- (NSString *)text {
  return _text;
}

- (StructuredTextDocument *)document {
  if (self->_document)
    return self->_document;

  self->_document = [[StructuredTextDocument alloc] init];
  [self parse];
  return _document;
}

- (StructuredStack *)stack {
  if (self->_stack == nil)
    self->_stack = [[StructuredStack alloc] init];
  
  return self->_stack;
}

- (StructuredStack *)paragraphs {
  if (self->_paragraphs == nil)
    self->_paragraphs = [[StructuredStack alloc] init];
  
  return self->_paragraphs;
}

- (void)parse {
#if DISABLE_BUG_FIX
  currentHeaderLevel = 1;
#endif
  
  [self separateIntoBlocks];
  [self adjustLineLevels];
  [self buildDocument];
}

- (void)separateIntoBlocks {
  NSArray	  *lines;
  StructuredStack *pars;
  NSString	  *text, *currentLine, *trimmedLine;
  NSMutableString *buf;
  NSCharacterSet  *set;
  int i, count;
  
  set   = [NSCharacterSet characterSetWithCharactersInString:@"\r"];
  buf   = [NSMutableString stringWithCapacity:256];
  text  = [self text];
  pars  = [self paragraphs];

  lines = [text componentsSeparatedByString:@"\n"];
  count = [lines count];
  
  for (i = 0; i < count; i++) {
    currentLine = [lines objectAtIndex:i];
    currentLine = [currentLine stringByTrimmingCharactersInSet:set];
    trimmedLine = [currentLine stringByTrimmingCharactersInSet:
				 [NSCharacterSet whitespaceCharacterSet]];
    
    if ([trimmedLine length] > 0) {
      if ([buf length] > 0)
        [buf appendString:@"\n"];
      
      [buf appendString:currentLine];
    }
    else {
      if ([buf length] > 0) {
	StructuredLine *sl;

	sl = [[StructuredLine alloc]
	       initWithString:[NSString stringWithString:buf]
	       level:0];;
        [pars push:sl];
	// TODO: shouldn't we release the object?
      }

      [buf setString:@""];
    }
  }

  if ([buf length] > 0) {
    StructuredLine *sl;
    
    sl = [[StructuredLine alloc]
	   initWithString:[NSString stringWithString:buf] level:0];
    [pars push:sl];
    // TODO: shouldn't we release the object?
  }
}

- (void)adjustLineLevels {
  StructuredStack	*paragraphs;
  StructuredStack	*stack;
  StructuredLine	*line;
  StructuredLine	*lastParagraph = nil;
  int level = 0;

  stack = [self stack];
  [stack setCursorFollowsFIFO:YES];

  paragraphs = [self paragraphs];
  [paragraphs first];

  while ((line = [paragraphs nextObject])) {
    StructuredLine *tmpLine;
    
    while ((tmpLine = [stack currentObject])) {
      if ([line numberOfSpacesAtBeginning]>[tmpLine numberOfSpacesAtBeginning])
        break;
      
      [stack pop];
      level--;
    }

    if (!tmpLine)
      level = 0;
    
    switch ([self lineType:line]) {
    case StructuredTextParserLine_Header:
      [line setLevel:level++];
      [stack push:line];
      break;
    case StructuredTextParserLine_Paragraph:
      lastParagraph = line;
    case StructuredTextParserLine_LiteralBlock:
      [line setLevel:level];
      break;
    case StructuredTextParserLine_List: {
      [line setLevel:level++];
      [stack push:line];
      break;
    }
    }
  }

  [stack removeAllObjects];
}

- (void)buildDocument {
  StructuredTextDocument *document;
  StructuredStack	 *paragraphs;
  StructuredStack	 *stack, *objectStack;
  StructuredLine	 *line;
  
  document = [self document];

  stack = [self stack];
  [stack setCursorFollowsFIFO:YES];

  paragraphs = [self paragraphs];
  [paragraphs first];

  objectStack = [[StructuredStack alloc] init];
  [objectStack setCursorFollowsFIFO:YES];

  while ((line = [paragraphs currentObject])) {
    StructuredLine *tmpLine;
    id object = nil;

    switch ([self lineType:line]) {
    case StructuredTextParserLine_Header:
      object = [self buildHeader];
#if DISABLE_BUG_FIX
      currentHeaderLevel++;
#endif
      break;
    case StructuredTextParserLine_Paragraph:
      object = [self buildParagraph];
      //NSLog(@"par %@", [object text]);
      break;
    case StructuredTextParserLine_LiteralBlock:
      object = [self buildLiteralBlock];
      break;
    case StructuredTextParserLine_List:
      object = [self buildList];
      break;
    }

    if (object != nil) {
      StructuredTextBodyElement *body;

      body = [objectStack currentObject];

      if (body && [body respondsToSelector:@selector(addElement:)])
        [body addElement:object];
      else
        [document addBodyElement:object];
      
      if ([object isKindOfClass:[StructuredTextHeader class]]
          /* || [object isKindOfClass:[StructuredTextList class]] */) {
        while ((tmpLine = [stack currentObject])) {
          id currentObject;

          if ([line level] > [tmpLine level])
            break;
	  
          [stack pop];
          currentObject = [objectStack pop];

#if DISABLE_BUG_FIX
          if ([currentObject isKindOfClass:[StructuredTextHeader class]])
            currentHeaderLevel--;
#endif
        }

        [objectStack push:object];
        [stack push:line];
      }
    }
    
    [paragraphs nextObject];
  }

  [objectStack release];
}

- (int)lineType:(StructuredLine *)aLine {
  if ([self checkForListItem:aLine])
    return StructuredTextParserLine_List;
  
  if ([self checkForHeader:aLine]) {
    return [self checkForPreformattedStatement:aLine]
      ? StructuredTextParserLine_Paragraph
      : StructuredTextParserLine_Header;
  } 
  
  if ([self checkForPreformattedBlock:aLine])
    return StructuredTextParserLine_LiteralBlock;

  return StructuredTextParserLine_Paragraph;
}

- (BOOL)checkForHeader:(StructuredLine *)aLine {
  StructuredLine *nextLine;

  nextLine = [[self paragraphs] objectRelativeToCursorAtIndex:1];
  
  if (nextLine == nil)
    return NO;
  
  if ([nextLine numberOfSpacesAtBeginning]>[aLine numberOfSpacesAtBeginning])
    return YES;
  
  return NO;
}

- (BOOL)checkForListItem:(StructuredLine *)aLine {
  return ([self listItemTypology:aLine] == NSNotFound) ? NO : YES;
}

- (BOOL)checkForPreformattedStatement:(StructuredLine *)aLine {
  NSString *s;
  
  if (aLine == nil)
    return NO;
  
  s = [aLine text];
  s = [s stringByTrimmingCharactersInSet:
	   [NSCharacterSet whitespaceCharacterSet]];
  return [s hasSuffix:@"::"];
}

- (BOOL)checkForPreformattedBlock:(StructuredLine *)aLine {
  id stmt;
  
  stmt = [[self paragraphs] objectRelativeToCursorAtIndex:-1];
  return [self checkForPreformattedStatement:stmt] ? YES : NO;
}

- (StructuredTextHeader *)buildHeader {
  StructuredTextHeader *result;
  StructuredLine       *line;
  
  line = [[self paragraphs] currentObject];
  
#if DISABLE_BUG_FIX
  result = [[StructuredTextHeader alloc] initWithString:[line text] 
					 level:currentHeaderLevel];
#else
  result = [[StructuredTextHeader alloc] initWithString:[line text] 
                                         level:([line level] + 1)];
#endif
  return [result autorelease];
}

- (StructuredTextParagraph *)buildParagraph {
  StructuredTextParagraph	*result;
  StructuredLine			*line;
  NSString				*text;

  line = [[self paragraphs] currentObject];
  text = [line text];
  
  if ([[text stringByTrimmingCharactersInSet:
	       [NSCharacterSet whitespaceCharacterSet]] hasSuffix:@"::"]) {
    int length;

    length = [text length];
    text   = [text substringToIndex:length - 2];
  }
  
  result = [[StructuredTextParagraph alloc] initWithString:text];
  return [result autorelease];
}

- (StructuredTextLiteralBlock *)buildLiteralBlock {
  StructuredTextLiteralBlock *result;
  StructuredLine             *line;
  NSString *s;
  
  line = [[self paragraphs] currentObject];
  
  s = [[line originalText] stringByAppendingString:@"\n"];
  result = [[StructuredTextLiteralBlock alloc] initWithString:s];
  return [result autorelease];
}

- (StructuredTextList *)buildList {
  StructuredTextList	 *result;
  StructuredLine	 *line, *prevLine = nil;
  StructuredTextListItem *item = nil;
  StructuredStack	 *paragraphs;
  int type;
  
  result     = nil;
  paragraphs = [self paragraphs];
  line       = [paragraphs currentObject];
  
  while (line != nil) {
    NSString	*text, *title;

    text = [line text];
    title = nil;

    type = [self listItemTypology:line];

    if (type == NSNotFound) {
      [paragraphs prevObject];
      break;
    }

    if (!result)
      result = [[StructuredTextList alloc] initWithTypology:type];
    else if ([result typology] != type)
      break;

    if (prevLine) {
      if ([line level] > [prevLine level]) {
        if (item) {
          [item addElement:[self buildList]];

          line = [paragraphs currentObject];

          continue;
        }
      } else if ([line level] < [prevLine level]) {
        return result;
      }
    }

    switch (type) {
    case StructuredTextList_BULLET:
      text = [text substringFromIndex:2];
      break;
    case StructuredTextList_DEFINITION: {
      NSArray *components;
      int i, count;

      components = [text componentsSeparatedByString:@" -- "];
      count = [components count];

      title = [components objectAtIndex:0];

      if (count > 2) {
        NSMutableString *buffer;
	
        buffer = [NSMutableString stringWithCapacity:(count * 8)];
	
        for (i = 1; i < count; i++) {
          if (i > 1) {
            [buffer appendString:@" -- "];
          }

          [buffer appendString:[components objectAtIndex:i]];
        }

        text = buffer;
      } 
      else
        text = [components objectAtIndex:1];
      
      break;
    }
    case StructuredTextList_ENUMERATED: {
      NSRange range;

      range = [text rangeOfString:@" "];
      if (range.length > 0)
        text = [text substringFromIndex:range.location + 1];
      
      break;
    }
    }

    item = [[StructuredTextListItem alloc] initWithTitle:title text:text];
    [result addElement:item];
    [item release];

    prevLine = line;
    line = [paragraphs nextObject];
  }

  return [result autorelease];
}

- (int)listItemTypology:(StructuredLine *)aLine {
  NSString *text;
  int      type = NSNotFound;
  int      i, h, length;
  NSRange  range;

  text = [aLine text];

  if ([text hasPrefix:@"* "])
    return StructuredTextList_BULLET;
  
  range = [text rangeOfString:@" -- "];
  if (range.length > 0 && range.length == 4)
    return StructuredTextList_DEFINITION;
  
  for (i = h = 0, length = [text length]; i < length; i++) {
    if (!isdigit([text characterAtIndex:i]))
      break;
    
    h++;
  }
  
  if (h > 0)
    type = StructuredTextList_ENUMERATED;
  
  return type;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  if (self->_text) [ms appendFormat:@" text-len=%d", [self->_text length]];
  if (self->_document)
    [ms appendFormat:@" document=%@", self->_document];

#if DISABLE_BUG_FIX
  [ms appendFormat:@" headerlevel=%i", self->currentHeaderLevel];
#endif
  
  [ms appendString:@">"];
  return ms;
}

@end /* StructuredText */
