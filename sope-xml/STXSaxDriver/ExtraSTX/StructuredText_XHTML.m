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

#error does not compile, just for reference!

#include "StructuredText_XHTML.h"
#include "common.h"

@implementation StructuredTextRenderingDelegate_XHTML

- (NSString *)insertText:(NSString *)_txt inContext:(NSDictionary *)_ctx {
  return [NSString stringWithFormat:@"<p>%@</p>", _txt];
}

- (NSString *)insertItalics:(NSString *)_txt inContext:(NSDictionary *)_ctx {
  return [NSString stringWithFormat:
                     @"<span class=\"italics\">%@</span>", _txt];
}

- (NSString *)insertUnderline:(NSString *)_txt inContext:(NSDictionary *)_ctx {
  return [NSString stringWithFormat:
                     @"<span class=\"underline\">%@</span>", _txt];
}

- (NSString *)insertBold:(NSString *)_txt inContext:(NSDictionary *)_ctx {
  return [NSString stringWithFormat:@"<span class=\"bold\">%@</span>", _txt];
}

- (NSString *)insertPreformatted:(NSString *)_txt 
  inContext:(NSDictionary *)_ctx 
{
  return [NSString stringWithFormat:
                     @"<span class=\"preformatted\">%@</span>", _txt];
}

- (NSString *)insertLink:(NSString *)_txt 
  withUrl:(NSString *)anUrl target:(NSString *)aTarget 
  inContext:(NSDictionary *)_ctx 
{
  NSString *result;

  if ([aTarget length] > 0) {
    result = [NSString stringWithFormat:
                         @"<a href=\"%@\" target=\"%@\">%@</a>", 
                         anUrl, aTarget, _txt];
  } 
  else {
    result = [NSString stringWithFormat:@"<a href=\"%@\">%@</a>", anUrl, _txt];
  }
  
  return result;
}

- (NSString *)insertEmail:(NSString *)_txt withAddress:(NSString *)anAddress 
  inContext:(NSDictionary *)_ctx 
{
  return [NSString stringWithFormat:@"<a href=\"%@\">%@</a>", anAddress, _txt];
}

- (NSString *)insertImage:(NSString *)_txt withUrl:(NSString *)anUrl 
  inContext:(NSDictionary *)_ctx 
{
  return [NSString stringWithFormat:@"<img src=\"%@\" title=\"%@\" />", 
                     anUrl, _txt];
}

- (NSString *)insertExtrapolaLink:(NSString *)_txt 
  parameters:(NSDictionary *)someParameters withTarget:(NSString *)aTarget 
  inContext:(NSDictionary *)_ctx 
{
  NSString	*result;
  NSString	*targetString;

	
  if ([aTarget length] > 0)
    targetString = [NSString stringWithFormat:@" target = \"%@\"", aTarget];
  else
    targetString = @"";
  
  result = [NSString stringWithFormat:
                       @"<a href=\"/cgi-bin/WebObjects/NewsX.woa/wa/%@\" %@>%@</a>", 
                     [someParameters objectForKey:@"page"], 
                     targetString, _txt];

  return result;
}

- (NSString *)insertPreprocessedTextForKey:(NSString *)aKey 
  inContext:(NSDictionary *)_ctx 
{
  return [_ctx objectForKey:aKey];
}

@end /* StructuredTextRenderingDelegate_XHTML */

@implementation NSArray (StructuredText_XHTML)

- (NSString *)toXhtmlInContext:(NSDictionary *)_ctx {
  NSMutableString	*result;
  int	i,c;

  c = [self count];
  result = [NSMutableString stringWithCapacity:(c * 16)];
  for (i = 0; i < c; i++) {
    id	currentObject;

    currentObject = [self objectAtIndex:i];
    [result appendString:[currentObject toXhtmlInContext:_ctx]];
  }

  return result;
}

@end

@implementation StructuredText(StructuredText_XHTML)

- (NSString *)toXhtmlInContext:(NSDictionary *)_ctx {
  return [[self document] toXhtmlInContext:_ctx];
}

@end /* StructuredText(StructuredText_XHTML) */

@implementation StructuredTextDocument(StructuredText_XHTML)

- (NSString *)toXhtmlInContext:(NSDictionary *)_ctx {
  return [[self bodyElements] toXhtmlInContext:_ctx];
}

@end /* StructuredTextDocument(StructuredText_XHTML) */

@implementation StructuredTextBodyElement(StructuredText_XHTML)

- (NSString *)toXhtmlInContext:(NSDictionary *)_ctx {
  return [[self elements] toXhtmlInContext:_ctx];
}

@end /* StructuredTextBodyElement(StructuredText_XHTML) */

@implementation StructuredTextHeader(StructuredText_XHTML)

- (NSString *)toXhtmlInContext:(NSDictionary *)_ctx {
  NSMutableString *ms;
  id delegate;
  
  delegate = [StructuredTextRenderingDelegate_XHTML delegate] ;
  
  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<h%d>", [self level]];
  [ms appendString:[self textParsedWithDelegate:delegate inContext:_ctx]];
  [ms appendFormat:@"</h%d>", [self level]];
  
  [ms appendString:[super toXhtmlInContext:_ctx]];
  return ms;
}

@end /* StructuredTextHeader(StructuredText_XHTML) */

@implementation StructuredTextParagraph(StructuredText_XHTML)

- (NSString *)toXhtmlInContext:(NSDictionary *)_ctx {
  id delegate;

  delegate = [StructuredTextRenderingDelegate_XHTML delegate];
  return [self textParsedWithDelegate:delegate inContext:_ctx];
}

@end /* StructuredTextParagraph (StructuredText_XHTML) */

@implementation StructuredTextList(StructuredText_XHTML)

- (NSString *)toXhtmlInContext:(NSDictionary *)_ctx {
  NSString *result;
  NSString *elemText;
  
  elemText = [[self elements] toXhtmlInContext:_ctx];
  
  switch ([self typology]) {
    case StructuredTextList_BULLET: {
      result = [NSString stringWithFormat:@"<ul>%@</ul>", elemText];
      break;
    }
    case StructuredTextList_ENUMERATED: {
      result = [NSString stringWithFormat:@"<ol>%@</ol>", elemText];
      break;
    }
    case StructuredTextList_DEFINITION: {
      result = [NSString stringWithFormat:@"<dl>%@</dl>", elemText];
      break;
    }
    default: {
      result = @"";
      break;
    }
  }
  return result;
}

@end /* StructuredTextList(StructuredText_XHTML) */

@implementation StructuredTextListItem(StructuredText_XHTML)

- (NSString *)toXhtmlInContext:(NSDictionary *)_ctx {
  NSString *result;
  NSString *textParsed;
  NSString *elemText;
  
  elemText   = [[self elements] toXhtmlInContext:_ctx];
  textParsed = [self textParsedWithDelegate:
		       [StructuredTextRenderingDelegate_XHTML delegate] 
		     inContext:_ctx];

  switch ([[self list] typology]) {
  case StructuredTextList_BULLET: {
    result = [NSString stringWithFormat:@"<li>%@%@</li>", 
                       textParsed, elemText];
    break;
  }
  case StructuredTextList_ENUMERATED: {
    result = [NSString stringWithFormat:@"<li>%@%@</li>", 
		       textParsed, elemText];
    break;
  }
  case StructuredTextList_DEFINITION: {
    result = [NSString stringWithFormat:@"<dt>%@</dt><dd>%@</dd>", 
                       [self titleParsedWithDelegate:
                               [StructuredTextRenderingDelegate_XHTML delegate] 
			     inContext:_ctx], 
		       textParsed];
    break;
  }
  default: {
    result = @"";
    break;
  }
  }

  return result;
}

@end /* StructuredTextListItem(StructuredText_XHTML) */

@implementation StructuredTextLiteralBlock(StructuredText_XHTML)

- (NSString *)toXhtmlInContext:(NSDictionary *)_ctx {
  return [NSString stringWithFormat:
                     @"<div class=\"preformatted\">%@</div>", [self text]];
}

@end /* StructuredTextLiteralBlock(StructuredText_XHTML) */
