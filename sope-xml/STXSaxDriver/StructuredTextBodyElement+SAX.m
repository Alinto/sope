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

#include "StructuredTextBodyElement.h"
#include "StructuredTextParagraph.h"
#include "StructuredTextList.h"
#include "StructuredTextListItem.h"
#include "StructuredTextLiteralBlock.h"
#include "StructuredTextHeader.h"
#include "STXSaxDriver.h"
#include "common.h"

@implementation StructuredTextBodyElement(SAX)

@end /* StructuredTextBodyElement(SAX) */

@implementation StructuredTextParagraph(SAX)

- (void)produceSaxEventsOnSTXSaxDriver:(STXSaxDriver *)_sax {
  [_sax produceSaxEventsForParagraph:self];
}

@end /* StructuredTextParagraph(SAX) */

@implementation StructuredTextList(SAX)

- (void)produceSaxEventsOnSTXSaxDriver:(STXSaxDriver *)_sax {
  [_sax produceSaxEventsForList:self];
}

@end /* StructuredTextList(SAX) */

@implementation StructuredTextListItem(SAX)

- (void)produceSaxEventsOnSTXSaxDriver:(STXSaxDriver *)_sax {
  [_sax produceSaxEventsForListItem:self];
}

@end /* StructuredTextListItem(SAX) */

@implementation StructuredTextLiteralBlock(SAX)

- (void)produceSaxEventsOnSTXSaxDriver:(STXSaxDriver *)_sax {
  [_sax produceSaxEventsForLiteralBlock:self];
}

@end /* StructuredTextLiteralBlock(SAX) */

@implementation StructuredTextHeader(SAX)

- (void)produceSaxEventsOnSTXSaxDriver:(STXSaxDriver *)_sax {
  [_sax produceSaxEventsForHeader:self];
}

@end /* StructuredTextHeader(SAX) */
